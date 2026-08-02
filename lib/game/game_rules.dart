import 'dart:math' as math;

import 'game_state.dart';

/// Pure, deterministic game-state transitions.
///
/// The class has no Riverpod, timer, or Flutter dependency.  Callers provide
/// the current state and a delta (and, when creating a map, a [math.Random])
/// and receive a new immutable state.  Concrete dispatch, combat, CPU, and
/// map-generation rules remain deliberately outside this foundation.
final class GameRules {
  const GameRules();

  static const startCountdownDurationMs = 3000;
  static const movementDurationMs = 5000;

  GameState initialState({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
  }) {
    return GameState(
      configuration: configuration,
      phase: GamePhase.configuration,
      elapsedMs: 0,
      islands: generateIslands(configuration: configuration, random: random),
      selectedIslandId: null,
      movingForces: const <MovingForce>[],
      result: null,
      countdownRemainingMs: 0,
    );
  }

  /// Alias useful to callers that treat the rules object as a state factory.
  GameState createInitialState({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
  }) {
    return initialState(configuration: configuration, random: random);
  }

  List<IslandState> generateIslands({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
  }) {
    final source = random ?? math.Random();
    final neutralSizes = _neutralSizes(configuration.totalIslandCount);
    return [
      const IslandState(
        id: 0,
        position: IslandPosition(x: 1, y: 1),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 100,
        durability: 0,
        capacity: 200,
      ),
      const IslandState(
        id: 1,
        position: IslandPosition(x: -1, y: -1),
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 100,
        durability: 0,
        capacity: 200,
      ),
      for (var id = 2; id < configuration.totalIslandCount; id++)
        _neutralIsland(id: id, size: neutralSizes[id - 2], random: source),
    ];
  }

  /// Returns whether a phase change is valid without mutating any state.
  bool canTransition(GamePhase from, GamePhase to) {
    if (from == to) {
      return true;
    }
    return switch (from) {
      GamePhase.configuration => to == GamePhase.startCountdown,
      GamePhase.startCountdown => to == GamePhase.playing,
      GamePhase.playing => to == GamePhase.paused || to == GamePhase.result,
      GamePhase.paused =>
        to == GamePhase.resumeCountdown || to == GamePhase.configuration,
      GamePhase.resumeCountdown => to == GamePhase.playing,
      GamePhase.result => to == GamePhase.configuration,
    };
  }

  /// Applies a phase transition, returning the original state for an invalid
  /// request.  This makes UI commands idempotent while [canTransition]
  /// remains available for validation and tests.
  GameState transitionTo(GameState state, GamePhase target) {
    if (!canTransition(state.phase, target) ||
        (target == GamePhase.result && state.result == null)) {
      return state;
    }

    final nextState = state.copyWith(
      phase: target,
      countdownRemainingMs:
          target == GamePhase.startCountdown ||
              target == GamePhase.resumeCountdown
          ? startCountdownDurationMs
          : 0,
    );
    return target == GamePhase.result ? nextState : nextState.clearResult();
  }

  GameState startCountdown(
    GameState state, {
    int durationMs = startCountdownDurationMs,
  }) {
    if (state.phase != GamePhase.configuration) {
      return state;
    }
    return state
        .copyWith(
          phase: GamePhase.startCountdown,
          countdownRemainingMs: math.max(0, durationMs),
        )
        .clearResult();
  }

  GameState resumeCountdown(
    GameState state, {
    int durationMs = startCountdownDurationMs,
  }) {
    if (state.phase != GamePhase.paused) {
      return state;
    }
    return state
        .copyWith(
          phase: GamePhase.resumeCountdown,
          countdownRemainingMs: math.max(0, durationMs),
        )
        .clearResult();
  }

  GameState pause(GameState state) {
    return transitionTo(state, GamePhase.paused);
  }

  GameState finish(GameState state, GameResult result) {
    if (state.phase != GamePhase.playing) {
      return state;
    }
    return transitionTo(state.copyWith(result: result), GamePhase.result);
  }

  /// Advances countdowns and the time-based foundation state.
  GameState tick(GameState state, {required int deltaMs}) {
    if (deltaMs < 0) {
      throw ArgumentError.value(deltaMs, 'deltaMs', 'must not be negative');
    }

    if (state.phase == GamePhase.startCountdown ||
        state.phase == GamePhase.resumeCountdown) {
      final remaining = math.max(0, state.countdownRemainingMs - deltaMs);
      return state.copyWith(
        phase: remaining == 0 ? GamePhase.playing : state.phase,
        countdownRemainingMs: remaining,
      );
    }

    if (state.phase != GamePhase.playing || deltaMs == 0) {
      return state;
    }

    final elapsedMs = state.elapsedMs + deltaMs;
    var islands = [...state.islands];

    // Resource ticks are represented here as a deterministic time boundary;
    // concrete ownership/combat rules can later replace this helper without
    // changing controller or loop orchestration.
    final resourceTicks = elapsedMs ~/ 1000 - state.elapsedMs ~/ 1000;
    for (var tick = 0; tick < resourceTicks; tick++) {
      islands = [
        for (final island in islands)
          island.copyWith(
            currentForces: math.min(island.capacity, island.currentForces + 1),
          ),
      ];
    }

    final remainingForces = <MovingForce>[];
    for (final force in state.movingForces) {
      final duration = math.max(1, force.durationMs);
      final nextProgress = math.min(1.0, force.progress + deltaMs / duration);
      if (nextProgress >= 1.0) {
        final targetIndex = islands.indexWhere(
          (island) => island.id == force.destinationIslandId,
        );
        if (targetIndex >= 0) {
          final target = islands[targetIndex];
          islands[targetIndex] = target.copyWith(
            currentForces: math.min(
              target.capacity,
              target.currentForces + force.strength,
            ),
          );
        }
        continue;
      }

      final source = islands.firstWhere(
        (island) => island.id == force.sourceIslandId,
        orElse: () => const IslandState(
          id: 0,
          position: IslandPosition(x: 0, y: 0),
          faction: Faction.neutral,
        ),
      );
      final target = islands.firstWhere(
        (island) => island.id == force.destinationIslandId,
        orElse: () => source,
      );
      final nextPosition = IslandPosition(
        x: source.x + (target.x - source.x) * nextProgress,
        y: source.y + (target.y - source.y) * nextProgress,
      );
      remainingForces.add(
        force.copyWith(
          position: nextPosition,
          progress: nextProgress,
          deltaX: target.x - source.x,
          deltaY: target.y - source.y,
        ),
      );
    }

    final nextState = state.copyWith(
      elapsedMs: elapsedMs,
      islands: islands,
      movingForces: remainingForces,
    );
    return remainingForces.isEmpty ? nextState.clearSelection() : nextState;
  }

  MovingForce createMovingForce({
    required int id,
    required Faction faction,
    required IslandState source,
    required IslandState destination,
    required int strength,
    int departureTimeMs = 0,
  }) {
    final distance = math.sqrt(
      math.pow(destination.x - source.x, 2) +
          math.pow(destination.y - source.y, 2),
    );
    final durationMs = math.max(
      1,
      (movementDurationMs * distance / math.sqrt(8)).round(),
    );
    return MovingForce(
      id: id,
      faction: faction,
      sourceIslandId: source.id,
      destinationIslandId: destination.id,
      strength: strength,
      position: source.position,
      departureTimeMs: departureTimeMs,
      arrivalTimeMs: departureTimeMs + durationMs,
      durationMs: durationMs,
      progress: 0,
      deltaX: destination.x - source.x,
      deltaY: destination.y - source.y,
    );
  }

  static IslandState _neutralIsland({
    required int id,
    required IslandSize size,
    required math.Random random,
  }) {
    return IslandState(
      id: id,
      position: IslandPosition(
        x: _randomCoordinate(random),
        y: _randomCoordinate(random),
      ),
      faction: Faction.neutral,
      size: size,
      currentForces: 0,
      durability: size.neutralDurability ?? 0,
      capacity: size.capacity,
    );
  }

  static double _randomCoordinate(math.Random random) {
    return random.nextBool() ? random.nextDouble() : random.nextDouble() - 1;
  }

  static List<IslandSize> _neutralSizes(int totalIslandCount) {
    return switch (totalIslandCount) {
      6 => const [
        IslandSize.small,
        IslandSize.small,
        IslandSize.medium,
        IslandSize.medium,
      ],
      8 => const [
        IslandSize.small,
        IslandSize.small,
        IslandSize.medium,
        IslandSize.medium,
        IslandSize.large,
        IslandSize.large,
      ],
      10 => const [
        IslandSize.small,
        IslandSize.small,
        IslandSize.small,
        IslandSize.small,
        IslandSize.medium,
        IslandSize.medium,
        IslandSize.large,
        IslandSize.large,
      ],
      12 => const [
        IslandSize.small,
        IslandSize.small,
        IslandSize.small,
        IslandSize.small,
        IslandSize.medium,
        IslandSize.medium,
        IslandSize.medium,
        IslandSize.medium,
        IslandSize.large,
        IslandSize.large,
      ],
      _ => throw ArgumentError.value(
        totalIslandCount,
        'totalIslandCount',
        'must be one of 6, 8, 10, or 12',
      ),
    };
  }
}
