import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cpu_strategy.dart';
import 'game_loop.dart';
import 'game_rules.dart';
import 'game_state.dart';
import '../rank_progression.dart';
import '../profile/match_persistence.dart';
import '../profile/match_contracts.dart';

part 'game_controller.g.dart';

/// Kept as a Random provider so callers of the PR #3 API can continue to
/// inject `Random(seed)` directly.  GameRules receives the value as an
/// explicit argument and does not retain global randomness.
final randomProvider = Provider<Random>((ref) => Random());

/// CPU timing and decision-quality streams are separate from map generation
/// and from each other.  Tests and spectator-mode callers can seed each
/// stream independently without changing the other series.
final cpuTimingRandomProvider = Provider<Random>((ref) => Random());
final cpuQualityRandomProvider = Provider<Random>((ref) => Random());
final playerCpuRandomProvider = Provider<Random>((ref) => Random());
final playerCpuQualityRandomProvider = Provider<Random>((ref) => Random());

final gameConfigurationProvider = Provider<GameConfiguration>(
  (ref) => GameConfiguration.initial,
);

final gameRulesProvider = Provider<GameRules>((ref) => const GameRules());
final gameSessionOriginProvider = Provider<SessionOrigin>(
  (ref) => SessionOrigin.gameplay,
);

/// The renderer supplies the SafeArea-sized layout viewport before the
/// controller is created.  Keeping it as a provider makes the map generator
/// and Home use one source of truth without coupling GameRules to Flutter.
final mapViewportProvider = Provider<IslandMapViewport>(
  (ref) => GameRules.defaultMapViewport,
);

/// The standard CPU is injectable as a whole so deterministic tests can use
/// a seeded strategy or a no-op strategy without changing the game engine.
final cpuStrategyProvider = Provider<CpuStrategy>((ref) {
  return CpuStrategy(
    timingRandom: ref.read(cpuTimingRandomProvider),
    qualityRandom: ref.read(cpuQualityRandomProvider),
    rules: ref.read(gameRulesProvider),
    viewport: ref.watch(mapViewportProvider),
  );
});

final playerCpuStrategyProvider = Provider<CpuStrategy>((ref) {
  return CpuStrategy(
    controlledFaction: Faction.player,
    timingRandom: ref.read(playerCpuRandomProvider),
    qualityRandom: ref.read(playerCpuQualityRandomProvider),
    rules: ref.read(gameRulesProvider),
    viewport: ref.watch(mapViewportProvider),
  );
});

enum RematchUnavailableReason { missingSnapshot, viewportTooSmall }

/// Session-only immutable starting board, independent of the placement cache.
final class _MatchStartSnapshot {
  _MatchStartSnapshot(GameState state)
    : configuration = state.configuration,
      islands = List.unmodifiable(state.islands);

  final GameConfiguration configuration;
  final List<IslandState> islands;

  GameState restore() => GameState(
    configuration: configuration,
    islands: islands,
    phase: GamePhase.configuration,
    elapsedMs: 0,
  );
}

@riverpod
class GameController extends _$GameController {
  late GameLoop _gameLoop;
  late Random _random;
  late GameClock _clock;
  late GameRules _rules;
  late Map<Faction, CpuStrategy> _cpuStrategies;

  var _disposed = false;
  int? _lastTickMs;
  final Map<Faction, int> _nextCpuDecisionAtMsByFaction = {};
  IslandMapViewport? _cachedViewport;
  // Movement uses the actual board, not the conservative placement envelope.
  // Do not replace this with an invalid viewport while a match is held.
  IslandMapViewport? _movementViewport;
  GameConfiguration? _cachedConfiguration;
  GameState? _cachedInitialState;
  _MatchStartSnapshot? _matchStartSnapshot;
  String? _currentMatchId;
  MatchPersistence? _persistence;
  bool _finalizationSubmitted = false;

  String? get currentMatchId => _currentMatchId;
  MatchSaveState? get currentSave => _persistence?.saveFor(_currentMatchId);
  bool get canStartMatch =>
      !_disposed &&
      (state.configuration.gameMode == GameMode.cpuVsCpu ||
          (_persistence?.canStart ?? true));

  static const _interactionFeedbackDurationMs = 1500;

  @override
  GameState build() {
    // Riverpod may invoke the disposal callbacks while rebuilding this
    // notifier after a watched viewport changes.  A completed rebuild is a
    // live controller again; the final disposal still leaves this true.
    _disposed = false;
    _persistence = ref.read(matchPersistenceProvider);
    final persistence = _persistence;
    persistence?.addListener(_applyReceipt);
    _gameLoop = ref.read(gameLoopProvider);
    _random = ref.read(randomProvider);
    _clock = ref.read(gameClockProvider);
    _rules = ref.read(gameRulesProvider);
    _cpuStrategies = {
      Faction.player: ref.read(playerCpuStrategyProvider),
      Faction.cpu: ref.read(cpuStrategyProvider),
    };
    final viewport = ref.watch(mapViewportProvider);
    final providerConfiguration = ref.read(gameConfigurationProvider);
    ref.onDispose(() {
      persistence?.removeListener(_applyReceipt);
      _disposed = true;
      _gameLoop.stop();
    });

    final previousState = stateOrNull;
    // The provider supplies the initial match configuration. Once a state
    // exists, its configuration is the match's source of truth so viewport
    // rebuilds cannot replace a user-selected island count.
    final configuration = previousState?.configuration ?? providerConfiguration;
    if (previousState != null &&
        previousState.phase != GamePhase.configuration) {
      final isActivePhase = switch (previousState.phase) {
        GamePhase.startCountdown ||
        GamePhase.playing ||
        GamePhase.resumeCountdown => true,
        GamePhase.configuration ||
        GamePhase.paused ||
        GamePhase.result => false,
      };
      final canContinueMatch =
          isActivePhase || previousState.phase == GamePhase.paused;
      if (canContinueMatch &&
          (!viewport.isMovementValid ||
              !viewport.canRenderIslands(previousState.islands))) {
        // Keep every match value exactly as-is while the window is too small
        // for the existing rectangles. The UI presents an explicit enlarge
        // and resume action once the same map can be rendered again.
        _gameLoop.stop();
        _lastTickMs = null;
        return previousState.copyWith(viewportUnavailable: true);
      }
      if (canContinueMatch && previousState.viewportUnavailable) {
        // A safe resize does not implicitly resume a match that was held for
        // an unsafe resize. The user must explicitly choose Resume.
        _gameLoop.stop();
        _lastTickMs = null;
        return previousState;
      }
      final nextState = canContinueMatch
          ? _replanForViewport(previousState, viewport)
          : previousState;
      final shouldResumeLoop =
          previousState.phase == GamePhase.startCountdown ||
          previousState.phase == GamePhase.resumeCountdown ||
          previousState.phase == GamePhase.playing;
      if (shouldResumeLoop && !_gameLoop.isRunning) {
        // A dependency rebuild runs the disposal callback before build. Keep
        // an in-progress match or countdown alive by resuming its loop after
        // rebuilding. Reset the wall-clock baseline so time spent rebuilding
        // cannot advance the game past the countdown boundary.
        _lastTickMs = _clock.nowMs();
        _gameLoop.start(_tick);
      }
      return nextState;
    }

    if (previousState != null &&
        previousState.phase == GamePhase.configuration &&
        previousState.viewportUnavailable) {
      // A tutorial can restore the original map while the current viewport
      // is too small to show it. Keep that map held through later resizes;
      // the explicit Resume action clears this hold, while a normal island
      // count change still calls _initialStateFor and generates a new map.
      return previousState;
    }

    if (viewport.isMovementValid) _movementViewport = viewport;
    return _initialStateFor(configuration: configuration, viewport: viewport);
  }

  /// Starts a match and the production/manual loop.
  ///
  /// The generated map remains visible while [GamePhase.startCountdown] is
  /// active.  The rules engine does not advance game time, move forces, grow
  /// islands, or run CPU decisions during that phase; the first playing tick
  /// after the countdown is the shared start boundary for every subsystem.
  void startGame() {
    if (!canStartMatch ||
        _disposed ||
        state.viewportUnavailable ||
        state.phase == GamePhase.playing ||
        (state.phase == GamePhase.configuration &&
            state.islands.length != state.configuration.totalIslandCount)) {
      return;
    }

    final nextState = switch (state.phase) {
      GamePhase.configuration => _startNewMatch(),
      GamePhase.paused => _rules.resumeCountdown(state),
      _ => state,
    };
    if (nextState == state) {
      return;
    }

    state = nextState;
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  void pauseGame() {
    if (_disposed ||
        (state.phase != GamePhase.playing &&
            state.phase != GamePhase.startCountdown &&
            state.phase != GamePhase.resumeCountdown)) {
      return;
    }
    state = _rules.pause(state);
    _gameLoop.stop();
    _lastTickMs = null;
  }

  void resumeGame() {
    if (state.viewportUnavailable) {
      resumeAfterViewportChange();
      return;
    }
    if (_disposed || state.phase != GamePhase.paused) {
      return;
    }
    final nextState = _rules.resumeCountdown(state);
    if (nextState == state) {
      return;
    }
    state = nextState;
    // Game time is frozen while paused, so preserve the pending judgment's
    // absolute game-time deadline across resume.  A null deadline only occurs
    // after a rebuilt controller and needs a fresh injected interval.
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  /// Resumes a match that was held because a resized window could not safely
  /// display its existing map. Returning to a safe size only enables this
  /// action; it never starts the loop automatically.
  void resumeAfterViewportChange() {
    if (_disposed || !state.viewportUnavailable) return;
    final viewport = ref.read(mapViewportProvider);
    if (!viewport.isMovementValid ||
        !viewport.canRenderIslands(state.islands)) {
      return;
    }

    state = _replanForViewport(
      state,
      viewport,
    ).copyWith(viewportUnavailable: false);
    if (state.phase == GamePhase.paused) {
      resumeGame();
      return;
    }
    if (state.phase != GamePhase.startCountdown &&
        state.phase != GamePhase.resumeCountdown &&
        state.phase != GamePhase.playing) {
      return;
    }
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  GameState _replanForViewport(GameState current, IslandMapViewport viewport) {
    if (!viewport.isMovementValid || _movementViewport == viewport) {
      return current;
    }
    final replanned = _rules.replanMovingForces(current, viewport: viewport);
    _movementViewport = viewport;
    return replanned;
  }

  void finish(GameResult result) {
    if (_disposed) {
      return;
    }
    final nextState = _rules.finish(state, result);
    if (nextState == state) {
      return;
    }
    _gameLoop.stop();
    _lastTickMs = null;
    _clearCpuDecisionDeadlines();
    _submitCompletion(nextState);
    state = nextState;
  }

  /// Leaves the current match and shows the island-count configuration again.
  ///
  /// Explicitly abandoning a played match is recorded. Returning creates
  /// a fresh map, clears all transient match state, and leaves the loop
  /// stopped until the player starts another match.
  void returnToConfiguration() {
    if (_disposed ||
        (state.phase != GamePhase.paused && state.phase != GamePhase.result)) {
      return;
    }

    _gameLoop.stop();
    _lastTickMs = null;
    _clearCpuDecisionDeadlines();
    if (state.phase == GamePhase.paused &&
        _currentMatchId != null &&
        !_finalizationSubmitted) {
      _finalizationSubmitted = true;
      unawaited(_persistence!.abandon(_currentMatchId!, state.matchSummary));
    }
    _currentMatchId = null;
    _matchStartSnapshot = null;
    state = _newInitialStateFor(
      configuration: state.configuration,
      viewport: ref.read(mapViewportProvider),
    );
  }

  /// Alias matching the action's user-facing wording.
  void returnToSettings() => returnToConfiguration();

  /// Starts a new match with the same island count and a newly generated map.
  void replayGame() {
    if (!canStartMatch || _disposed || state.phase != GamePhase.result) {
      return;
    }

    final initial = _newInitialStateFor(
      configuration: state.configuration,
      viewport: ref.read(mapViewportProvider),
    );
    if (initial.islands.length != state.configuration.totalIslandCount) {
      // Map generation can fail closed for a viewport that cannot fit all
      // islands. Never start a zero-island replay, which would otherwise
      // resolve immediately as a draw.
      _gameLoop.stop();
      _clearCpuDecisionDeadlines();
      _lastTickMs = null;
      _matchStartSnapshot = null;
      state = initial;
      return;
    }
    state = _countdownForNewMatch(initial);
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  GameState _startNewMatch() {
    return _countdownForNewMatch(state);
  }

  GameState _countdownForNewMatch(GameState initial) {
    final viewport = ref.read(mapViewportProvider);
    if (viewport.isMovementValid) _movementViewport = viewport;
    _matchStartSnapshot = _MatchStartSnapshot(initial);
    _beginNewMatch();
    _clearCpuDecisionDeadlines();
    return _rules.startCountdown(initial);
  }

  RematchUnavailableReason? get rematchUnavailableReason {
    if (_disposed) return RematchUnavailableReason.missingSnapshot;
    final snapshot = _matchStartSnapshot;
    if (snapshot == null ||
        snapshot.islands.length != snapshot.configuration.totalIslandCount) {
      return RematchUnavailableReason.missingSnapshot;
    }
    if (!ref.read(mapViewportProvider).canRenderIslands(snapshot.islands)) {
      return RematchUnavailableReason.viewportTooSmall;
    }
    return null;
  }

  /// Restores the starting board without consuming map-generation randomness.
  void rematchGame() {
    if (!canStartMatch ||
        _disposed ||
        state.phase != GamePhase.result ||
        rematchUnavailableReason != null) {
      return;
    }
    state = _countdownForNewMatch(_matchStartSnapshot!.restore());
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  void _beginNewMatch() {
    _currentMatchId = null;
    _finalizationSubmitted = false;
  }

  void _recordFirstPlaying(GameConfiguration configuration) {
    _currentMatchId ??= _persistence?.begin(
      configuration,
      origin: ref.read(gameSessionOriginProvider),
    );
  }

  void _submitCompletion(GameState finished) {
    final id = _currentMatchId;
    if (id == null || _finalizationSubmitted || finished.result == null) return;
    _finalizationSubmitted = true;
    unawaited(
      _persistence!.finish(
        id,
        result: finished.result!,
        summary: finished.matchSummary,
      ),
    );
  }

  void _applyReceipt() {
    if (_disposed || stateOrNull == null || state.phase != GamePhase.result)
      return;
    final receipt = currentSave?.receipt;
    if (receipt == null ||
        receipt.record.start.matchId != _currentMatchId ||
        state.result == null)
      return;
    if (state.result!.totalXpAfter != null) return;
    final before = RankProgress.fromTotalXp(receipt.totalXpBefore);
    final after = RankProgress.fromTotalXp(receipt.totalXpAfter);
    state = state.finishWithResult(
      state.result!.copyWith(
        xpAwarded: receipt.xpAwarded,
        rankBefore: before.rank,
        rankAfter: after.rank,
        totalXpBefore: receipt.totalXpBefore,
        totalXpAfter: receipt.totalXpAfter,
      ),
    );
  }

  /// Compatibility alias for callers that name the replay action restart.
  void restartGame() => replayGame();

  /// Changes the selected island count before a match starts and regenerates
  /// only the typed initial state.  Concrete map placement remains a later
  /// concern; this operation simply makes the setting representable now.
  void selectIslandCount(int totalIslandCount) {
    if (_disposed || state.phase != GamePhase.configuration) {
      return;
    }
    if (!GameConfiguration.isValidIslandCount(totalIslandCount) ||
        totalIslandCount == state.configuration.totalIslandCount) {
      return;
    }
    final configuration = state.configuration.copyWith(
      totalIslandCount: totalIslandCount,
    );
    state = _initialStateFor(
      configuration: configuration,
      viewport: ref.read(mapViewportProvider),
    );
  }

  /// Changes the selected CPU difficulty before a match starts without
  /// regenerating the currently displayed map.
  void selectCpuDifficulty(CpuDifficulty difficulty) {
    if (_disposed || state.phase != GamePhase.configuration) {
      return;
    }
    if (state.configuration.cpuDifficulty == difficulty) {
      return;
    }

    _updateConfigurationWithoutRegeneratingMap(
      state.configuration.copyWith(cpuDifficulty: difficulty),
    );
  }

  /// Selects the standard player-versus-CPU or CPU-versus-CPU mode before a
  /// match starts. The current generated map remains visible while settings
  /// change, so mode selection does not consume map-generation randomness.
  void selectGameMode(GameMode mode) {
    if (_disposed || state.phase != GamePhase.configuration) {
      return;
    }
    if (state.configuration.gameMode == mode) {
      return;
    }
    _updateConfigurationWithoutRegeneratingMap(
      state.configuration.copyWith(gameMode: mode),
    );
  }

  /// Selects the 1P CPU difficulty used by spectator matches. The value is
  /// retained when switching back to the standard mode.
  void selectPlayerCpuDifficulty(CpuDifficulty difficulty) {
    if (_disposed || state.phase != GamePhase.configuration) {
      return;
    }
    if (state.configuration.playerCpuDifficulty == difficulty) {
      return;
    }
    _updateConfigurationWithoutRegeneratingMap(
      state.configuration.copyWith(playerCpuDifficulty: difficulty),
    );
  }

  void _updateConfigurationWithoutRegeneratingMap(
    GameConfiguration configuration,
  ) {
    final updated = state.copyWith(configuration: configuration);
    state = updated;

    // Configuration-only changes keep the map itself intact. Keep the cache's
    // key and value in sync so the next provider rebuild does not regenerate a
    // map from an already-advanced random source.
    _cachedConfiguration = configuration;
    _cachedViewport = _placementViewport(ref.read(mapViewportProvider));
    _cachedInitialState = updated;
  }

  GameState _initialStateFor({
    required GameConfiguration configuration,
    required IslandMapViewport viewport,
  }) {
    final placementViewport = _placementViewport(viewport);
    if (_cachedInitialState != null &&
        _cachedConfiguration == configuration &&
        _cachedViewport == placementViewport) {
      return _cachedInitialState!;
    }

    final nextState =
        _rules.tryInitialState(
          configuration: configuration,
          random: _random,
          viewport: placementViewport,
        ) ??
        GameState(
          configuration: configuration,
          phase: GamePhase.configuration,
          elapsedMs: 0,
        );
    _cachedConfiguration = configuration;
    _cachedViewport = placementViewport;
    _cachedInitialState = nextState;
    return nextState;
  }

  GameState _newInitialStateFor({
    required GameConfiguration configuration,
    required IslandMapViewport viewport,
  }) {
    final placementViewport = _placementViewport(viewport);
    final nextState =
        _rules.tryInitialState(
          configuration: configuration,
          random: _random,
          viewport: placementViewport,
        ) ??
        GameState(
          configuration: configuration,
          phase: GamePhase.configuration,
          elapsedMs: 0,
        );
    _cachedConfiguration = configuration;
    _cachedViewport = placementViewport;
    _cachedInitialState = nextState;
    return nextState;
  }

  /// Restores the configuration map that was visible before the optional
  /// tutorial opened. The tutorial owns its own session, so a viewport change
  /// while it is visible must not consume a new map-generation result for the
  /// normal match. An unsafe viewport keeps the restored map held until the
  /// player enlarges the window.
  void restoreConfigurationAfterTutorial({
    required GameState state,
    required IslandMapViewport viewport,
  }) {
    if (_disposed || state.phase != GamePhase.configuration) return;
    _gameLoop.stop();
    _lastTickMs = null;
    _clearCpuDecisionDeadlines();
    _matchStartSnapshot = null;
    final viewportUnavailable = !viewport.canRenderIslands(state.islands);
    final restored = state.copyWith(viewportUnavailable: viewportUnavailable);
    _cachedConfiguration = restored.configuration;
    _cachedViewport = _placementViewport(viewport);
    _cachedInitialState = restored;
    this.state = restored;
  }

  IslandMapViewport _placementViewport(IslandMapViewport viewport) {
    // A tablet-sized logical window must be safe after swapping width and
    // height. Keep narrower phone-sized layouts on their existing placement
    // contract; an unusually small resizable window is still checked against
    // the actual viewport before a match can continue.
    return min(viewport.width, viewport.height) >= 600
        ? viewport.orientationSafePlacementViewport
        : viewport;
  }

  /// Selects a player island or dispatches a new force to the tapped island.
  /// Every successful dispatch is appended to the in-flight force list so an
  /// earlier troop cannot be retargeted or cancelled.
  void tapBase(int baseId) {
    if (_disposed ||
        state.viewportUnavailable ||
        state.phase != GamePhase.playing ||
        state.configuration.gameMode != GameMode.playerVsCpu) {
      return;
    }

    final selectedIslandId = state.selectedIslandId;
    final selectedSource = selectedIslandId == null
        ? null
        : _findIsland(selectedIslandId);
    if (selectedIslandId != null &&
        (selectedSource == null ||
            selectedSource.faction != Faction.player ||
            selectedSource.currentForces <= 1)) {
      state = state.clearSelection();
      _showInteractionFeedback(InteractionFeedbackType.invalidatedSource);
      return;
    }

    final tappedIsland = _findIsland(baseId);
    if (tappedIsland == null) {
      return;
    }

    if (selectedIslandId == null) {
      if (tappedIsland.faction != Faction.player ||
          tappedIsland.currentForces <= 1) {
        _showInteractionFeedback(InteractionFeedbackType.unavailableSource);
        return;
      }
      state = state
          .copyWith(selectedIslandId: baseId)
          .clearInteractionFeedback();
      return;
    }

    if (selectedIslandId == baseId) {
      state = state.clearSelection().clearInteractionFeedback();
      return;
    }

    final source = selectedSource!;
    final strength = _rules.dispatchStrength(source);
    if (strength <= 0) {
      state = state.clearSelection();
      _showInteractionFeedback(InteractionFeedbackType.invalidatedSource);
      return;
    }

    final islands = [...state.islands];
    final sourceIndex = islands.indexWhere((island) => island.id == source.id);
    islands[sourceIndex] = _rules.dispatchSource(source);

    final movingForces = [...state.movingForces];
    final nextForce = _rules.createMovingForce(
      id: _nextMovingForceId,
      faction: Faction.player,
      source: source,
      destination: tappedIsland,
      strength: strength,
      departureTimeMs: state.elapsedMs,
      viewport: ref.read(mapViewportProvider),
    );
    movingForces.add(nextForce);

    state = state
        .copyWith(
          islands: islands,
          movingForces: movingForces,
          matchSummary: state.matchSummary.recordDispatch(strength),
        )
        .clearSelection()
        .clearInteractionFeedback();
  }

  void _tick() {
    if (_disposed ||
        state.viewportUnavailable ||
        state.phase == GamePhase.paused) {
      return;
    }

    final now = _clock.nowMs();
    final previous = _lastTickMs;
    _lastTickMs = now;

    // Timer callbacks and manual callbacks have the same semantics.  A clock
    // with fixed time intentionally falls back to one 50ms engine step so the
    // original ManualGameLoop tests remain useful; advancing a fake clock uses
    // its exact delta instead.
    final measuredDelta = _clock is SystemGameClock || previous == null
        ? 0
        : now - previous;
    final deltaMs = measuredDelta > 0 ? measuredDelta : 50;
    final phaseBeforeTick = state.phase;
    final selectedBeforeTick = state.selectedIslandId;
    final nextState = _rules.tick(state, deltaMs: deltaMs);
    if (phaseBeforeTick == GamePhase.startCountdown &&
        nextState.phase == GamePhase.playing) {
      _recordFirstPlaying(nextState.configuration);
    }
    if (nextState.phase == GamePhase.result) {
      _gameLoop.stop();
      _lastTickMs = null;
      _clearCpuDecisionDeadlines();
      _submitCompletion(nextState);
      state = nextState;
      return;
    }
    state = nextState;
    if (phaseBeforeTick == GamePhase.playing &&
        selectedBeforeTick != null &&
        state.selectedIslandId == null &&
        state.phase == GamePhase.playing) {
      _showInteractionFeedback(InteractionFeedbackType.invalidatedSource);
    }
    if (state.interactionFeedback != null &&
        state.elapsedMs >= state.interactionFeedbackUntilMs) {
      state = state.clearInteractionFeedback();
    }
    if (state.phase == GamePhase.playing) {
      if (phaseBeforeTick == GamePhase.startCountdown) {
        // The initial match has no pending CPU deadline yet.  A resume
        // countdown intentionally skips this branch so its frozen, absolute
        // deadline remains unchanged across the pause interval.
        for (final faction in _activeCpuFactions) {
          _scheduleNextCpuDecision(faction);
        }
      }
      _runCpuDecisionIfDue();
    }
  }

  Iterable<Faction> get _activeCpuFactions =>
      state.configuration.gameMode == GameMode.cpuVsCpu
      ? const [Faction.player, Faction.cpu]
      : const [Faction.cpu];

  CpuDifficulty _difficultyFor(Faction faction) => switch (faction) {
    Faction.player => state.configuration.playerCpuDifficulty,
    Faction.cpu => state.configuration.cpuDifficulty,
    Faction.neutral => throw ArgumentError.value(faction, 'faction'),
  };

  void _scheduleNextCpuDecision(Faction faction) {
    final strategy = _cpuStrategies[faction];
    if (strategy == null) return;
    _nextCpuDecisionAtMsByFaction[faction] =
        state.elapsedMs +
        strategy.nextDecisionDelayMs(difficulty: _difficultyFor(faction));
  }

  void _clearCpuDecisionDeadlines() {
    _nextCpuDecisionAtMsByFaction.clear();
  }

  void _runCpuDecisionIfDue() {
    final active = _activeCpuFactions.toList(growable: false);
    for (final faction in active) {
      _nextCpuDecisionAtMsByFaction.putIfAbsent(
        faction,
        () =>
            state.elapsedMs +
            _cpuStrategies[faction]!.nextDecisionDelayMs(
              difficulty: _difficultyFor(faction),
            ),
      );
    }

    final due = [
      for (final faction in const [Faction.player, Faction.cpu])
        if (active.contains(faction) &&
            state.elapsedMs >= _nextCpuDecisionAtMsByFaction[faction]!)
          faction,
    ];
    if (due.isEmpty) return;

    // All decisions in one tick use the exact same post-rule-tick state.
    // Applying the collected decisions afterwards prevents the stable order
    // from affecting the other CPU's choice.
    final snapshot = state;
    final decisions = [
      for (final faction in due)
        (
          faction: faction,
          decision: _cpuStrategies[faction]!.decide(
            snapshot,
            difficulty: _difficultyFor(faction),
          ),
        ),
    ];
    for (final entry in decisions) {
      final decision = entry.decision;
      if (decision != null) {
        state = _cpuStrategies[entry.faction]!.applyDecision(
          state,
          decision,
          movingForceId: _nextMovingForceId,
        );
      }
    }
    for (final faction in due) {
      // Schedule from current game time rather than an old deadline. This
      // prevents catch-up bursts after a delayed callback.
      _scheduleNextCpuDecision(faction);
    }
  }

  IslandState? _findIsland(int id) {
    for (final island in state.islands) {
      if (island.id == id) {
        return island;
      }
    }
    return null;
  }

  int get _nextMovingForceId {
    var maxId = -1;
    for (final force in state.movingForces) {
      maxId = max(maxId, force.id);
    }
    return maxId + 1;
  }

  void _showInteractionFeedback(InteractionFeedbackType message) {
    state = state.copyWith(
      interactionFeedback: message,
      interactionFeedbackUntilMs:
          state.elapsedMs + _interactionFeedbackDurationMs,
    );
  }
}
