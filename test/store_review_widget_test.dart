import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:conquest/reviews/store_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_controller_test.dart' show ManualGameLoop;
import 'store_review_test.dart' show FakeReviewRequester;
import 'support/match_setup.dart';

void main() {
  for (final victory in [true, false]) {
    testWidgets(
      'requests after a settled ${victory ? 'victory' : 'defeat'} only once',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'storeReview.firstOpened': DateTime.now()
              .subtract(const Duration(days: 8))
              .millisecondsSinceEpoch,
          'storeReview.completedMatches': 2,
        });
        final requester = FakeReviewRequester();
        final prompter = StoreReviewPrompter(
          preferences: await SharedPreferences.getInstance(),
          requester: requester,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storeReviewPrompterProvider.overrideWith((ref) async => prompter),
              gameLoopProvider.overrideWithValue(ManualGameLoop()),
              randomProvider.overrideWithValue(Random(1)),
            ],
            child: const MyApp(locale: Locale('en')),
          ),
        );
        await openMatchSetup(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('settings-view'))),
        );
        final controller = container.read(gameControllerProvider.notifier);
        controller.state = controller.state.copyWith(phase: GamePhase.playing);
        await tester.pump();
        controller.state = controller.state.finishWithResult(
          victory
              ? const GameResult.victory(elapsedMs: 10000)
              : const GameResult.defeat(elapsedMs: 10000),
        );
        await tester.pumpAndSettle();
        expect(requester.requests, 0);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(requester.requests, 1);
        controller.state = controller.state.copyWith(elapsedMs: 10001);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        expect(requester.requests, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('leaving the result screen cancels a pending review request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'storeReview.firstOpened': DateTime.now()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch,
      'storeReview.completedMatches': 2,
    });
    final requester = FakeReviewRequester();
    final prompter = StoreReviewPrompter(
      preferences: await SharedPreferences.getInstance(),
      requester: requester,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeReviewPrompterProvider.overrideWith((ref) async => prompter),
          gameLoopProvider.overrideWithValue(ManualGameLoop()),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(locale: Locale('en')),
      ),
    );
    await openMatchSetup(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('settings-view'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.state = controller.state.copyWith(phase: GamePhase.playing);
    await tester.pump();
    controller.state = controller.state.finishWithResult(
      const GameResult.defeat(elapsedMs: 10000),
    );
    await tester.pumpAndSettle();
    controller.returnToConfiguration();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(requester.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final condition in ['spectator', 'background', 'disposed']) {
    testWidgets('does not request a review when $condition', (tester) async {
      SharedPreferences.setMockInitialValues({
        'storeReview.firstOpened': DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
        'storeReview.completedMatches': 2,
      });
      final requester = FakeReviewRequester();
      final prompter = StoreReviewPrompter(
        preferences: await SharedPreferences.getInstance(),
        requester: requester,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeReviewPrompterProvider.overrideWith((ref) async => prompter),
            gameLoopProvider.overrideWithValue(ManualGameLoop()),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(locale: Locale('en')),
        ),
      );
      await openMatchSetup(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('settings-view'))),
      );
      final controller = container.read(gameControllerProvider.notifier);
      if (condition == 'spectator')
        controller.selectGameMode(GameMode.cpuVsCpu);
      controller.state = controller.state.copyWith(phase: GamePhase.playing);
      await tester.pump();
      controller.state = controller.state.finishWithResult(
        const GameResult.defeat(elapsedMs: 10000),
      );
      await tester.pumpAndSettle();
      if (condition == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      if (condition == 'disposed')
        await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(requester.requests, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
