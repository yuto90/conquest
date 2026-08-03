import 'dart:math' as math;

import 'game_state.dart';

/// Pure, deterministic game-state transitions.
///
/// The class has no Riverpod, timer, or Flutter dependency.  Callers provide
/// the current state and a delta (and, when creating a map, a [math.Random])
/// and receive a new immutable state.  Concrete dispatch, combat, and CPU
/// rules remain deliberately outside this foundation.  Map generation lives
/// here because it is a deterministic, renderer-independent part of the
/// initial state.
final class GameRules {
  const GameRules();

  static const startCountdownDurationMs = 3000;
  static const movementDurationMs = 5000;

  /// Normalized alignment coordinates used by the first renderer.
  static const mapMinCoordinate = -1.0;
  static const mapMaxCoordinate = 1.0;

  /// A small global gap keeps islands from touching even when their visual
  /// footprints are smaller than the size-specific collision radii below.
  static const minimumIslandSpacing = 0.20;

  /// The default retry budget for a complete map generation attempt.
  static const defaultMapGenerationAttempts = 64;

  /// The retry budget for placing one symmetric pair during a map attempt.
  static const defaultPairPlacementAttempts = 128;

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

  /// Generates a valid map or throws a [StateError] after the bounded retry
  /// budget is exhausted.  Call [tryGenerateIslands] when a caller needs to
  /// handle an impossible map as a nullable result instead.
  List<IslandState> generateIslands({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
    int maxAttempts = defaultMapGenerationAttempts,
    int? maxRetries,
    int maxPairAttempts = defaultPairPlacementAttempts,
    int? maxPairRetries,
  }) {
    final islands = tryGenerateIslands(
      configuration: configuration,
      random: random,
      maxAttempts: maxAttempts,
      maxRetries: maxRetries,
      maxPairAttempts: maxPairAttempts,
      maxPairRetries: maxPairRetries,
    );
    if (islands == null) {
      final attempts = maxRetries ?? maxAttempts;
      final pairAttempts = maxPairRetries ?? maxPairAttempts;
      throw StateError(
        'Unable to generate a valid map after $attempts map attempts '
        'and $pairAttempts pair attempts',
      );
    }
    return islands;
  }

  /// Attempts to generate a valid map without ever retrying indefinitely.
  ///
  /// The two headquarters are fixed at the bottom-right and top-left corners.
  /// Every neutral island is generated as a pair so its counterpart is the
  /// exact point reflection around the screen center.  A null result means the
  /// supplied retry budget could not produce a non-overlapping placement.
  List<IslandState>? tryGenerateIslands({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
    int maxAttempts = defaultMapGenerationAttempts,
    int? maxRetries,
    int maxPairAttempts = defaultPairPlacementAttempts,
    int? maxPairRetries,
  }) {
    final attempts = maxRetries ?? maxAttempts;
    final pairAttempts = maxPairRetries ?? maxPairAttempts;
    if (attempts < 0) {
      throw ArgumentError.value(
        attempts,
        'maxAttempts',
        'must not be negative',
      );
    }
    if (pairAttempts < 0) {
      throw ArgumentError.value(
        pairAttempts,
        'maxPairAttempts',
        'must not be negative',
      );
    }
    if (attempts == 0 || pairAttempts == 0) {
      return null;
    }

    final source = random ?? math.Random();
    final neutralSizes = _neutralSizes(configuration.totalIslandCount);
    for (var mapAttempt = 0; mapAttempt < attempts; mapAttempt++) {
      final islands = <IslandState>[_playerHeadquarters, _cpuHeadquarters];
      var generated = true;
      for (var pairIndex = 0; pairIndex < neutralSizes.length; pairIndex += 2) {
        final pair = _tryPlaceNeutralPair(
          firstId: pairIndex + 2,
          size: neutralSizes[pairIndex],
          existing: islands,
          random: source,
          maxAttempts: pairAttempts,
        );
        if (pair == null) {
          generated = false;
          break;
        }
        islands.addAll(pair);
      }
      if (generated) {
        return List<IslandState>.unmodifiable(islands);
      }
    }
    return null;
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
    if (state.phase == target) {
      return state;
    }
    if (!canTransition(state.phase, target) ||
        (target == GamePhase.result && state.result == null)) {
      return state;
    }

    if (target == GamePhase.result) {
      return state.finishWithResult(state.result!);
    }
    return state.transitionToPhase(
      target,
      countdownRemainingMs:
          target == GamePhase.startCountdown ||
              target == GamePhase.resumeCountdown
          ? startCountdownDurationMs
          : 0,
    );
  }

  GameState startCountdown(
    GameState state, {
    int durationMs = startCountdownDurationMs,
  }) {
    if (state.phase != GamePhase.configuration) {
      return state;
    }
    return state.transitionToPhase(
      GamePhase.startCountdown,
      countdownRemainingMs: math.max(0, durationMs),
    );
  }

  GameState resumeCountdown(
    GameState state, {
    int durationMs = startCountdownDurationMs,
  }) {
    if (state.phase != GamePhase.paused) {
      return state;
    }
    return state.transitionToPhase(
      GamePhase.resumeCountdown,
      countdownRemainingMs: math.max(0, durationMs),
    );
  }

  GameState pause(GameState state) {
    return transitionTo(state, GamePhase.paused);
  }

  GameState finish(GameState state, GameResult result) {
    if (state.phase != GamePhase.playing ||
        !canTransition(state.phase, GamePhase.result)) {
      return state;
    }
    return state.finishWithResult(result);
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

    // A selected source remains active while the player is choosing a
    // destination.  Only clear it after an existing dispatch has completed,
    // or when the source can no longer dispatch under the current rules.
    final selectedIsland = nextState.selectedIslandId == null
        ? null
        : nextState.islands.firstWhere(
            (island) => island.id == nextState.selectedIslandId,
            orElse: () => const IslandState(
              id: -1,
              position: IslandPosition(x: 0, y: 0),
              faction: Faction.neutral,
            ),
          );
    final selectionInvalid =
        nextState.selectedIslandId != null &&
        (selectedIsland == null ||
            selectedIsland.id == -1 ||
            selectedIsland.faction != Faction.player ||
            selectedIsland.currentForces <= 1);
    final dispatchCompleted =
        state.movingForces.isNotEmpty && remainingForces.isEmpty;
    return dispatchCompleted || selectionInvalid
        ? nextState.clearSelection()
        : nextState;
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

  static const _playerHeadquarters = IslandState(
    id: 0,
    position: IslandPosition(x: 1, y: 1),
    faction: Faction.player,
    size: IslandSize.headquarters,
    currentForces: 100,
    durability: 0,
    capacity: 200,
  );

  static const _cpuHeadquarters = IslandState(
    id: 1,
    position: IslandPosition(x: -1, y: -1),
    faction: Faction.cpu,
    size: IslandSize.headquarters,
    currentForces: 100,
    durability: 0,
    capacity: 200,
  );

  /// Approximate normalized collision radius for the renderer's island
  /// footprints.  The value is intentionally conservative so generated
  /// centers cannot visually overlap at the expected widget sizes.
  static double islandRadius(IslandSize size) {
    return switch (size) {
      IslandSize.small => 0.10,
      IslandSize.medium => 0.14,
      IslandSize.large => 0.18,
      IslandSize.headquarters => 0.24,
    };
  }

  static List<IslandState>? _tryPlaceNeutralPair({
    required int firstId,
    required IslandSize size,
    required List<IslandState> existing,
    required math.Random random,
    required int maxAttempts,
  }) {
    final radius = islandRadius(size);
    final minCoordinate = mapMinCoordinate + radius;
    final coordinateRange = mapMaxCoordinate - radius - minCoordinate;
    if (coordinateRange < 0) {
      return null;
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final firstPosition = IslandPosition(
        x: minCoordinate + random.nextDouble() * coordinateRange,
        y: minCoordinate + random.nextDouble() * coordinateRange,
      );
      final secondPosition = IslandPosition(
        x: -firstPosition.x,
        y: -firstPosition.y,
      );
      final first = _neutralIsland(
        id: firstId,
        size: size,
        position: firstPosition,
      );
      final second = _neutralIsland(
        id: firstId + 1,
        size: size,
        position: secondPosition,
      );

      if (_islandPairSeparated(first, second, existing)) {
        return [first, second];
      }
    }
    return null;
  }

  static bool _islandPairSeparated(
    IslandState first,
    IslandState second,
    List<IslandState> existing,
  ) {
    if (!_islandPositionsSeparated(first, second)) {
      return false;
    }
    for (final island in existing) {
      if (!_islandPositionsSeparated(first, island) ||
          !_islandPositionsSeparated(second, island)) {
        return false;
      }
    }
    return true;
  }

  static bool _islandPositionsSeparated(IslandState first, IslandState second) {
    final requiredDistance = math.max(
      minimumIslandSpacing,
      islandRadius(first.size) + islandRadius(second.size),
    );
    final deltaX = first.x - second.x;
    final deltaY = first.y - second.y;
    final distanceSquared = deltaX * deltaX + deltaY * deltaY;
    return distanceSquared + 1e-12 >= requiredDistance * requiredDistance;
  }

  static IslandState _neutralIsland({
    required int id,
    required IslandSize size,
    required IslandPosition position,
  }) {
    return IslandState(
      id: id,
      position: position,
      faction: Faction.neutral,
      size: size,
      currentForces: 0,
      durability: size.neutralDurability ?? 0,
      capacity: size.capacity,
    );
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
