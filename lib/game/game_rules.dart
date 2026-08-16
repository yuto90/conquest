import 'dart:math' as math;

import 'game_state.dart';
import 'movement_timing.dart';

/// The pixel viewport used to translate normalized [IslandPosition] values
/// into the same alignment centers as the renderer.
final class IslandMapViewport {
  const IslandMapViewport({required this.width, required this.height});

  /// Shared geometry for the renderer's top-right pause control.  The map
  /// reserves the button plus its padding so random islands cannot leave only
  /// a sliver of a tap target visible underneath it on a phone screen.
  static const pauseControlPadding = 12.0;
  static const pauseButtonWidth = 96.0;
  static const pauseButtonHeight = 48.0;
  static const topRightControlReservedWidth =
      pauseButtonWidth + pauseControlPadding * 2;
  static const topRightControlReservedHeight =
      pauseButtonHeight + pauseControlPadding * 2;

  /// A representative portrait viewport used by the regression tests.
  static const reference = IslandMapViewport(width: 390, height: 844);

  /// The minimum axis envelope for supported portrait layouts.  Maps generated
  /// for this viewport also fit every larger portrait screen.
  static const minimumPortrait = IslandMapViewport(width: 320, height: 320);

  final double width;
  final double height;

  IslandMapRect get topRightControlExclusion {
    final reservedWidth = math.min(width, topRightControlReservedWidth);
    final reservedHeight = math.min(height, topRightControlReservedHeight);
    return IslandMapRect(
      left: width - reservedWidth,
      top: 0,
      right: width,
      bottom: reservedHeight,
    );
  }

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

  bool containsPoint(double x, double y) {
    return x >= left && x <= right && y >= top && y <= bottom;
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

  /// Compatibility alias for the canonical screen-diagonal duration.
  static const movementDurationMs = MovementTiming.screenDiagonalDurationMs;

  /// Normalized alignment coordinates used by the first renderer.
  static const mapMinCoordinate = -1.0;
  static const mapMaxCoordinate = 1.0;

  /// These dimensions are shared with [Home]'s `SizedBox` widgets.  Distinct
  /// sizes make the small, medium, large, and headquarters roles visible on
  /// the board while keeping the small-island footprint compatible with the
  /// original map envelope.
  static const headquartersWidgetSize = 100.0;
  static const neutralWidgetSize = 50.0;
  static const mediumIslandWidgetSize = 64.0;
  static const largeIslandWidgetSize = 80.0;
  static const movingForceWidgetSize = 30.0;

  /// Insets the fixed headquarters from the HUD while preserving the map's
  /// point symmetry. At the 390x844 Open Design reference viewport these
  /// anchors place the CPU headquarters at (66, 98) and the player
  /// headquarters at (324, 746), the closest point-symmetric match to the
  /// prototype's (62, 104) and (320, 752) centers.
  static const _headquartersAlignmentX = 129 / 145;
  static const _headquartersAlignmentY = 27 / 31;

  /// A layout-independent fallback for state creation before Flutter layout
  /// constraints are available.  Callers with a real viewport should pass it
  /// to [generateIslands] so collision and safe-area checks use exact pixels.
  static const defaultMapViewport = IslandMapViewport.minimumPortrait;
  static const referenceMapViewport = IslandMapViewport.reference;

  /// The default retry budget for a complete map generation attempt.
  static const defaultMapGenerationAttempts = 1024;

  /// The retry budget for placing one symmetric pair during a map attempt.
  static const defaultPairPlacementAttempts = 128;

  static double islandWidgetSize(IslandSize size) {
    return switch (size) {
      IslandSize.headquarters => headquartersWidgetSize,
      IslandSize.small => neutralWidgetSize,
      IslandSize.medium => mediumIslandWidgetSize,
      IslandSize.large => largeIslandWidgetSize,
    };
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
  /// The two headquarters are fixed at opposing point-symmetric anchors.
  /// Every neutral island is generated as a pair so its counterpart is the
  /// exact point reflection around the screen center. A null result means the
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
    final headquarters = _headquartersFor(viewport);
    final playerHeadquartersRect = viewport.rectFor(headquarters.$1);
    final cpuHeadquartersRect = viewport.rectFor(headquarters.$2);
    if (!playerHeadquartersRect.isWithin(viewport) ||
        !cpuHeadquartersRect.isWithin(viewport) ||
        playerHeadquartersRect.overlaps(cpuHeadquartersRect)) {
      return null;
    }

    final source = random ?? math.Random();
    final neutralSizes = _neutralSizes(configuration.totalIslandCount);
    for (var mapAttempt = 0; mapAttempt < attempts; mapAttempt++) {
      final islands = <IslandState>[headquarters.$1, headquarters.$2];
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
      GamePhase.startCountdown =>
        to == GamePhase.playing || to == GamePhase.paused,
      GamePhase.playing => to == GamePhase.paused || to == GamePhase.result,
      GamePhase.paused =>
        to == GamePhase.resumeCountdown || to == GamePhase.configuration,
      GamePhase.resumeCountdown =>
        to == GamePhase.playing || to == GamePhase.paused,
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
    if (state.phase != GamePhase.playing &&
        state.phase != GamePhase.startCountdown &&
        state.phase != GamePhase.resumeCountdown) {
      return state;
    }
    return state.transitionToPhase(GamePhase.paused);
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

    // Validate existing selections before applying resource ticks.  A
    // source that was already exhausted or lost before this tick must not be
    // revived by the same tick's regeneration.
    final playerSelectionInvalidAtStart = _isSelectionInvalid(
      selectedId: state.selectedIslandId,
      islands: islands,
      faction: Faction.player,
    );
    final opponentSelectionInvalidAtStart = _isSelectionInvalid(
      selectedId: state.opponentSelectedIslandId,
      islands: islands,
      faction: Faction.cpu,
    );

    final arrivalsByTime = <int, List<MovingForce>>{};
    for (final force in remainingForces) {
      final eventTime = math.max(force.arrivalTimeMs, force.departureTimeMs);
      if (eventTime <= endMs) {
        arrivalsByTime.putIfAbsent(eventTime, () => []).add(force);
      }
    }

    final arrivalTimes = arrivalsByTime.keys.toList()..sort();
    var stateAtCurrentTime = state;
    for (final arrivalTime in arrivalTimes) {
      final eventTime = math.max(startMs, arrivalTime);
      islands = _applyGrowth(islands, fromMs: currentMs, toMs: eventTime);
      currentMs = eventTime;

      final group = arrivalsByTime[arrivalTime]!;
      final groupIds = group.map((force) => force.id).toSet();
      remainingForces.removeWhere((force) => groupIds.contains(force.id));
      islands = _resolveArrivalGroup(islands, group);

      final eventState = _stateAtTime(
        stateAtCurrentTime,
        elapsedMs: currentMs,
        islands: islands,
        movingForces: _updateMovingForcePositions(
          remainingForces,
          islands,
          currentMs,
        ),
        playerSelectionInvalidAtStart: playerSelectionInvalidAtStart,
        opponentSelectionInvalidAtStart: opponentSelectionInvalidAtStart,
      );
      stateAtCurrentTime = eventState;
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
      stateAtCurrentTime,
      elapsedMs: endMs,
      islands: islands,
      movingForces: _updateMovingForcePositions(
        remainingForces,
        islands,
        endMs,
      ),
      playerSelectionInvalidAtStart: playerSelectionInvalidAtStart,
      opponentSelectionInvalidAtStart: opponentSelectionInvalidAtStart,
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
    required bool playerSelectionInvalidAtStart,
    required bool opponentSelectionInvalidAtStart,
  }) {
    var nextState = state.copyWith(
      elapsedMs: elapsedMs,
      islands: islands,
      movingForces: movingForces,
    );

    // A selected source remains active while a human is choosing a
    // destination.  Clear it only when the source can no longer dispatch
    // under the current rules; an unrelated troop arrival must not affect it.
    final playerSelectionInvalid =
        playerSelectionInvalidAtStart ||
        _isSelectionInvalid(
          selectedId: nextState.selectedIslandId,
          islands: nextState.islands,
          faction: Faction.player,
        );
    if (playerSelectionInvalid && nextState.selectedIslandId != null) {
      nextState = nextState.clearSelection();
    }
    final opponentSelectionInvalid =
        opponentSelectionInvalidAtStart ||
        _isSelectionInvalid(
          selectedId: nextState.opponentSelectedIslandId,
          islands: nextState.islands,
          faction: Faction.cpu,
        );
    if (opponentSelectionInvalid &&
        nextState.opponentSelectedIslandId != null) {
      nextState = nextState.clearOpponentSelection();
    }
    return nextState;
  }

  static bool _isSelectionInvalid({
    required int? selectedId,
    required List<IslandState> islands,
    required Faction faction,
  }) {
    if (selectedId == null) {
      return false;
    }
    IslandState? selectedIsland;
    for (final island in islands) {
      if (island.id == selectedId) {
        selectedIsland = island;
        break;
      }
    }
    return selectedIsland == null ||
        selectedIsland.faction != faction ||
        selectedIsland.currentForces <= 1;
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

  static (IslandState, IslandState) _headquartersFor(
    IslandMapViewport viewport,
  ) {
    // The 320x320 stress-test envelope needs the original corner anchors to
    // leave enough room for twelve islands. Portrait game surfaces use the
    // Open Design HUD-safe anchors.
    final isPortrait = viewport.height > viewport.width;
    final x = isPortrait ? _headquartersAlignmentX : 1.0;
    final y = isPortrait ? _headquartersAlignmentY : 1.0;
    return (
      IslandState(
        id: 0,
        position: IslandPosition(x: x, y: y),
        faction: Faction.player,
        size: IslandSize.headquarters,
        currentForces: 100,
        durability: 0,
        capacity: 200,
      ),
      IslandState(
        id: 1,
        position: IslandPosition(x: -x, y: -y),
        faction: Faction.cpu,
        size: IslandSize.headquarters,
        currentForces: 100,
        durability: 0,
        capacity: 200,
      ),
    );
  }

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
    if (islandRectanglesOverlap(first, second, viewport) ||
        _islandOverlapsTopRightControl(first, viewport) ||
        _islandOverlapsTopRightControl(second, viewport)) {
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

  static bool _islandOverlapsTopRightControl(
    IslandState island,
    IslandMapViewport viewport,
  ) {
    return viewport.rectFor(island).overlaps(viewport.topRightControlExclusion);
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
      opponentSelectedIslandId: null,
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
