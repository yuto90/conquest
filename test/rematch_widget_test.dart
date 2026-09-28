import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_controller_test.dart' show ManualGameLoop, completeStartCountdown;
import 'support/match_setup.dart';

void main() {
  for (final locale in ['en', 'ja']) {
    testWidgets('explains missing and unsafe rematches in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final loop = ManualGameLoop();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
            gameConfigurationProvider.overrideWithValue(
              GameConfiguration(gameMode: GameMode.cpuVsCpu),
            ),
          ],
          child: MyApp(locale: Locale(locale)),
        ),
      );
      await openMatchSetup(tester);
      final controller = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      ).read(gameControllerProvider.notifier);
      final initial = controller.state;
      controller.state = initial.finishWithResult(
        const GameResult.draw(elapsedMs: 0),
      );
      await tester.pump();
      ElevatedButton rematchButton() => tester.widget(
        find.descendant(
          of: find.byKey(const ValueKey('rematch-game')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(rematchButton().onPressed, isNull);
      expect(
        find.text(
          locale == 'en'
              ? 'The starting map is unavailable for rematch.'
              : '再戦用の初期盤面を利用できません',
        ),
        findsOneWidget,
      );
      controller.state = initial;
      controller.startGame();
      completeStartCountdown(loop);
      controller.finish(const GameResult.draw(elapsedMs: 0));
      await tester.pump();
      expect(
        find.text(
          locale == 'en'
              ? 'Same map and both CPU difficulties'
              : '同じマップ・両CPUの難易度で再戦します',
        ),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(280, 500));
      await tester.pumpAndSettle();
      expect(rematchButton().onPressed, isNull);
      expect(
        find.text(
          locale == 'en'
              ? 'Enlarge the window to rematch on the same map.'
              : '同じマップで再戦するには画面を広げてください',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('return-settings')));
      expect(
        find.byKey(const ValueKey('return-settings')).hitTestable(),
        findsOneWidget,
      );
      controller.rematchGame();
      expect(controller.state.phase, GamePhase.result);
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpAndSettle();
      expect(rematchButton().onPressed, isNotNull);
      expect(controller.state.phase, GamePhase.result);
      await tester.ensureVisible(find.byKey(const ValueKey('rematch-game')));
      await tester.tap(find.byKey(const ValueKey('rematch-game')));
      await tester.pump();
      expect(controller.state.islands, orderedEquals(initial.islands));
      expect(controller.state.phase, GamePhase.startCountdown);
      expect(tester.takeException(), isNull);
    });
  }
  for (final locale in ['en', 'ja']) {
    for (final size in [
      const Size(280, 500),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      testWidgets(
        'result actions accessible in $locale at $size with 2x text',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.binding.setSurfaceSize(null);
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final semantics = tester.ensureSemantics();

          final loop = ManualGameLoop();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                gameLoopProvider.overrideWithValue(loop),
                randomProvider.overrideWithValue(Random(1)),
              ],
              child: MyApp(locale: Locale(locale)),
            ),
          );
          await openMatchSetup(tester);
          final container = ProviderScope.containerOf(
            tester.element(find.byKey(const ValueKey('island-0'))),
          );
          final controller = container.read(gameControllerProvider.notifier);
          final initial = controller.state;
          controller.startGame();
          completeStartCountdown(loop);
          controller.finish(const GameResult.draw(elapsedMs: 0));
          await tester.pump();
          for (final key in [
            'rematch-game',
            'replay-game',
            'return-settings',
          ]) {
            final action = find.byKey(ValueKey(key));
            await tester.ensureVisible(action);
            await tester.pump();
            expect(action.hitTestable(), findsOneWidget);
            final button = find.descendant(
              of: action,
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            );
            expect(tester.getSemantics(button).label, isNotEmpty);
          }
          expect(
            find.text(
              locale == 'en' ? 'Same map and difficulty' : '同じマップ・難易度で再戦します',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('rematch-game')),
          );
          await tester.tap(find.byKey(const ValueKey('rematch-game')));
          await tester.pump();
          expect(controller.state.phase, GamePhase.startCountdown);
          expect(controller.state.islands, orderedEquals(initial.islands));
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }
}
