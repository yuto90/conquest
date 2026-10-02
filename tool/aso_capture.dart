// Render the real 1.0.2 UI with deterministic maps and silent audio.
// Run: flutter test tool/aso_capture.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart' hide ManualGameLoop;
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/game_controller_test.dart'
    show ManualGameLoop, completeStartCountdown;
import '../test/support/match_setup.dart';

void main() {
  for (final device in ['iphone', 'ipad']) {
    for (final locale in ['en', 'ja']) {
      testWidgets('capture $device $locale', (tester) async {
        // This tool is a flutter_test capture harness rather than app code.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = device == 'ipad'
            ? const Size(768, 1024)
            : const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          for (final family in ['Noto Sans JP', 'Roboto']) {
            final loader = FontLoader(family);
            final prefix = family == 'Roboto' ? 'Roboto' : 'NotoSansJP';
            for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
              loader.addFont(
                rootBundle.load('assets/fonts/$prefix-$weight.ttf'),
              );
            }
            await loader.load();
          }
        });
        final loop = ManualGameLoop();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('aso-capture'),
            child: ProviderScope(
              overrides: [
                bgmPlayerProvider.overrideWithValue(_SilentBgm()),
                menuBgmPlayerProvider.overrideWithValue(_SilentBgm()),
                randomProvider.overrideWithValue(Random(6800177702)),
                gameLoopProvider.overrideWithValue(loop),
              ],
              child: MyApp(locale: Locale(locale)),
            ),
          ),
        );
        await openMatchSetup(tester);
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('settings-view'))),
        );
        final controller = container.read(gameControllerProvider.notifier);

        Future<void> capture(String name) async {
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('aso-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory(
              'tool/app-store-screenshots/public/screenshots/apple/$device/$locale',
            );
            await dir.create(recursive: true);
            await File(
              '${dir.path}/$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        Future<void> start() async {
          await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
          await tester.tap(find.byKey(const ValueKey('start-game')));
          completeStartCountdown(loop);
          await tester.pumpAndSettle();
        }

        await capture('setup');
        await start();
        final own = container
            .read(gameControllerProvider)
            .islands
            .firstWhere((i) => i.faction == Faction.player);
        final target = container
            .read(gameControllerProvider)
            .islands
            .firstWhere((i) => i.faction == Faction.neutral);
        controller.tapBase(own.id);
        controller.tapBase(target.id);
        loop.tickMany(30);
        await capture('battle');
        controller.tapBase(own.id);
        await capture('controls');

        controller.pauseGame();
        controller.returnToConfiguration();
        controller.selectIslandCount(16);
        await tester.pumpAndSettle();
        await start();
        loop.tickMany(50);
        await capture('map16');

        controller.pauseGame();
        controller.returnToConfiguration();
        controller.selectIslandCount(10);
        controller.selectGameMode(GameMode.cpuVsCpu);
        await tester.pumpAndSettle();
        await start();
        loop.tickMany(150);
        await capture('spectator');
        controller.pauseGame();
        controller.returnToConfiguration();
        controller.selectIslandCount(16);
        await tester.pumpAndSettle();
        await start();
        loop.tickMany(150);
        await capture('spectator16');

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
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
