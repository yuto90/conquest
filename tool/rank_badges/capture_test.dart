import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/rank_badge.dart';
import 'package:conquest/ui/rank_badge_spec.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/rank_badge_fixture.dart';

const _output = 'docs/qa/issue-124/product';

void main() {
  testWidgets('capture integrated screens, all ranks and product costs', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      for (final family in ['Noto Sans JP', 'Roboto']) {
        final loader = FontLoader(family);
        final prefix = family == 'Roboto' ? 'Roboto' : 'NotoSansJP';
        for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
          loader.addFont(rootBundle.load('assets/fonts/$prefix-$weight.ttf'));
        }
        await loader.load();
      }
    });

    for (final sample in [
      (
        name: 'settings-ja',
        locale: 'ja',
        rank: 140,
        width: 390.0,
        scale: 1.0,
        result: false,
      ),
      (
        name: 'settings-en',
        locale: 'en',
        rank: 44,
        width: 390.0,
        scale: 1.0,
        result: false,
      ),
      (
        name: 'settings-en-narrow',
        locale: 'en',
        rank: 44,
        width: 280.0,
        scale: 1.0,
        result: false,
      ),
      (
        name: 'settings-en-large-text',
        locale: 'en',
        rank: 44,
        width: 390.0,
        scale: 2.0,
        result: false,
      ),
      (
        name: 'result-ja-rank-up',
        locale: 'ja',
        rank: 0,
        width: 390.0,
        scale: 1.0,
        result: true,
      ),
      (
        name: 'result-en-snapshot',
        locale: 'en',
        rank: 100,
        width: 390.0,
        scale: 1.0,
        result: true,
      ),
    ]) {
      await tester.binding.setSurfaceSize(Size(sample.width, 844));
      tester.platformDispatcher.textScaleFactorTestValue = sample.scale;
      final boundary = GlobalKey();
      final fixture = await RankBadgeFixture.mount(
        tester,
        xp: RankCatalog.cumulativeXp[sample.rank],
        locale: Locale(sample.locale),
        presentedRank: sample.name == 'result-en-snapshot' ? 140 : null,
        boundaryKey: boundary,
      );
      if (sample.result) await fixture.finish(tester);
      if (sample.rank >= 91) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(rankBadgeCrestAsset),
            tester.element(find.byType(RankBadge).first),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, sample.name);
      await fixture.close(tester);
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(const Size(900, 2340));
    final sheet = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTacticalTheme(),
        home: RepaintBoundary(
          key: sheet,
          child: ColoredBox(
            color: TacticalPalette.background,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('PRODUCT C / RANK 0–140 / 36dp + 56dp'),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 7,
                    childAspectRatio: 1.25,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var rank = 0; rank <= 140; rank++)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RankBadge(rank: rank),
                                RankBadge(rank: rank, size: 56),
                              ],
                            ),
                            Text(
                              'RANK $rank',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RankBadge), findsNWidgets(282));
    expect(tester.takeException(), isNull);
    await _capture(tester, sheet, 'all-ranks');
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.runAsync(() async {
      final bytes = await File(rankBadgeCrestAsset).readAsBytes();
      final decodeTimes = <int>[];
      late ui.Image crest;
      for (var i = 0; i < 35; i++) {
        final watch = Stopwatch()..start();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        watch.stop();
        if (i >= 5) decodeTimes.add(watch.elapsedMicroseconds);
        if (i == 34) {
          crest = image;
        } else {
          image.dispose();
        }
        codec.dispose();
      }
      final timings = <String, Object>{};
      for (final size in [36.0, 56.0]) {
        for (final rank in [0, 44, 99, 105, 139, 140]) {
          final spec = RankBadgeSpec.fromRank(rank);
          final record = <int>[];
          final raster = <int>[];
          for (var i = 0; i < 1010; i++) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            final watch = Stopwatch()..start();
            _paint(canvas, spec, size, crest);
            final picture = recorder.endRecording();
            watch.stop();
            if (i >= 10) record.add(watch.elapsedMicroseconds);
            picture.dispose();
          }
          for (var i = 0; i < 35; i++) {
            final recorder = ui.PictureRecorder();
            _paint(Canvas(recorder)..scale(3), spec, size, crest);
            final picture = recorder.endRecording();
            final watch = Stopwatch()..start();
            final image = await picture.toImage(
              (size * 3).round(),
              (size * 3).round(),
            );
            watch.stop();
            if (i >= 5) raster.add(watch.elapsedMicroseconds);
            image.dispose();
            picture.dispose();
          }
          timings['rank_${rank}_${size.round()}dp'] = {
            'record_1000_samples_us': _stats(record),
            'offscreen_raster_30_samples_us': _stats(raster),
          };
        }
      }
      crest.dispose();
      await File('$_output/metrics.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'environment': {
            'os': Platform.operatingSystem,
            'mode':
                'flutter test debug / offscreen; not release frame profiling',
            'flutter': '3.44.8',
            'dpr': 3,
            'scope':
                'Canvas layers + decoded crest; excludes widget layout and compositing',
          },
          'shared_crest_png_bytes': bytes.length,
          'shared_crest_gzip_bytes': gzip.encode(bytes).length,
          'shared_crest_decoded_rgba_bytes': 192 * 192 * 4,
          'png_decode_30_samples_us': _stats(decodeTimes),
          'timings': timings,
        }),
      );
    });
  });
}

void _paint(Canvas canvas, RankBadgeSpec spec, double size, ui.Image crest) {
  RankBadgePainter(
    spec: spec,
    layer: RankBadgeLayer.base,
  ).paint(canvas, Size.square(size));
  if (spec.usesCrest) {
    canvas.save();
    canvas.scale(size / 100);
    canvas.drawImageRect(
      crest,
      const Rect.fromLTWH(0, 0, 192, 192),
      rankBadgeCrestRect(spec),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }
  RankBadgePainter(
    spec: spec,
    layer: RankBadgeLayer.details,
  ).paint(canvas, Size.square(size));
}

Map<String, int> _stats(List<int> values) {
  values.sort();
  return {
    'median': values[values.length ~/ 2],
    'p95': values[(values.length * 0.95).ceil() - 1],
  };
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
