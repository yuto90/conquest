import 'package:conquest/game/game_state.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/rank_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rank_badge_fixture.dart';

void main() {
  for (final locale in ['en', 'ja']) {
    for (final width in [280.0, 390.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'integrated $locale settings/result at $width, text $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 844));
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            final fixture = await RankBadgeFixture.mount(
              tester,
              xp: RankCatalog.cumulativeXp[44],
              locale: Locale(locale),
            );
            final l10n = await AppLocalizations.delegate.load(Locale(locale));
            final progress = RankProgress.fromTotalXp(
              RankCatalog.cumulativeXp[44],
            );
            final label = l10n.rankDisplay(
              rank: 44,
              title: progress.localizedTitle(l10n),
            );
            expect(find.text(label), findsOneWidget);
            expect(
              find.bySemanticsLabel(RegExp(RegExp.escape(label))),
              findsOneWidget,
            );
            expect(tester.widget<RankBadge>(find.byType(RankBadge)).rank, 44);
            expect(tester.widget<RankBadge>(find.byType(RankBadge)).size, 36);
            expect(tester.takeException(), isNull);
            await fixture.finish(tester);
            expect(find.text(label), findsOneWidget);
            expect(
              find.bySemanticsLabel(RegExp(RegExp.escape(label))),
              findsOneWidget,
            );
            expect(tester.widget<RankBadge>(find.byType(RankBadge)).rank, 44);
            expect(tester.widget<RankBadge>(find.byType(RankBadge)).size, 56);
            expect(find.text('+3000 XP'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await fixture.close(tester);
            semantics.dispose();
          },
        );
      }
    }
  }

  testWidgets('result badge uses the receipt, never a newer profile rank', (
    tester,
  ) async {
    final fixture = await RankBadgeFixture.mount(
      tester,
      xp: RankCatalog.cumulativeXp[100],
      presentedRank: 140,
    );
    expect(tester.widget<RankBadge>(find.byType(RankBadge)).rank, 140);
    await fixture.finish(tester);
    final result = fixture.controller.state.result!;
    expect(result.totalXpAfter, RankCatalog.cumulativeXp[100] + 3000);
    expect(result.rankAfter, 100);
    expect(tester.widget<RankBadge>(find.byType(RankBadge)).rank, 100);
    expect(find.text('Rank 100 · Colonel'), findsOneWidget);
    await fixture.close(tester);
  });

  testWidgets('rank-up text is read once beside the static badge', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final fixture = await RankBadgeFixture.mount(tester, xp: 0);
    await fixture.finish(tester);
    const label = 'Rank Up! Rank 1 · Private First Class';
    expect(find.text(label), findsOneWidget);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(find.text('Rank 1 · Private First Class'), findsNothing);
    expect(tester.widget<RankBadge>(find.byType(RankBadge)).rank, 1);
    await fixture.close(tester);
    semantics.dispose();
  });

  for (final result in [
    const GameResult.defeat(elapsedMs: 100),
    const GameResult.draw(elapsedMs: 100),
    const GameResult.victory(elapsedMs: 100),
  ]) {
    testWidgets('zero XP ${result.type.name} keeps the reward area absent', (
      tester,
    ) async {
      final fixture = await RankBadgeFixture.mount(tester, xp: 0);
      await fixture.finish(
        tester,
        result: result,
        mode: result.type == GameResultType.victory
            ? GameMode.cpuVsCpu
            : GameMode.playerVsCpu,
      );
      expect(fixture.controller.state.result!.xpAwarded, 0);
      expect(find.byKey(const ValueKey('result-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('rank-award-summary')), findsNothing);
      expect(find.byType(RankBadge), findsNothing);
      await fixture.close(tester);
    });
  }
}
