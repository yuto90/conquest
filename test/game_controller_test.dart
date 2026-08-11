import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
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

  void tickMany(int count) {
    for (var index = 0; index < count; index++) {
      tick();
    }
  }
}

final class _MinimumRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

final class _CountingMaximumRandom implements Random {
  int callCount = 0;

  @override
  bool nextBool() {
    callCount++;
    return true;
  }

  @override
  double nextDouble() {
    callCount++;
    return 0.9999999999999999;
  }

  @override
  int nextInt(int max) {
    callCount++;
    return max - 1;
  }
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
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
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

  test('selects CPU difficulty without regenerating the displayed map', () {
    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);

    controller.selectCpuDifficulty(CpuDifficulty.veryEasy);

    final after = container.read(gameControllerProvider);
    expect(after.phase, GamePhase.configuration);
    expect(after.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
    expect(after.configuration.totalIslandCount, 10);
    expect(after.islands, orderedEquals(before.islands));
    expect([
      for (var index = 0; index < before.islands.length; index++)
        identical(after.islands[index], before.islands[index]),
    ], everyElement(isTrue));
  });

  test('selects spectator settings without regenerating the displayed map', () {
    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);

    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);

    final after = container.read(gameControllerProvider);
    expect(after.configuration.gameMode, GameMode.cpuVsCpu);
    expect(after.configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(after.configuration.cpuDifficulty, CpuDifficulty.normal);
    expect(after.islands, orderedEquals(before.islands));
    expect([
      for (var index = 0; index < before.islands.length; index++)
        identical(after.islands[index], before.islands[index]),
    ], everyElement(isTrue));
  });

  test('ignores spectator setting changes after a match starts', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    final started = container.read(gameControllerProvider);

    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);

    expect(container.read(gameControllerProvider), same(started));
  });

  test('ignores direct island taps while spectating', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.startGame();
    controller.state = container
        .read(gameControllerProvider)
        .copyWith(phase: GamePhase.playing, countdownRemainingMs: 0);
    final before = container.read(gameControllerProvider);

    controller.tapBase(0);
    controller.tapBase(1);

    expect(container.read(gameControllerProvider), same(before));
  });

  test('does not start spectator CPUs when map generation failed', () {
    final failedLoop = ManualGameLoop();
    final failedContainer = ProviderContainer(
      overrides: [
        gameConfigurationProvider.overrideWithValue(
          GameConfiguration(totalIslandCount: 6, gameMode: GameMode.cpuVsCpu),
        ),
        gameLoopProvider.overrideWithValue(failedLoop),
        mapViewportProvider.overrideWithValue(
          const IslandMapViewport(width: 180, height: 180),
        ),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
      ],
    );
    addTearDown(failedContainer.dispose);
    final controller = failedContainer.read(gameControllerProvider.notifier);
    final before = failedContainer.read(gameControllerProvider);
    expect(before.phase, GamePhase.configuration);
    expect(before.islands, isEmpty);

    controller.startGame();

    expect(failedContainer.read(gameControllerProvider), same(before));
    expect(failedLoop.isRunning, isFalse);
  });

  test(
    'preserves CPU difficulty through island count changes and rejects play changes',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(CpuDifficulty.veryEasy);
      controller.selectIslandCount(6);
      controller.selectIslandCount(12);

      final configured = container.read(gameControllerProvider);
      expect(configured.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(configured.configuration.totalIslandCount, 12);
      expect(configured.islands, hasLength(12));

      controller.startGame();
      final countdown = container.read(gameControllerProvider);
      controller.selectCpuDifficulty(CpuDifficulty.hard);

      expect(container.read(gameControllerProvider), same(countdown));
    },
  );

  test(
    'retains Very Easy through pause resume replay settings and quality RNG boundaries',
    () {
      final localLoop = ManualGameLoop();
      final qualityRandom = _CountingMaximumRandom();
      final localContainer = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(localLoop),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              timingRandom: _MinimumRandom(),
              qualityRandom: qualityRandom,
              viewport: GameRules.defaultMapViewport,
            ),
          ),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(gameControllerProvider.notifier);
      controller.selectCpuDifficulty(CpuDifficulty.veryEasy);
      controller.startGame();
      completeStartCountdown(localLoop);

      expect(
        localContainer.read(gameControllerProvider).configuration.cpuDifficulty,
        CpuDifficulty.veryEasy,
      );
      expect(qualityRandom.callCount, 0);

      localLoop.tickMany(10);
      controller.pauseGame();
      final paused = localContainer.read(gameControllerProvider);
      expect(paused.phase, GamePhase.paused);
      expect(paused.elapsedMs, 500);
      expect(qualityRandom.callCount, 0);

      controller.resumeGame();
      expect(
        localContainer.read(gameControllerProvider).phase,
        GamePhase.resumeCountdown,
      );
      localLoop.tickMany(60);
      final resumed = localContainer.read(gameControllerProvider);
      expect(resumed.phase, GamePhase.playing);
      expect(resumed.elapsedMs, paused.elapsedMs);
      expect(resumed.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(qualityRandom.callCount, 0);

      controller.state = resumed.copyWith(
        islands: [
          for (final island in resumed.islands)
            island.id == 0
                ? island.copyWith(
                    faction: Faction.player,
                    currentForces: 100,
                    durability: 0,
                  )
                : island.copyWith(
                    faction: Faction.cpu,
                    currentForces: 100,
                    durability: 0,
                  ),
        ],
      );
      localLoop.tickMany(99);
      expect(localContainer.read(gameControllerProvider).elapsedMs, 5450);
      expect(qualityRandom.callCount, 0);

      localLoop.tick();
      final firstDecision = localContainer.read(gameControllerProvider);
      expect(firstDecision.elapsedMs, 5500);
      expect(
        firstDecision.movingForces.where(
          (force) => force.faction == Faction.cpu,
        ),
        hasLength(1),
      );
      expect(qualityRandom.callCount, greaterThan(0));

      final callsAfterDecision = qualityRandom.callCount;
      controller.finish(const GameResult.victory(elapsedMs: 5500));
      expect(
        localContainer.read(gameControllerProvider).configuration.cpuDifficulty,
        CpuDifficulty.veryEasy,
      );
      localLoop.tickMany(10);
      expect(qualityRandom.callCount, callsAfterDecision);

      controller.replayGame();
      final replay = localContainer.read(gameControllerProvider);
      expect(replay.phase, GamePhase.startCountdown);
      expect(replay.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(qualityRandom.callCount, callsAfterDecision);
      localLoop.tickMany(60);
      expect(
        localContainer.read(gameControllerProvider).phase,
        GamePhase.playing,
      );
      expect(qualityRandom.callCount, callsAfterDecision);

      controller.finish(const GameResult.victory(elapsedMs: 0));
      controller.returnToConfiguration();
      final settings = localContainer.read(gameControllerProvider);
      expect(settings.phase, GamePhase.configuration);
      expect(settings.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(qualityRandom.callCount, callsAfterDecision);
    },
  );

  test('starts the game and loop only once', () {
    final controller = container.read(gameControllerProvider.notifier);

    controller.startGame();
    controller.startGame();

    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(loop.startCount, 1);
  });

  test('holds the generated map during the start countdown', () {
    final controller = container.read(gameControllerProvider.notifier);
    final initial = container.read(gameControllerProvider);

    controller.startGame();

    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(container.read(gameControllerProvider).countdownRemainingMs, 3000);
    expect(container.read(gameControllerProvider).elapsedMs, 0);

    controller.tapBase(0);
    expect(container.read(gameControllerProvider).selectedIslandId, isNull);
    expect(container.read(gameControllerProvider).movingForces, isEmpty);

    for (var index = 0; index < 59; index++) {
      loop.tick();
    }
    final beforeStart = container.read(gameControllerProvider);
    expect(beforeStart.phase, GamePhase.startCountdown);
    expect(beforeStart.countdownRemainingMs, 50);
    expect(beforeStart.elapsedMs, 0);
    expect(beforeStart.islands, initial.islands);

    loop.tick();
    final started = container.read(gameControllerProvider);
    expect(started.phase, GamePhase.playing);
    expect(started.countdownRemainingMs, 0);
    expect(started.elapsedMs, 0);
    expect(loop.isRunning, isTrue);

    loop.tick();
    expect(container.read(gameControllerProvider).elapsedMs, 50);
  });

  test('selects a source and creates movement on the next tap', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);

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
      completeStartCountdown(loop);

      controller.tapBase(2);
      expect(container.read(gameControllerProvider).selectedBaseId, isNull);

      controller.tapBase(0);
      expect(container.read(gameControllerProvider).selectedBaseId, 0);

      controller.tapBase(0);
      expect(container.read(gameControllerProvider).selectedBaseId, isNull);
    },
  );

  test('reports unavailable feedback for non-player and exhausted sources', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);

    controller.tapBase(1);
    var state = container.read(gameControllerProvider);
    expect(state.selectedIslandId, isNull);
    expect(
      state.interactionFeedback,
      InteractionFeedbackType.unavailableSource,
    );

    controller.tapBase(0);
    state = container.read(gameControllerProvider);
    expect(state.selectedIslandId, 0);
    controller.state = state.copyWith(
      islands: [
        for (final island in state.islands)
          island.id == 0 ? island.copyWith(currentForces: 1) : island,
      ],
    );
    controller.tapBase(2);

    state = container.read(gameControllerProvider);
    expect(state.selectedIslandId, isNull);
    expect(
      state.interactionFeedback,
      InteractionFeedbackType.invalidatedSource,
    );

    for (var index = 0; index < 30; index++) {
      loop.tick();
    }
    expect(container.read(gameControllerProvider).interactionFeedback, isNull);
  });

  test(
    'uses force at destination tap time and clears an invalid selection',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      completeStartCountdown(loop);
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

      final cleared = container.read(gameControllerProvider);
      expect(cleared.selectedIslandId, isNull);
      expect(
        cleared.interactionFeedback,
        InteractionFeedbackType.invalidatedSource,
      );
    },
  );

  test(
    'shows feedback when a selected source is cleared and reoccupied in one tick',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      completeStartCountdown(loop);

      controller.state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        selectedIslandId: 0,
        islands: const [
          IslandState(
            id: 0,
            faction: Faction.player,
            size: IslandSize.small,
            currentForces: 3,
            capacity: 50,
          ),
          IslandState(
            id: 1,
            faction: Faction.cpu,
            size: IslandSize.small,
            currentForces: 10,
            capacity: 50,
          ),
          IslandState(
            id: 2,
            faction: Faction.player,
            size: IslandSize.small,
            currentForces: 10,
            capacity: 50,
          ),
        ],
        movingForces: const [
          MovingForce(
            id: 0,
            faction: Faction.cpu,
            sourceIslandId: 1,
            destinationIslandId: 0,
            strength: 10,
            arrivalTimeMs: 1,
            durationMs: 1,
          ),
          MovingForce(
            id: 1,
            faction: Faction.player,
            sourceIslandId: 2,
            destinationIslandId: 0,
            strength: 9,
            arrivalTimeMs: 2,
            durationMs: 1,
          ),
        ],
      );

      loop.tick();

      final afterTick = container.read(gameControllerProvider);
      final source = afterTick.islands.firstWhere((island) => island.id == 0);
      expect(afterTick.phase, GamePhase.playing);
      expect(source.faction, Faction.player);
      expect(source.currentForces, 2);
      expect(afterTick.selectedIslandId, isNull);
      expect(
        afterTick.interactionFeedback,
        InteractionFeedbackType.invalidatedSource,
      );
      expect(afterTick.hasInteractionFeedback, isTrue);

      for (var index = 0; index < 30; index++) {
        loop.tick();
      }
      expect(
        container.read(gameControllerProvider).interactionFeedback,
        isNull,
      );
    },
  );

  test(
    'dispatches floor half for zero, one, even, odd, and maximum forces',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      completeStartCountdown(loop);
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
    completeStartCountdown(loop);
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

  test(
    'keeps a diagonal movement in flight until ten seconds, then arrives',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      completeStartCountdown(loop);
      controller.tapBase(0);
      controller.tapBase(1);

      for (var i = 0; i < 199; i++) {
        loop.tick();
      }

      final beforeArrival = container.read(gameControllerProvider);
      expect(beforeArrival.elapsedMs, 9950);
      expect(beforeArrival.movingForces, hasLength(1));
      expect(beforeArrival.movingForces.single.progress, closeTo(0.995, 1e-12));
      expect(beforeArrival.movingForces.single.arrivalTimeMs, 10000);
      expect(beforeArrival.bases[0].scale, 59);
      expect(beforeArrival.bases[1].scale, 109);

      loop.tick();

      final arrived = container.read(gameControllerProvider);
      expect(arrived.elapsedMs, 10000);
      expect(arrived.movement, isNull);
      expect(arrived.selectedBaseId, isNull);
      expect(arrived.bases[0].scale, 60);
      expect(arrived.bases[1].scale, 60);
    },
  );

  test('freezes movement timing through pause and resume countdown', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);
    controller.tapBase(0);
    controller.tapBase(1);
    loop.tickMany(20);

    final moving = container.read(gameControllerProvider).movingForces.single;
    expect(moving.departureTimeMs, 0);
    expect(moving.durationMs, 10000);
    expect(moving.arrivalTimeMs, 10000);
    expect(moving.progress, closeTo(0.1, 1e-12));

    controller.pauseGame();
    final paused = container.read(gameControllerProvider);
    expect(paused.phase, GamePhase.paused);
    expect(paused.elapsedMs, 1000);
    expect(paused.movingForces.single, moving);

    loop.tickMany(100);
    expect(container.read(gameControllerProvider), same(paused));

    controller.resumeGame();
    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.resumeCountdown,
    );
    loop.tickMany(60);

    final resumed = container.read(gameControllerProvider);
    expect(resumed.phase, GamePhase.playing);
    expect(resumed.elapsedMs, paused.elapsedMs);
    expect(resumed.movingForces.single.departureTimeMs, moving.departureTimeMs);
    expect(resumed.movingForces.single.durationMs, moving.durationMs);
    expect(resumed.movingForces.single.arrivalTimeMs, moving.arrivalTimeMs);
    expect(resumed.movingForces.single.progress, moving.progress);
  });

  test('stops the game loop when arrival resolution finalizes a result', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);
    controller.state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: const [
        IslandState(
          id: 0,
          faction: Faction.player,
          size: IslandSize.small,
          currentForces: 1,
          capacity: 50,
        ),
        IslandState(
          id: 1,
          faction: Faction.cpu,
          size: IslandSize.small,
          currentForces: 100,
          capacity: 50,
        ),
      ],
      movingForces: const [
        MovingForce(
          id: 0,
          faction: Faction.cpu,
          sourceIslandId: 1,
          destinationIslandId: 0,
          strength: 2,
          arrivalTimeMs: 0,
          durationMs: 1,
        ),
      ],
    );

    loop.tick();

    final result = container.read(gameControllerProvider);
    expect(result.phase, GamePhase.result);
    expect(result.result?.type, GameResultType.defeat);
    expect(loop.isRunning, isFalse);
    expect(loop.stopCount, 1);
  });

  test(
    'increments owned bases after one second without growing neutral bases',
    () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      completeStartCountdown(loop);

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
    completeStartCountdown(loop);
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
    completeStartCountdown(loop);

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

  test('returns a paused match to settings without retaining match state', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    completeStartCountdown(loop);
    controller.tapBase(0);
    controller.tapBase(1);
    loop.tick();

    final beforeQuit = container.read(gameControllerProvider);
    expect(beforeQuit.phase, GamePhase.playing);
    expect(beforeQuit.movingForces, isNotEmpty);

    controller.pauseGame();
    controller.returnToConfiguration();

    final settings = container.read(gameControllerProvider);
    expect(settings.phase, GamePhase.configuration);
    expect(settings.configuration, beforeQuit.configuration);
    expect(settings.elapsedMs, 0);
    expect(settings.selectedIslandId, isNull);
    expect(settings.movingForces, isEmpty);
    expect(settings.result, isNull);
    expect(
      settings.islands,
      hasLength(beforeQuit.configuration.totalIslandCount),
    );
    expect(loop.isRunning, isFalse);
  });

  test('replays a result with the same island count and a new map', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectCpuDifficulty(CpuDifficulty.hard);
    controller.selectIslandCount(6);
    final beforeReplay = container.read(gameControllerProvider);
    controller.startGame();
    completeStartCountdown(loop);
    controller.finish(const GameResult.victory(elapsedMs: 25));

    expect(container.read(gameControllerProvider).phase, GamePhase.result);
    controller.replayGame();

    final replay = container.read(gameControllerProvider);
    expect(replay.phase, GamePhase.startCountdown);
    expect(replay.configuration.totalIslandCount, 6);
    expect(replay.configuration.cpuDifficulty, CpuDifficulty.hard);
    expect(replay.islands, hasLength(6));
    expect(replay.elapsedMs, 0);
    expect(replay.movingForces, isEmpty);
    expect(replay.islands, isNot(beforeReplay.islands));
    expect(loop.isRunning, isTrue);

    controller.finish(const GameResult.victory(elapsedMs: 25));
    controller.returnToConfiguration();
    final settings = container.read(gameControllerProvider);
    expect(settings.configuration.totalIslandCount, 6);
    expect(settings.configuration.cpuDifficulty, CpuDifficulty.hard);
  });

  test('pauses an in-progress start countdown and resumes safely', () {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    loop.tick();
    final countdown = container.read(gameControllerProvider);
    expect(countdown.phase, GamePhase.startCountdown);
    expect(countdown.countdownRemainingMs, 2950);

    controller.pauseGame();
    final paused = container.read(gameControllerProvider);
    expect(paused.phase, GamePhase.paused);
    expect(paused.countdownRemainingMs, 0);
    expect(loop.isRunning, isFalse);

    controller.resumeGame();
    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.resumeCountdown,
    );
    expect(container.read(gameControllerProvider).countdownRemainingMs, 3000);
  });

  test(
    'fails closed when replay map generation cannot produce a valid map',
    () {
      final failedLoop = ManualGameLoop();
      final failedContainer = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(failedLoop),
          mapViewportProvider.overrideWithValue(
            const IslandMapViewport(width: 180, height: 180),
          ),
          randomProvider.overrideWithValue(Random(1)),
          cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        ],
      );
      addTearDown(failedContainer.dispose);

      final controller = failedContainer.read(gameControllerProvider.notifier);
      controller.state = GameState(
        configuration: GameConfiguration(totalIslandCount: 6),
        phase: GamePhase.result,
        elapsedMs: 120,
        result: const GameResult.victory(elapsedMs: 120),
      );

      controller.replayGame();

      final state = failedContainer.read(gameControllerProvider);
      expect(state.phase, GamePhase.configuration);
      expect(state.configuration.totalIslandCount, 6);
      expect(state.islands, isEmpty);
      expect(state.movingForces, isEmpty);
      expect(state.result, isNull);
      expect(state.elapsedMs, 0);
      expect(failedLoop.isRunning, isFalse);
    },
  );
}
