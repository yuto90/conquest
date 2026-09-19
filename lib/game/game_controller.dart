import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cpu_strategy.dart';
import 'game_loop.dart';
import 'game_rules.dart';
import 'game_state.dart';
import 'very_hard_cpu.dart';
import '../rank_progression.dart';

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

/// Same-origin gateway client. Tests replace this provider with a deterministic
/// fake so normal Flutter tests never call Jev.
final veryHardCpuGatewayProvider = Provider<VeryHardCpuGateway>((ref) {
  final gateway = HttpVeryHardCpuGateway();
  ref.onDispose(gateway.close);
  return gateway;
});

@riverpod
class GameController extends _$GameController {
  late GameLoop _gameLoop;
  late Random _random;
  late GameClock _clock;
  late GameRules _rules;
  late Map<Faction, CpuStrategy> _cpuStrategies;
  late VeryHardCpuGateway _veryHardCpuGateway;
  VeryHardCpuCoordinator? _veryHardCpuCoordinator;

  var _disposed = false;
  int? _lastTickMs;
  final Map<Faction, int> _nextCpuDecisionAtMsByFaction = {};
  IslandMapViewport? _cachedViewport;
  GameConfiguration? _cachedConfiguration;
  GameState? _cachedInitialState;
  var _matchSerial = 0;
  var _currentMatchId = 'match-0';
  var _rankRewardGranted = false;
  var _veryHardRequestGeneration = 0;
  var _veryHardBatchPending = false;
  Future<void>? _veryHardPreflight;

  static const _interactionFeedbackDurationMs =
      VeryHardCpuConfig.debugFallbackNoticeDurationMs;

  @override
  GameState build() {
    // Riverpod may invoke the disposal callbacks while rebuilding this
    // notifier after a watched viewport changes.  A completed rebuild is a
    // live controller again; the final disposal still leaves this true.
    _disposed = false;
    _gameLoop = ref.read(gameLoopProvider);
    _random = ref.read(randomProvider);
    _clock = ref.read(gameClockProvider);
    _rules = ref.read(gameRulesProvider);
    final viewport = ref.watch(mapViewportProvider);
    _cpuStrategies = {
      Faction.player: ref.read(playerCpuStrategyProvider),
      Faction.cpu: ref.read(cpuStrategyProvider),
    };
    _veryHardCpuGateway = ref.read(veryHardCpuGatewayProvider);
    final existingCoordinator = _veryHardCpuCoordinator;
    if (existingCoordinator == null ||
        !identical(existingCoordinator.gateway, _veryHardCpuGateway)) {
      _veryHardCpuCoordinator = VeryHardCpuCoordinator(
        gateway: _veryHardCpuGateway,
        candidateGenerator: VeryHardCandidateGenerator(
          rules: _rules,
          viewport: viewport,
        ),
      );
    } else {
      existingCoordinator.updateViewport(viewport);
    }
    final providerConfiguration = ref.read(gameConfigurationProvider);
    ref.onDispose(() {
      _disposed = true;
      _veryHardRequestGeneration++;
      _veryHardBatchPending = false;
      _gameLoop.stop();
    });

    final previousState = stateOrNull;
    // The provider supplies the initial match configuration. Once a state
    // exists, its configuration is the match's source of truth so viewport
    // rebuilds cannot replace a user-selected island count.
    final configuration = previousState?.configuration ?? providerConfiguration;
    if (previousState != null &&
        previousState.phase != GamePhase.configuration) {
      _cachedViewport = viewport;
      final isActivePhase = switch (previousState.phase) {
        GamePhase.startCountdown ||
        GamePhase.playing ||
        GamePhase.resumeCountdown => true,
        GamePhase.configuration ||
        GamePhase.paused ||
        GamePhase.result => false,
      };
      if (isActivePhase && !viewport.canRenderIslands(previousState.islands)) {
        // Keep every match value exactly as-is while the window is too small
        // for the existing rectangles. The UI presents an explicit enlarge
        // and resume action once the same map can be rendered again.
        _gameLoop.stop();
        _lastTickMs = null;
        return previousState.copyWith(viewportUnavailable: true);
      }
      if (isActivePhase && previousState.viewportUnavailable) {
        // A safe resize does not implicitly resume a match that was held for
        // an unsafe resize. The user must explicitly choose Resume.
        _gameLoop.stop();
        _lastTickMs = null;
        return previousState;
      }
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
      return previousState;
    }

    return _initialStateFor(configuration: configuration, viewport: viewport);
  }

  /// Starts a match and the production/manual loop.
  ///
  /// The generated map remains visible while [GamePhase.startCountdown] is
  /// active.  The rules engine does not advance game time, move forces, grow
  /// islands, or run CPU decisions during that phase; the first playing tick
  /// after the countdown is the shared start boundary for every subsystem.
  Future<void> startGame() async {
    if (_disposed ||
        state.phase == GamePhase.playing ||
        (state.phase == GamePhase.configuration &&
            state.islands.length != state.configuration.totalIslandCount)) {
      return;
    }

    if (state.requiresVeryHardPreflight &&
        state.veryHardPreflightStatus != VeryHardPreflightStatus.available) {
      final existing = _veryHardPreflight;
      if (existing != null) {
        await existing;
        return;
      }
      state = state.copyWith(
        veryHardPreflightStatus: VeryHardPreflightStatus.checking,
      );
      final matchId = _currentMatchId;
      final generation = _veryHardRequestGeneration;
      final operation = _runVeryHardPreflight(matchId, generation);
      _veryHardPreflight = operation;
      try {
        await operation;
      } finally {
        if (identical(_veryHardPreflight, operation)) {
          _veryHardPreflight = null;
        }
      }
      return;
    }

    _startGameAfterPreflight();
  }

  void cancelPendingStart() {
    if (_disposed ||
        state.phase != GamePhase.configuration ||
        _veryHardPreflight == null) {
      return;
    }

    _veryHardRequestGeneration++;
    _veryHardPreflight = null;
    state = state.copyWith(
      veryHardPreflightStatus: _preflightStatusFor(state.configuration),
    );
  }

  Future<void> _runVeryHardPreflight(String matchId, int generation) async {
    late VeryHardPreflightResult result;
    try {
      result = await _veryHardCpuGateway
          .preflight(matchId: matchId)
          .timeout(VeryHardCpuConfig.preflightTimeout);
    } on Object catch (error) {
      result = VeryHardPreflightResult.unavailable(error.toString());
    }
    if (_disposed ||
        state.phase != GamePhase.configuration ||
        _currentMatchId != matchId ||
        _veryHardRequestGeneration != generation ||
        !state.requiresVeryHardPreflight) {
      return;
    }
    if (!result.available) {
      state = state.copyWith(
        veryHardPreflightStatus: VeryHardPreflightStatus.unavailable,
      );
      return;
    }
    state = state.copyWith(
      veryHardPreflightStatus: VeryHardPreflightStatus.available,
    );
    _startGameAfterPreflight();
  }

  void _startGameAfterPreflight() {
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
    _veryHardRequestGeneration++;
    _veryHardBatchPending = false;
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
    if (!viewport.canRenderIslands(state.islands)) return;

    state = state.copyWith(viewportUnavailable: false);
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

  void finish(GameResult result) {
    if (_disposed) {
      return;
    }
    final nextState = _rules.finish(state, result);
    if (nextState == state) {
      return;
    }
    state = nextState;
    _veryHardRequestGeneration++;
    _veryHardBatchPending = false;
    _gameLoop.stop();
    _lastTickMs = null;
    _clearCpuDecisionDeadlines();
    _awardRankForResult(result);
  }

  /// Leaves the current match and shows the island-count configuration again.
  ///
  /// A match is intentionally not persisted.  Returning to settings creates
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
    _veryHardRequestGeneration++;
    _veryHardBatchPending = false;
    _rankRewardGranted = false;
    state = _newInitialStateFor(
      configuration: state.configuration,
      viewport: ref.read(mapViewportProvider),
    );
  }

  /// Alias matching the action's user-facing wording.
  void returnToSettings() => returnToConfiguration();

  /// Starts a new match with the same island count and a newly generated map.
  Future<void> replayGame() async {
    if (_disposed || state.phase != GamePhase.result) {
      return;
    }

    _veryHardRequestGeneration++;
    _veryHardBatchPending = false;

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
      state = initial;
      return;
    }
    final countdown = _rules.startCountdown(initial);
    if (initial.requiresVeryHardPreflight) {
      state = initial;
      await startGame();
      return;
    }
    _beginNewMatch();
    state = countdown;
    _clearCpuDecisionDeadlines();
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  GameState _startNewMatch() {
    _beginNewMatch();
    return _rules.startCountdown(state);
  }

  void _beginNewMatch() {
    _matchSerial++;
    _currentMatchId = 'match-$_matchSerial';
    _rankRewardGranted = false;
    _veryHardRequestGeneration++;
    _veryHardBatchPending = false;
  }

  bool _isRankEligible(GameConfiguration configuration, GameResult result) {
    return configuration.gameMode == GameMode.playerVsCpu &&
        result.type == GameResultType.victory &&
        result.winner == Faction.player;
  }

  Future<void> _awardRankForMatch({
    required String matchId,
    required CpuDifficulty difficulty,
  }) async {
    try {
      final award = await ref
          .read(rankProgressProvider.notifier)
          .recordVictory(matchId: matchId, difficulty: difficulty);
      if (_disposed ||
          _currentMatchId != matchId ||
          state.phase != GamePhase.result ||
          state.result == null) {
        return;
      }
      if (award.xpAwarded == 0 || state.result!.xpAwarded != 0) return;
      state = state.finishWithResult(
        state.result!.copyWith(
          xpAwarded: award.xpAwarded,
          rankBefore: award.before.rank,
          rankAfter: award.after.rank,
          totalXpBefore: award.before.totalXp,
          totalXpAfter: award.after.totalXp,
        ),
      );
    } catch (_) {
      // Rank progression must never make a completed match unusable. The
      // manager already keeps the loaded value in memory when storage fails.
    }
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
    if (!GameConfiguration.isValidIslandCount(totalIslandCount)) {
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
    final updated = state.copyWith(
      configuration: configuration,
      veryHardPreflightStatus: _preflightStatusFor(configuration),
    );
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
    final withPreflightStatus = nextState.copyWith(
      veryHardPreflightStatus: _preflightStatusFor(configuration),
    );
    _cachedConfiguration = configuration;
    _cachedViewport = placementViewport;
    _cachedInitialState = withPreflightStatus;
    return withPreflightStatus;
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
    final withPreflightStatus = nextState.copyWith(
      veryHardPreflightStatus: _preflightStatusFor(configuration),
    );
    _cachedConfiguration = configuration;
    _cachedViewport = placementViewport;
    _cachedInitialState = withPreflightStatus;
    return withPreflightStatus;
  }

  VeryHardPreflightStatus _preflightStatusFor(GameConfiguration configuration) {
    final requiresPreflight =
        configuration.cpuDifficulty == CpuDifficulty.veryHard ||
        (configuration.gameMode == GameMode.cpuVsCpu &&
            configuration.playerCpuDifficulty == CpuDifficulty.veryHard);
    return requiresPreflight
        ? VeryHardPreflightStatus.notChecked
        : VeryHardPreflightStatus.notRequired;
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
    final strength = source.currentForces ~/ 2;
    if (strength <= 0) {
      state = state.clearSelection();
      _showInteractionFeedback(InteractionFeedbackType.invalidatedSource);
      return;
    }

    final islands = [...state.islands];
    final sourceIndex = islands.indexWhere((island) => island.id == source.id);
    islands[sourceIndex] = source.copyWith(
      currentForces: source.currentForces - strength,
    );

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
    if (_disposed || state.phase == GamePhase.paused) {
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
    if (nextState.phase == GamePhase.result) {
      _gameLoop.stop();
      _lastTickMs = null;
      _clearCpuDecisionDeadlines();
      final result = nextState.result;
      if (result != null) _awardRankForResult(result);
    }
  }

  void _awardRankForResult(GameResult result) {
    if (!_isRankEligible(state.configuration, result) || _rankRewardGranted) {
      return;
    }
    _rankRewardGranted = true;
    _awardRankForMatch(
      difficulty: state.configuration.cpuDifficulty,
      matchId: _currentMatchId,
    );
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
    // A mixed spectator batch is intentionally held together while the
    // asynchronous Very Hard decision is in flight.  Otherwise the local
    // CPU would get a head start while Jev is still evaluating the same
    // snapshot.
    if (_veryHardBatchPending) return;

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
    final snapshot = state;
    final localDue = [
      for (final faction in due)
        if (_difficultyFor(faction) != CpuDifficulty.veryHard) faction,
    ];
    final veryHardDue = [
      for (final faction in due)
        if (_difficultyFor(faction) == CpuDifficulty.veryHard) faction,
    ];
    final localDecisions = <Faction, CpuDecision?>{
      for (final faction in localDue)
        faction: _cpuStrategies[faction]!.decide(
          snapshot,
          difficulty: _difficultyFor(faction),
        ),
    };
    final coordinator = _veryHardCpuCoordinator;
    if (veryHardDue.isNotEmpty) {
      if (coordinator == null) {
        // The coordinator is normally created with the controller. Keep the
        // local Hard-equivalent fallback deterministic if construction ever
        // fails, while still applying the complete due batch atomically.
        final fallbackDecisions = <Faction, CpuDecision?>{
          ...localDecisions,
          for (final faction in veryHardDue)
            faction: _cpuStrategies[faction]!.decide(
              snapshot,
              difficulty: CpuDifficulty.hard,
            ),
        };
        final batchFactions = [
          for (final faction in const [Faction.player, Faction.cpu])
            if (due.contains(faction)) faction,
        ];
        _applyCpuDecisionBatch(
          factions: batchFactions,
          decisions: fallbackDecisions,
        );
        for (final faction in batchFactions) {
          _scheduleNextCpuDecision(faction);
        }
        return;
      }
      if (coordinator.hasInFlightRequest) return;

      _veryHardBatchPending = true;
      final batchFactions = [
        for (final faction in const [Faction.player, Faction.cpu])
          if (due.contains(faction)) faction,
      ];
      _startVeryHardDecision(
        snapshot,
        veryHardDue,
        batchFactions: batchFactions,
        localDecisions: localDecisions,
      );
      return;
    }

    _applyCpuDecisionBatch(factions: localDue, decisions: localDecisions);
    for (final faction in localDue) {
      // Schedule from current game time rather than an old deadline. This
      // prevents catch-up bursts after a delayed callback.
      _scheduleNextCpuDecision(faction);
    }
  }

  void _applyCpuDecisionBatch({
    required List<Faction> factions,
    required Map<Faction, CpuDecision?> decisions,
  }) {
    for (final faction in const [Faction.player, Faction.cpu]) {
      if (!factions.contains(faction)) continue;
      final decision = decisions[faction];
      if (decision != null) {
        state = _cpuStrategies[faction]!.applyDecision(
          state,
          decision,
          movingForceId: _nextMovingForceId,
        );
      }
    }
  }

  void _startVeryHardDecision(
    GameState snapshot,
    List<Faction> veryHardFactions, {
    required List<Faction> batchFactions,
    required Map<Faction, CpuDecision?> localDecisions,
  }) {
    final generation = _veryHardRequestGeneration;
    final matchId = _currentMatchId;
    unawaited(() async {
      try {
        final coordinator = _veryHardCpuCoordinator;
        if (coordinator == null) return;
        final outcome = await coordinator.decide(
          state: snapshot,
          matchId: matchId,
          factions: veryHardFactions,
          fallback: (faction) => _cpuStrategies[faction]!.decide(
            state,
            difficulty: CpuDifficulty.hard,
          ),
        );
        if (outcome.skipped ||
            _disposed ||
            generation != _veryHardRequestGeneration ||
            matchId != _currentMatchId ||
            state.phase != GamePhase.playing) {
          return;
        }

        // Decisions were selected from [snapshot], but applyDecision checks
        // the current source forces and phase again. This revalidation keeps
        // a delayed response from dispatching a stale move. The fixed order
        // is preserved even when the local CPU is part of this batch.
        _applyCpuDecisionBatch(
          factions: batchFactions,
          decisions: {...localDecisions, ...outcome.decisions},
        );
        if (outcome.usedFallback && kDebugMode) {
          _showInteractionFeedback(InteractionFeedbackType.veryHardFallback);
        }
        if (state.phase == GamePhase.playing) {
          // A mixed batch gets one fresh deadline per faction after both
          // decisions have been applied from the same snapshot.
          for (final faction in batchFactions) {
            _scheduleNextCpuDecision(faction);
          }
        }
      } finally {
        _veryHardBatchPending = false;
      }
    }());
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
