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

final class _ViewportNotifier extends Notifier<IslandMapViewport> {
  @override
  IslandMapViewport build() => GameRules.defaultMapViewport;

  void setViewport(IslandMapViewport viewport) => state = viewport;
}

final _viewportProvider =
    NotifierProvider<_ViewportNotifier, IslandMapViewport>(
      _ViewportNotifier.new,
    );

int cpuMovingForceCount(GameState state) {
  return state.movingForces
      .where((force) => force.faction == Faction.cpu)
      .length;
}

List<IslandState> _simultaneousDecisionBoard(List<IslandState> generated) => [
  generated[0].copyWith(
    faction: Faction.player,
    currentForces: 100,
    durability: 0,
    x: -0.8,
    y: 0,
  ),
  generated[1].copyWith(
    faction: Faction.cpu,
    currentForces: 10,
    durability: 0,
    x: 0.8,
    y: 0,
  ),
  generated[2].copyWith(
    faction: Faction.cpu,
    currentForces: 100,
    durability: 0,
    x: 0.7,
    y: 0,
  ),
  generated[3].copyWith(
    faction: Faction.player,
    currentForces: 10,
    durability: 0,
    x: -0.7,
    y: 0,
  ),
];

void completeStartCountdown(ManualGameLoop loop) {
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
}

void tickMany(ManualGameLoop loop, int count) {
  for (var index = 0; index < count; index++) {
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

  test('spectator CPUs use independent difficulty deadlines', () {
    final localLoop = ManualGameLoop();
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(localLoop),
        randomProvider.overrideWithValue(Random(7)),
        playerCpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.player,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.cpu,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
    addTearDown(localContainer.dispose);
    final controller = localContainer.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
    controller.selectCpuDifficulty(CpuDifficulty.easy);
    controller.startGame();
    completeStartCountdown(localLoop);

    for (var index = 0; index < 29; index++) {
      localLoop.tick();
    }
    expect(
      localContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.player),
      isEmpty,
    );
    localLoop.tick();
    final state = localContainer.read(gameControllerProvider);
    expect(
      state.movingForces.where((force) => force.faction == Faction.player),
      hasLength(1),
    );
    expect(
      state.movingForces.where((force) => force.faction == Faction.cpu),
      isEmpty,
    );
  });

  test(
    'production 1P strategy keeps seeded RNG streams across a viewport rebuild',
    () {
      final timingRandom = Random(17);
      final qualityRandom = Random(23);
      final container = ProviderContainer(
        overrides: [
          mapViewportProvider.overrideWith(
            (ref) => ref.watch(_viewportProvider),
          ),
          playerCpuRandomProvider.overrideWithValue(timingRandom),
          playerCpuQualityRandomProvider.overrideWithValue(qualityRandom),
        ],
      );
      addTearDown(container.dispose);

      const candidates = [
        CpuDecision(
          kind: CpuDecisionKind.attack,
          sourceIslandId: 0,
          destinationIslandId: 1,
          strength: 10,
        ),
        CpuDecision(
          kind: CpuDecisionKind.attack,
          sourceIslandId: 2,
          destinationIslandId: 3,
          strength: 10,
        ),
      ];

      final first = container.read(playerCpuStrategyProvider);
      expect(first.controlledFaction, Faction.player);
      expect(first.timingRandom, same(timingRandom));
      expect(first.qualityRandom, same(qualityRandom));
      final firstDelay = first.nextDecisionDelayMs(
        difficulty: CpuDifficulty.hard,
      );
      final firstDecision = first.selectCandidate(
        candidates,
        difficulty: CpuDifficulty.normal,
      );

      container
          .read(_viewportProvider.notifier)
          .setViewport(const IslandMapViewport(width: 321, height: 500));
      final rebuilt = container.read(playerCpuStrategyProvider);
      expect(rebuilt, isNot(same(first)));
      expect(rebuilt.timingRandom, same(timingRandom));
      expect(rebuilt.qualityRandom, same(qualityRandom));
      final secondDelay = rebuilt.nextDecisionDelayMs(
        difficulty: CpuDifficulty.hard,
      );
      final secondDecision = rebuilt.selectCandidate(
        candidates,
        difficulty: CpuDifficulty.normal,
      );

      final expectedTiming = Random(17);
      final expectedFirstDelay =
          CpuDifficultyProfile.hard.minDecisionIntervalMs +
          expectedTiming.nextInt(
            CpuDifficultyProfile.hard.maxDecisionIntervalMs -
                CpuDifficultyProfile.hard.minDecisionIntervalMs +
                1,
          );
      final expectedSecondDelay =
          CpuDifficultyProfile.hard.minDecisionIntervalMs +
          expectedTiming.nextInt(
            CpuDifficultyProfile.hard.maxDecisionIntervalMs -
                CpuDifficultyProfile.hard.minDecisionIntervalMs +
                1,
          );
      expect(firstDelay, expectedFirstDelay);
      expect(secondDelay, expectedSecondDelay);

      final expectedQuality = Random(23);
      final expectedFirstDecision =
          expectedQuality.nextInt(100) <
              CpuDifficultyProfile.normal.skipDecisionRatePercent
          ? null
          : expectedQuality.nextInt(100) <
                CpuDifficultyProfile.normal.primaryCandidateRatePercent
          ? candidates.first
          : candidates[1 + expectedQuality.nextInt(candidates.length - 1)];
      final expectedSecondDecision =
          expectedQuality.nextInt(100) <
              CpuDifficultyProfile.normal.skipDecisionRatePercent
          ? null
          : expectedQuality.nextInt(100) <
                CpuDifficultyProfile.normal.primaryCandidateRatePercent
          ? candidates.first
          : candidates[1 + expectedQuality.nextInt(candidates.length - 1)];
      expect(firstDecision, expectedFirstDecision);
      expect(secondDecision, expectedSecondDecision);
    },
  );

  test('standard mode never schedules the player CPU', () {
    final localLoop = ManualGameLoop();
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(localLoop),
        randomProvider.overrideWithValue(Random(7)),
        playerCpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.player,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.cpu,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
    addTearDown(localContainer.dispose);
    final controller = localContainer.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.startGame();
    completeStartCountdown(localLoop);
    for (var index = 0; index < 30; index++) {
      localLoop.tick();
    }

    final state = localContainer.read(gameControllerProvider);
    expect(state.configuration.gameMode, GameMode.playerVsCpu);
    expect(
      state.movingForces.where((force) => force.faction == Faction.player),
      isEmpty,
    );
    expect(
      state.movingForces.where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
  });

  test('simultaneous CPUs decide from the same pre-dispatch snapshot', () {
    final localLoop = ManualGameLoop();
    final playerStrategy = CpuStrategy(
      controlledFaction: Faction.player,
      timingRandom: ZeroRandom(),
      qualityRandom: MaximumRandom(),
      viewport: GameRules.defaultMapViewport,
    );
    final cpuStrategy = CpuStrategy(
      controlledFaction: Faction.cpu,
      timingRandom: ZeroRandom(),
      qualityRandom: MaximumRandom(),
      viewport: GameRules.defaultMapViewport,
    );
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(localLoop),
        randomProvider.overrideWithValue(Random(7)),
        playerCpuStrategyProvider.overrideWithValue(playerStrategy),
        cpuStrategyProvider.overrideWithValue(cpuStrategy),
      ],
    );
    addTearDown(localContainer.dispose);
    final controller = localContainer.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.startGame();
    completeStartCountdown(localLoop);
    final started = localContainer.read(gameControllerProvider);
    final board = started.copyWith(
      islands: _simultaneousDecisionBoard(started.islands),
    );
    controller.state = board;

    final dueSnapshot = board.copyWith(elapsedMs: 1500);
    final expectedPlayer = playerStrategy.decide(
      dueSnapshot,
      difficulty: CpuDifficulty.hard,
    )!;
    final expectedCpu = cpuStrategy.decide(
      dueSnapshot,
      difficulty: CpuDifficulty.hard,
    )!;
    expect(
      (expectedPlayer.sourceIslandId, expectedPlayer.destinationIslandId),
      (0, 1),
    );
    expect(
      (expectedCpu.sourceIslandId, expectedCpu.destinationIslandId),
      (2, 3),
    );

    final afterPlayer = playerStrategy.applyDecision(
      dueSnapshot,
      expectedPlayer,
      movingForceId: 0,
    );
    final sequentialCpu = cpuStrategy.decide(
      afterPlayer,
      difficulty: CpuDifficulty.hard,
    )!;
    expect(sequentialCpu.kind, CpuDecisionKind.defense);
    expect(sequentialCpu.destinationIslandId, 1);

    for (var index = 0; index < 30; index++) {
      localLoop.tick();
    }
    final forces = localContainer.read(gameControllerProvider).movingForces;
    expect(forces.map((force) => force.faction), [Faction.player, Faction.cpu]);
    expect(forces.map((force) => force.id).toSet(), hasLength(forces.length));
    expect(
      forces.map((force) => (force.sourceIslandId, force.destinationIslandId)),
      [(0, 1), (2, 3)],
    );
  });

  test('one null simultaneous decision does not block the other CPU', () {
    final localLoop = ManualGameLoop();
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(localLoop),
        randomProvider.overrideWithValue(Random(7)),
        playerCpuStrategyProvider.overrideWithValue(
          CpuStrategy.noop(controlledFaction: Faction.player),
        ),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.cpu,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
    addTearDown(localContainer.dispose);
    final controller = localContainer.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.startGame();
    completeStartCountdown(localLoop);

    tickMany(localLoop, 30);
    expect(
      localContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      hasLength(1),
    );
    tickMany(localLoop, 30);
    expect(
      localContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      hasLength(2),
    );
  });

  test(
    'preserves both spectator deadlines across pause and stops at result',
    () {
      final localLoop = ManualGameLoop();
      final localContainer = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(localLoop),
          randomProvider.overrideWithValue(Random(7)),
          playerCpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              controlledFaction: Faction.player,
              timingRandom: ZeroRandom(),
              qualityRandom: MaximumRandom(),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
          cpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              controlledFaction: Faction.cpu,
              timingRandom: ZeroRandom(),
              qualityRandom: MaximumRandom(),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
        ],
      );
      addTearDown(localContainer.dispose);
      final controller = localContainer.read(gameControllerProvider.notifier);
      controller.selectGameMode(GameMode.cpuVsCpu);
      controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
      controller.selectCpuDifficulty(CpuDifficulty.easy);
      controller.startGame();
      completeStartCountdown(localLoop);
      tickMany(localLoop, 14);
      expect(localContainer.read(gameControllerProvider).elapsedMs, 700);
      expect(localContainer.read(gameControllerProvider).movingForces, isEmpty);

      controller.pauseGame();
      controller.resumeGame();
      completeStartCountdown(localLoop);
      expect(localContainer.read(gameControllerProvider).elapsedMs, 700);
      tickMany(localLoop, 16);
      expect(
        localContainer
            .read(gameControllerProvider)
            .movingForces
            .where((force) => force.faction == Faction.player),
        hasLength(1),
      );
      expect(
        localContainer
            .read(gameControllerProvider)
            .movingForces
            .where((force) => force.faction == Faction.cpu),
        isEmpty,
      );

      controller.finish(const GameResult.victory(elapsedMs: 1500));
      final result = localContainer.read(gameControllerProvider);
      tickMany(localLoop, 10);
      expect(localContainer.read(gameControllerProvider), same(result));
    },
  );

  test('replays spectator settings with fresh CPU deadlines', () {
    final localLoop = ManualGameLoop();
    final localContainer = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(localLoop),
        randomProvider.overrideWithValue(Random(7)),
        playerCpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.player,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.cpu,
            timingRandom: ZeroRandom(),
            qualityRandom: MaximumRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
    );
    addTearDown(localContainer.dispose);
    final controller = localContainer.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
    controller.selectCpuDifficulty(CpuDifficulty.easy);
    controller.startGame();
    completeStartCountdown(localLoop);
    controller.finish(const GameResult.victory(elapsedMs: 0));

    controller.replayGame();
    final replayCountdown = localContainer.read(gameControllerProvider);
    expect(replayCountdown.phase, GamePhase.startCountdown);
    expect(replayCountdown.configuration.gameMode, GameMode.cpuVsCpu);
    expect(
      replayCountdown.configuration.playerCpuDifficulty,
      CpuDifficulty.hard,
    );
    expect(replayCountdown.configuration.cpuDifficulty, CpuDifficulty.easy);
    expect(replayCountdown.movingForces, isEmpty);
    completeStartCountdown(localLoop);
    tickMany(localLoop, 29);
    expect(
      localContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.player),
      isEmpty,
    );
    localLoop.tick();
    expect(
      localContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.player),
      hasLength(1),
    );

    controller.finish(const GameResult.victory(elapsedMs: 1500));
    controller.returnToConfiguration();
    final settings = localContainer.read(gameControllerProvider);
    expect(settings.phase, GamePhase.configuration);
    expect(settings.configuration.gameMode, GameMode.cpuVsCpu);
    expect(settings.configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(settings.configuration.cpuDifficulty, CpuDifficulty.easy);
    expect(settings.movingForces, isEmpty);
    expect(localLoop.isRunning, isFalse);
  });

  test('uses the selected difficulty interval for the first judgment', () {
    const dueTicks = <CpuDifficulty, int>{
      CpuDifficulty.veryEasy: 110,
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
      CpuDifficulty.veryEasy: 110,
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
              // Keep every deadline one millisecond past a 50ms callback so
              // the judgment is processed late and current-time rescheduling
              // can be distinguished from rescheduling from the old due
              // timestamp. The third value is consumed when the second due
              // judgment schedules its following deadline.
              timingRandom: SequenceRandom([1, 1, 1]),
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

      for (var index = 0; index < due; index += 1) {
        localLoop.tick();
      }
      expect(
        localContainer.read(gameControllerProvider).elapsedMs,
        due * 50,
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
        localContainer.read(gameControllerProvider).elapsedMs,
        due * 2 * 50,
        reason: '$difficulty before old rescheduled deadline',
      );
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 1 : 0,
        reason: '$difficulty before old rescheduled deadline',
      );
      localLoop.tick();
      expect(
        localContainer.read(gameControllerProvider).elapsedMs,
        due * 2 * 50 + 50,
        reason: '$difficulty old rescheduled deadline',
      );
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 1 : 0,
        reason: '$difficulty old rescheduled deadline must not fire',
      );
      localLoop.tick();
      expect(
        localContainer.read(gameControllerProvider).elapsedMs,
        due * 2 * 50 + 100,
        reason: '$difficulty current-time rescheduled deadline',
      );
      expect(
        cpuMovingForceCount(localContainer.read(gameControllerProvider)),
        difficulty == CpuDifficulty.hard ? 2 : 1,
        reason: '$difficulty current-time rescheduled deadline',
      );
    }
  });
}
