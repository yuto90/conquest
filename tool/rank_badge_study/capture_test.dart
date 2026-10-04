import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'badge.dart';
import 'cards.dart';

const representatives = [0, 1, 46, 51, 76, 91, 100, 140];
const output = 'docs/qa/issue-124';
const assets = 'tool/rank_badge_study/assets';

void main() {
  testWidgets('export isolated rank-badge comparison and measurements', (
    tester,
  ) async {
    final images = <int, ui.Image>{};
    late ui.Image crest;
    final metrics = <String, Object>{};
    await tester.runAsync(() async {
      for (final family in ['Noto Sans JP', 'Roboto']) {
        final loader = FontLoader(family);
        final prefix = family == 'Roboto' ? 'Roboto' : 'NotoSansJP';
        for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
          loader.addFont(rootBundle.load('assets/fonts/$prefix-$weight.ttf'));
        }
        await loader.load();
      }
      crest = await rasterize(paintCrestSource);
      final crestBytes = await png(crest);
      await File('$assets/chart-crest.png').writeAsBytes(crestBytes);
      final sizes = <String, Object>{};
      for (final method in BadgeMethod.values) {
        var total = 0;
        var gzipTotal = 0;
        final individualSizes = <String, int>{};
        for (final rank in representatives) {
          final spec = BadgeSpec.fromRank(rank);
          final image = await rasterize((canvas) {
            if (method == BadgeMethod.individual) {
              paintIndividualSource(canvas, spec, crest);
            } else {
              paintVectorBadge(
                canvas,
                spec,
                crest: method == BadgeMethod.composite ? crest : null,
              );
            }
          });
          final bytes = await png(image);
          total += bytes.length;
          gzipTotal += gzip.encode(bytes).length;
          individualSizes['$rank'] = bytes.length;
          if (method == BadgeMethod.individual) {
            images[rank] = image;
            await File('$assets/a-rank-$rank.png').writeAsBytes(bytes);
          } else {
            image.dispose();
          }
        }
        sizes[method.name] = {
          'eight_png_bytes': total,
          'eight_gzip_bytes': gzipTotal,
          'per_rank_png_bytes': individualSizes,
        };
      }
      metrics['environment'] = {
        'os': Platform.operatingSystem,
        'mode': 'flutter test debug / offscreen',
        'sample_pixels': 192,
        'logical_dp': 64,
        'dpr': 3,
        'scope': 'eight representatives only; not release frame profiling',
      };
      metrics['assets'] = sizes;
      metrics['crest_png_bytes'] = crestBytes.length;
      metrics['crest_gzip_bytes'] = gzip.encode(crestBytes).length;
      metrics['decoded_rgba_bytes_per_192px_image'] = 192 * 192 * 4;
      metrics['decoded_rgba_bytes_eight_images'] = 8 * 192 * 192 * 4;
      metrics['decoded_rgba_bytes_141_images_if_all_loaded'] =
          141 * 192 * 192 * 4;
      final timings = <String, Object>{};
      for (final method in BadgeMethod.values) {
        final painter = BadgePainter(
          spec: BadgeSpec.fromRank(100),
          method: method,
          crest: crest,
          individual: images[100],
        );
        final recordTimes = <int>[];
        for (var i = 0; i < 1010; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final watch = Stopwatch()..start();
          painter.paint(canvas, const Size(64, 64));
          final picture = recorder.endRecording();
          watch.stop();
          if (i >= 10) recordTimes.add(watch.elapsedMicroseconds);
          picture.dispose();
        }
        final rasterTimes = <int>[];
        for (var i = 0; i < 35; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(3);
          painter.paint(canvas, const Size(64, 64));
          final picture = recorder.endRecording();
          final watch = Stopwatch()..start();
          final image = await picture.toImage(192, 192);
          watch.stop();
          if (i >= 5) rasterTimes.add(watch.elapsedMicroseconds);
          image.dispose();
          picture.dispose();
        }
        timings[method.name] = {
          'record_1000_samples_us': stats(recordTimes),
          'offscreen_raster_30_samples_us': stats(rasterTimes),
        };
      }
      metrics['timings'] = timings;
      final decodeTimes = <int>[];
      final referenceBytes = await File('$assets/a-rank-100.png').readAsBytes();
      for (var i = 0; i < 35; i++) {
        final watch = Stopwatch()..start();
        final codec = await ui.instantiateImageCodec(referenceBytes);
        final frame = await codec.getNextFrame();
        watch.stop();
        if (i >= 5) decodeTimes.add(watch.elapsedMicroseconds);
        frame.image.dispose();
        codec.dispose();
      }
      metrics['png_decode_30_samples_us'] = stats(decodeTimes);
      await File('$output/metrics.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(metrics)}\n',
      );
    });
    addTearDown(() {
      crest.dispose();
      for (final image in images.values) {
        image.dispose();
      }
      tester.view.reset();
    });

    StudyBadge badge(int rank, BadgeMethod method, double size) => StudyBadge(
      spec: BadgeSpec.fromRank(rank),
      method: method,
      size: size,
      crest: crest,
      individual: images[rank],
    );
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    await capture(
      tester,
      'methods.png',
      const Size(1000, 780),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'RANK INSIGNIA / ORIGINAL DESIGN STUDY',
            'A: frozen PNG references    B: geometric Canvas    C: Canvas + original compass crest',
          ),
          Row(
            children: [
              const SizedBox(width: 240),
              for (final method in BadgeMethod.values)
                Expanded(
                  child: Text(
                    '${method.name.toUpperCase()} / 32 + 64 dp',
                    style: labelStyle,
                  ),
                ),
            ],
          ),
          for (final rank in representatives)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        'RANK $rank\n${RankCatalog.tiers[rank].localizedTitle(en)}',
                        style: labelStyle,
                      ),
                    ),
                  ),
                  for (final method in BadgeMethod.values)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          badge(rank, method, 32),
                          const SizedBox(width: 20),
                          badge(rank, method, 64),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          footnote(
            'All methods share the same silhouette, background and rank source. A is an illustrative frozen-image workflow, not 141 commissioned artworks.',
          ),
        ],
      ),
    );

    await capture(
      tester,
      'sizes.png',
      const Size(1040, 810),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'C / ACTUAL LOGICAL SIZES',
            '24 / 32 / 48 / 64 / 96 dp. Exported at 2x; view at 1040px width for logical size.',
          ),
          Row(
            children: [
              const SizedBox(width: 64),
              for (final rank in representatives)
                Expanded(
                  child: Text(
                    'RANK $rank',
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
            ],
          ),
          for (final size in [24.0, 32.0, 48.0, 64.0, 96.0])
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${size.toInt()} dp',
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                  for (final rank in representatives)
                    Expanded(
                      child: Center(
                        child: badge(rank, BadgeMethod.composite, size),
                      ),
                    ),
                ],
              ),
            ),
          Text(
            'C / GRAYSCALE SHAPE CHECK / 48 dp',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          SizedBox(
            height: 90,
            child: Row(
              children: [
                const SizedBox(width: 64),
                for (final rank in representatives)
                  Expanded(
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: badge(rank, BadgeMethod.composite, 48),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          footnote(
            '24dp is a fallback/silhouette size, not a reliable stage identifier. Numeric rank + localized title remain authoritative.',
          ),
        ],
      ),
    );

    await capture(
      tester,
      'stages.png',
      const Size(1080, 700),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'C / GROUP BOUNDARIES & STAGE BANDS',
            'Five lower pips maximum. Stages 6–10 add an upper rail; no row of ten stars.',
          ),
          for (final ranks in [
            List.generate(5, (i) => i + 1),
            List.generate(4, (i) => i + 96),
            List.generate(10, (i) => i + 100),
            List.generate(10, (i) => i + 130),
          ])
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${ranks.first}–${ranks.last}\n${ranks.length} stages',
                        style: labelStyle,
                      ),
                    ),
                  ),
                  for (final rank in ranks)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          badge(rank, BadgeMethod.composite, 48),
                          const SizedBox(height: 8),
                          Text('$rank', style: labelStyle),
                        ],
                      ),
                    ),
                  if (ranks.length < 10) Spacer(flex: 10 - ranks.length),
                ],
              ),
            ),
          footnote(
            'Rank 0 and 140 are singletons without stage pips. Four-stage lieutenant colonel uses the same rule with only four positions.',
          ),
        ],
      ),
    );

    for (final locale in [const Locale('en'), const Locale('ja')]) {
      final progress = RankProgress.fromTotalXp(
        RankCatalog.cumulativeXp[75] + 1200,
      );
      final xp = RankCatalog.cumulativeXp[100] + 300;
      final result = GameResult.victory(
        elapsedMs: 60000,
        xpAwarded: 1500,
        rankBefore: 99,
        rankAfter: 100,
        totalXpBefore: xp - 1500,
        totalXpAfter: xp,
      );
      await capture(
        tester,
        'cards-${locale.languageCode}.png',
        const Size(1100, 1280),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(
              'C / SETUP & RESULT PLACEMENT / ${locale.languageCode.toUpperCase()}',
              'Isolated widget mockups on the production TacticalPalette, not a change to the game UI.',
            ),
            for (final scale in [1.0, 2.0])
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final width in [280.0, 340.0, 420.0])
                      SizedBox(
                        width: width,
                        child: Builder(
                          builder: (context) => MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(textScaler: TextScaler.linear(scale)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${width.toInt()}dp card / text ${scale}x',
                                  style: labelStyle,
                                ),
                                const SizedBox(height: 12),
                                StudyRankCard(progress: progress, crest: crest),
                                const SizedBox(height: 20),
                                StudyResultCard(result: result, crest: crest),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            footnote(
              '36dp setup / 56dp result. Long names wrap; enlarged text stacks the badge above the label. Result uses totalXpAfter.',
            ),
          ],
        ),
        locale: locale,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

const labelStyle = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 12,
  color: TacticalPalette.foreground,
  fontWeight: FontWeight.w600,
);

Widget heading(String title, String subtitle) => Padding(
  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: labelStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: labelStyle),
    ],
  ),
);
Widget footnote(String label) => Padding(
  padding: const EdgeInsets.all(20),
  child: Text(label, style: labelStyle.copyWith(fontSize: 11)),
);

Future<ui.Image> rasterize(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(1.92);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(192, 192);
  picture.dispose();
  return image;
}

Future<List<int>> png(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.png,
))!.buffer.asUint8List();

Map<String, int> stats(List<int> values) {
  values.sort();
  return {
    'median': values[values.length ~/ 2],
    'p95': values[(values.length * 0.95).ceil() - 1],
  };
}

Future<void> capture(
  WidgetTester tester,
  String name,
  Size size,
  Widget content, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTacticalTheme(
        typography: TacticalTypography.forLocale(locale),
      ),
      home: RepaintBoundary(
        key: const ValueKey('capture'),
        child: Scaffold(body: content),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    await File('$output/$name').writeAsBytes(await png(image));
    image.dispose();
  });
}
