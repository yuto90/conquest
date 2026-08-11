import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _LocalizationLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tickMany(int count) {
    for (var index = 0; index < count; index++) {
      _onTick?.call();
    }
  }
}

void main() {
  testWidgets('resolves regional locales and falls back to English', (
    tester,
  ) async {
    for (final locale in <Locale>[
      const Locale('en', 'US'),
      const Locale('en', 'GB'),
    ]) {
      await tester.pumpWidget(MyApp(locale: locale));
      expect(find.text('Match Setup'), findsOneWidget);
    }
    await tester.pumpWidget(const MyApp(locale: Locale('ja', 'JP')));
    expect(find.text('対戦設定'), findsOneWidget);
    await tester.pumpWidget(const MyApp(locale: Locale('fr', 'FR')));
    expect(find.text('Match Setup'), findsOneWidget);
  });

  testWidgets('renders the configuration screen in English and Japanese', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(locale: Locale('en', 'US')));
    expect(find.text('Match Setup / 01'), findsOneWidget);
    expect(find.text('Match Setup'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);

    await tester.pumpWidget(const MyApp(locale: Locale('ja', 'JP')));
    await tester.pump();
    expect(find.text('対戦設定 / 01'), findsOneWidget);
    expect(find.text('対戦設定'), findsOneWidget);
    expect(find.text('ゲーム開始'), findsOneWidget);
  });

  testWidgets('translates game mode labels while preserving English labels', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(locale: Locale('ja', 'JP')));
    expect(find.text('CPU対戦'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
    await tester.pump();
    expect(find.text('CPU同士を観戦'), findsOneWidget);

    await tester.pumpWidget(const MyApp(locale: Locale('en', 'US')));
    expect(find.text('PLAY VS CPU'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
    await tester.pump();
    expect(find.text('WATCH CPU VS CPU'), findsOneWidget);
  });

  testWidgets('changes displayed locale without resetting the running match', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('en', 'US'));
    addTearDown(locale.dispose);
    final loop = _LocalizationLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomProvider.overrideWithValue(Random(1)),
          gameLoopProvider.overrideWithValue(loop),
        ],
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, child) => MyApp(locale: value),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start-game')));
    loop.tickMany(60);
    await tester.pump();
    final beforeContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final before = beforeContainer.read(gameControllerProvider);
    expect(before.phase, GamePhase.playing);
    expect(find.text('Tactical Chart / 10 islands'), findsOneWidget);

    locale.value = const Locale('ja', 'JP');
    await tester.pump();
    final after = beforeContainer.read(gameControllerProvider);
    expect(after.phase, before.phase);
    expect(after.elapsedMs, before.elapsedMs);
    expect(after.configuration, before.configuration);
    expect(find.text('戦術海図 / 10島'), findsOneWidget);
    expect(find.text('CONQUEST'), findsOneWidget);
  });
}
