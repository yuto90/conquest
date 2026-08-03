import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  int startCount = 0;
  int stopCount = 0;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) {
    startCount++;
    _onTick = onTick;
  }

  @override
  void stop() {
    stopCount++;
    _onTick = null;
  }

  void tick() => _onTick?.call();
}

void main() {
  late ManualGameLoop loop;
  late ProviderContainer container;

  setUp(() {
    loop = ManualGameLoop();
    container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('builds the ten expected bases', () {
    final state = container.read(gameControllerProvider);

    expect(state.phase, GamePhase.ready);
    expect(state.bases, hasLength(10));
    expect(
      state.bases[0],
      const BaseState(id: 0, x: 1, y: 1, control: BaseControl.ally, scale: 100),
    );
    expect(
      state.bases[1],
      const BaseState(
        id: 1,
        x: -1,
        y: -1,
        control: BaseControl.enemy,
        scale: 100,
      ),
    );
    expect(
      state.bases
          .skip(2)
          .every(
            (base) => base.control == BaseControl.neutral && base.scale == 0,
          ),
      isTrue,
    );
  });

  test('starts the game and loop only once', () {
    final controller = container.read(gameControllerProvider.notifier);

    controller.startGame();
    controller.startGame();

    expect(container.read(gameControllerProvider).phase, GamePhase.playing);
    expect(loop.startCount, 1);
  });

  test('selects a source and creates movement on the next tap', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();

    controller.tapBase(0);
    expect(container.read(gameControllerProvider).selectedBaseId, 0);
    expect(container.read(gameControllerProvider).movement, isNull);

    controller.tapBase(1);
    final state = container.read(gameControllerProvider);

    expect(state.selectedBaseId, 0);
    expect(state.movement, isNotNull);
    expect(state.movement!.sourceBaseId, 0);
    expect(state.movement!.targetBaseId, 1);
    expect(state.movement!.scale, 50);
    expect(state.bases[0].scale, 50);
  });

  test('preserves a selected source across ticks before destination tap', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    controller.tapBase(0);

    loop.tick();
    loop.tick();

    expect(container.read(gameControllerProvider).selectedBaseId, 0);
    expect(container.read(gameControllerProvider).movement, isNull);

    controller.tapBase(1);
    final state = container.read(gameControllerProvider);
    expect(state.selectedBaseId, 0);
    expect(state.movement, isNotNull);
  });

  test('ticks movement and resolves it at the target', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    controller.tapBase(0);
    controller.tapBase(1);

    for (var i = 0; i < 100; i++) {
      loop.tick();
    }

    final state = container.read(gameControllerProvider);
    expect(state.movement, isNull);
    expect(state.selectedBaseId, isNull);
    expect(state.bases[0].scale, 55);
    expect(state.bases[1].scale, 155);
  });

  test('increments every base after one second', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();

    for (var i = 0; i < 20; i++) {
      loop.tick();
    }

    final state = container.read(gameControllerProvider);
    expect(state.elapsedMs, 1000);
    expect(
      state.bases.every((base) => base.scale == (base.id < 2 ? 101 : 1)),
      isTrue,
    );
  });

  test('preserves retargeting and re-halving while moving', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    controller.tapBase(0);
    controller.tapBase(1);
    controller.tapBase(2);

    final state = container.read(gameControllerProvider);
    expect(state.movement!.targetBaseId, 2);
    expect(state.movement!.scale, 25);
    expect(state.bases[0].scale, 25);
  });

  test('stops the loop when the provider is disposed', () {
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
    );
    localContainer.read(gameControllerProvider);
    localContainer.read(gameControllerProvider.notifier).startGame();

    localContainer.dispose();

    expect(loop.stopCount, 1);
    expect(loop.isRunning, isFalse);
  });
}
