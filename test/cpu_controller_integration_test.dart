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

final class MaximumRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.9999999999999999;

  @override
  int nextInt(int max) => max - 1;
}

final class SequenceRandom implements Random {
  SequenceRandom(Iterable<int> values) : _values = [...values];

  final List<int> _values;

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1000) / 1000;

  @override
  int nextInt(int max) {
    if (_values.isEmpty) {
      throw StateError('sequence random exhausted');
    }
    final value = _values.removeAt(0);
    if (value < 0 || value >= max) {
      throw RangeError.range(value, 0, max - 1, 'value');
    }
    return value;
  }
}

int cpuMovingForceCount(GameState state) {
  return state.movingForces
      .where((force) => force.faction == Faction.cpu)
      .length;
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
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('dispatches at most one CPU troop per due judgment', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
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

  test('uses the selected difficulty interval for the first judgment', () {
    const dueTicks = <CpuDifficulty, int>{
      CpuDifficulty.veryEasy: 100,
      CpuDifficulty.easy: 80,
      CpuDifficulty.normal: 55,
      CpuDifficulty.hard: 30,
    };

    for (final entry in dueTicks.entries) {
      final localLoop = ManualGameLoop();
      final localContainer = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(localLoop),
          randomProvider.overrideWithValue(Random(7)),
          cpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              timingRandom: ZeroRandom(),
              qualityRandom: entry.key == CpuDifficulty.hard
                  ? SequenceRandom(const [])
                  : MaximumRandom(),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
        ],
      );

      try {
        final controller = localContainer.read(gameControllerProvider.notifier);
        controller.selectCpuDifficulty(entry.key);
        controller.startGame();
        completeStartCountdown(localLoop);

        for (var index = 0; index < entry.value - 1; index++) {
          localLoop.tick();
        }
        expect(
          cpuMovingForceCount(localContainer.read(gameControllerProvider)),
          0,
          reason: '${entry.key} dispatched before its deadline',
        );

        localLoop.tick();
        expect(
          cpuMovingForceCount(localContainer.read(gameControllerProvider)),
          1,
          reason: '${entry.key} did not dispatch at its deadline',
        );
      } finally {
        localContainer.dispose();
      }
    }
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

  test('retains a pending CPU deadline across the resume countdown', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);

    for (var index = 0; index < 54; index++) {
      loop.tick();
    }
    expect(container.read(gameControllerProvider).elapsedMs, 2700);
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      isEmpty,
    );

    controller.pauseGame();
    controller.resumeGame();
    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.resumeCountdown,
    );
    completeStartCountdown(loop);
    expect(container.read(gameControllerProvider).elapsedMs, 2700);

    loop.tick();
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
  });

  test('retains the selected difficulty deadline across pause and resume', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.startGame();
    completeStartCountdown(loop);

    for (var index = 0; index < 9; index++) {
      loop.tick();
    }
    expect(container.read(gameControllerProvider).elapsedMs, 450);

    controller.pauseGame();
    controller.resumeGame();
    completeStartCountdown(loop);
    expect(container.read(gameControllerProvider).elapsedMs, 450);

    for (var index = 0; index < 20; index++) {
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
    expect(
      container
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
  });

  test('reschedules skipped judgments from current game time', () {
    const dueTicks = <CpuDifficulty, int>{
      CpuDifficulty.veryEasy: 100,
      CpuDifficulty.easy: 80,
      CpuDifficulty.normal: 55,
      CpuDifficulty.hard: 30,
    };

    for (final entry in dueTicks.entries) {
      final difficulty = entry.key;
      final due = entry.value;
      final localLoop = ManualGameLoop();
      final localContainer = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(localLoop),
          randomProvider.overrideWithValue(Random(7)),
          cpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              timingRandom: ZeroRandom(),
              qualityRandom: difficulty == CpuDifficulty.hard
                  ? SequenceRandom(const [])
                  : SequenceRandom([0, 99, 0]),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(difficulty);
      controller.startGame();
      completeStartCountdown(localLoop);

      for (var index = 0; index < due - 1; index += 1) {
        localLoop.tick();
      }
      expect(
        localContainer.read(gameControllerProvider).elapsedMs,
        (due - 1) * 50,
        reason: '$difficulty before first deadline',
      );
      localLoop.tick();
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 1 : 0,
        reason: '$difficulty first deadline',
      );

      // A skipped judgment must not be caught up on the next 50ms callback.
      localLoop.tick();
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 1 : 0,
        reason: '$difficulty catch-up after first deadline',
      );

      for (var index = 0; index < due - 2; index += 1) {
        localLoop.tick();
      }
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 1 : 0,
        reason: '$difficulty before rescheduled deadline',
      );
      localLoop.tick();
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 2 : 1,
        reason: '$difficulty rescheduled deadline',
      );
    }
  });
}
