import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _portrait = IslandMapViewport(width: 800, height: 1200);
const _landscape = IslandMapViewport(width: 1200, height: 800);

final class _ViewportNotifier extends Notifier<IslandMapViewport> {
  @override
  IslandMapViewport build() => _portrait;

  void setViewport(IslandMapViewport viewport) => state = viewport;
}

final _viewportProvider =
    NotifierProvider<_ViewportNotifier, IslandMapViewport>(
      _ViewportNotifier.new,
    );

final class _Clock extends GameClock {
  int elapsedMs = 0;

  @override
  int nowMs() => elapsedMs;
}

final class _CountingZeroRandom implements Random {
  int calls = 0;

  @override
  bool nextBool() {
    calls++;
    return false;
  }

  @override
  double nextDouble() {
    calls++;
    return 0;
  }

  @override
  int nextInt(int max) {
    calls++;
    return 0;
  }
}

void main() {
  late ProviderContainer container;
  late GameController controller;
  late ManualGameLoop loop;
  late _Clock clock;
  late _CountingZeroRandom timingRandom;

  void tickMany(int count) {
    for (var index = 0; index < count; index++) {
      loop.tick();
    }
  }

  void resize(IslandMapViewport viewport) {
    container.read(_viewportProvider.notifier).setViewport(viewport);
    container.read(gameControllerProvider);
  }

  void dispatch() {
    controller.startGame();
    tickMany(60);
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
    tickMany(10);
    controller.tapBase(0);
  }

  setUp(() {
    loop = ManualGameLoop();
    clock = _Clock();
    timingRandom = _CountingZeroRandom();
    container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        gameClockProvider.overrideWithValue(clock),
        randomProvider.overrideWithValue(Random(1)),
        cpuTimingRandomProvider.overrideWithValue(timingRandom),
        cpuQualityRandomProvider.overrideWithValue(_CountingZeroRandom()),
        mapViewportProvider.overrideWith((ref) => ref.watch(_viewportProvider)),
      ],
    );
    final subscription = container.listen(gameControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    controller = container.read(gameControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('safe resize replans only movement at the frozen game time', () {
    dispatch();
    final before = controller.state;
    final force = before.movingForces.single;

    resize(_landscape);

    final after = controller.state;
    final replanned = after.movingForces.single;
    expect(after, before.copyWith(movingForces: after.movingForces));
    expect(replanned.id, force.id);
    expect(replanned.sourceIslandId, force.sourceIslandId);
    expect(replanned.destinationIslandId, force.destinationIslandId);
    expect(replanned.faction, force.faction);
    expect(replanned.strength, force.strength);
    expect(replanned.departureTimeMs, force.departureTimeMs);
    expect(replanned.progress, force.progress);
    expect(replanned.position, force.position);
    expect(replanned.segmentStartTimeMs, before.elapsedMs);
    expect(replanned.segmentStartProgress, force.progress);
    final remaining = max(
      1,
      (GameRules.movementDurationMs *
              _landscape.movingForceDistance(
                force.position,
                before.islands.last.position,
              ) /
              _landscape.movingForceScreenDiagonal)
          .round(),
    );
    expect(replanned.arrivalTimeMs, before.elapsedMs + remaining);
    expect(replanned.arrivalTimeMs, isNot(force.arrivalTimeMs));
    expect(loop.isRunning, isTrue);

    loop.tick();
    expect(controller.state.elapsedMs, before.elapsedMs + 50);
    expect(
      controller.state.movingForces.single.progress,
      greaterThan(force.progress),
    );
  });

  test('same-size rebuild and pause resume do not replace the plan', () {
    dispatch();
    final force = controller.state.movingForces.single;
    container.invalidate(mapViewportProvider);
    container.read(gameControllerProvider);
    expect(controller.state.movingForces.single, same(force));

    controller.pauseGame();
    clock.elapsedMs += 100000;
    controller.resumeGame();
    tickMany(60);
    expect(controller.state.phase, GamePhase.playing);
    expect(controller.state.elapsedMs, 500);
    expect(controller.state.movingForces.single, same(force));
  });

  test('paused resize replans once and never starts the loop', () {
    dispatch();
    controller.pauseGame();
    final before = controller.state;
    resize(_landscape);
    final replanned = controller.state.movingForces.single;
    expect(controller.state.phase, GamePhase.paused);
    expect(controller.state.elapsedMs, before.elapsedMs);
    expect(replanned.progress, before.movingForces.single.progress);
    expect(replanned.segmentStartTimeMs, before.elapsedMs);
    expect(loop.isRunning, isFalse);

    container.invalidate(mapViewportProvider);
    container.read(gameControllerProvider);
    expect(controller.state.movingForces.single, same(replanned));
    controller.resumeGame();
    tickMany(60);
    expect(controller.state.movingForces.single, same(replanned));
    expect(controller.state.elapsedMs, before.elapsedMs);
  });

  test(
    'invalid viewports retain the old plan until explicit safe recovery',
    () {
      dispatch();
      final before = controller.state;
      for (final viewport in const [
        IslandMapViewport(width: 0, height: 800),
        IslandMapViewport(width: 30, height: 800),
        IslandMapViewport(width: double.nan, height: 800),
        IslandMapViewport(width: 800, height: double.infinity),
        IslandMapViewport(width: 100, height: 100),
      ]) {
        resize(viewport);
        expect(controller.state.viewportUnavailable, isTrue);
        expect(controller.state.elapsedMs, before.elapsedMs);
        expect(
          controller.state.movingForces.single,
          same(before.movingForces.single),
        );
        expect(loop.isRunning, isFalse);
        controller.resumeAfterViewportChange();
        controller.startGame();
        controller.tapBase(1);
        loop.tick();
        expect(controller.state.selectedIslandId, before.selectedIslandId);
        expect(controller.state.movingForces, before.movingForces);
        expect(controller.state.elapsedMs, before.elapsedMs);
      }

      clock.elapsedMs += 100000;
      resize(_landscape);
      expect(controller.state.viewportUnavailable, isTrue);
      expect(
        controller.state.movingForces.single,
        same(before.movingForces.single),
      );
      expect(loop.isRunning, isFalse);
      controller.resumeAfterViewportChange();
      expect(controller.state.viewportUnavailable, isFalse);
      expect(controller.state.elapsedMs, before.elapsedMs);
      expect(
        controller.state.movingForces.single.segmentStartTimeMs,
        before.elapsedMs,
      );
      expect(
        controller.state.movingForces.single.progress,
        before.movingForces.single.progress,
      );
      expect(loop.isRunning, isTrue);
      loop.tick();
      expect(controller.state.elapsedMs, before.elapsedMs + 50);
    },
  );

  test('returning to the previous valid size keeps the old plan', () {
    dispatch();
    final force = controller.state.movingForces.single;
    resize(const IslandMapViewport(width: 100, height: 100));
    resize(_portrait);
    controller.resumeAfterViewportChange();
    expect(controller.state.movingForces.single, same(force));
    expect(controller.state.elapsedMs, 500);
  });

  test('repeated resizes do not reset the pending CPU deadline', () {
    dispatch();
    expect(timingRandom.calls, 1);
    resize(_landscape);
    resize(_portrait);
    resize(_landscape);
    expect(timingRandom.calls, 1);
    tickMany(44);
    expect(controller.state.elapsedMs, 2700);
    expect(timingRandom.calls, 1);
    loop.tick();
    expect(controller.state.elapsedMs, 2750);
    expect(timingRandom.calls, 2);
  });
}
