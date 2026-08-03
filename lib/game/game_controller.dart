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

@riverpod
class GameController extends _$GameController {
  late final GameLoop _gameLoop;
  late final Random _random;
  late final GameClock _clock;
  late final GameRules _rules;

  var _disposed = false;
  int? _lastTickMs;

  @override
  GameState build() {
    _gameLoop = ref.read(gameLoopProvider);
    _random = ref.read(randomProvider);
    _clock = ref.read(gameClockProvider);
    _rules = ref.read(gameRulesProvider);
    ref.onDispose(() {
      _disposed = true;
      _gameLoop.stop();
    });

    return _rules.initialState(
      configuration: ref.read(gameConfigurationProvider),
      random: _random,
    );
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
    state = _rules.initialState(configuration: configuration, random: _random);
  }

  /// Selects a player island and creates (or retargets the legacy first)
  /// moving force.  The state itself supports any number of forces; retaining
  /// the first-force retarget behavior keeps the PR #3 interaction intact.
  void tapBase(int baseId) {
    if (_disposed || state.phase != GamePhase.playing) {
      return;
    }

    final selectedIslandId = state.selectedIslandId;
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

    final source = _findIsland(selectedIslandId);
    if (source == null ||
        source.faction != Faction.player ||
        source.currentForces <= 1) {
      state = state.clearSelection();
      return;
    }

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

    final existingIndex = state.movingForces.indexWhere(
      (force) => force.sourceIslandId == source.id,
    );
    final movingForces = [...state.movingForces];
    final nextForce = _rules.createMovingForce(
      id: existingIndex >= 0
          ? movingForces[existingIndex].id
          : _nextMovingForceId,
      faction: Faction.player,
      source: source,
      destination: tappedIsland,
      strength: strength,
      departureTimeMs: state.elapsedMs,
    );
    if (existingIndex >= 0) {
      movingForces[existingIndex] = nextForce;
    } else {
      movingForces.add(nextForce);
    }

    state = state.copyWith(
      islands: islands,
      movingForces: movingForces,
      selectedIslandId: baseId == source.id ? null : selectedIslandId,
    );
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
