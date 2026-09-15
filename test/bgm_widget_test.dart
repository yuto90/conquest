import 'dart:math';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_loop.dart';
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

  testWidgets('shows a temporary notice with a retry action', (tester) async {
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

    final notice = find.byKey(const ValueKey('bgm-unavailable-notice'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(
        of: notice,
        matching: find.byKey(const ValueKey('bgm-retry')),
      ),
      findsOneWidget,
    );
    expect(find.text('BGMを再生できません。音なしで対戦を続けます。'), findsOneWidget);
    expect(tester.getSemantics(notice).label, 'BGMを再生できません。音なしで対戦を続けます。');
    expect(
      tester.getSemantics(find.byKey(const ValueKey('bgm-retry'))).label,
      'BGMを再生',
    );

    await tester.pump(const Duration(milliseconds: 2999));
    expect(notice, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(notice, findsNothing);
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
    expect(find.byKey(const ValueKey('bgm-unavailable-notice')), findsNothing);
  });

  testWidgets('BGM notice is centered below the top controls on a phone', (
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
    final retryRect = tester.getRect(find.byKey(const ValueKey('bgm-retry')));
    final pauseRect = tester.getRect(find.byKey(const ValueKey('pause-game')));
    expect(noticeRect.left, greaterThanOrEqualTo(12));
    expect(noticeRect.right, lessThanOrEqualTo(390 - 12));
    expect(noticeRect.top, greaterThanOrEqualTo(pauseRect.bottom));
    expect(noticeRect.center.dx, closeTo(390 / 2, 1));
    expect(retryRect.top, greaterThanOrEqualTo(noticeRect.top));
    expect(retryRect.bottom, lessThanOrEqualTo(noticeRect.bottom));
    expect(retryRect.intersect(pauseRect).isEmpty, isTrue);
  });

  testWidgets('same BGM failure does not reset the notice timer on a tick', (
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

    final notice = find.byKey(const ValueKey('bgm-unavailable-notice'));
    await tester.pump(const Duration(milliseconds: 2500));
    loop.tick();
    await tester.pump();
    expect(notice, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(notice, findsNothing);
  });

  testWidgets('failed retry shows a fresh temporary notice', (tester) async {
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

    final notice = find.byKey(const ValueKey('bgm-unavailable-notice'));
    expect(notice, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.tap(find.byKey(const ValueKey('bgm-retry')));
    await tester.pump();
    await tester.pump();

    expect(player.calls.where((call) => call == 'playFromStart'), hasLength(2));
    expect(notice, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(notice, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(notice, findsNothing);
  });
}
