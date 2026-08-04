import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'game_loop.dart';
import 'game_rules.dart';
import 'game_state.dart';

part 'game_controller.g.dart';

/// Kept as a Random provider so callers of the PR #3 API can continue to
/// inject `Random(seed)` directly.  GameRules receives the value as an
/// explicit argument and does not retain global randomness.
final randomProvider = Provider<Random>((ref) => Random());

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

@riverpod
class GameController extends _$GameController {
  late GameLoop _gameLoop;
  late Random _random;
  late GameClock _clock;
  late GameRules _rules;

  var _disposed = false;
  int? _lastTickMs;
  IslandMapViewport? _cachedViewport;
  GameConfiguration? _cachedConfiguration;
  GameState? _cachedInitialState;

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
    final providerConfiguration = ref.read(gameConfigurationProvider);
    ref.onDispose(() {
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
      _cachedViewport = viewport;
      if (previousState.phase == GamePhase.playing && !_gameLoop.isRunning) {
        // A dependency rebuild runs the disposal callback before build. Keep
        // an in-progress match alive by resuming its loop after rebuilding.
        _lastTickMs = _clock.nowMs();
        _gameLoop.start(_tick);
      }
      return previousState;
    }

    return _initialStateFor(configuration: configuration, viewport: viewport);
  }

  /// Starts a match and the production/manual loop.  The first screen in
  /// PR #3 started immediately on tap; the countdown phase remains available
  /// through [GameRules.startCountdown] while this compatibility entry point
  /// keeps that startup behavior unchanged.
  void startGame() {
    if (_disposed || state.phase == GamePhase.playing) {
      return;
    }

    final nextState = switch (state.phase) {
      GamePhase.configuration => _rules.startCountdown(state),
      GamePhase.paused => _rules.resumeCountdown(state),
      _ => state,
    };
    if (nextState == state) {
      return;
    }

    // Preserve the existing tap-to-play behavior.  Consumers that need a
    // visible countdown can apply GameRules.tick to the same state instead.
    state = nextState.copyWith(
      phase: GamePhase.playing,
      countdownRemainingMs: 0,
    );
    _lastTickMs = _clock.nowMs();
    _gameLoop.start(_tick);
  }

  void pauseGame() {
    if (_disposed || state.phase != GamePhase.playing) {
      return;
    }
    state = _rules.pause(state);
    _gameLoop.stop();
    _lastTickMs = null;
  }

  void resumeGame() {
    if (_disposed || state.phase != GamePhase.paused) {
      return;
    }
    final nextState = _rules.resumeCountdown(state);
    if (nextState == state) {
      return;
    }
    // See startGame: preserve the established immediate-resume UI behavior.
    state = nextState.copyWith(
      phase: GamePhase.playing,
      countdownRemainingMs: 0,
    );
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
    _gameLoop.stop();
    _lastTickMs = null;
  }

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

  GameState _initialStateFor({
    required GameConfiguration configuration,
    required IslandMapViewport viewport,
  }) {
    if (_cachedInitialState != null &&
        _cachedConfiguration == configuration &&
        _cachedViewport == viewport) {
      return _cachedInitialState!;
    }

    final nextState =
        _rules.tryInitialState(
          configuration: configuration,
          random: _random,
          viewport: viewport,
        ) ??
        GameState(
          configuration: configuration,
          phase: GamePhase.configuration,
          elapsedMs: 0,
        );
    _cachedConfiguration = configuration;
    _cachedViewport = viewport;
    _cachedInitialState = nextState;
    return nextState;
  }

  /// Selects a player island or dispatches a new force to the tapped island.
  /// Every successful dispatch is appended to the in-flight force list so an
  /// earlier troop cannot be retargeted or cancelled.
  void tapBase(int baseId) {
    if (_disposed || state.phase != GamePhase.playing) {
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
      return;
    }

    final tappedIsland = _findIsland(baseId);
    if (tappedIsland == null) {
      return;
    }

    if (selectedIslandId == null) {
      if (tappedIsland.faction != Faction.player ||
          tappedIsland.currentForces <= 1) {
        return;
      }
      state = state.copyWith(selectedIslandId: baseId);
      return;
    }

    if (selectedIslandId == baseId) {
      state = state.clearSelection();
      return;
    }

    final source = selectedSource!;
    final strength = source.currentForces ~/ 2;
    if (strength <= 0) {
      state = state.clearSelection();
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
    );
    movingForces.add(nextForce);

    state = state
        .copyWith(islands: islands, movingForces: movingForces)
        .clearSelection();
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
    state = _rules.tick(state, deltaMs: deltaMs);
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
}
