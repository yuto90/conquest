import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

final class _ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;
}

void main() {
  testWidgets('shows the same player summary for victory, defeat, and draw', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    addTearDown(semanticsHandle.dispose);
    final loop = _ManualGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    const summary = MatchSummary(
      elapsedMs: 3_723_999,
      playerDispatchCount: 2,
      playerDispatchedForces: 7,
      playerCaptureCount: 1,
    );

    for (final result in const <GameResult>[
      GameResult.victory(elapsedMs: 3_723_999),
      GameResult.defeat(elapsedMs: 3_723_999),
      GameResult.draw(elapsedMs: 3_723_999),
    ]) {
      controller.state = controller.state
          .copyWith(matchSummary: summary)
          .finishWithResult(result);
      await tester.pump();

      expect(find.byKey(const ValueKey('match-summary')), findsOneWidget);
      expect(find.text('試合サマリー'), findsOneWidget);
      expect(find.text('10島 / CPU Normal'), findsOneWidget);
      expect(find.text('試合時間 1:02:03'), findsOneWidget);
      expect(find.text('成立出兵 2回'), findsOneWidget);
      expect(find.text('累計送兵数 7'), findsOneWidget);
      expect(find.text('占領 1回'), findsOneWidget);
      expect(find.byKey(const ValueKey('replay-game')), findsOneWidget);
      expect(find.byKey(const ValueKey('return-settings')), findsOneWidget);

      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('match-summary')),
      );
      expect(semantics.label, contains('試合時間 1:02:03'));
      expect(semantics.label, contains('成立出兵 2回'));
    }
  });

  testWidgets('keeps result actions reachable on a compact English screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loop = _ManualGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(locale: Locale('en', 'GB')),
      ),
    );
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.state = controller.state.finishWithResult(
      const GameResult.defeat(elapsedMs: 61_000),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('match-summary')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('replay-game')));
    await tester.ensureVisible(find.byKey(const ValueKey('return-settings')));
    expect(find.text('Match Summary'), findsOneWidget);
    expect(find.text('Match time 1:01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show a human summary for spectator results', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          gameConfigurationProvider.overrideWithValue(
            GameConfiguration(gameMode: GameMode.cpuVsCpu),
          ),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    container.read(gameControllerProvider.notifier).state = container
        .read(gameControllerProvider)
        .finishWithResult(
          const GameResult.victory(elapsedMs: 1_000, winner: Faction.player),
        );
    await tester.pump();

    expect(find.byKey(const ValueKey('match-summary')), findsNothing);
    expect(find.byKey(const ValueKey('replay-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('return-settings')), findsOneWidget);
  });
}
