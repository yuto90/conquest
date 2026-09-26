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
      expect(find.text('100 → 50'), findsOneWidget);
      expect(find.text('50を送る / 50を残す'), findsOneWidget);

      final screen = tester.widget<TutorialScreen>(find.byType(TutorialScreen));
      final force = screen.session.gameState.movingForces.single;
      screen.session.tick(force.durationMs + 2000);
      await tester.pump();
      expect(find.text('50 > 10'), findsOneWidget);
      expect(find.text('占領'), findsOneWidget);
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
      expect(find.text('同数では占領不可'), findsOneWidget);
      expect(find.text('自軍島へ増援'), findsOneWidget);
      expect(find.text('兵力1以下は出兵不可'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('tutorial-rule-equal-forces')),
            )
            .label,
        '同数では占領不可',
      );
    },
  );

  testWidgets(
    'keeps selected spectator settings when returning from tutorial',
    (tester) async {
      await _pumpTutorialApp(tester);
      await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('island-count-8')));
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

      final victoryTitleRect = tester.getRect(find.text('4. Your goal'));
      expect(victoryTitleRect.top, greaterThanOrEqualTo(0));
      expect(victoryTitleRect.bottom, lessThanOrEqualTo(500));
      await tester.ensureVisible(
        find.byKey(const ValueKey('tutorial-rule-equal-forces')),
      );
      expect(find.text('Rules to remember'), findsOneWidget);
      expect(find.text('Equal forces cannot capture'), findsOneWidget);
      expect(find.text('Send reinforcements to your island'), findsOneWidget);
      expect(find.text('One force or fewer cannot deploy'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tutorial-return-settings')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
