import 'dart:io';
import 'dart:ui' as ui;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/rank_badge_study/badge.dart';
import '../tool/rank_badge_study/cards.dart';

void main() {
  testWidgets('all ranks render with the real crest at all five study sizes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await File(
        'tool/rank_badge_study/assets/chart-crest.png',
      ).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final crest = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        for (final tier in RankCatalog.tiers) {
          for (final method in [BadgeMethod.geometry, BadgeMethod.composite]) {
            for (final dimension in [24.0, 32.0, 48.0, 64.0, 96.0]) {
              final recorder = ui.PictureRecorder();
              final painter = BadgePainter(
                spec: BadgeSpec.fromRank(tier.rank),
                method: method,
                crest: crest,
              );
              painter.paint(Canvas(recorder), Size.square(dimension));
              final picture = recorder.endRecording();
              if (dimension == 24) {
                final image = await picture.toImage(24, 24);
                final rgba = await image.toByteData();
                expect(
                  rgba!.getUint8((12 * 24 + 12) * 4 + 3),
                  greaterThan(0),
                  reason: 'rank ${tier.rank} / $method',
                );
                image.dispose();
              }
              picture.dispose();
            }
          }
        }
      } finally {
        crest.dispose();
      }
    });
  });

  test('all 141 ranks use the canonical 26 group boundaries', () {
    final groups = <RankTitleKey, List<BadgeSpec>>{};
    for (final tier in RankCatalog.tiers) {
      final spec = BadgeSpec.fromRank(tier.rank);
      expect(spec.tier, same(tier));
      expect(spec.stage, tier.rank - tier.titleKey.firstRank);
      expect(spec.pips, inInclusiveRange(0, 5));
      groups.putIfAbsent(tier.titleKey, () => []).add(spec);
    }
    expect(groups.length, 26);
    for (final specs in groups.values) {
      expect(specs.map((s) => s.stage), List.generate(specs.length, (i) => i));
      expect(specs.every((s) => s.stageCount == specs.length), isTrue);
    }
    expect(BadgeSpec.fromRank(0).stageCount, 1);
    expect(BadgeSpec.fromRank(96).stageCount, 4);
    expect(BadgeSpec.fromRank(99).stage, 3);
    expect(BadgeSpec.fromRank(100).stageCount, 10);
    expect(BadgeSpec.fromRank(109).secondBand, isTrue);
    expect(BadgeSpec.fromRank(130).stageCount, 10);
    expect(BadgeSpec.fromRank(139).stage, 9);
    expect(BadgeSpec.fromRank(140).stageCount, 1);
    expect(() => BadgeSpec.fromRank(-1), throwsRangeError);
    expect(() => BadgeSpec.fromRank(141), throwsRangeError);
  });

  test('repaint depends on visual inputs, not localized labels or XP', () {
    final original = BadgePainter(
      spec: BadgeSpec.fromRank(100),
      method: BadgeMethod.geometry,
    );
    expect(
      BadgePainter(
        spec: BadgeSpec.fromRank(100),
        method: BadgeMethod.geometry,
      ).shouldRepaint(original),
      isFalse,
    );
    expect(
      BadgePainter(
        spec: BadgeSpec.fromRank(101),
        method: BadgeMethod.geometry,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      BadgePainter(
        spec: BadgeSpec.fromRank(100),
        method: BadgeMethod.composite,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      BadgePainter(
        spec: BadgeSpec.fromRank(100),
        method: BadgeMethod.geometry,
        monochrome: true,
      ).shouldRepaint(original),
      isTrue,
    );
  });

  for (final locale in [const Locale('ja'), const Locale('en')]) {
    for (final width in [160.0, 320.0, 390.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('rank card ${locale.languageCode} ${width}dp ${scale}x', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final progress = RankProgress.fromTotalXp(
            RankCatalog.cumulativeXp[75],
          );
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            studyApp(
              locale: locale,
              scale: scale,
              child: StudyRankCard(progress: progress),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final l10n = await AppLocalizations.delegate.load(locale);
          final label = l10n.rankDisplay(
            rank: 75,
            title: progress.localizedTitle(l10n),
          );
          expect(find.text(label), findsOneWidget);
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(tester.getSize(find.byType(StudyBadge)), const Size(36, 36));
          semantics.dispose();
        });
      }
    }
  }

  testWidgets('result uses its match snapshot without a live provider', (
    tester,
  ) async {
    final after = RankCatalog.cumulativeXp[100] + 300;
    final result = GameResult.victory(
      elapsedMs: 60000,
      xpAwarded: 1500,
      rankBefore: 99,
      rankAfter: 100,
      totalXpBefore: after - 1500,
      totalXpAfter: after,
    );
    await tester.pumpWidget(studyApp(child: StudyResultCard(result: result)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<StudyBadge>(find.byType(StudyBadge)).spec.tier.rank,
      100,
    );
    expect(tester.takeException(), isNull);
    expect(result.totalXpAfter, after);
  });

  for (final result in [
    const GameResult.defeat(elapsedMs: 1000),
    const GameResult.draw(elapsedMs: 1000),
    const GameResult.victory(elapsedMs: 1000),
  ]) {
    testWidgets(
      'no new reward for ${result.type} with ${result.xpAwarded} XP',
      (tester) async {
        await tester.pumpWidget(
          studyApp(child: StudyResultCard(result: result)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StudyBadge), findsNothing);
      },
    );
  }
}

Widget studyApp({
  Locale locale = const Locale('en'),
  double scale = 1,
  required Widget child,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: content!,
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: child),
  ),
);
