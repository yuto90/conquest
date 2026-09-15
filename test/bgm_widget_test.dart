import 'dart:math';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

final class _ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tick() => _onTick?.call();
}

final class _WidgetBgmPlayer implements BgmPlayer {
  final List<String> calls = <String>[];
  Object? prepareError;
  Object? playError;

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    final error = prepareError;
    if (error != null) throw error;
  }

  @override
  Future<void> playFromStart() async {
    calls.add('playFromStart');
    final error = playError;
    if (error != null) throw error;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stopAndReset() async => calls.add('stopAndReset');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

Future<void> _advanceToPlaying(
  WidgetTester tester,
  _ManualGameLoop loop,
) async {
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('BGM setting persists between setup, pause, and resume', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    final player = _WidgetBgmPlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          bgmPlayerProvider.overrideWithValue(player),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);

    final toggle = find.byKey(const ValueKey('bgm-toggle'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await _advanceToPlaying(tester, loop);
    expect(player.calls, contains('prepare'));
    expect(player.calls, isNot(contains('playFromStart')));

    await tester.tap(find.byKey(const ValueKey('pause-game')));
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(player.calls, isNot(contains('playFromStart')));

    await tester.tap(find.byKey(const ValueKey('resume-game')));
    await _advanceToPlaying(tester, loop);
    expect(player.calls, contains('playFromStart'));
  });

  testWidgets('shows a non-modal retry action when BGM playback is rejected', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    final player = _WidgetBgmPlayer()
      ..prepareError = StateError('autoplay rejected');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          bgmPlayerProvider.overrideWithValue(player),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await _advanceToPlaying(tester, loop);

    expect(find.byKey(const ValueKey('bgm-retry')), findsOneWidget);
    expect(find.text('BGMを再生できません。音なしで対戦を続けます。'), findsOneWidget);

    player.prepareError = null;
    await tester.tap(find.byKey(const ValueKey('bgm-retry')));
    await tester.pump();
    await tester.pump();
    expect(player.calls, contains('playFromStart'));
  });

  testWidgets('retries a rejected prepared BGM from the retry action', (
    tester,
  ) async {
    final loop = _ManualGameLoop();
    final player = _WidgetBgmPlayer()
      ..playError = StateError('autoplay rejected');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          bgmPlayerProvider.overrideWithValue(player),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await _advanceToPlaying(tester, loop);

    expect(find.byKey(const ValueKey('bgm-retry')), findsOneWidget);
    expect(player.calls.where((call) => call == 'playFromStart'), hasLength(1));

    player.playError = null;
    await tester.tap(find.byKey(const ValueKey('bgm-retry')));
    await tester.pump();
    await tester.pump();

    expect(player.calls.where((call) => call == 'playFromStart'), hasLength(2));
  });

  testWidgets('BGM notice does not block an island behind its message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loop = _ManualGameLoop();
    final player = _WidgetBgmPlayer()
      ..playError = StateError('autoplay rejected');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(0)),
          bgmPlayerProvider.overrideWithValue(player),
        ],
        child: const MyApp(locale: Locale('ja')),
      ),
    );
    await openMatchSetup(tester);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await _advanceToPlaying(tester, loop);

    final noticeRect = tester.getRect(
      find.byKey(const ValueKey('bgm-unavailable-notice')),
    );
    final headquartersRect = tester.getRect(
      find.byKey(const ValueKey('island-button-0')),
    );
    final retryRect = tester.getRect(find.byKey(const ValueKey('bgm-retry')));
    final overlap = noticeRect.intersect(headquartersRect);
    expect(overlap.width, greaterThan(0));
    expect(overlap.height, greaterThan(0));
    final reserved = IslandMapViewport.reference.topRightControlExclusion;
    expect(retryRect.left, greaterThanOrEqualTo(reserved.left));
    expect(retryRect.top, greaterThanOrEqualTo(reserved.top));
    expect(retryRect.right, lessThanOrEqualTo(reserved.right));
    expect(retryRect.bottom, lessThanOrEqualTo(reserved.bottom));
    expect(retryRect.intersect(headquartersRect).isEmpty, isTrue);

    Offset? tapPoint;
    for (var x = overlap.left + 2; x < overlap.right; x += 4) {
      for (var y = overlap.top + 2; y < overlap.bottom; y += 4) {
        final candidate = Offset(x, y);
        if (!retryRect.contains(candidate)) {
          tapPoint = candidate;
          break;
        }
      }
      if (tapPoint != null) break;
    }
    expect(tapPoint, isNotNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-button-0'))),
    );
    await tester.tapAt(tapPoint!);
    await tester.pump();
    expect(container.read(gameControllerProvider).selectedIslandId, 0);
  });
}
