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

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    final error = prepareError;
    if (error != null) throw error;
  }

  @override
  Future<void> playFromStart() async => calls.add('playFromStart');

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
}
