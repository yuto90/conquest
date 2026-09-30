import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// This regression intentionally uses only pre-#116 public APIs so it can be
// run unchanged against the original implementation to demonstrate the bug.
void main() {
  test('resize updates the arrival deadline for remaining screen distance', () {
    const portrait = IslandMapViewport(width: 800, height: 1200);
    const landscape = IslandMapViewport(width: 1200, height: 800);
    final loop = ManualGameLoop();
    final random = Random(1);
    final cpu = CpuStrategy.noop();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(random),
        cpuStrategyProvider.overrideWithValue(cpu),
        mapViewportProvider.overrideWithValue(portrait),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(gameControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    controller.state = controller.state.copyWith(
      islands: const [
        IslandState(
          id: 0,
          position: IslandPosition(x: -0.7, y: -0.4),
          faction: Faction.player,
          size: IslandSize.headquarters,
          currentForces: 100,
          capacity: 200,
        ),
        IslandState(
          id: 1,
          position: IslandPosition(x: 0.7, y: 0.1),
          faction: Faction.cpu,
          size: IslandSize.headquarters,
          currentForces: 100,
          capacity: 200,
        ),
      ],
    );
    controller.tapBase(0);
    controller.tapBase(1);
    for (var index = 0; index < 10; index++) {
      loop.tick();
    }
    final before = controller.state;
    final force = before.movingForces.single;
    final expectedRemainder = max(
      1,
      (GameRules.movementDurationMs *
              landscape.movingForceDistance(
                force.position,
                before.islands.last.position,
              ) /
              landscape.movingForceScreenDiagonal)
          .round(),
    );

    container.updateOverrides([
      gameLoopProvider.overrideWithValue(loop),
      randomProvider.overrideWithValue(random),
      cpuStrategyProvider.overrideWithValue(cpu),
      mapViewportProvider.overrideWithValue(landscape),
    ]);
    final after = container.read(gameControllerProvider);

    expect(after.elapsedMs, before.elapsedMs);
    expect(after.movingForces.single.progress, force.progress);
    expect(after.movingForces.single.position, force.position);
    expect(
      after.movingForces.single.arrivalTimeMs,
      before.elapsedMs + expectedRemainder,
    );
    expect(after.movingForces.single.arrivalTimeMs, isNot(force.arrivalTimeMs));
  });
}
