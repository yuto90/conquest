import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
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
  testWidgets('shows the ready screen and ten bases', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('T A P  T O  P L A Y'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(10));
  });

  testWidgets('renders and clears a moving tank through Riverpod state', (
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

    await tester.tap(find.text('T A P  T O  P L A Y'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton).at(0));
    await tester.tap(find.byType(ElevatedButton).at(1));
    await tester.pump();

    expect(find.byKey(const ValueKey('tank')), findsOneWidget);

    for (var i = 0; i < 100; i++) {
      loop.tick();
    }
    await tester.pump();

    expect(find.byKey(const ValueKey('tank')), findsNothing);
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

    final buttons = find.byType(ElevatedButton);
    expect(buttons, findsNWidgets(10));
    expect(tester.getTopLeft(buttons.at(1)).dy, closeTo(24, 1e-6));
    expect(tester.getBottomRight(buttons.at(0)).dy, closeTo(484, 1e-6));
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
}
