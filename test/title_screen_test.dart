import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

void main() {
  testWidgets(
    'keeps title actions at least 48 pixels tall on desktop',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MyApp(locale: Locale('en'))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('title-start'))).height,
        greaterThanOrEqualTo(48),
      );
      await openMatchSetup(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('return-title'))).height,
        greaterThanOrEqualTo(48),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('launches on the title without advancing the match', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp(locale: Locale('ja'))),
    );

    expect(find.byKey(const ValueKey('title-wordmark')), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-view')), findsNothing);
    expect(find.byKey(const ValueKey('island-0')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('title-view'))),
    );
    final before = container.read(gameControllerProvider);
    await tester.pump(const Duration(minutes: 1));
    expect(container.read(gameControllerProvider), same(before));
    expect(before.phase, GamePhase.configuration);
    expect(before.elapsedMs, 0);
    expect(container.read(gameLoopProvider).isRunning, isFalse);

    await openMatchSetup(tester);
    expect(find.byKey(const ValueKey('title-view')), findsNothing);
    expect(find.text('対戦設定'), findsOneWidget);
    expect(find.text('タイトルへ戻る'), findsOneWidget);
  });

  for (final systemBack in [false, true]) {
    testWidgets(
      'preserves all selections when returning via ${systemBack ? 'system back' : 'the title button'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const ProviderScope(child: MyApp(locale: Locale('ja'))),
        );
        await openMatchSetup(tester);
        await tester.tap(find.byKey(const ValueKey('island-count-8')));
        await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('player-cpu-difficulty-hard')),
        );
        await tester.tap(find.byKey(const ValueKey('cpu-difficulty-easy')));
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('settings-view'))),
        );
        final before = container.read(gameControllerProvider);
        expect(before.configuration.totalIslandCount, 8);
        expect(before.configuration.gameMode, GameMode.cpuVsCpu);
        expect(before.configuration.playerCpuDifficulty, CpuDifficulty.hard);
        expect(before.configuration.cpuDifficulty, CpuDifficulty.easy);

        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.ensureVisible(
            find.byKey(const ValueKey('return-title')),
          );
          await tester.tap(find.byKey(const ValueKey('return-title')));
        }
        await tester.pump();
        expect(find.byKey(const ValueKey('title-view')), findsOneWidget);
        expect(find.byKey(const ValueKey('settings-view')), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(container.read(gameControllerProvider), same(before));
        expect(container.read(gameLoopProvider).isRunning, isFalse);

        await openMatchSetup(tester);
        expect(container.read(gameControllerProvider), same(before));
        expect(find.text('選択中：8島 / 1P Hard / 2P Easy'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'restores the current screen on resume and the title on a fresh launch',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MyApp(locale: Locale('en'))),
      );
      expect(find.text('START'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('title-view')), findsOneWidget);
      await openMatchSetup(tester);
      expect(find.text('Back to Title'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('title-view')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const ProviderScope(child: MyApp(locale: Locale('en'))),
      );
      expect(find.byKey(const ValueKey('title-view')), findsOneWidget);
    },
  );

  testWidgets(
    'keeps the title action accessible with large text in a small SafeArea',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(280, 320),
              padding: EdgeInsets.only(top: 30, bottom: 20),
              textScaler: TextScaler.linear(2),
            ),
            child: Home(),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('title-start'));
      await tester.ensureVisible(button);
      await tester.pump();
      final bounds = tester.getRect(button);
      expect(bounds.height, greaterThanOrEqualTo(48));
      expect(bounds.top, greaterThanOrEqualTo(30));
      expect(bounds.bottom, lessThanOrEqualTo(300));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(280));
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Start',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.tap(button);
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
    },
  );

  testWidgets('centers the title inside the Web portrait stage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Home(letterboxToPortrait: true)),
    );
    final stage = tester.getRect(find.byKey(const ValueKey('playable-stage')));
    final title = tester.getRect(find.byKey(const ValueKey('title-view')));
    expect(title, stage);
    expect(stage.width / stage.height, closeTo(390 / 844, 0.001));
    expect(stage.center.dx, 720);
    final button = tester.getRect(find.byKey(const ValueKey('title-start')));
    expect(button.center.dx, closeTo(stage.center.dx, 0.1));
    expect(stage.contains(button.topLeft), isTrue);
    expect(stage.contains(button.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });
}
