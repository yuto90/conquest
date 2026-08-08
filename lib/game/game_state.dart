/// Immutable value objects used by the game engine.
///
/// The model intentionally does not depend on Flutter.  This keeps the rule
/// transitions usable by a later renderer, a CPU player, and deterministic
/// tests without having to construct a widget tree.

import 'movement_timing.dart';

enum GamePhase {
  configuration,
  startCountdown,
  playing,
  paused,
  resumeCountdown,
  result;

  /// Compatibility name used by the first Riverpod screen.
  static const ready = configuration;

  /// Short aliases make phase checks read naturally at call sites while the
  /// full names remain the canonical representation in persisted state.
  static const countdown = startCountdown;
  static const resuming = resumeCountdown;
}

/// The selectable CPU decision interval profile for a match.
enum CpuDifficulty { easy, normal, hard }

enum Faction {
  player,
  cpu,
  neutral;

  /// Names used by the original PR #3 model.
  static const ally = player;
  static const enemy = cpu;
}

/// `BaseControl` is kept as a source-compatible alias for the PR #3 screen.
typedef BaseControl = Faction;

/// A stable position in the normalized game coordinate space.
final class IslandPosition {
  const IslandPosition({required this.x, required this.y});

  final double x;
  final double y;

  IslandPosition copyWith({double? x, double? y}) {
    return IslandPosition(x: x ?? this.x, y: y ?? this.y);
  }

  @override
  bool operator ==(Object other) {
    return other is IslandPosition && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// Compatibility aliases for consumers that prefer a generic position name.
typedef GamePosition = IslandPosition;
typedef Position = IslandPosition;

enum IslandSize {
  small(neutralDurability: 10, capacity: 50),
  medium(neutralDurability: 30, capacity: 100),
  large(neutralDurability: 50, capacity: 150),
  headquarters(neutralDurability: null, capacity: 200);

  const IslandSize({required this.neutralDurability, required this.capacity});

  final int? neutralDurability;
  final int capacity;

  /// A base is the legacy name for a headquarters island.
  static const base = headquarters;
}

/// The selectable island-count configuration for a match.
final class GameConfiguration {
  static const allowedIslandCounts = <int>[6, 8, 10, 12];
  static const defaultIslandCount = 10;

  factory GameConfiguration({
    int? totalIslandCount,
    int? islandCount,
    CpuDifficulty? cpuDifficulty,
  }) {
    final count = totalIslandCount ?? islandCount ?? defaultIslandCount;
    if (!isValidIslandCount(count)) {
      throw ArgumentError.value(
        count,
        'totalIslandCount',
        'must be one of 6, 8, 10, or 12',
      );
    }
    return GameConfiguration._(count, cpuDifficulty ?? CpuDifficulty.normal);
  }

  const GameConfiguration._(this.totalIslandCount, this.cpuDifficulty);

  final int totalIslandCount;
  final CpuDifficulty cpuDifficulty;

  static bool isValidIslandCount(int count) {
    return count == 6 || count == 8 || count == 10 || count == 12;
  }

  /// Alternate spelling used by map-facing code.
  int get islandCount => totalIslandCount;

  /// The initial selection required by the rules document.
  static const initial = GameConfiguration._(
    defaultIslandCount,
    CpuDifficulty.normal,
  );
  static const defaultConfiguration = initial;

  GameConfiguration copyWith({
    int? totalIslandCount,
    int? islandCount,
    CpuDifficulty? cpuDifficulty,
  }) {
    return GameConfiguration(
      totalIslandCount:
          totalIslandCount ?? islandCount ?? this.totalIslandCount,
      cpuDifficulty: cpuDifficulty ?? this.cpuDifficulty,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameConfiguration &&
        other.totalIslandCount == totalIslandCount &&
        other.cpuDifficulty == cpuDifficulty;
  }

  @override
  int get hashCode => Object.hash(totalIslandCount, cpuDifficulty);
}

/// A typed island state.  Neutral islands use [durability], while owned
/// islands use [currentForces].  Keeping both values allows later combat rules
/// to model a damaged neutral island without introducing a dynamic payload.
class IslandState {
  const IslandState({
    required this.id,
    double? x,
    double? y,
    IslandPosition? position,
    Faction? faction,
    BaseControl? control,
    IslandSize? size,
    int? currentForces,
    int? forces,
    int? durability,
    int? currentDurability,
    int? scale,
    int? capacity,
  }) : _x = x ?? 0,
       _y = y ?? 0,
       _position = position,
       faction = faction ?? control ?? Faction.neutral,
       size =
           size ??
           (id == 0 || id == 1 ? IslandSize.headquarters : IslandSize.small),
       currentForces = currentForces ?? forces ?? scale ?? 0,
       durability =
           durability ??
           currentDurability ??
           ((faction ?? control ?? Faction.neutral) == Faction.neutral
               ? scale ?? forces ?? 0
               : 0),
       capacity =
           capacity ??
           ((size == IslandSize.headquarters ||
                   (size == null && (id == 0 || id == 1)))
               ? 200
               : size == IslandSize.medium
               ? 100
               : size == IslandSize.large
               ? 150
               : 50);

  final int id;
  final double _x;
  final double _y;
  final IslandPosition? _position;
  final Faction faction;
  final IslandSize size;
  final int currentForces;
  final int durability;
  final int capacity;

  double get x => _position?.x ?? _x;
  double get y => _position?.y ?? _y;

  IslandPosition get position => IslandPosition(x: x, y: y);

  /// Canonical and descriptive aliases for [currentForces].
  int get forces => currentForces;
  int get currentStrength => currentForces;

  /// The value currently displayed for this island, regardless of whether it
  /// is an owned island's forces or a neutral island's durability.
  int get currentValue =>
      faction == Faction.neutral ? currentDurability : currentForces;

  /// Whether this island can be selected as a player dispatch source.
  bool get canDispatch => faction == Faction.player && currentForces > 1;

  /// A descriptive alias used by accessibility-facing board code.
  bool get actionAvailable => canDispatch;

  /// Canonical alias for the neutral-island value.
  int get currentDurability => durability;

  /// Legacy PR #3 names.  They intentionally expose the force value so the
  /// existing renderer can continue to watch the same fields.
  Faction get control => faction;
  int get scale => currentForces;

  IslandState copyWith({
    int? id,
    double? x,
    double? y,
    IslandPosition? position,
    Faction? faction,
    BaseControl? control,
    IslandSize? size,
    int? currentForces,
    int? forces,
    int? durability,
    int? currentDurability,
    int? capacity,
    int? scale,
  }) {
    final nextFaction = faction ?? control ?? this.faction;
    final nextPosition = position ?? this.position;
    final positioned = x == null && y == null
        ? nextPosition
        : nextPosition.copyWith(x: x, y: y);
    final nextForces = currentForces ?? forces ?? scale ?? this.currentForces;
    final nextDurability =
        durability ??
        currentDurability ??
        (scale == null || this.faction != Faction.neutral
            ? this.durability
            : scale);

    return IslandState(
      id: id ?? this.id,
      x: positioned.x,
      y: positioned.y,
      position: positioned,
      faction: nextFaction,
      size: size ?? this.size,
      currentForces: nextForces,
      durability: nextDurability,
      capacity: capacity ?? this.capacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IslandState &&
        other.id == id &&
        other.position == position &&
        other.faction == faction &&
        other.size == size &&
        other.currentForces == currentForces &&
        other.durability == durability &&
        other.capacity == capacity;
  }

  @override
  int get hashCode => Object.hash(
    id,
    position,
    faction,
    size,
    currentForces,
    durability,
    capacity,
  );
}

/// Compatibility value object for the original PR #3 constructor.  The
/// canonical state is [IslandState]; this subtype exists only so existing UI
/// and tests can continue to use `const BaseState(x: ..., scale: ...)`.
final class BaseState extends IslandState {
  const BaseState({
    required super.id,
    required double x,
    required double y,
    required BaseControl control,
    required int scale,
  }) : super(
         x: x,
         y: y,
         faction: control,
         size: id == 0 || id == 1 ? IslandSize.headquarters : IslandSize.small,
         currentForces: scale,
         durability: control == Faction.neutral ? scale : 0,
         capacity: control == Faction.neutral ? 50 : 200,
       );
}

/// A force that is currently travelling between two islands.
class MovingForce {
  const MovingForce({
    this.id = 0,
    this.faction = Faction.player,
    required this.sourceIslandId,
    required this.destinationIslandId,
    required this.strength,
    double? x,
    double? y,
    IslandPosition? position,
    this.departureTimeMs = 0,
    this.arrivalTimeMs = movementDefaultArrivalTimeMs,
    this.durationMs = movementDefaultDurationMs,
    this.progress = 0,
    this.deltaX = 0,
    this.deltaY = 0,
  }) : _x = x ?? 0,
       _y = y ?? 0,
       _position = position;

  /// Compatibility alias for the canonical screen-diagonal duration.
  static const movementDefaultDurationMs =
      MovementTiming.screenDiagonalDurationMs;
  static const movementDefaultArrivalTimeMs = movementDefaultDurationMs;

  final int id;
  final Faction faction;
  final int sourceIslandId;
  final int destinationIslandId;
  final int strength;
  final double _x;
  final double _y;
  final IslandPosition? _position;
  final int departureTimeMs;
  final int arrivalTimeMs;
  final int durationMs;
  final double progress;
  final double deltaX;
  final double deltaY;

  double get x => _position?.x ?? _x;
  double get y => _position?.y ?? _y;

  IslandPosition get position => IslandPosition(x: x, y: y);

  /// Legacy PR #3 names.
  int get sourceBaseId => sourceIslandId;
  int get targetBaseId => destinationIslandId;
  int get scale => strength;

  /// The value rendered on a moving troop marker.
  int get currentValue => strength;

  /// Moving troops have no player action of their own.
  bool get actionAvailable => false;
  bool get isTappable => false;

  MovingForce copyWith({
    int? id,
    Faction? faction,
    int? sourceIslandId,
    int? sourceBaseId,
    int? destinationIslandId,
    int? targetBaseId,
    int? strength,
    int? scale,
    IslandPosition? position,
    double? x,
    double? y,
    int? departureTimeMs,
    int? startTimeMs,
    int? arrivalTimeMs,
    int? durationMs,
    double? progress,
    double? deltaX,
    double? deltaY,
  }) {
    final nextPosition = position ?? this.position;
    final positionWithCoordinates = x == null && y == null
        ? nextPosition
        : nextPosition.copyWith(x: x, y: y);
    return MovingForce(
      id: id ?? this.id,
      faction: faction ?? this.faction,
      sourceIslandId: sourceIslandId ?? sourceBaseId ?? this.sourceIslandId,
      destinationIslandId:
          destinationIslandId ?? targetBaseId ?? this.destinationIslandId,
      strength: strength ?? scale ?? this.strength,
      x: positionWithCoordinates.x,
      y: positionWithCoordinates.y,
      position: positionWithCoordinates,
      departureTimeMs: departureTimeMs ?? startTimeMs ?? this.departureTimeMs,
      arrivalTimeMs: arrivalTimeMs ?? this.arrivalTimeMs,
      durationMs: durationMs ?? this.durationMs,
      progress: progress ?? this.progress,
      deltaX: deltaX ?? this.deltaX,
      deltaY: deltaY ?? this.deltaY,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovingForce &&
        other.id == id &&
        other.faction == faction &&
        other.sourceIslandId == sourceIslandId &&
        other.destinationIslandId == destinationIslandId &&
        other.strength == strength &&
        other.position == position &&
        other.departureTimeMs == departureTimeMs &&
        other.arrivalTimeMs == arrivalTimeMs &&
        other.durationMs == durationMs &&
        other.progress == progress &&
        other.deltaX == deltaX &&
        other.deltaY == deltaY;
  }

  @override
  int get hashCode => Object.hash(
    id,
    faction,
    sourceIslandId,
    destinationIslandId,
    strength,
    position,
    departureTimeMs,
    arrivalTimeMs,
    durationMs,
    progress,
    deltaX,
    deltaY,
  );
}

/// Compatibility value object for PR #3's constructor and field names.
final class MovementState extends MovingForce {
  const MovementState({
    required int sourceBaseId,
    required int targetBaseId,
    required double x,
    required double y,
    required double deltaX,
    required double deltaY,
    required int scale,
  }) : super(
         sourceIslandId: sourceBaseId,
         destinationIslandId: targetBaseId,
         strength: scale,
         x: x,
         y: y,
         deltaX: deltaX,
         deltaY: deltaY,
       );
}

enum GameResultType {
  victory,
  defeat,
  draw;

  static const win = victory;
  static const loss = defeat;
}

typedef GameOutcome = GameResultType;

final class GameResult {
  const GameResult({required this.type, required this.elapsedMs, this.winner});

  const GameResult.victory({
    required int elapsedMs,
    Faction winner = Faction.player,
  }) : this(type: GameResultType.victory, elapsedMs: elapsedMs, winner: winner);

  const GameResult.defeat({
    required int elapsedMs,
    Faction winner = Faction.cpu,
  }) : this(type: GameResultType.defeat, elapsedMs: elapsedMs, winner: winner);

  const GameResult.draw({required int elapsedMs})
    : this(type: GameResultType.draw, elapsedMs: elapsedMs);

  final GameResultType type;
  final int elapsedMs;
  final Faction? winner;

  GameResultType get outcome => type;
  GameResultType get resultType => type;

  @override
  bool operator ==(Object other) {
    return other is GameResult &&
        other.type == type &&
        other.elapsedMs == elapsedMs &&
        other.winner == winner;
  }

  @override
  int get hashCode => Object.hash(type, elapsedMs, winner);
}

final class GameState {
  GameState({
    required this.phase,
    required this.elapsedMs,
    GameConfiguration? configuration,
    List<IslandState>? islands,
    List<BaseState>? bases,
    int? selectedIslandId,
    int? selectedBaseId,
    List<MovingForce>? movingForces,
    MovingForce? movement,
    String? interactionFeedback,
    int interactionFeedbackUntilMs = 0,
    GameResult? result,
    int? countdownRemainingMs,
  }) : configuration = configuration ?? GameConfiguration.initial,
       islands = List.unmodifiable(islands ?? bases ?? const <IslandState>[]),
       selectedIslandId = selectedIslandId ?? selectedBaseId,
       movingForces = List.unmodifiable(
         movingForces ??
             (movement == null
                 ? const <MovingForce>[]
                 : <MovingForce>[movement]),
       ),
       interactionFeedback = interactionFeedback,
       interactionFeedbackUntilMs = interactionFeedbackUntilMs,
       result = result,
       countdownRemainingMs = countdownRemainingMs ?? 0 {
    if ((phase == GamePhase.result) != (result != null)) {
      throw StateError(
        'Only a result phase may include a GameResult, and it must include one',
      );
    }
  }

  final GameConfiguration configuration;
  final GamePhase phase;
  final int elapsedMs;
  final List<IslandState> islands;
  final int? selectedIslandId;
  final List<MovingForce> movingForces;
  final String? interactionFeedback;
  final int interactionFeedbackUntilMs;
  final GameResult? result;
  final int countdownRemainingMs;

  /// PR #3 compatibility getters.
  List<IslandState> get bases => islands;
  int? get selectedBaseId => selectedIslandId;
  MovingForce? get movement => movingForces.isEmpty ? null : movingForces.first;

  bool get hasInteractionFeedback =>
      interactionFeedback != null && elapsedMs < interactionFeedbackUntilMs;

  /// Compatibility alias for callers that use the shorter feedback name.
  String? get feedback => interactionFeedback;

  bool get isCountdown =>
      phase == GamePhase.startCountdown || phase == GamePhase.resumeCountdown;

  GameState copyWith({
    GameConfiguration? configuration,
    GamePhase? phase,
    int? elapsedMs,
    List<IslandState>? islands,
    List<BaseState>? bases,
    int? selectedIslandId,
    int? selectedBaseId,
    List<MovingForce>? movingForces,
    String? interactionFeedback,
    int? interactionFeedbackUntilMs,
    GameResult? result,
    int? countdownRemainingMs,
  }) {
    return GameState(
      configuration: configuration ?? this.configuration,
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      islands: islands ?? bases ?? this.islands,
      selectedIslandId:
          selectedIslandId ?? selectedBaseId ?? this.selectedIslandId,
      movingForces: movingForces ?? this.movingForces,
      interactionFeedback: interactionFeedback ?? this.interactionFeedback,
      interactionFeedbackUntilMs:
          interactionFeedbackUntilMs ?? this.interactionFeedbackUntilMs,
      result: result ?? this.result,
      countdownRemainingMs: countdownRemainingMs ?? this.countdownRemainingMs,
    );
  }

  /// Atomically enters the result phase with its result.  This avoids a
  /// transient non-result phase that carries a result.
  GameState finishWithResult(GameResult nextResult) {
    return GameState(
      configuration: configuration,
      phase: GamePhase.result,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: movingForces,
      interactionFeedback: interactionFeedback,
      interactionFeedbackUntilMs: interactionFeedbackUntilMs,
      result: nextResult,
      countdownRemainingMs: 0,
    );
  }

  /// Atomically enters a non-result phase without a result.  This is used for
  /// reset/configuration transitions from a completed match.
  GameState transitionToPhase(
    GamePhase nextPhase, {
    int countdownRemainingMs = 0,
  }) {
    if (nextPhase == GamePhase.result) {
      throw ArgumentError.value(
        nextPhase,
        'nextPhase',
        'use finishWithResult for the result phase',
      );
    }
    return GameState(
      configuration: configuration,
      phase: nextPhase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: movingForces,
      interactionFeedback: interactionFeedback,
      interactionFeedbackUntilMs: interactionFeedbackUntilMs,
      result: null,
      countdownRemainingMs: countdownRemainingMs,
    );
  }

  /// Clears the nullable selection through a typed API rather than a dynamic
  /// sentinel in [copyWith].
  GameState clearSelection() {
    return GameState(
      configuration: configuration,
      phase: phase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: null,
      movingForces: movingForces,
      interactionFeedback: interactionFeedback,
      interactionFeedbackUntilMs: interactionFeedbackUntilMs,
      result: result,
      countdownRemainingMs: countdownRemainingMs,
    );
  }

  /// Clears all moving forces through a typed API.
  GameState clearMovingForces() {
    return GameState(
      configuration: configuration,
      phase: phase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: const <MovingForce>[],
      interactionFeedback: interactionFeedback,
      interactionFeedbackUntilMs: interactionFeedbackUntilMs,
      result: result,
      countdownRemainingMs: countdownRemainingMs,
    );
  }

  /// Clears a result only while the state is not in the result phase.  This
  /// preserves the invariant that a result phase always carries its result.
  GameState clearResult() {
    if (phase == GamePhase.result) {
      throw StateError('A result phase cannot clear its GameResult');
    }
    return GameState(
      configuration: configuration,
      phase: phase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: movingForces,
      interactionFeedback: interactionFeedback,
      interactionFeedbackUntilMs: interactionFeedbackUntilMs,
      result: null,
      countdownRemainingMs: countdownRemainingMs,
    );
  }

  /// Compatibility helper for callers that used the old singular movement
  /// field while keeping the update statically typed.
  GameState copyWithMovement(MovingForce? movement) {
    return movement == null
        ? clearMovingForces()
        : copyWith(movingForces: <MovingForce>[movement]);
  }

  /// Removes transient interaction feedback without changing the match.
  GameState clearInteractionFeedback() {
    return GameState(
      configuration: configuration,
      phase: phase,
      elapsedMs: elapsedMs,
      islands: islands,
      selectedIslandId: selectedIslandId,
      movingForces: movingForces,
      interactionFeedback: null,
      interactionFeedbackUntilMs: 0,
      result: result,
      countdownRemainingMs: countdownRemainingMs,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameState &&
        other.configuration == configuration &&
        other.phase == phase &&
        other.elapsedMs == elapsedMs &&
        _listEquals(other.islands, islands) &&
        other.selectedIslandId == selectedIslandId &&
        _listEquals(other.movingForces, movingForces) &&
        other.interactionFeedback == interactionFeedback &&
        other.interactionFeedbackUntilMs == interactionFeedbackUntilMs &&
        other.result == result &&
        other.countdownRemainingMs == countdownRemainingMs;
  }

  @override
  int get hashCode => Object.hash(
    configuration,
    phase,
    elapsedMs,
    Object.hashAll(islands),
    selectedIslandId,
    Object.hashAll(movingForces),
    interactionFeedback,
    interactionFeedbackUntilMs,
    result,
    countdownRemainingMs,
  );

  static bool _listEquals<T>(List<T> first, List<T> second) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}
