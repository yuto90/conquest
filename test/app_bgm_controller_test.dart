import 'dart:async';

import 'package:conquest/audio/app_bgm_controller.dart';
import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBgmPlayer implements BgmPlayer {
  final List<String> calls = <String>[];
  Completer<void>? playGate;
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
    final gate = playGate;
    if (gate != null) await gate.future;
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

void main() {
  test('title and configuration share the menu track position', () async {
    final menu = _FakeBgmPlayer();
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.title);
    await controller.settled;
    controller.handleSurface(AppBgmSurface.game);
    await controller.settled;

    expect(menu.calls, ['prepare', 'playFromStart']);
    expect(battle.calls, isEmpty);

    await controller.dispose();
  });

  test('starting a match stops menu music before battle music', () async {
    final menu = _FakeBgmPlayer();
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.game);
    await controller.settled;
    controller.handlePhase(GamePhase.startCountdown);
    await controller.settled;

    expect(menu.calls, ['prepare', 'playFromStart', 'stopAndReset']);
    expect(battle.calls, ['prepare']);

    controller.handlePhase(GamePhase.playing);
    await controller.settled;
    expect(battle.calls, ['prepare', 'playFromStart']);

    await controller.dispose();
  });

  test(
    'result then configuration starts menu music from the beginning',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.game);
      await controller.settled;
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      controller.handlePhase(GamePhase.result);
      await controller.settled;
      controller.handlePhase(GamePhase.configuration);
      await controller.settled;

      expect(menu.calls, [
        'prepare',
        'playFromStart',
        'stopAndReset',
        'prepare',
        'playFromStart',
      ]);
      expect(battle.calls, ['prepare', 'playFromStart', 'stopAndReset']);

      await controller.dispose();
    },
  );

  test('battle pause and resume preserve the battle position', () async {
    final menu = _FakeBgmPlayer();
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.game);
    controller.handlePhase(GamePhase.startCountdown);
    controller.handlePhase(GamePhase.playing);
    await controller.settled;
    controller.handlePhase(GamePhase.paused);
    await controller.settled;
    controller.handlePhase(GamePhase.resumeCountdown);
    controller.handlePhase(GamePhase.playing);
    await controller.settled;

    expect(battle.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

    await controller.dispose();
  });

  test(
    'menu music resumes after visibility returns but battle waits for resume',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      controller.setAppVisible(false);
      await controller.settled;
      controller.setAppVisible(true);
      await controller.settled;
      expect(menu.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      controller.setAppVisible(false);
      await controller.settled;
      controller.setAppVisible(true);
      await controller.settled;
      expect(battle.calls, ['prepare', 'playFromStart', 'pause']);
      controller.handlePhase(GamePhase.resumeCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(battle.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

      await controller.dispose();
    },
  );

  test('a rejected menu playback is non-fatal and can be retried', () async {
    final menu = _FakeBgmPlayer()..prepareError = StateError('missing asset');
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.title);
    await controller.settled;
    expect(controller.canRetry, isTrue);
    expect(menu.calls, ['prepare']);

    menu.prepareError = null;
    controller.retry();
    await controller.settled;
    expect(menu.calls, ['prepare', 'prepare', 'playFromStart']);

    await controller.dispose();
  });

  test('stale playback is paused before a match can take ownership', () async {
    final menu = _FakeBgmPlayer()..playGate = Completer<void>();
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.title);
    await Future<void>.delayed(Duration.zero);
    controller.handleSurface(AppBgmSurface.game);
    controller.handlePhase(GamePhase.startCountdown);
    menu.playGate!.complete();
    await controller.settled;

    expect(menu.calls, ['prepare', 'playFromStart', 'pause', 'stopAndReset']);
    expect(battle.calls, ['prepare']);

    await controller.dispose();
  });
}
