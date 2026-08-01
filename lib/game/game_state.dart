enum GamePhase { ready, playing }

enum BaseControl { ally, enemy, neutral }

final class BaseState {
  const BaseState({
    required this.id,
    required this.x,
    required this.y,
    required this.control,
    required this.scale,
  });

  final int id;
  final double x;
  final double y;
  final BaseControl control;
  final int scale;

  BaseState copyWith({
    int? id,
    double? x,
    double? y,
    BaseControl? control,
    int? scale,
  }) {
    return BaseState(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      control: control ?? this.control,
      scale: scale ?? this.scale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BaseState &&
        other.id == id &&
        other.x == x &&
        other.y == y &&
        other.control == control &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(id, x, y, control, scale);
}

final class MovementState {
  const MovementState({
    required this.sourceBaseId,
    required this.targetBaseId,
    required this.x,
    required this.y,
    required this.deltaX,
    required this.deltaY,
    required this.scale,
  });

  final int sourceBaseId;
  final int targetBaseId;
  final double x;
  final double y;
  final double deltaX;
  final double deltaY;
  final int scale;

  MovementState copyWith({
    int? sourceBaseId,
    int? targetBaseId,
    double? x,
    double? y,
    double? deltaX,
    double? deltaY,
    int? scale,
  }) {
    return MovementState(
      sourceBaseId: sourceBaseId ?? this.sourceBaseId,
      targetBaseId: targetBaseId ?? this.targetBaseId,
      x: x ?? this.x,
      y: y ?? this.y,
      deltaX: deltaX ?? this.deltaX,
      deltaY: deltaY ?? this.deltaY,
      scale: scale ?? this.scale,
    );
  }
}

final class GameState {
  GameState({
    required this.phase,
    required this.elapsedMs,
    required List<BaseState> bases,
    required this.selectedBaseId,
    required this.movement,
  }) : bases = List.unmodifiable(bases);

  final GamePhase phase;
  final int elapsedMs;
  final List<BaseState> bases;
  final int? selectedBaseId;
  final MovementState? movement;

  static const _unchanged = Object();

  GameState copyWith({
    GamePhase? phase,
    int? elapsedMs,
    List<BaseState>? bases,
    Object? selectedBaseId = _unchanged,
    Object? movement = _unchanged,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      bases: bases ?? this.bases,
      selectedBaseId: identical(selectedBaseId, _unchanged)
          ? this.selectedBaseId
          : selectedBaseId as int?,
      movement: identical(movement, _unchanged)
          ? this.movement
          : movement as MovementState?,
    );
  }
}
