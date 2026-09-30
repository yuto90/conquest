import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_controller_test.dart' show ManualGameLoop, completeStartCountdown;

class CountingRandom implements Random {
  final Random delegate = Random(42);
  int calls = 0;
  @override
  bool nextBool() {
    calls++;
    return delegate.nextBool();
  }

  @override
  double nextDouble() {
    calls++;
    return delegate.nextDouble();
  }

  @override
  int nextInt(int max) {
    calls++;
    return delegate.nextInt(max);
  }
}

void main() {
  for (final mode in GameMode.values) {
    for (final count in [8, 10, 12, 16]) {
      for (final difficulty in CpuDifficulty.values) {
        test('restores $mode $count $difficulty through repeated results', () {
          final random = CountingRandom();
          final loop = ManualGameLoop();
          final configuration = GameConfiguration(
            totalIslandCount: count,
            gameMode: mode,
            cpuDifficulty: difficulty,
            playerCpuDifficulty: CpuDifficulty.values.reversed
                .toList()[difficulty.index],
          );
          final container = ProviderContainer(
            overrides: [
              mapViewportProvider.overrideWithValue(
                const IslandMapViewport(width: 320, height: 568),
              ),
              randomProvider.overrideWithValue(random),
              gameLoopProvider.overrideWithValue(loop),
              gameConfigurationProvider.overrideWithValue(configuration),
              cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
              playerCpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
            ],
          );
          addTearDown(container.dispose);
          final controller = container.read(gameControllerProvider.notifier);
          final initial = controller.state;
          controller.rematchGame();
          expect(loop.startCount, 0);
          controller.startGame();
          final calls = random.calls;
          for (final result in const [
            GameResult.victory(elapsedMs: 8000),
            GameResult.defeat(elapsedMs: 8000),
            GameResult.draw(elapsedMs: 8000),
            GameResult.victory(elapsedMs: 8000, winner: Faction.cpu),
          ]) {
            completeStartCountdown(loop);
            loop.tickMany(20);
            // Model a played board with growth, conquest and neutral damage.
            controller.state = controller.state.copyWith(
              islands: [
                for (final island in controller.state.islands)
                  island.copyWith(
                    currentForces: 3,
                    durability: 1,
                    faction: Faction.player,
                  ),
              ],
              selectedIslandId: 0,
              interactionFeedback: InteractionFeedbackType.unavailableSource,
              matchSummary: const MatchSummary(
                elapsedMs: 8000,
                playerDispatchCount: 3,
              ),
            );
            controller.finish(result);
            expect(controller.rematchUnavailableReason, isNull);
            final starts = loop.startCount;
            controller.rematchGame();
            final restored = controller.state;
            controller.rematchGame();
            expect(identical(controller.state, restored), isTrue);
            expect(loop.startCount, starts + 1);
            expect(restored.configuration, configuration);
            expect(restored.islands, orderedEquals(initial.islands));
            expect(() => restored.islands.clear(), throwsUnsupportedError);
            expect(restored.phase, GamePhase.startCountdown);
            expect(restored.elapsedMs, 0);
            expect(restored.movingForces, isEmpty);
            expect(restored.selectedIslandId, isNull);
            expect(restored.interactionFeedback, isNull);
            expect(restored.result, isNull);
            expect(restored.matchSummary, MatchSummary.empty);
            expect(restored.viewportUnavailable, isFalse);
            loop.tick();
            expect(controller.state.elapsedMs, 0);
            expect(controller.state.islands, orderedEquals(initial.islands));
            expect(random.calls, calls);
          }
          completeStartCountdown(loop);
          controller.finish(const GameResult.draw(elapsedMs: 0));
          controller.replayGame();
          expect(random.calls, greaterThan(calls));
          final newBoard = controller.state.islands;
          completeStartCountdown(loop);
          controller.finish(const GameResult.draw(elapsedMs: 0));
          controller.rematchGame();
          expect(controller.state.islands, orderedEquals(newBoard));
        });
      }
    }
  }

  test(
    'resize retains result and snapshot; safe resize needs explicit rematch',
    () {
      final loop = ManualGameLoop();
      final container = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          mapViewportProvider.overrideWithValue(GameRules.defaultMapViewport),
        ],
      );
      final subscription = container.listen(gameControllerProvider, (_, _) {});
      final controller = container.read(gameControllerProvider.notifier);
      final initial = controller.state;
      controller.startGame();
      completeStartCountdown(loop);
      controller.finish(const GameResult.draw(elapsedMs: 100));
      final result = controller.state;
      container.updateOverrides([
        mapViewportProvider.overrideWithValue(
          const IslandMapViewport(width: 100, height: 100),
        ),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ]);
      container.read(gameControllerProvider);
      expect(
        controller.rematchUnavailableReason,
        RematchUnavailableReason.viewportTooSmall,
      );
      final starts = loop.startCount;
      controller.rematchGame();
      expect(identical(controller.state, result), isTrue);
      expect(loop.startCount, starts);
      container.updateOverrides([
        mapViewportProvider.overrideWithValue(GameRules.defaultMapViewport),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ]);
      container.read(gameControllerProvider);
      expect(controller.state.phase, GamePhase.result);
      expect(controller.rematchUnavailableReason, isNull);
      controller.rematchGame();
      expect(controller.state.islands, orderedEquals(initial.islands));
      controller.pauseGame();
      controller.returnToSettings();
      expect(
        controller.rematchUnavailableReason,
        RematchUnavailableReason.missingSnapshot,
      );
      controller.state = controller.state.finishWithResult(
        const GameResult.draw(elapsedMs: 0),
      );
      controller.rematchGame();
      expect(controller.state.phase, GamePhase.result);
      subscription.close();
      container.dispose();
      expect(controller.rematchGame, returnsNormally);
    },
  );

  test('missing snapshot fails closed', () {
    final loop = ManualGameLoop();
    final container = ProviderContainer(
      overrides: [gameLoopProvider.overrideWithValue(loop)],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    controller.state = controller.state.finishWithResult(
      const GameResult.draw(elapsedMs: 0),
    );
    controller.rematchGame();
    expect(loop.startCount, 0);
    expect(
      controller.rematchUnavailableReason,
      RematchUnavailableReason.missingSnapshot,
    );
  });
}
