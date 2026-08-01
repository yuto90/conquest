import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
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
}
