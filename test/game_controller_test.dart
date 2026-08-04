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

  test('uses an externally configured island count on initial build', () {
    final configuredContainer = ProviderContainer(
      overrides: [
        gameConfigurationProvider.overrideWithValue(
          GameConfiguration(totalIslandCount: 8),
        ),
        gameLoopProvider.overrideWithValue(ManualGameLoop()),
        randomProvider.overrideWithValue(Random(1)),
      ],
    );
    addTearDown(configuredContainer.dispose);

    final state = configuredContainer.read(gameControllerProvider);

    expect(state.configuration.totalIslandCount, 8);
    expect(state.islands, hasLength(8));
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

    expect(state.selectedBaseId, isNull);
    expect(state.movement, isNotNull);
    expect(state.movement!.sourceBaseId, 0);
    expect(state.movement!.targetBaseId, 1);
    expect(state.movement!.scale, 50);
    expect(state.bases[0].scale, 50);
  });

  test(
    'rejects non-player sources and deselects a source when tapped again',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();

      controller.tapBase(2);
      expect(container.read(gameControllerProvider).selectedBaseId, isNull);

      controller.tapBase(0);
      expect(container.read(gameControllerProvider).selectedBaseId, 0);

      controller.tapBase(0);
      expect(container.read(gameControllerProvider).selectedBaseId, isNull);
    },
  );

  test(
    'uses force at destination tap time and clears an invalid selection',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      controller.tapBase(0);

      final selected = container.read(gameControllerProvider);
      final changedIslands = [
        for (final island in selected.islands)
          island.id == 0 ? island.copyWith(currentForces: 7) : island,
      ];
      controller.state = selected.copyWith(islands: changedIslands);
      controller.tapBase(2);

      final dispatched = container.read(gameControllerProvider);
      expect(dispatched.movingForces.single.strength, 3);
      expect(dispatched.islands.first.currentForces, 4);
      expect(dispatched.selectedIslandId, isNull);

      controller.tapBase(0);
      final invalidated = container.read(gameControllerProvider);
      controller.state = invalidated.copyWith(
        islands: [
          for (final island in invalidated.islands)
            island.id == 0 ? island.copyWith(currentForces: 1) : island,
        ],
      );
      loop.tick();

      expect(container.read(gameControllerProvider).selectedIslandId, isNull);
    },
  );

  test(
    'dispatches floor half for zero, one, even, odd, and maximum forces',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      final playing = container.read(gameControllerProvider);

      for (final force in [0, 1, 2, 5, 200]) {
        controller.state = playing.copyWith(
          islands: [
            for (final island in playing.islands)
              island.id == 0 ? island.copyWith(currentForces: force) : island,
          ],
        );
        controller.tapBase(0);
        controller.tapBase(2);

        final state = container.read(gameControllerProvider);
        final expectedDispatch = force ~/ 2;
        if (expectedDispatch == 0) {
          expect(state.movingForces, isEmpty, reason: 'force=$force');
          expect(state.selectedIslandId, isNull, reason: 'force=$force');
        } else {
          expect(state.movingForces.single.strength, expectedDispatch);
          expect(state.islands.first.currentForces, force - expectedDispatch);
          expect(state.selectedIslandId, isNull, reason: 'force=$force');
        }
      }
    },
  );

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
    expect(state.selectedBaseId, isNull);
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

  test(
    'increments owned bases after one second without growing neutral bases',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();

      for (var i = 0; i < 20; i++) {
        loop.tick();
      }

      final state = container.read(gameControllerProvider);
      expect(state.elapsedMs, 1000);
      expect(
        state.bases.every((base) => base.scale == (base.id < 2 ? 101 : 0)),
        isTrue,
      );
    },
  );

  test('appends consecutive dispatches from one source', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    controller.tapBase(0);
    controller.tapBase(1);
    final first = container.read(gameControllerProvider).movingForces.single;

    controller.tapBase(0);
    controller.tapBase(2);

    final state = container.read(gameControllerProvider);
    expect(state.movingForces, hasLength(2));
    expect(state.movingForces[0], first);
    expect(state.movingForces[0].targetBaseId, 1);
    expect(state.movingForces[0].scale, 50);
    expect(state.movingForces[1].targetBaseId, 2);
    expect(state.movingForces[1].scale, 25);
    expect(state.movingForces[1].id, isNot(state.movingForces[0].id));
    expect(state.bases[0].scale, 25);
    expect(state.selectedIslandId, isNull);
  });

  test('keeps troops from different sources independent', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();

    final initial = container.read(gameControllerProvider);
    controller.state = initial.copyWith(
      islands: [
        for (final island in initial.islands)
          if (island.id == 2)
            island.copyWith(faction: Faction.player, currentForces: 40)
          else
            island,
      ],
    );

    controller.tapBase(0);
    controller.tapBase(2);
    controller.tapBase(2);
    controller.tapBase(3);

    final state = container.read(gameControllerProvider);
    expect(state.movingForces, hasLength(2));
    expect(
      state.movingForces.map((force) => force.sourceIslandId),
      orderedEquals([0, 2]),
    );
    expect(
      state.movingForces.map((force) => force.destinationIslandId),
      orderedEquals([2, 3]),
    );
    expect(
      state.movingForces.map((force) => force.strength),
      orderedEquals([50, 20]),
    );
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
