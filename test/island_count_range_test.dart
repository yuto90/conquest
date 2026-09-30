import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_controller_test.dart' show ManualGameLoop, completeStartCountdown;

void main() {
  test(
    'all integer counts are accepted and both outside bounds are rejected',
    () {
      expect(
        GameConfiguration.allowedIslandCounts,
        List.generate(9, (i) => 8 + i),
      );
      for (var count = 8; count <= 16; count++) {
        expect(
          GameConfiguration(totalIslandCount: count).totalIslandCount,
          count,
        );
      }
      for (final count in [-1, 0, 6, 7, 17, 20, 100]) {
        expect(GameConfiguration.isValidIslandCount(count), isFalse);
        expect(
          () => GameConfiguration(totalIslandCount: count),
          throwsArgumentError,
        );
      }
    },
  );

  test('tutorial retains its fixed six-island internal preset', () {
    const tutorial = GameConfiguration.tutorial;
    expect(tutorial.totalIslandCount, 6);
    expect(tutorial.copyWith(), tutorial);
    expect(
      tutorial.copyWith(cpuDifficulty: CpuDifficulty.easy).totalIslandCount,
      6,
    );
    expect(tutorial.copyWith(totalIslandCount: 8).totalIslandCount, 8);
    expect(() => tutorial.copyWith(totalIslandCount: 6), throwsArgumentError);
    expect(
      const GameRules().generateIslands(
        configuration: tutorial,
        random: Random(119),
      ),
      hasLength(6),
    );
  });

  test(
    'approved neutral sizes preserve presets and stop midway for odd counts',
    () {
      const expected = {
        8: [2, 2, 2],
        9: [3, 2, 2],
        10: [4, 2, 2],
        11: [4, 3, 2],
        12: [4, 4, 2],
        13: [4, 4, 3],
        14: [4, 4, 4],
        15: [5, 4, 4],
        16: [6, 4, 4],
      };
      for (final entry in expected.entries) {
        final islands = const GameRules().generateIslands(
          configuration: GameConfiguration(totalIslandCount: entry.key),
          viewport: const IslandMapViewport(width: 320, height: 568),
          random: Random(119),
        );
        expect([
          for (final size in [
            IslandSize.small,
            IslandSize.medium,
            IslandSize.large,
          ])
            islands.where((island) => island.size == size).length,
        ], entry.value);
      }
    },
  );

  test(
    'dense maps remain reproducible and impossible maps fail without random use',
    () {
      const rules = GameRules();
      final configuration = GameConfiguration(totalIslandCount: 16);
      const viewport = IslandMapViewport(width: 320, height: 480);
      final first = rules.generateIslands(
        configuration: configuration,
        viewport: viewport,
        random: Random(119),
      );
      final second = rules.generateIslands(
        configuration: configuration,
        viewport: viewport,
        random: Random(119),
      );
      expect(second, first);
      final source = _CountingZeroRandom();
      expect(
        rules.tryGenerateIslands(
          configuration: configuration,
          viewport: const IslandMapViewport(width: 200, height: 200),
          random: source,
        ),
        isNull,
      );
      expect(source.calls, 0);
      expect(
        rules.tryGenerateIslands(
          configuration: configuration,
          viewport: viewport,
          random: source,
          maxAttempts: 2,
          maxIslandAttempts: 1,
        ),
        isNull,
      );
      expect(source.calls, greaterThan(0));
      expect(source.calls, 328);
      expect(source.rollbackCalls, 2 * GameRules.maxDenseMapRepairs);
    },
  );

  test('every count generates exact safe maps on phone and tablet viewports', () {
    const rules = GameRules();
    for (final viewport in [
      const IslandMapViewport(width: 320, height: 480),
      const IslandMapViewport(width: 320, height: 568),
      const IslandMapViewport(width: 390, height: 844),
      const IslandMapViewport(width: 600, height: 600),
      const IslandMapViewport(width: 834, height: 834),
    ]) {
      for (final count in GameConfiguration.allowedIslandCounts) {
        for (var seed = 0; seed < 40; seed++) {
          final islands = rules.tryGenerateIslands(
            configuration: GameConfiguration(totalIslandCount: count),
            viewport: viewport,
            random: Random(seed),
          );
          final reason =
              '$count islands, seed $seed, ${viewport.width}x${viewport.height}';
          expect(islands, isNotNull, reason: reason);
          expect(islands, hasLength(count), reason: reason);
          expect(viewport.canRenderIslands(islands!), isTrue, reason: reason);
          expect(
            islands.where((i) => i.size == IslandSize.headquarters),
            hasLength(2),
          );
          expect(
            islands.where((i) => i.faction == Faction.player),
            hasLength(1),
          );
          expect(islands.where((i) => i.faction == Faction.cpu), hasLength(1));
          expect(
            islands.where((i) => i.faction == Faction.neutral),
            hasLength(count - 2),
          );
        }
      }
    }
  });

  for (final mode in GameMode.values) {
    test('new counts start and rematch with preserved settings in $mode', () {
      for (final count in GameConfiguration.allowedIslandCounts) {
        final loop = ManualGameLoop();
        final container = ProviderContainer(
          overrides: [
            randomProvider.overrideWithValue(Random(count)),
            gameLoopProvider.overrideWithValue(loop),
            mapViewportProvider.overrideWithValue(
              const IslandMapViewport(width: 320, height: 568),
            ),
            gameConfigurationProvider.overrideWithValue(
              GameConfiguration(
                gameMode: mode,
                cpuDifficulty: CpuDifficulty.easy,
                playerCpuDifficulty: CpuDifficulty.hard,
              ),
            ),
          ],
        );
        try {
          final controller = container.read(gameControllerProvider.notifier);
          controller.selectIslandCount(count);
          final initial = controller.state;
          controller.selectIslandCount(count);
          expect(
            controller.state,
            same(initial),
            reason: 'duplicate count must not reroll',
          );
          controller.selectIslandCount(21);
          expect(controller.state, same(initial));
          expect(initial.islands, hasLength(count));
          controller.startGame();
          completeStartCountdown(loop);
          expect(controller.state.phase, GamePhase.playing);
          controller.tapBase(0);
          controller.tapBase(2);
          if (mode == GameMode.playerVsCpu) {
            expect(controller.state.movingForces, hasLength(1));
            expect(controller.state.movingForces.single.strength, 50);
          } else {
            expect(controller.state.movingForces, isEmpty);
          }
          controller.selectIslandCount(count == 8 ? 9 : 8);
          expect(controller.state.configuration, initial.configuration);
          controller.state = controller.state.copyWith(
            phase: GamePhase.result,
            result: const GameResult.victory(elapsedMs: 1000),
          );
          controller.rematchGame();
          expect(controller.state.configuration, initial.configuration);
          expect(controller.state.islands, initial.islands);
        } finally {
          container.dispose();
        }
      }
    });
  }
}

class _CountingZeroRandom implements Random {
  int calls = 0;
  int rollbackCalls = 0;
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
    rollbackCalls++;
    return 0;
  }
}
