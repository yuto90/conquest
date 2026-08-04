import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

void completeStartCountdown(ManualGameLoop loop) {
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
}

void main() {
  late ManualGameLoop loop;
  late ProviderContainer container;

  setUp(() {
    loop = ManualGameLoop();
    container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(7)),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            random: ZeroRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('dispatches at most one CPU troop per due judgment', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);

    for (var index = 0; index < 29; index++) {
      loop.tick();
    }
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      isEmpty,
    );

    loop.tick();
    final firstDue = container.read(gameControllerProvider);
    expect(
      firstDue.movingForces.where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );

    loop.tick();
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
  });

  test('does not decide during a countdown or after pausing', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    controller.state = container
        .read(gameControllerProvider)
        .copyWith(phase: GamePhase.startCountdown, countdownRemainingMs: 1000);

    for (var index = 0; index < 20; index++) {
      loop.tick();
    }
    expect(container.read(gameControllerProvider).phase, GamePhase.playing);
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      isEmpty,
    );

    controller.pauseGame();
    final paused = container.read(gameControllerProvider);
    expect(paused.phase, GamePhase.paused);
    expect(loop.isRunning, isFalse);
    loop.tick();
    expect(container.read(gameControllerProvider), paused);
  });
}
