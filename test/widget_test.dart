import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ManualWidgetGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tick() => _onTick?.call();
}

void main() {
  testWidgets('offers every island-count preset with ten selected initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    for (final count in GameConfiguration.allowedIslandCounts) {
      expect(find.byKey(ValueKey('island-count-$count')), findsOneWidget);
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-count-10'))),
    );
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      10,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('island-count-10')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('island-count-6')));
    await tester.pump();

    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      6,
    );
    expect(container.read(gameControllerProvider).islands, hasLength(6));
  });

  testWidgets('shows the map before countdown and starts exactly at zero', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);
    expect(find.text('3'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);

    for (var index = 0; index < 59; index++) {
      loop.tick();
    }
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    loop.tick();
    await tester.pump();
    expect(find.text('START'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.playing);
    expect(state.elapsedMs, 0);
  });

  testWidgets('shows the generated map and configuration controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-9')), findsOneWidget);
  });

  testWidgets('exposes faction, size, and numeric values semantically', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-0'))).label,
      contains('Player headquarters, forces 100 of 200'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-1'))).label,
      contains('CPU headquarters, forces 100 of 200'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-2'))).label,
      contains('Neutral small island, durability 10'),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-2'))).width,
      50,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-6'))).width,
      64,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-8'))).width,
      80,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-0'))).width,
      100,
    );
    semantics.dispose();
  });

  testWidgets('keeps every island-count preset physically operable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    for (final count in GameConfiguration.allowedIslandCounts) {
      controller.selectIslandCount(count);
      await tester.pump();
      final state = container.read(gameControllerProvider);
      expect(state.islands, hasLength(count));

      final rectangles = [
        for (final island in state.islands)
          (
            topLeft: tester.getTopLeft(
              find.byKey(ValueKey('island-button-${island.id}')),
            ),
            size: tester.getSize(
              find.byKey(ValueKey('island-button-${island.id}')),
            ),
          ),
      ];
      for (var first = 0; first < rectangles.length; first++) {
        final firstRect = Rect.fromLTWH(
          rectangles[first].topLeft.dx,
          rectangles[first].topLeft.dy,
          rectangles[first].size.width,
          rectangles[first].size.height,
        );
        for (var second = first + 1; second < rectangles.length; second++) {
          final secondRect = Rect.fromLTWH(
            rectangles[second].topLeft.dx,
            rectangles[second].topLeft.dy,
            rectangles[second].size.width,
            rectangles[second].size.height,
          );
          expect(firstRect.overlaps(secondRect), isFalse);
        }
      }
    }
  });

  testWidgets('keeps headquarters inside the SafeArea insets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 500),
              padding: EdgeInsets.only(top: 24, bottom: 16),
            ),
            child: const Home(),
          ),
        ),
      ),
    );

    final cpu = find.byKey(const ValueKey('island-button-1'));
    final player = find.byKey(const ValueKey('island-button-0'));
    expect(tester.getTopLeft(cpu).dy, closeTo(24, 1e-6));
    expect(tester.getBottomRight(player).dy, closeTo(484, 1e-6));
  });

  testWidgets('generates using the actual sub-320 layout constraints', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    final button = tester.element(find.byType(ElevatedButton).first);
    final container = ProviderScope.containerOf(button);
    final state = container.read(gameControllerProvider);
    const viewport = IslandMapViewport(width: 280, height: 500);

    expect(state.islands, hasLength(10));
    expect(
      state.islands,
      const GameRules().generateIslands(random: Random(1), viewport: viewport),
    );
    final rectangles = [
      for (final island in state.islands) viewport.rectFor(island),
    ];
    for (final rectangle in rectangles) {
      expect(rectangle.isWithin(viewport), isTrue);
    }
    for (var first = 0; first < rectangles.length; first++) {
      for (var second = first + 1; second < rectangles.length; second++) {
        expect(rectangles[first].overlaps(rectangles[second]), isFalse);
      }
    }
  });

  testWidgets('fails closed when the actual viewport cannot fit headquarters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(180, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(child: const MyApp()));

    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets(
    'preserves the selected island count in configuration on resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [randomProvider.overrideWithValue(Random(1))],
          child: const MyApp(),
        ),
      );

      final beforeButton = tester.element(find.byType(ElevatedButton).first);
      final beforeContainer = ProviderScope.containerOf(beforeButton);
      final controller = beforeContainer.read(gameControllerProvider.notifier);
      controller.selectIslandCount(6);
      await tester.pump();

      final before = beforeContainer.read(gameControllerProvider);
      expect(before.phase, GamePhase.configuration);
      expect(before.configuration.totalIslandCount, 6);
      expect(before.islands, hasLength(6));

      await tester.binding.setSurfaceSize(const Size(321, 500));
      await tester.pump();

      final afterButton = tester.element(find.byType(ElevatedButton).first);
      final afterContainer = ProviderScope.containerOf(afterButton);
      final after = afterContainer.read(gameControllerProvider);
      expect(after.phase, GamePhase.configuration);
      expect(after.configuration.totalIslandCount, 6);
      expect(after.islands, hasLength(6));
    },
  );

  testWidgets(
    'preserves a selected island count during an in-progress resize',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      final beforeButton = tester.element(find.byType(ElevatedButton).first);
      final beforeContainer = ProviderScope.containerOf(beforeButton);
      final controller = beforeContainer.read(gameControllerProvider.notifier);
      controller.selectIslandCount(6);
      await tester.pump();
      controller.startGame();
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      controller.tapBase(0);
      controller.tapBase(1);
      loop.tick();
      await tester.pump();

      final before = beforeContainer.read(gameControllerProvider);
      expect(before.phase, GamePhase.playing);
      expect(before.configuration.totalIslandCount, 6);
      expect(before.islands, hasLength(6));
      expect(before.elapsedMs, greaterThan(0));
      expect(before.movingForces, isNotEmpty);
      expect(before.selectedIslandId, isNull);

      await tester.binding.setSurfaceSize(const Size(321, 500));
      await tester.pump();

      final afterButton = tester.element(find.byType(ElevatedButton).first);
      final afterContainer = ProviderScope.containerOf(afterButton);
      final after = afterContainer.read(gameControllerProvider);
      expect(after.phase, GamePhase.playing);
      expect(after.configuration.totalIslandCount, 6);
      expect(after.islands, hasLength(6));
      expect(after.elapsedMs, before.elapsedMs);
      expect(after.movingForces, before.movingForces);
      expect(after.selectedIslandId, isNull);
      expect(loop.isRunning, isTrue);

      loop.tick();
      await tester.pump();
      final continued = afterContainer.read(gameControllerProvider);
      expect(continued.elapsedMs, greaterThan(after.elapsedMs));
      expect(continued.movingForces.first.progress, greaterThan(0));
    },
  );

  testWidgets('continues the start countdown after a viewport change', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    final beforeResize = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    expect(
      beforeResize.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(
      beforeResize.read(gameControllerProvider).countdownRemainingMs,
      3000,
    );
    expect(loop.isRunning, isTrue);

    await tester.binding.setSurfaceSize(const Size(321, 500));
    await tester.pump();

    final afterResize = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    expect(
      afterResize.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(afterResize.read(gameControllerProvider).countdownRemainingMs, 3000);
    expect(loop.isRunning, isTrue);

    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    expect(afterResize.read(gameControllerProvider).phase, GamePhase.playing);
  });

  testWidgets('preserves an in-progress game after the viewport changes', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('island-button-0')));
    await tester.tap(find.byKey(const ValueKey('island-button-1')));
    loop.tick();
    await tester.pump();

    final beforeButton = tester.element(find.byType(ElevatedButton).first);
    final beforeContainer = ProviderScope.containerOf(beforeButton);
    final before = beforeContainer.read(gameControllerProvider);
    expect(before.phase, GamePhase.playing);
    expect(before.elapsedMs, greaterThan(0));
    expect(before.movingForces, isNotEmpty);

    await tester.binding.setSurfaceSize(const Size(321, 500));
    await tester.pump();

    final afterButton = tester.element(find.byType(ElevatedButton).first);
    final afterContainer = ProviderScope.containerOf(afterButton);
    final after = afterContainer.read(gameControllerProvider);
    expect(after.phase, GamePhase.playing);
    expect(after.elapsedMs, before.elapsedMs);
    expect(after.islands, before.islands);
    expect(after.selectedIslandId, isNull);
    expect(after.movingForces, before.movingForces);
    expect(loop.isRunning, isTrue);

    loop.tick();
    await tester.pump();
    final continued = afterContainer.read(gameControllerProvider);
    expect(continued.elapsedMs, greaterThan(after.elapsedMs));
    expect(continued.movingForces.first.progress, greaterThan(0));
  });

  testWidgets(
    'pauses from the board and requires confirmation before quitting',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('start-game')));
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      await tester.pump();

      expect(find.byKey(const ValueKey('pause-game')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pause-game')));
      await tester.pump();
      expect(find.text('Game Paused'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-game')), findsOneWidget);
      expect(find.byKey(const ValueKey('quit-game')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quit-game')));
      await tester.pump();
      expect(find.text('Quit match?'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-quit')), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-quit')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cancel-quit')));
      await tester.pump();
      expect(find.text('Game Paused'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quit-game')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-quit')));
      await tester.pump();
      expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
      expect(find.text('Game Paused'), findsNothing);
    },
  );

  testWidgets('backgrounding a playing board pauses it automatically', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    loop.tick();
    await tester.pump();
    final before = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Game Paused'), findsOneWidget);
    expect(loop.isRunning, isFalse);

    loop.tick();
    await tester.pump();
    final after = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider);
    expect(after, before.copyWith(phase: GamePhase.paused));
  });

  testWidgets('result screen offers replay and settings actions', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    final islandFinder = find.byKey(const ValueKey('island-0'));
    final container = ProviderScope.containerOf(tester.element(islandFinder));
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    controller.finish(const GameResult.victory(elapsedMs: 1));
    await tester.pump();

    expect(find.text('Victory'), findsOneWidget);
    expect(find.byKey(const ValueKey('replay-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('return-settings')), findsOneWidget);
    expect(loop.isRunning, isFalse);

    await tester.tap(find.byKey(const ValueKey('return-settings')));
    await tester.pump();
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
    expect(find.text('Victory'), findsNothing);
  });
}
