import 'dart:math' as math;

import 'game_state.dart';

/// The pixel viewport used to translate normalized [IslandPosition] values
/// into the same alignment centers as the renderer.
final class IslandMapViewport {
  const IslandMapViewport({required this.width, required this.height});

  /// A representative portrait viewport used by the regression tests.
  static const reference = IslandMapViewport(width: 390, height: 844);

  /// The minimum axis envelope for supported portrait layouts.  Maps generated
  /// for this viewport also fit every larger portrait screen.
  static const minimumPortrait = IslandMapViewport(width: 320, height: 320);

  final double width;
  final double height;

  bool get isValid =>
      width.isFinite && height.isFinite && width > 0 && height > 0;

  @override
  bool operator ==(Object other) {
    return other is IslandMapViewport &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);

  IslandMapRect rectFor(IslandState island) {
    return rectForPosition(island.position, island.size);
  }

  IslandMapRect rectForPosition(IslandPosition position, IslandSize size) {
    final widgetSize = GameRules.islandWidgetSize(size);
    // Flutter's Align lays out a child with
    // `(parent - child) * (alignment + 1) / 2`; using the child size here is
    // what makes this contract match the actual centers in lib/home.dart.
    final left = (width - widgetSize) * (position.x + 1) / 2;
    final top = (height - widgetSize) * (position.y + 1) / 2;
    return IslandMapRect(
      left: left,
      top: top,
      right: left + widgetSize,
      bottom: top + widgetSize,
    );
  }

  /// Returns the screen-space distance travelled by a moving-force widget
  /// between two normalized alignment positions.  [Align] positions the
  /// center using `(viewport - child) * alignment / 2`, so each axis uses the
  /// available travel span for the 30px troop widget rather than the raw
  /// normalized coordinate span.
  double movingForceDistance(
    IslandPosition source,
    IslandPosition destination,
  ) {
    final horizontalSpan = width - GameRules.movingForceWidgetSize;
    final verticalSpan = height - GameRules.movingForceWidgetSize;
    final deltaX = horizontalSpan * (destination.x - source.x) / 2;
    final deltaY = verticalSpan * (destination.y - source.y) / 2;
    return math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  /// The screen-space diagonal available to a moving-force widget.
  double get movingForceScreenDiagonal {
    final horizontalSpan = width - GameRules.movingForceWidgetSize;
    final verticalSpan = height - GameRules.movingForceWidgetSize;
    return math.sqrt(
      horizontalSpan * horizontalSpan + verticalSpan * verticalSpan,
    );
  }
}

/// A renderer-independent rectangle for one island's square widget.
final class IslandMapRect {
  const IslandMapRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool overlaps(IslandMapRect other) {
    return left < other.right &&
        other.left < right &&
        top < other.bottom &&
        other.top < bottom;
  }

  bool isWithin(IslandMapViewport viewport) {
    return left >= 0 &&
        top >= 0 &&
        right <= viewport.width &&
        bottom <= viewport.height;
  }
}

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

  /// These dimensions are shared with [Home]'s `SizedBox` widgets.  Neutral
  /// island variants currently use the same 50px square; the enum is retained
  /// in the API so a future renderer can give each variant its own size.
  static const headquartersWidgetSize = 100.0;
  static const neutralWidgetSize = 50.0;
  static const movingForceWidgetSize = 30.0;

  /// A layout-independent fallback for state creation before Flutter layout
  /// constraints are available.  Callers with a real viewport should pass it
  /// to [generateIslands] so collision and safe-area checks use exact pixels.
  static const defaultMapViewport = IslandMapViewport.minimumPortrait;
  static const referenceMapViewport = IslandMapViewport.reference;

  /// The default retry budget for a complete map generation attempt.
  static const defaultMapGenerationAttempts = 64;

  /// The retry budget for placing one symmetric pair during a map attempt.
  static const defaultPairPlacementAttempts = 128;

  static double islandWidgetSize(IslandSize size) {
    return size == IslandSize.headquarters
        ? headquartersWidgetSize
        : neutralWidgetSize;
  }

  GameState initialState({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
    IslandMapViewport viewport = defaultMapViewport,
  }) {
    return _initialState(
      configuration: configuration,
      phase: GamePhase.configuration,
      elapsedMs: 0,
      islands: generateIslands(
        configuration: configuration,
        random: random,
        viewport: viewport,
      ),
      selectedIslandId: null,
      movingForces: const <MovingForce>[],
      result: null,
      countdownRemainingMs: 0,
    );
  }

  /// Creates an initial state when the supplied viewport can fit a complete
  /// map, or returns null after the bounded generation budget is exhausted.
  /// This is used by the renderer-facing controller so an unusually small
  /// layout fails closed without displaying overlapping islands.
  GameState? tryInitialState({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
    IslandMapViewport viewport = defaultMapViewport,
    int maxAttempts = defaultMapGenerationAttempts,
    int? maxRetries,
    int maxPairAttempts = defaultPairPlacementAttempts,
    int? maxPairRetries,
  }) {
    final islands = tryGenerateIslands(
      configuration: configuration,
      random: random,
      viewport: viewport,
      maxAttempts: maxAttempts,
      maxRetries: maxRetries,
      maxPairAttempts: maxPairAttempts,
      maxPairRetries: maxPairRetries,
    );
    if (islands == null) {
      return null;
    }
    return _initialState(
      configuration: configuration,
      phase: GamePhase.configuration,
      elapsedMs: 0,
      islands: islands,
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
    IslandMapViewport viewport = defaultMapViewport,
  }) {
    return initialState(
      configuration: configuration,
      random: random,
      viewport: viewport,
    );
  }

  /// Generates a valid map or throws a [StateError] after the bounded retry
  /// budget is exhausted.  Call [tryGenerateIslands] when a caller needs to
  /// handle an impossible map as a nullable result instead.
  List<IslandState> generateIslands({
    GameConfiguration configuration = GameConfiguration.initial,
    math.Random? random,
    IslandMapViewport viewport = defaultMapViewport,
    int maxAttempts = defaultMapGenerationAttempts,
    int? maxRetries,
    int maxPairAttempts = defaultPairPlacementAttempts,
    int? maxPairRetries,
  }) {
    final islands = tryGenerateIslands(
      configuration: configuration,
      random: random,
      viewport: viewport,
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
    IslandMapViewport viewport = defaultMapViewport,
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
    if (!viewport.isValid) {
      throw ArgumentError.value(
        viewport,
        'viewport',
        'must have positive dimensions',
      );
    }
    final playerHeadquarters = viewport.rectFor(_playerHeadquarters);
    final cpuHeadquarters = viewport.rectFor(_cpuHeadquarters);
    if (!playerHeadquarters.isWithin(viewport) ||
        !cpuHeadquarters.isWithin(viewport) ||
        playerHeadquarters.overlaps(cpuHeadquarters)) {
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
          viewport: viewport,
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

  /// Advances countdowns, growth, movement, and arrival events.
  ///
  /// Arrivals are handled as chronological event groups.  Growth boundaries
  /// are applied immediately before an arrival at the same timestamp, while
  /// all arrivals in one timestamp are removed and resolved together.  This
  /// keeps the result independent of the order in which moving forces happen
  /// to be stored in the state list.
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

    if (state.phase != GamePhase.playing) {
      return state;
    }

    final startMs = state.elapsedMs;
    final endMs = startMs + deltaMs;
    var currentMs = startMs;
    var islands = [...state.islands];
    final remainingForces = [...state.movingForces];

    // Validate an existing selection before applying resource ticks.  A
    // source that was already exhausted or lost before this tick must not be
    // revived by the same tick's regeneration.
    final selectedIslandId = state.selectedIslandId;
    IslandState? selectedAtStart;
    if (selectedIslandId != null) {
      for (final island in islands) {
        if (island.id == selectedIslandId) {
          selectedAtStart = island;
          break;
        }
      }
    }
    final selectionInvalidAtStart =
        selectedIslandId != null &&
        (selectedAtStart == null ||
            selectedAtStart.faction != Faction.player ||
            selectedAtStart.currentForces <= 1);

    final arrivalsByTime = <int, List<MovingForce>>{};
    for (final force in remainingForces) {
      final eventTime = math.max(force.arrivalTimeMs, force.departureTimeMs);
      if (eventTime <= endMs) {
        arrivalsByTime.putIfAbsent(eventTime, () => []).add(force);
      }
    }

    final arrivalTimes = arrivalsByTime.keys.toList()..sort();
    for (final arrivalTime in arrivalTimes) {
      final eventTime = math.max(startMs, arrivalTime);
      islands = _applyGrowth(islands, fromMs: currentMs, toMs: eventTime);
      currentMs = eventTime;

      final group = arrivalsByTime[arrivalTime]!;
      final groupIds = group.map((force) => force.id).toSet();
      remainingForces.removeWhere((force) => groupIds.contains(force.id));
      islands = _resolveArrivalGroup(islands, group);

      final eventState = _stateAtTime(
        state,
        elapsedMs: currentMs,
        islands: islands,
        movingForces: _updateMovingForcePositions(
          remainingForces,
          islands,
          currentMs,
        ),
        selectionInvalidAtStart: selectionInvalidAtStart,
      );
      final result = _resultFor(
        elapsedMs: currentMs,
        islands: eventState.islands,
        movingForces: eventState.movingForces,
      );
      if (result != null) {
        return eventState.finishWithResult(result);
      }
    }

    islands = _applyGrowth(islands, fromMs: currentMs, toMs: endMs);
    final nextState = _stateAtTime(
      state,
      elapsedMs: endMs,
      islands: islands,
      movingForces: _updateMovingForcePositions(
        remainingForces,
        islands,
        endMs,
      ),
      selectionInvalidAtStart: selectionInvalidAtStart,
    );

    final result = _resultFor(
      elapsedMs: endMs,
      islands: nextState.islands,
      movingForces: nextState.movingForces,
    );
    if (result != null) {
      return nextState.finishWithResult(result);
    }

    return nextState;
  }

  /// Resolves one arriving faction against an island.
  ///
  /// A neutral island uses [IslandState.durability] as its defense value;
  /// owned islands use [IslandState.currentForces].  Strictly greater attack
  /// strength captures the island, while equal strength leaves the owner in
  /// place with a zero value.
  IslandState resolveArrival(
    IslandState island,
    Faction faction,
    int strength,
  ) {
    if (strength <= 0 || faction == Faction.neutral) {
      return island;
    }

    if (island.faction == faction) {
      return island.copyWith(
        currentForces: math.min(
          island.capacity,
          island.currentForces + strength,
        ),
      );
    }

    if (island.faction == Faction.neutral) {
      final defense = math.max(0, island.durability);
      if (strength > defense) {
        return island.copyWith(
          faction: faction,
          currentForces: math.min(island.capacity, strength - defense),
          durability: 0,
        );
      }
      return island.copyWith(currentForces: 0, durability: defense - strength);
    }

    final defense = math.max(0, island.currentForces);
    if (strength > defense) {
      return island.copyWith(
        faction: faction,
        currentForces: math.min(island.capacity, strength - defense),
        durability: 0,
      );
    }
    return island.copyWith(currentForces: defense - strength);
  }

  List<IslandState> _resolveArrivalGroup(
    List<IslandState> islands,
    List<MovingForce> group,
  ) {
    final arrivalsByTarget = <int, Map<Faction, int>>{};
    for (final force in group) {
      if (force.strength <= 0 || force.faction == Faction.neutral) {
        continue;
      }
      final byFaction = arrivalsByTarget.putIfAbsent(
        force.destinationIslandId,
        () => <Faction, int>{},
      );
      byFaction[force.faction] =
          (byFaction[force.faction] ?? 0) + force.strength;
    }

    final nextIslands = [...islands];
    for (final entry in arrivalsByTarget.entries) {
      final targetIndex = nextIslands.indexWhere(
        (island) => island.id == entry.key,
      );
      if (targetIndex < 0) {
        continue;
      }
      final playerStrength = entry.value[Faction.player] ?? 0;
      final cpuStrength = entry.value[Faction.cpu] ?? 0;
      if (playerStrength == cpuStrength) {
        continue;
      }
      final faction = playerStrength > cpuStrength
          ? Faction.player
          : Faction.cpu;
      final strength = playerStrength > cpuStrength
          ? playerStrength - cpuStrength
          : cpuStrength - playerStrength;
      nextIslands[targetIndex] = resolveArrival(
        nextIslands[targetIndex],
        faction,
        strength,
      );
    }
    return nextIslands;
  }

  List<IslandState> _applyGrowth(
    List<IslandState> islands, {
    required int fromMs,
    required int toMs,
  }) {
    final resourceTicks = toMs ~/ 1000 - fromMs ~/ 1000;
    if (resourceTicks <= 0) {
      return islands;
    }
    return [
      for (final island in islands)
        if (island.faction == Faction.neutral)
          island
        else
          island.copyWith(
            currentForces: math.min(
              island.capacity,
              island.currentForces + resourceTicks,
            ),
          ),
    ];
  }

  List<MovingForce> _updateMovingForcePositions(
    List<MovingForce> movingForces,
    List<IslandState> islands,
    int elapsedMs,
  ) {
    final nextForces = <MovingForce>[];
    for (final force in movingForces) {
      final duration = math.max(1, force.durationMs);
      final elapsedSinceDeparture = elapsedMs - force.departureTimeMs;
      final nextProgress = elapsedSinceDeparture <= 0
          ? 0.0
          : math.min(1.0, elapsedSinceDeparture / duration);
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
      nextForces.add(
        force.copyWith(
          position: nextPosition,
          progress: nextProgress,
          deltaX: target.x - source.x,
          deltaY: target.y - source.y,
        ),
      );
    }
    return nextForces;
  }

  GameState _stateAtTime(
    GameState state, {
    required int elapsedMs,
    required List<IslandState> islands,
    required List<MovingForce> movingForces,
    required bool selectionInvalidAtStart,
  }) {
    final nextState = state.copyWith(
      elapsedMs: elapsedMs,
      islands: islands,
      movingForces: movingForces,
    );

    // A selected source remains active while the player is choosing a
    // destination.  Clear it only when the source can no longer dispatch
    // under the current rules; an unrelated troop arrival must not affect it.
    final nextSelectedIslandId = nextState.selectedIslandId;
    if (nextSelectedIslandId == null) {
      return nextState;
    }
    IslandState? selectedIsland;
    for (final island in nextState.islands) {
      if (island.id == nextSelectedIslandId) {
        selectedIsland = island;
        break;
      }
    }
    final selectionInvalid =
        selectionInvalidAtStart ||
        selectedIsland == null ||
        selectedIsland.faction != Faction.player ||
        selectedIsland.currentForces <= 1;
    return selectionInvalid ? nextState.clearSelection() : nextState;
  }

  GameResult? _resultFor({
    required int elapsedMs,
    required List<IslandState> islands,
    required List<MovingForce> movingForces,
  }) {
    final playerAlive =
        islands.any((island) => island.faction == Faction.player) ||
        movingForces.any(
          (force) => force.faction == Faction.player && force.strength > 0,
        );
    final cpuAlive =
        islands.any((island) => island.faction == Faction.cpu) ||
        movingForces.any(
          (force) => force.faction == Faction.cpu && force.strength > 0,
        );

    if (playerAlive && cpuAlive) {
      return null;
    }
    if (!playerAlive && !cpuAlive) {
      return GameResult.draw(elapsedMs: elapsedMs);
    }
    if (!playerAlive) {
      return GameResult.defeat(elapsedMs: elapsedMs, winner: Faction.cpu);
    }
    return GameResult.victory(elapsedMs: elapsedMs, winner: Faction.player);
  }

  MovingForce createMovingForce({
    required int id,
    required Faction faction,
    required IslandState source,
    required IslandState destination,
    required int strength,
    int departureTimeMs = 0,
    IslandMapViewport viewport = defaultMapViewport,
  }) {
    final distance = viewport.movingForceDistance(
      source.position,
      destination.position,
    );
    final screenDiagonal = viewport.movingForceScreenDiagonal;
    final durationMs = screenDiagonal <= 0
        ? 1
        : math.max(1, (movementDurationMs * distance / screenDiagonal).round());
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

  static List<IslandState>? _tryPlaceNeutralPair({
    required int firstId,
    required IslandSize size,
    required List<IslandState> existing,
    required math.Random random,
    required IslandMapViewport viewport,
    required int maxAttempts,
  }) {
    // Align itself keeps any child inside the viewport for every alignment in
    // [-1, 1], so the normalized map bounds are also the safe-area bounds.
    final minX = mapMinCoordinate;
    final maxX = mapMaxCoordinate;
    final minY = mapMinCoordinate;
    final maxY = mapMaxCoordinate;
    final xRange = maxX - minX;
    final yRange = maxY - minY;
    if (xRange < 0 || yRange < 0) {
      return null;
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final firstPosition = IslandPosition(
        x: minX + random.nextDouble() * xRange,
        y: minY + random.nextDouble() * yRange,
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

      if (_islandPairSeparated(first, second, existing, viewport)) {
        return [first, second];
      }
    }
    return null;
  }

  static bool _islandPairSeparated(
    IslandState first,
    IslandState second,
    List<IslandState> existing,
    IslandMapViewport viewport,
  ) {
    if (islandRectanglesOverlap(first, second, viewport)) {
      return false;
    }
    for (final island in existing) {
      if (islandRectanglesOverlap(first, island, viewport) ||
          islandRectanglesOverlap(second, island, viewport)) {
        return false;
      }
    }
    return true;
  }

  static bool islandRectanglesOverlap(
    IslandState first,
    IslandState second,
    IslandMapViewport viewport,
  ) {
    return viewport.rectFor(first).overlaps(viewport.rectFor(second));
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

  static GameState _initialState({
    required GameConfiguration configuration,
    required GamePhase phase,
    required int elapsedMs,
    required List<IslandState> islands,
    required int? selectedIslandId,
    required List<MovingForce> movingForces,
    required GameResult? result,
    required int countdownRemainingMs,
  }) {
    return GameState(
      configuration: configuration,
      phase: phase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: movingForces,
      result: result,
      countdownRemainingMs: countdownRemainingMs,
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
