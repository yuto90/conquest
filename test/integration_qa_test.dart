import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deterministic replacement for the production periodic loop.
///
/// Every callback advances one 50 ms engine step when the system clock is
/// used.  This keeps the controller, CPU, and rules connected in these tests
/// without waiting for wall-clock timers.
final class _QaManualLoop implements GameLoop {
  void Function()? _onTick;

  int startCount = 0;
  int stopCount = 0;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) {
    if (isRunning) {
      return;
    }
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

ProviderContainer _createContainer({
  required _QaManualLoop loop,
  required int islandCount,
  required int seed,
  CpuStrategy? cpuStrategy,
}) {
  return ProviderContainer(
    overrides: [
      gameConfigurationProvider.overrideWithValue(
        GameConfiguration(totalIslandCount: islandCount),
      ),
      gameLoopProvider.overrideWithValue(loop),
      randomProvider.overrideWithValue(Random(seed)),
      if (cpuStrategy != null)
        cpuStrategyProvider.overrideWithValue(cpuStrategy)
      else
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy.noop(viewport: GameRules.defaultMapViewport),
        ),
    ],
  );
}

GameState _startMatch(ProviderContainer container, _QaManualLoop loop) {
  final controller = container.read(gameControllerProvider.notifier);
  controller.startGame();
  expect(
    container.read(gameControllerProvider).phase,
    GamePhase.startCountdown,
  );
  expect(container.read(gameControllerProvider).elapsedMs, 0);

  loop.tickMany(59);
  final beforeStart = container.read(gameControllerProvider);
  expect(beforeStart.phase, GamePhase.startCountdown);
  expect(beforeStart.countdownRemainingMs, 50);
  expect(beforeStart.elapsedMs, 0);

  loop.tick();
  final started = container.read(gameControllerProvider);
  expect(started.phase, GamePhase.playing);
  expect(started.countdownRemainingMs, 0);
  expect(started.elapsedMs, 0);
  return started;
}

final class _MatchTrace {
  const _MatchTrace({
    required this.resultType,
    required this.winner,
    required this.elapsedMs,
    required this.ticks,
  });

  final GameResultType resultType;
  final Faction? winner;
  final int elapsedMs;
  final int ticks;

  @override
  bool operator ==(Object other) {
    return other is _MatchTrace &&
        other.resultType == resultType &&
        other.winner == winner &&
        other.elapsedMs == elapsedMs &&
        other.ticks == ticks;
  }

  @override
  int get hashCode => Object.hash(resultType, winner, elapsedMs, ticks);
}

_MatchTrace _runCpuVictory({required int islandCount, required int seed}) {
  final loop = _QaManualLoop();
  final container = _createContainer(
    loop: loop,
    islandCount: islandCount,
    seed: seed,
    cpuStrategy: CpuStrategy(
      random: Random(seed),
      viewport: GameRules.defaultMapViewport,
    ),
  );

  try {
    final controller = container.read(gameControllerProvider.notifier);
    final started = _startMatch(container, loop);

    // Keep the generated map and its viewport geometry, but reduce the
    // scripted player to one vulnerable headquarters.  The CPU still uses
    // the production strategy and dispatch/movement path, making the result
    // deterministic without relying on a long wall-clock match.
    controller.state = started.copyWith(
      islands: [
        for (final island in started.islands)
          island.id == 0
              ? island.copyWith(
                  faction: Faction.player,
                  currentForces: 1,
                  durability: 0,
                )
              : island.copyWith(
                  faction: Faction.cpu,
                  currentForces: island.id == 1 ? 100 : 1,
                  durability: 0,
                ),
      ],
    );

    var ticks = 0;
    while (container.read(gameControllerProvider).phase != GamePhase.result &&
        ticks < 300) {
      loop.tick();
      ticks++;
    }

    final result = container.read(gameControllerProvider);
    expect(result.phase, GamePhase.result);
    expect(result.result, isNotNull);
    return _MatchTrace(
      resultType: result.result!.type,
      winner: result.result!.winner,
      elapsedMs: result.result!.elapsedMs,
      ticks: ticks,
    );
  } finally {
    container.dispose();
  }
}

void _assertIslandCountAndMap(GameState state, int islandCount) {
  expect(state.configuration.totalIslandCount, islandCount);
  expect(state.islands, hasLength(islandCount));
  expect(state.islands[0].faction, Faction.player);
  expect(state.islands[1].faction, Faction.cpu);
  expect(state.islands[0].currentForces, 100);
  expect(state.islands[1].currentForces, 100);
  for (var index = 2; index < state.islands.length; index += 2) {
    final first = state.islands[index];
    final second = state.islands[index + 1];
    expect(first.faction, Faction.neutral);
    expect(second.faction, Faction.neutral);
    expect(second.size, first.size);
    expect(second.position.x, closeTo(-first.position.x, 1e-12));
    expect(second.position.y, closeTo(-first.position.y, 1e-12));
    expect(second.durability, first.durability);
  }
}

void main() {
  test(
    'starts every supported map deterministically through the countdown',
    () {
      for (final islandCount in GameConfiguration.allowedIslandCounts) {
        final firstLoop = _QaManualLoop();
        final secondLoop = _QaManualLoop();
        final first = _createContainer(
          loop: firstLoop,
          islandCount: islandCount,
          seed: 1500 + islandCount,
        );
        final second = _createContainer(
          loop: secondLoop,
          islandCount: islandCount,
          seed: 1500 + islandCount,
        );

        try {
          final firstInitial = first.read(gameControllerProvider);
          final secondInitial = second.read(gameControllerProvider);
          expect(firstInitial, secondInitial, reason: 'islands=$islandCount');
          _assertIslandCountAndMap(firstInitial, islandCount);

          final firstStarted = _startMatch(first, firstLoop);
          final secondStarted = _startMatch(second, secondLoop);
          expect(firstStarted, secondStarted, reason: 'islands=$islandCount');

          firstLoop.tick();
          expect(first.read(gameControllerProvider).elapsedMs, 50);
          expect(first.read(gameControllerProvider).movingForces, isEmpty);
        } finally {
          first.dispose();
          second.dispose();
        }
      }
    },
  );

  test('replays the same CPU result with a fixed seed and manual loop', () {
    for (final islandCount in GameConfiguration.allowedIslandCounts) {
      final first = _runCpuVictory(islandCount: islandCount, seed: 9000);
      final second = _runCpuVictory(islandCount: islandCount, seed: 9000);

      expect(first, second, reason: 'islands=$islandCount');
      expect(first.resultType, GameResultType.defeat);
      expect(first.winner, Faction.cpu);
    }
  });

  test('completes a scripted player victory on every map size', () {
    for (final islandCount in GameConfiguration.allowedIslandCounts) {
      final loop = _QaManualLoop();
      final container = _createContainer(
        loop: loop,
        islandCount: islandCount,
        seed: 7000 + islandCount,
      );
      try {
        final controller = container.read(gameControllerProvider.notifier);
        final started = _startMatch(container, loop);
        controller.state = started.copyWith(
          islands: [
            for (final island in started.islands)
              island.id == 1
                  ? island.copyWith(
                      currentForces: 10,
                      faction: Faction.cpu,
                      durability: 0,
                    )
                  : island,
          ],
        );

        controller.tapBase(0);
        controller.tapBase(1);
        expect(
          container.read(gameControllerProvider).movingForces,
          hasLength(1),
        );
        loop.tickMany(100);

        final result = container.read(gameControllerProvider);
        expect(result.phase, GamePhase.result);
        expect(result.result?.type, GameResultType.victory);
        expect(result.result?.winner, Faction.player);
        expect(loop.isRunning, isFalse);
      } finally {
        container.dispose();
      }
    }
  });

  test(
    'resolves a draw from simultaneous equal arrivals and freezes the loop',
    () {
      final loop = _QaManualLoop();
      final container = _createContainer(loop: loop, islandCount: 10, seed: 42);
      try {
        final controller = container.read(gameControllerProvider.notifier);
        final started = _startMatch(container, loop);
        final target = started.islands.firstWhere((island) => island.id == 2);
        controller.state = started.copyWith(
          islands: [
            for (final island in started.islands)
              island.copyWith(faction: Faction.neutral, currentForces: 0),
          ],
          movingForces: [
            MovingForce(
              id: 101,
              faction: Faction.player,
              sourceIslandId: 0,
              destinationIslandId: target.id,
              strength: target.durability,
              arrivalTimeMs: 0,
              durationMs: 1,
            ),
            MovingForce(
              id: 102,
              faction: Faction.cpu,
              sourceIslandId: 1,
              destinationIslandId: target.id,
              strength: target.durability,
              arrivalTimeMs: 0,
              durationMs: 1,
            ),
          ],
        );

        loop.tick();

        final result = container.read(gameControllerProvider);
        expect(result.phase, GamePhase.result);
        expect(result.result?.type, GameResultType.draw);
        expect(result.movingForces, isEmpty);
        expect(loop.isRunning, isFalse);
        final frozen = result;
        loop.tickMany(100);
        expect(container.read(gameControllerProvider), same(frozen));
      } finally {
        container.dispose();
      }
    },
  );

  test('keeps friendly, neutral, and enemy boundary arrivals independent', () {
    final loop = _QaManualLoop();
    final container = _createContainer(loop: loop, islandCount: 6, seed: 81);
    try {
      final controller = container.read(gameControllerProvider.notifier);
      final started = _startMatch(container, loop);
      final source = started.islands[0];
      final friendly = started.islands[2].copyWith(
        faction: Faction.player,
        currentForces: 49,
        durability: 0,
        size: IslandSize.small,
        capacity: 50,
      );
      final neutral = started.islands[3].copyWith(
        faction: Faction.neutral,
        currentForces: 0,
        durability: 30,
        size: IslandSize.medium,
        capacity: 100,
      );
      final enemy = started.islands[4].copyWith(
        faction: Faction.cpu,
        currentForces: 10,
        durability: 0,
        size: IslandSize.medium,
        capacity: 100,
      );
      controller.state = started.copyWith(
        islands: [
          source,
          started.islands[1],
          friendly,
          neutral,
          enemy,
          started.islands[5],
        ],
        movingForces: [
          MovingForce(
            id: 1,
            faction: Faction.player,
            sourceIslandId: source.id,
            destinationIslandId: friendly.id,
            strength: 20,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
          MovingForce(
            id: 2,
            faction: Faction.player,
            sourceIslandId: source.id,
            destinationIslandId: neutral.id,
            strength: 30,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
          MovingForce(
            id: 3,
            faction: Faction.player,
            sourceIslandId: source.id,
            destinationIslandId: enemy.id,
            strength: 11,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      );

      loop.tick();

      final next = container.read(gameControllerProvider);
      expect(next.movingForces, isEmpty);
      expect(
        next.islands
            .firstWhere((island) => island.id == friendly.id)
            .currentForces,
        50,
      );
      final damagedNeutral = next.islands.firstWhere(
        (island) => island.id == neutral.id,
      );
      expect(damagedNeutral.faction, Faction.neutral);
      expect(damagedNeutral.durability, 0);
      final capturedEnemy = next.islands.firstWhere(
        (island) => island.id == enemy.id,
      );
      expect(capturedEnemy.faction, Faction.player);
      expect(capturedEnemy.currentForces, 1);
      expect(next.phase, GamePhase.playing);
    } finally {
      container.dispose();
    }
  });

  test('pauses, resumes, rematches, and disposes without advancing state', () {
    final loop = _QaManualLoop();
    final container = _createContainer(loop: loop, islandCount: 8, seed: 123);
    final controller = container.read(gameControllerProvider.notifier);
    final started = _startMatch(container, loop);

    loop.tickMany(10);
    controller.pauseGame();
    final paused = container.read(gameControllerProvider);
    expect(paused.phase, GamePhase.paused);
    expect(loop.isRunning, isFalse);
    loop.tickMany(100);
    expect(container.read(gameControllerProvider), same(paused));

    controller.resumeGame();
    expect(
      container.read(gameControllerProvider).phase,
      GamePhase.resumeCountdown,
    );
    expect(container.read(gameControllerProvider).elapsedMs, paused.elapsedMs);
    loop.tickMany(60);
    expect(container.read(gameControllerProvider).phase, GamePhase.playing);
    expect(container.read(gameControllerProvider).elapsedMs, paused.elapsedMs);

    controller.finish(const GameResult.victory(elapsedMs: 500));
    final result = container.read(gameControllerProvider);
    expect(result.phase, GamePhase.result);
    expect(loop.isRunning, isFalse);
    final beforeReplayMap = result.islands;
    controller.replayGame();
    final replay = container.read(gameControllerProvider);
    expect(replay.phase, GamePhase.startCountdown);
    expect(
      replay.configuration.totalIslandCount,
      started.configuration.totalIslandCount,
    );
    expect(replay.islands, isNot(beforeReplayMap));
    loop.tickMany(60);
    expect(container.read(gameControllerProvider).phase, GamePhase.playing);

    // A result or configuration transition is the only place where a match
    // is intentionally reset.  Disposal must stop the active loop as well.
    controller.finish(const GameResult.victory(elapsedMs: 600));
    expect(loop.isRunning, isFalse);
    container.dispose();
    expect(loop.stopCount, greaterThanOrEqualTo(1));
  });

  test(
    'handles many simultaneous troops without dropping or overwriting them',
    () {
      final loop = _QaManualLoop();
      final container = _createContainer(loop: loop, islandCount: 6, seed: 222);
      try {
        final controller = container.read(gameControllerProvider.notifier);
        final started = _startMatch(container, loop);
        final source = started.islands[0];
        final target = started.islands[2].copyWith(
          faction: Faction.player,
          currentForces: 0,
          durability: 0,
          size: IslandSize.headquarters,
          capacity: 200,
        );
        final troops = [
          for (var id = 0; id < 200; id++)
            MovingForce(
              id: id,
              faction: id.isEven ? Faction.player : Faction.cpu,
              sourceIslandId: source.id,
              destinationIslandId: target.id,
              strength: 1,
              arrivalTimeMs: 0,
              durationMs: 1,
            ),
        ];
        controller.state = started.copyWith(
          islands: [
            source,
            started.islands[1],
            target,
            ...started.islands.skip(3),
          ],
          movingForces: troops,
        );

        loop.tick();

        final next = container.read(gameControllerProvider);
        expect(next.movingForces, isEmpty);
        expect(next.islands, hasLength(6));
        expect(
          next.islands
              .firstWhere((island) => island.id == target.id)
              .currentForces,
          0,
        );
        expect(next.phase, GamePhase.playing);
      } finally {
        container.dispose();
      }
    },
  );
}
