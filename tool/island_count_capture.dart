import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/home.dart';
import 'package:conquest/audio/bgm_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/match_setup.dart';
import '../test/game_controller_test.dart'
    show ManualGameLoop, completeStartCountdown;

const captureCount = int.fromEnvironment('ISLAND_COUNT', defaultValue: 20);
void main() {
  testWidgets('capture real setup and twenty-island battle', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const bool.fromEnvironment('SMALL_PHONE')
        ? const Size(320, 568)
        : const Size(390, 844);
    if (const bool.fromEnvironment('SMALL_PHONE'))
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final family in ['Noto Sans JP', 'Roboto']) {
        final loader = FontLoader(family);
        final prefix = family == 'Roboto' ? 'Roboto' : 'NotoSansJP';
        for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
          loader.addFont(rootBundle.load('assets/fonts/$prefix-$weight.ttf'));
        }
        await loader.load();
      }
    });
    final loop = ManualGameLoop();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: ProviderScope(
          overrides: [
            bgmPlayerProvider.overrideWithValue(_SilentBgm()),
            menuBgmPlayerProvider.overrideWithValue(_SilentBgm()),
            randomProvider.overrideWithValue(Random(119)),
            gameLoopProvider.overrideWithValue(loop),
          ],
          child: const bool.fromEnvironment('WEB_LAYOUT')
              ? const MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale('ja'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Home(letterboxToPortrait: true),
                )
              : const MyApp(locale: Locale('ja')),
        ),
      ),
    );
    await openMatchSetup(tester);
    await setIslandCount(tester, captureCount);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('settings-view'))),
    );
    expect(
      container.read(gameControllerProvider).islands,
      hasLength(captureCount),
    );
    await _capture(tester, 'island-count-$captureCount-setup.png');
    await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    completeStartCountdown(loop);
    loop.tickMany(30);
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider).phase, GamePhase.playing);
    await _capture(tester, 'island-count-$captureCount-battle.png');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (const bool.fromEnvironment('SMALL_PHONE'))
    name = name.replaceAll(
      '.png',
      const bool.fromEnvironment('WEB_LAYOUT')
          ? '-small-web.png'
          : '-small-phone.png',
    );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = Directory(
      Platform.environment['CONQUEST_CAPTURE_DIR'] ?? 'docs/qa/issue-119',
    );
    await output.create(recursive: true);
    await File(
      '${output.path}/$name',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _SilentBgm implements BgmPlayer {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> playFromStart() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAndReset() async {}
  @override
  Future<void> dispose() async {}
}
