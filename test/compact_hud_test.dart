import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_controller_test.dart' show ManualGameLoop, completeStartCountdown;
import 'support/match_setup.dart';

void main() {
  for (final language in ['en', 'ja']) {
    for (final mode in GameMode.values) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets(
          'compact dense HUD fits pause reservation $language/$mode/$scale',
          (tester) async {
            tester.view
              ..devicePixelRatio = 1
              ..physicalSize = const Size(320, 568)
              ..padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();

            final loop = ManualGameLoop();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  randomProvider.overrideWithValue(Random(119)),
                  gameLoopProvider.overrideWithValue(loop),
                  gameConfigurationProvider.overrideWithValue(
                    GameConfiguration(
                      totalIslandCount: 16,
                      gameMode: mode,
                      playerCpuDifficulty: CpuDifficulty.veryEasy,
                      cpuDifficulty: CpuDifficulty.veryEasy,
                    ),
                  ),
                ],
                child: MyApp(locale: Locale(language)),
              ),
            );
            await openMatchSetup(tester);
            final container = ProviderScope.containerOf(
              tester.element(find.byKey(const ValueKey('settings-view'))),
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('start-game')),
            );
            await tester.tap(find.byKey(const ValueKey('start-game')));
            completeStartCountdown(loop);
            await tester.pump();
            final badge = find.byKey(const ValueKey('compact-board-summary'));
            final badgeRect = tester.getRect(badge);
            final stage = tester.getRect(
              find.byKey(const ValueKey('playable-stage')),
            );
            final reserved = container
                .read(mapViewportProvider)
                .topRightControlExclusion;
            expect(
              badgeRect.left,
              greaterThanOrEqualTo(stage.left + reserved.left),
            );
            expect(
              badgeRect.right,
              lessThanOrEqualTo(stage.left + reserved.right),
            );
            expect(
              badgeRect.top,
              greaterThanOrEqualTo(stage.top + reserved.top),
            );
            expect(
              badgeRect.bottom,
              lessThanOrEqualTo(stage.top + reserved.bottom),
            );
            expect(
              badgeRect.overlaps(
                tester.getRect(find.byKey(const ValueKey('pause-game'))),
              ),
              isFalse,
            );
            for (final island
                in container.read(gameControllerProvider).islands) {
              expect(
                badgeRect.overlaps(
                  tester.getRect(
                    find.byKey(ValueKey('island-button-${island.id}')),
                  ),
                ),
                isFalse,
              );
            }
            final summary = mode == GameMode.cpuVsCpu
                ? '1P Very Easy / 2P Very Easy / ${language == 'en' ? '16 islands' : '16島'}'
                : 'Very Easy / ${language == 'en' ? '16 islands' : '16島'}';
            expect(tester.getSemantics(badge).label, summary);
            expect(
              find.byKey(const ValueKey('board-title-block')),
              findsNothing,
            );
            if (scale == 1) {
              await tester.longPress(badge);
              await tester.pumpAndSettle();
              expect(find.text(summary), findsOneWidget);
            }
            await tester.tap(find.byKey(const ValueKey('pause-game')));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const ValueKey('paused-board-summary')),
                  )
                  .data,
              summary,
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
