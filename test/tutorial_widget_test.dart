import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:conquest/tutorial/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/match_setup.dart';

final class _ManualTutorialLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;
}

Future<void> _pumpTutorialApp(
  WidgetTester tester, {
  Locale locale = const Locale('ja'),
  Size size = const Size(390, 844),
  Size? stageSize,
  ValueNotifier<Size>? stageSizeNotifier,
  TextScaler textScaler = const TextScaler.linear(1),
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
    ),
    child: MyApp(locale: locale),
  );
  final stage = stageSize ?? size;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(_ManualTutorialLoop()),
        randomProvider.overrideWithValue(Random(1)),
      ],
      child: Center(
        child: stageSizeNotifier == null
            ? SizedBox(width: stage.width, height: stage.height, child: app)
            : ValueListenableBuilder<Size>(
                valueListenable: stageSizeNotifier,
                builder: (context, currentStage, child) => SizedBox(
                  width: currentStage.width,
                  height: currentStage.height,
                  child: child,
                ),
                child: app,
              ),
      ),
    ),
  );
  await openMatchSetup(tester);
}

double _tutorialScrollExtent(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('tutorial-info-scroll')),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
}

Future<void> _advanceTutorialToVictory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tutorial-island-button-0')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('tutorial-island-button-2')));
  await tester.pump();
  final screen = tester.widget<TutorialScreen>(find.byType(TutorialScreen));
  final force = screen.session.gameState.movingForces.single;
  screen.session.tick(force.durationMs + 2000);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('tutorial-next')));
  await tester.tap(find.byKey(const ValueKey('tutorial-next')));
  await tester.pump();
}

void main() {
  testWidgets('opens the hands-on tutorial from match setup', (tester) async {
    await _pumpTutorialApp(tester);

    expect(find.byKey(const ValueKey('how-to-play')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('how-to-play')));
    await tester.pump();

    expect(find.byKey(const ValueKey('tutorial-screen')), findsOneWidget);
    expect(find.text('遊び方'), findsOneWidget);
    expect(find.text('手順 1 / 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('island-highlight-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tutorial-island-button-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tutorial-island-button-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tutorial-back')), findsOneWidget);
  });

  testWidgets(
    'fits every normal-size tutorial step without unnecessary scrolling',
    (tester) async {
      for (final scenario in [
        (locale: const Locale('ja'), size: const Size(440, 956)),
        (locale: const Locale('en'), size: const Size(440, 956)),
        (locale: const Locale('ja'), size: const Size(390, 844)),
        (locale: const Locale('en'), size: const Size(390, 844)),
      ]) {
        await _pumpTutorialApp(
          tester,
          locale: scenario.locale,
          size: scenario.size,
        );
        await tester.tap(find.byKey(const ValueKey('how-to-play')));
        await tester.pump();

        void expectNaturalCard() {
          final cardHeight = tester
              .getSize(find.byKey(const ValueKey('tutorial-info-card')))
              .height;
          final extent = _tutorialScrollExtent(tester);
          expect(cardHeight, lessThanOrEqualTo(scenario.size.height * 0.5));
          expect(extent, 0);
        }

        expectNaturalCard();
        await tester.tap(
          find.byKey(const ValueKey('tutorial-island-button-0')),
        );
        await tester.pump();
        expectNaturalCard();
        await tester.tap(
          find.byKey(const ValueKey('tutorial-island-button-2')),
        );
        await tester.pump();
        expectNaturalCard();

        final screen = tester.widget<TutorialScreen>(
          find.byType(TutorialScreen),
        );
        final force = screen.session.gameState.movingForces.single;
        screen.session.tick(force.durationMs + 2000);
        await tester.pump();
        expectNaturalCard();
        await tester.tap(find.byKey(const ValueKey('tutorial-next')));
        await tester.pump();
        expectNaturalCard();
        await tester.tap(find.byKey(const ValueKey('tutorial-back')));
        await tester.pump();
      }
    },
  );

  testWidgets(
    'caps compact large-text cards and scrolls only when the content needs it',
    (tester) async {
      await _pumpTutorialApp(
        tester,
        locale: const Locale('ja'),
        size: const Size(280, 500),
        stageSize: const Size(231, 500),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('how-to-play')));
      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('tutorial-info-card'))).height,
        lessThanOrEqualTo(250),
      );
      expect(
        find.byKey(const ValueKey('tutorial-island-button-0')),
        findsOneWidget,
      );

      await _advanceTutorialToVictory(tester);

      expect(
        tester.getSize(find.byKey(const ValueKey('tutorial-info-card'))).height,
        lessThanOrEqualTo(250),
      );
      expect(_tutorialScrollExtent(tester), greaterThan(0));
      expect(find.byKey(const ValueKey('tutorial-resume')), findsNothing);
      expect(find.byKey(const ValueKey('tutorial-map')), findsOneWidget);
    },
  );

  testWidgets(
    'does not pause when the tutorial card changes the board height',
    (tester) async {
      await _pumpTutorialApp(tester, size: const Size(390, 844));
      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();

      await _advanceTutorialToVictory(tester);

      final screen = tester.widget<TutorialScreen>(find.byType(TutorialScreen));
      expect(screen.session.lifecyclePaused, isFalse);
      expect(find.byKey(const ValueKey('tutorial-resume')), findsNothing);
      expect(
        find.byKey(const ValueKey('tutorial-moving-force-1')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('island-highlight-1')), findsOneWidget);
    },
  );

  testWidgets('exits to match setup when Escape is pressed immediately', (
    tester,
  ) async {
    await _pumpTutorialApp(tester);
    await tester.tap(find.byKey(const ValueKey('how-to-play')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-screen')), findsNothing);
  });

  testWidgets(
    'advances by tapping islands and shows the real occupation result',
    (tester) async {
      await _pumpTutorialApp(tester);
      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tutorial-island-button-0')));
      await tester.pump();
      expect(find.text('手順 2 / 4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tutorial-island-button-2')));
      await tester.pump();
      expect(find.text('出発時：100 → 50人'), findsOneWidget);
      expect(find.text('50人を送る / 50人を残す'), findsOneWidget);

      final screen = tester.widget<TutorialScreen>(find.byType(TutorialScreen));
      final force = screen.session.gameState.movingForces.single;
      screen.session.tick(force.durationMs + 2000);
      await tester.pump();
      expect(find.text('50 − 10 = 40人'), findsOneWidget);
      expect(find.text('島が緑になりました！'), findsOneWidget);
      expect(find.byKey(const ValueKey('tutorial-next')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('tutorial-next')));
      await tester.tap(find.byKey(const ValueKey('tutorial-next')));
      await tester.pump();
      expect(find.text('手順 4 / 4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tutorial-growth-demo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tutorial-return-settings')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('island-highlight-1')), findsOneWidget);
      expect(find.text('覚えておくルール'), findsOneWidget);
      expect(find.text('同じ数では島を取れません'), findsOneWidget);
      expect(find.text('自分の島にも兵士を送れます'), findsOneWidget);
      expect(find.text('兵士が1人以下の島からは送れません'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('tutorial-rule-equal-forces')),
            )
            .label,
        '同じ数では島を取れません',
      );
    },
  );

  testWidgets(
    'keeps selected spectator settings when returning from tutorial',
    (tester) async {
      await _pumpTutorialApp(tester);
      await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
      await tester.pump();
      await setIslandCount(tester, 8);
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('settings-view'))),
      );
      expect(
        container.read(gameControllerProvider).configuration.gameMode,
        GameMode.cpuVsCpu,
      );

      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('tutorial-spectator-notice')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('tutorial-back')));
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
      expect(find.text('選択中：8島 / 1P Normal / 2P Normal'), findsOneWidget);
    },
  );

  testWidgets('safe resize enables tutorial resume without advancing time', (
    tester,
  ) async {
    final stageSize = ValueNotifier(const Size(390, 844));
    addTearDown(stageSize.dispose);
    await _pumpTutorialApp(tester, stageSizeNotifier: stageSize);
    await tester.tap(find.byKey(const ValueKey('how-to-play')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-island-button-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-island-button-2')));
    await tester.pump();
    final session = tester
        .widget<TutorialScreen>(find.byType(TutorialScreen))
        .session;
    session.tick(500);
    final frozenTime = session.gameState.elapsedMs;

    stageSize.value = const Size(180, 200);
    await tester.pump();
    await tester.pump();
    expect(session.lifecyclePaused, isTrue);
    expect(session.canResumeAfterLifecycle, isFalse);
    final resumeButton = find.descendant(
      of: find.byKey(const ValueKey('tutorial-resume')),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(resumeButton).onPressed, isNull);

    stageSize.value = const Size(390, 844);
    await tester.pump();
    await tester.pump();
    expect(session.lifecyclePaused, isTrue);
    expect(session.canResumeAfterLifecycle, isTrue);
    expect(session.gameState.elapsedMs, frozenTime);
    expect(tester.widget<OutlinedButton>(resumeButton).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 1));
    expect(session.gameState.elapsedMs, frozenTime);

    await tester.tap(find.byKey(const ValueKey('tutorial-resume')));
    await tester.pump();
    expect(session.lifecyclePaused, isFalse);
    expect(session.gameState.elapsedMs, frozenTime);
    await tester.pump(const Duration(milliseconds: 50));
    expect(session.gameState.elapsedMs, frozenTime + 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves the normal map through a moving tutorial resize', (
    tester,
  ) async {
    final stageSize = ValueNotifier(const Size(390, 844));
    addTearDown(stageSize.dispose);
    await _pumpTutorialApp(tester, stageSizeNotifier: stageSize);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('settings-view'))),
    );
    final before = container.read(gameControllerProvider).islands;

    await tester.tap(find.byKey(const ValueKey('how-to-play')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-island-button-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-island-button-2')));
    await tester.pump();
    stageSize.value = const Size(280, 500);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('tutorial-back')));
    await tester.pump();

    final restored = container.read(gameControllerProvider);
    expect(restored.islands, orderedEquals(before));
    expect(restored.viewportUnavailable, isTrue);
  });

  testWidgets(
    'preserves the normal map when tutorial resize reaches an unsafe viewport',
    (tester) async {
      final stageSize = ValueNotifier(const Size(390, 844));
      addTearDown(stageSize.dispose);
      await _pumpTutorialApp(tester, stageSizeNotifier: stageSize);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('settings-view'))),
      );
      final before = container.read(gameControllerProvider).islands;

      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      stageSize.value = const Size(180, 200);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('tutorial-back')));
      await tester.pump();

      final restored = container.read(gameControllerProvider);
      expect(restored.islands, orderedEquals(before));
      expect(restored.viewportUnavailable, isTrue);
      expect(
        find.byKey(const ValueKey('viewport-unavailable-sheet')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('start-game')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'holds the restored map through resize until settings resume it',
    (tester) async {
      final stageSize = ValueNotifier(const Size(390, 844));
      addTearDown(stageSize.dispose);
      await _pumpTutorialApp(tester, stageSizeNotifier: stageSize);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('settings-view'))),
      );
      final before = container.read(gameControllerProvider).islands;

      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      stageSize.value = const Size(180, 200);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tutorial-back')));
      await tester.pump();

      stageSize.value = const Size(390, 844);
      await tester.pump();
      expect(
        container.read(gameControllerProvider).islands,
        orderedEquals(before),
      );

      await tester.tap(find.byKey(const ValueKey('resume-after-resize')));
      await tester.pump();
      await setIslandCount(tester, 8);
      await tester.pump();

      final changed = container.read(gameControllerProvider);
      expect(changed.configuration.totalIslandCount, 8);
      expect(changed.islands, hasLength(8));
      expect(changed.islands, isNot(orderedEquals(before)));
    },
  );

  testWidgets(
    'keeps tutorial controls reachable at compact size and large text',
    (tester) async {
      await _pumpTutorialApp(
        tester,
        locale: const Locale('en'),
        size: const Size(280, 500),
        stageSize: const Size(231, 500),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('how-to-play')));
      await tester.tap(find.byKey(const ValueKey('how-to-play')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tutorial-back')), findsOneWidget);
      final initialBackSize = tester.getSize(
        find.byKey(const ValueKey('tutorial-back')),
      );
      expect(initialBackSize.width, greaterThanOrEqualTo(48));
      expect(initialBackSize.height, greaterThanOrEqualTo(48));
      expect(
        find.byKey(const ValueKey('tutorial-island-button-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tutorial-island-button-2')),
        findsOneWidget,
      );
      final islandRects = [
        for (var id = 0; id < 6; id++)
          tester.getRect(find.byKey(ValueKey('tutorial-island-button-$id'))),
      ];
      for (var index = 0; index < islandRects.length; index++) {
        for (
          var otherIndex = index + 1;
          otherIndex < islandRects.length;
          otherIndex++
        ) {
          expect(islandRects[index].overlaps(islandRects[otherIndex]), isFalse);
        }
      }
      await tester.tap(find.byKey(const ValueKey('tutorial-island-button-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tutorial-island-button-2')));
      await tester.pump();
      final screen = tester.widget<TutorialScreen>(find.byType(TutorialScreen));
      final force = screen.session.gameState.movingForces.single;
      screen.session.tick(force.durationMs + 2000);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('tutorial-next')));
      final scrolledBackRect = tester.getRect(
        find.byKey(const ValueKey('tutorial-back')),
      );
      expect(scrolledBackRect.width, greaterThanOrEqualTo(48));
      expect(scrolledBackRect.height, greaterThanOrEqualTo(48));
      expect(scrolledBackRect.top, greaterThanOrEqualTo(0));
      expect(scrolledBackRect.bottom, lessThanOrEqualTo(500));
      await tester.tap(find.byKey(const ValueKey('tutorial-next')));
      await tester.pump();

      final victoryTitleRect = tester.getRect(
        find.text('4. Defeat the enemy to win!'),
      );
      expect(victoryTitleRect.top, greaterThanOrEqualTo(0));
      expect(victoryTitleRect.bottom, lessThanOrEqualTo(500));
      await tester.ensureVisible(
        find.byKey(const ValueKey('tutorial-rule-equal-forces')),
      );
      expect(find.text('Rules to remember'), findsOneWidget);
      expect(find.text('Equal numbers cannot take islands'), findsOneWidget);
      expect(find.text('Send soldiers to your island'), findsOneWidget);
      expect(find.text('One soldier cannot send'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tutorial-return-settings')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
