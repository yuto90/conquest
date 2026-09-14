import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

const _englishMessage =
    'The map cannot be prepared at this screen size. Enlarge the window or '
    'reopen in portrait orientation.';
const _japaneseMessage = '現在の画面サイズでは盤面を準備できません。ウィンドウを広げるか、縦向きで開き直してください。';

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
  testWidgets('shows the unavailable map guidance in English semantics', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(180, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(locale: Locale('en')),
      ),
    );
    await openMatchSetup(tester);

    final message = find.byKey(const ValueKey('map-unavailable-message'));
    expect(find.text(_englishMessage), findsOneWidget);
    expect(tester.getSemantics(message).label, _englishMessage);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('start-game')))
          .onPressed,
      isNull,
    );
    expect(loop.isRunning, isFalse);
    expect(find.text('3'), findsNothing);
    semantics.dispose();
  });

  testWidgets('shows the unavailable map guidance in Japanese semantics', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(180, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    final message = find.byKey(const ValueKey('map-unavailable-message'));
    expect(find.text(_japaneseMessage), findsOneWidget);
    expect(tester.getSemantics(message).label, _japaneseMessage);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('start-game')))
          .onPressed,
      isNull,
    );
    expect(loop.isRunning, isFalse);
    expect(find.text('3'), findsNothing);

    await tester.ensureVisible(message);
    await tester.ensureVisible(find.byKey(const ValueKey('return-title')));
    expect(find.byKey(const ValueKey('return-title')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('recovers after resize while preserving match settings', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    await tester.binding.setSurfaceSize(const Size(180, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
      tester.element(find.byKey(const ValueKey('start-game'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectIslandCount(12);
    controller.selectGameMode(GameMode.cpuVsCpu);
    controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
    controller.selectCpuDifficulty(CpuDifficulty.easy);
    await tester.pump();

    final unavailable = container.read(gameControllerProvider);
    expect(unavailable.islands, isEmpty);
    expect(unavailable.configuration.totalIslandCount, 12);
    expect(unavailable.configuration.gameMode, GameMode.cpuVsCpu);
    expect(unavailable.configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(unavailable.configuration.cpuDifficulty, CpuDifficulty.easy);
    expect(
      find.byKey(const ValueKey('map-unavailable-message')),
      findsOneWidget,
    );
    expect(loop.isRunning, isFalse);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();

    final recoveredContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('start-game'))),
    );
    final recovered = recoveredContainer.read(gameControllerProvider);
    expect(recovered.islands, hasLength(12));
    expect(recovered.configuration.totalIslandCount, 12);
    expect(recovered.configuration.gameMode, GameMode.cpuVsCpu);
    expect(recovered.configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(recovered.configuration.cpuDifficulty, CpuDifficulty.easy);
    expect(find.byKey(const ValueKey('map-unavailable-message')), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('start-game')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    expect(
      recoveredContainer.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(loop.isRunning, isTrue);
  });

  testWidgets('shows the same guidance after replay generation fails', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(locale: Locale('en')),
      ),
    );
    await openMatchSetup(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    await tester.binding.setSurfaceSize(const Size(180, 180));
    await tester.pump();
    final failedInitial = container.read(gameControllerProvider);
    expect(failedInitial.islands, isEmpty);

    controller.state = failedInitial.copyWith(
      phase: GamePhase.result,
      result: const GameResult.victory(elapsedMs: 0),
    );
    controller.replayGame();
    await tester.pump();

    final failed = container.read(gameControllerProvider);
    expect(failed.phase, GamePhase.configuration);
    expect(failed.islands, isEmpty);
    expect(loop.isRunning, isFalse);
    expect(find.text(_englishMessage), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('start-game')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('does not show guidance at supported compact sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(locale: Locale('en')),
      ),
    );
    await openMatchSetup(tester);

    final start = find.byKey(const ValueKey('start-game'));
    expect(find.byKey(const ValueKey('map-unavailable-message')), findsNothing);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);

    await tester.binding.setSurfaceSize(const Size(280, 500));
    await tester.pump();
    expect(find.byKey(const ValueKey('map-unavailable-message')), findsNothing);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);
  });
}
