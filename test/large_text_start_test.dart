import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/main.dart';
import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

void main() {
  testWidgets(
    'cold title start keeps setup visible at accessibility text size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(744, 1133));
      tester.binding.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(() {
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        return tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            randomProvider.overrideWithValue(Random(1)),
            rankProgressProvider.overrideWith(
              (ref) => Stream.value(RankProgress.zero),
            ),
          ],
          child: const MyApp(locale: Locale('ja')),
        ),
      );
      await tester.pumpAndSettle();
      await openMatchSetup(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('対戦設定').hitTestable(), findsOneWidget);
      final myPage = find.byKey(const ValueKey('open-my-page'));
      await tester.ensureVisible(myPage);
      await tester.pumpAndSettle();
      expect(myPage.hitTestable(), findsOneWidget);
      await tester.tap(myPage);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('my-page')), findsOneWidget);
    },
  );
}
