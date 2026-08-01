import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'game_loop.dart';
import 'game_state.dart';

part 'game_controller.g.dart';

final randomProvider = Provider<Random>((ref) => Random());

@riverpod
class GameController extends _$GameController {
  late final GameLoop _gameLoop;
  late final Random _random;

  @override
  GameState build() {
    _gameLoop = ref.read(gameLoopProvider);
    _random = ref.read(randomProvider);
    ref.onDispose(_gameLoop.stop);

    return GameState(
      phase: GamePhase.ready,
      elapsedMs: 0,
      bases: _generateBases(),
      selectedBaseId: null,
      movement: null,
    );
  }

  void startGame() {
    if (state.phase == GamePhase.playing) {
      return;
    }

    state = state.copyWith(phase: GamePhase.playing);
    _gameLoop.start(_tick);
  }

  void tapBase(int baseId) {
    final selectedBaseId = state.selectedBaseId;
    if (selectedBaseId == null) {
      state = state.copyWith(selectedBaseId: baseId);
      return;
    }

    final sourceBase = state.bases[selectedBaseId];
    final scale = (sourceBase.scale / 2).floor();
    final bases = [...state.bases];
    bases[selectedBaseId] = sourceBase.copyWith(scale: scale);

    state = state.copyWith(
      bases: bases,
      movement: MovementState(
        sourceBaseId: selectedBaseId,
        targetBaseId: baseId,
        x: sourceBase.x,
        y: sourceBase.y,
        deltaX: state.movement?.deltaX ?? 0,
        deltaY: state.movement?.deltaY ?? 0,
        scale: scale,
      ),
    );
  }

  void _tick() {
    var nextState = state.copyWith(elapsedMs: state.elapsedMs + 50);
    final movement = state.movement;

    if (movement != null) {
      final sourceBase = state.bases[movement.sourceBaseId];
      final targetBase = state.bases[movement.targetBaseId];
      var deltaX = movement.deltaX;
      var deltaY = movement.deltaY;

      if (deltaX == 0) {
        deltaX = _calcDiff(sourceBase.x, targetBase.x);
      }
      if (deltaY == 0) {
        deltaY = _calcDiff(sourceBase.y, targetBase.y);
      }

      var tankX = movement.x;
      var tankY = movement.y;
      if (sourceBase.x >= targetBase.x) {
        tankX -= deltaX / 100;
      } else {
        tankX += deltaX / 100;
      }
      if (sourceBase.y >= targetBase.y) {
        tankY -= deltaY / 100;
      } else {
        tankY += deltaY / 100;
      }

      final arrived =
          _calcDiff(targetBase.x, tankX) <= 0.01 &&
          _calcDiff(targetBase.y, tankY) <= 0.01;
      if (arrived) {
        final bases = [...nextState.bases];
        bases[movement.targetBaseId] = targetBase.copyWith(
          scale: targetBase.scale + movement.scale,
        );
        nextState = nextState.copyWith(
          bases: bases,
          selectedBaseId: null,
          movement: null,
        );
      } else {
        nextState = nextState.copyWith(
          movement: movement.copyWith(
            x: tankX,
            y: tankY,
            deltaX: deltaX,
            deltaY: deltaY,
          ),
        );
      }
    }

    if (nextState.elapsedMs % 1000 == 0) {
      nextState = nextState.copyWith(
        bases: [
          for (final base in nextState.bases)
            base.copyWith(scale: base.scale + 1),
        ],
      );
    }

    state = nextState;
  }

  List<BaseState> _generateBases() {
    return [
      const BaseState(id: 0, x: 1, y: 1, control: BaseControl.ally, scale: 100),
      const BaseState(
        id: 1,
        x: -1,
        y: -1,
        control: BaseControl.enemy,
        scale: 100,
      ),
      for (var id = 2; id <= 9; id++)
        BaseState(
          id: id,
          x: _randomDouble(),
          y: _randomDouble(),
          control: BaseControl.neutral,
          scale: 0,
        ),
    ];
  }

  double _randomDouble() {
    if (_random.nextBool()) {
      return _random.nextDouble();
    }
    return _random.nextDouble() - 1;
  }

  double _calcDiff(double first, double second) {
    return (first - second).abs();
  }
}
