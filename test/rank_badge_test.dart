import 'dart:ui' as ui;

import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/rank_badge.dart';
import 'package:conquest/ui/rank_badge_spec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/rank_badge_study/badge.dart' as study;
import '../tool/rank_badges/crest_source.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Missing test asset: $key');
}

void main() {
  test('maps all 141 ranks to the existing 26 variable-length groups', () {
    final lengths = <RankTitleKey, int>{};
    for (final tier in RankCatalog.tiers) {
      lengths.update(tier.titleKey, (value) => value + 1, ifAbsent: () => 1);
    }
    expect(lengths.length, 26);
    expect(lengths.values.toSet(), {1, 4, 5, 10});
    for (final tier in RankCatalog.tiers) {
      final spec = RankBadgeSpec.fromRank(tier.rank);
      expect(spec.tier, same(tier));
      expect(spec.groupIndex, RankTitleKey.values.indexOf(tier.titleKey));
      expect(spec.stage, tier.rank - tier.titleKey.firstRank);
      expect(spec.stageCount, lengths[tier.titleKey]);
      expect(spec.secondBand, spec.stageCount == 10 && spec.stage >= 5);
      expect(spec.pips, spec.stageCount == 1 ? 0 : spec.stage % 5 + 1);
    }
    expect(RankBadgeSpec.fromRank(0).stageCount, 1);
    expect(RankBadgeSpec.fromRank(99).stageCount, 4);
    expect(RankBadgeSpec.fromRank(99).pips, 4);
    expect(RankBadgeSpec.fromRank(109).secondBand, isTrue);
    expect(RankBadgeSpec.fromRank(139).secondBand, isTrue);
    expect(RankBadgeSpec.fromRank(140).stageCount, 1);
    expect(RankBadgeSpec.fromRank(140).secondBand, isFalse);
    expect(() => RankBadgeSpec.fromRank(-1), throwsRangeError);
    expect(() => RankBadgeSpec.fromRank(141), throwsRangeError);
  });

  test('repaints only for a rank or layer change', () {
    final original = RankBadgePainter(
      spec: RankBadgeSpec.fromRank(100),
      layer: RankBadgeLayer.base,
    );
    expect(
      RankBadgePainter(
        spec: RankBadgeSpec.fromRank(100),
        layer: RankBadgeLayer.base,
      ).shouldRepaint(original),
      isFalse,
    );
    for (final painter in [
      RankBadgePainter(
        spec: RankBadgeSpec.fromRank(101),
        layer: RankBadgeLayer.base,
      ),
      RankBadgePainter(
        spec: RankBadgeSpec.fromRank(100),
        layer: RankBadgeLayer.details,
      ),
    ]) {
      expect(painter.shouldRepaint(original), isTrue);
    }
  });

  testWidgets('the registered crest matches the original regeneration source', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(rankBadgeCrestAsset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final asset = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      paintRankCrestSource(Canvas(recorder)..scale(1.92));
      final picture = recorder.endRecording();
      final source = await picture.toImage(192, 192);
      expect(asset.width, 192);
      expect(asset.height, 192);
      expect(
        (await asset.toByteData())!.buffer.asUint8List(),
        orderedEquals((await source.toByteData())!.buffer.asUint8List()),
      );
      source.dispose();
      asset.dispose();
      codec.dispose();
      picture.dispose();
    });
  });

  testWidgets('all ranks match approved C geometry at each supported size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(rankBadgeCrestAsset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final crest = (await codec.getNextFrame()).image;
      for (final size in [24.0, 32.0, 36.0, 48.0, 56.0, 64.0, 96.0]) {
        final signatures = <String>{};
        for (var rank = 0; rank <= 140; rank++) {
          final spec = RankBadgeSpec.fromRank(rank);
          final actualRecorder = ui.PictureRecorder();
          final actualCanvas = Canvas(actualRecorder)..scale(3);
          RankBadgePainter(
            spec: spec,
            layer: RankBadgeLayer.base,
          ).paint(actualCanvas, Size.square(size));
          if (spec.usesCrest) {
            actualCanvas.save();
            actualCanvas.scale(size / 100);
            actualCanvas.drawImageRect(
              crest,
              const Rect.fromLTWH(0, 0, 192, 192),
              rankBadgeCrestRect(spec),
              Paint()..filterQuality = FilterQuality.medium,
            );
            actualCanvas.restore();
          }
          RankBadgePainter(
            spec: spec,
            layer: RankBadgeLayer.details,
          ).paint(actualCanvas, Size.square(size));
          final expectedRecorder = ui.PictureRecorder();
          study.BadgePainter(
            spec: study.BadgeSpec.fromRank(rank),
            method: study.BadgeMethod.composite,
            crest: crest,
          ).paint(Canvas(expectedRecorder)..scale(3), Size.square(size));
          final actualPicture = actualRecorder.endRecording();
          final expectedPicture = expectedRecorder.endRecording();
          final actual = await actualPicture.toImage(
            (size * 3).round(),
            (size * 3).round(),
          );
          final expected = await expectedPicture.toImage(
            (size * 3).round(),
            (size * 3).round(),
          );
          final pixels = (await actual.toByteData())!.buffer.asUint8List();
          expect(
            pixels,
            orderedEquals((await expected.toByteData())!.buffer.asUint8List()),
            reason: 'rank $rank at $size dp',
          );
          signatures.add(pixels.toString());
          actual.dispose();
          expected.dispose();
          actualPicture.dispose();
          expectedPicture.dispose();
        }
        expect(
          signatures.length,
          141,
          reason: 'distinct raster output at $size',
        );
      }
      crest.dispose();
      codec.dispose();
    });
  });

  for (final locale in ['en', 'ja']) {
    for (final width in [160.0, 240.0, 320.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('complete $locale label at $width dp and text $scale', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          final progress = RankProgress.fromTotalXp(
            RankCatalog.cumulativeXp[44],
          );
          final l10n = await AppLocalizations.delegate.load(Locale(locale));
          final label = l10n.rankDisplay(
            rank: progress.rank,
            title: progress.localizedTitle(l10n),
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: RankBadgeLabel(
                      progress: progress,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget);
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(tester.widget<Text>(find.text(label)).overflow, isNull);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
  }

  testWidgets('loading and missing crest keep a synchronous geometric badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _MissingBundle(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: RankBadge(rank: 140, size: 56)),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('rank-crest-fallback')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rank-crest-fallback')), findsOneWidget);
    expect(tester.getSize(find.byType(RankBadge)), const Size(56, 56));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'complex badges share the asset and do not expose image semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RankBadge(rank: 0),
                  RankBadge(rank: 99),
                  RankBadge(rank: 140),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(rankBadgeCrestAsset),
          tester.element(find.byType(RankBadge).first),
        );
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rank-crest-fallback')), findsNothing);
      expect(find.byType(Image), findsNWidgets(2));
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((i) => i.image)
            .toSet()
            .length,
        1,
      );
      expect(
        find.bySemanticsLabel(RegExp('rank|crest', caseSensitive: false)),
        findsNothing,
      );
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        expect(image.width, 324);
        expect(image.height, 108);
        final bytes = await rootBundle.load(rankBadgeCrestAsset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final crest = (await codec.getNextFrame()).image;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(3);
        for (final rank in [0, 99, 140]) {
          study.BadgePainter(
            spec: study.BadgeSpec.fromRank(rank),
            method: study.BadgeMethod.composite,
            crest: crest,
          ).paint(canvas, const Size(36, 36));
          canvas.translate(36, 0);
        }
        final picture = recorder.endRecording();
        final expected = await picture.toImage(324, 108);
        final actualPixels = (await image.toByteData())!.buffer.asUint8List();
        final expectedPixels = (await expected.toByteData())!.buffer
            .asUint8List();
        var maxDifference = 0;
        for (var i = 0; i < actualPixels.length; i++) {
          final difference = (actualPixels[i] - expectedPixels[i]).abs();
          if (difference > maxDifference) maxDifference = difference;
        }
        expect(
          maxDifference,
          lessThanOrEqualTo(2),
          reason:
              'Image widget layer rounding must preserve the approved drawing',
        );
        expected.dispose();
        picture.dispose();
        crest.dispose();
        codec.dispose();
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
