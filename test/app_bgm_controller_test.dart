import 'dart:async';

import 'package:conquest/audio/app_bgm_controller.dart';
import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBgmPlayer implements BgmPlayer {
  final List<String> calls = <String>[];
  Completer<void>? playGate;
  Completer<void>? pauseGate;
  final List<Object?> playErrors = <Object?>[];
  final List<Object?> stopErrors = <Object?>[];
  Object? prepareError;
  Object? playError;
  Object? pauseError;
  Object? stopAndResetError;

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
    if (playErrors.isNotEmpty) {
      final error = playErrors.removeAt(0);
      if (error != null) throw error;
    }
    final error = playError;
    if (error != null) throw error;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    final gate = pauseGate;
    if (gate != null) await gate.future;
    final error = pauseError;
    if (error != null) throw error;
  }

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stopAndReset() async {
    calls.add('stopAndReset');
    if (stopErrors.isNotEmpty) {
      final error = stopErrors.removeAt(0);
      if (error != null) throw error;
    }
    final error = stopAndResetError;
    if (error != null) throw error;
  }

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
    'stop failure with a working pause fallback still allows battle music',
    () async {
      final menu = _FakeBgmPlayer()
        ..stopAndResetError = StateError('stop failed');
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;

      expect(menu.calls, ['prepare', 'playFromStart', 'stopAndReset', 'pause']);
      expect(battle.calls, ['prepare']);
      expect(controller.activeTrack, AppBgmTrack.battle);

      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(battle.calls, ['prepare', 'playFromStart']);

      await controller.dispose();
    },
  );

  test(
    'a fallback-pause track is hard-reset before it owns music again',
    () async {
      final menu = _FakeBgmPlayer()
        ..stopErrors.addAll([StateError('stop failed during handoff'), null]);
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(battle.calls, ['prepare', 'playFromStart']);

      controller.handlePhase(GamePhase.result);
      await controller.settled;
      controller.handlePhase(GamePhase.configuration);
      await controller.settled;

      expect(menu.calls.where((call) => call == 'stopAndReset'), hasLength(2));
      expect(menu.calls.last, 'playFromStart');
      expect(menu.calls, isNot(contains('resume')));

      await controller.dispose();
    },
  );

  test('stop and pause failure blocks incoming battle ownership', () async {
    final menu = _FakeBgmPlayer()
      ..stopAndResetError = StateError('stop failed')
      ..pauseError = StateError('pause failed');
    final battle = _FakeBgmPlayer();
    final errors = <Object>[];
    final controller = AppBgmController(
      menuPlayer: menu,
      battlePlayer: battle,
      onError: (error, _) => errors.add(error),
    );

    controller.handleSurface(AppBgmSurface.title);
    await controller.settled;
    controller.handleSurface(AppBgmSurface.game);
    controller.handlePhase(GamePhase.startCountdown);
    await controller.settled;

    expect(menu.calls.take(4), [
      'prepare',
      'playFromStart',
      'stopAndReset',
      'pause',
    ]);
    expect(battle.calls, isEmpty);
    expect(controller.activeTrack, AppBgmTrack.menu);
    expect(controller.canRetry, isTrue);
    expect(controller.lastError, isNotNull);
    expect(errors.length, greaterThanOrEqualTo(2));

    await controller.dispose();
  });

  test('menu OFF retries cleanup after pause and stop both fail', () async {
    final menu = _FakeBgmPlayer()
      ..pauseError = StateError('pause failed')
      ..stopAndResetError = StateError('stop failed');
    final battle = _FakeBgmPlayer();
    final controller = AppBgmController(menuPlayer: menu, battlePlayer: battle);

    controller.handleSurface(AppBgmSurface.title);
    await controller.settled;
    controller.setEnabled(false);
    await controller.settled;

    expect(menu.calls, ['prepare', 'playFromStart', 'pause', 'stopAndReset']);
    expect(controller.isPlaying, isTrue);
    expect(controller.canRetry, isTrue);

    menu.pauseError = null;
    menu.stopAndResetError = null;
    controller.retry();
    await controller.settled;

    expect(menu.calls, [
      'prepare',
      'playFromStart',
      'pause',
      'stopAndReset',
      'stopAndReset',
    ]);
    expect(controller.isPlaying, isFalse);
    expect(controller.lastError, isNull);
    expect(controller.canRetry, isFalse);

    await controller.dispose();
  });

  test(
    'hidden pause failure is retryable again after visibility returns',
    () async {
      final menu = _FakeBgmPlayer()
        ..pauseError = StateError('pause failed')
        ..stopAndResetError = StateError('stop failed');
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      controller.setAppVisible(false);
      await controller.settled;

      expect(menu.calls, ['prepare', 'playFromStart', 'pause', 'stopAndReset']);
      expect(controller.isPlaying, isTrue);
      expect(controller.canRetry, isFalse);

      controller.setAppVisible(true);
      await controller.settled;
      expect(controller.canRetry, isTrue);

      menu.pauseError = null;
      menu.stopAndResetError = null;
      controller.retry();
      await controller.settled;

      expect(menu.calls.where((call) => call == 'stopAndReset'), hasLength(3));
      expect(menu.calls.sublist(menu.calls.length - 2), [
        'prepare',
        'playFromStart',
      ]);
      expect(controller.isPlaying, isTrue);
      expect(controller.lastError, isNull);
      expect(controller.canRetry, isFalse);

      await controller.dispose();
    },
  );

  test(
    'battle paused pause failure uses stop fallback before resuming',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer()..pauseError = StateError('pause failed');
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      controller.handlePhase(GamePhase.paused);
      await controller.settled;

      expect(battle.calls, [
        'prepare',
        'playFromStart',
        'pause',
        'stopAndReset',
      ]);
      expect(controller.isPlaying, isFalse);
      expect(controller.canRetry, isFalse);

      battle.pauseError = null;
      controller.handlePhase(GamePhase.resumeCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;

      expect(battle.calls, [
        'prepare',
        'playFromStart',
        'pause',
        'stopAndReset',
        'prepare',
        'playFromStart',
      ]);
      expect(controller.isPlaying, isTrue);

      await controller.dispose();
    },
  );

  test(
    'a failed result handoff remains retryable until battle music stops',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;

      battle.stopAndResetError = StateError('result stop failed');
      battle.pauseError = StateError('result pause failed');
      controller.handlePhase(GamePhase.result);
      await controller.settled;

      expect(controller.activeTrack, AppBgmTrack.battle);
      expect(controller.lastError, isNotNull);
      expect(controller.canRetry, isTrue);

      battle.stopAndResetError = null;
      battle.pauseError = null;
      controller.retry();
      await controller.settled;

      expect(battle.calls, [
        'prepare',
        'playFromStart',
        'stopAndReset',
        'pause',
        'stopAndReset',
      ]);
      expect(controller.activeTrack, AppBgmTrack.none);
      expect(controller.lastError, isNull);
      expect(controller.canRetry, isFalse);

      await controller.dispose();
    },
  );

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

  test(
    'stale pause rejection does not block the current menu resume',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      menu.pauseGate = Completer<void>();
      menu.pauseError = StateError('stale pause rejection');

      controller.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(menu.calls, ['prepare', 'playFromStart', 'pause']);

      controller.setEnabled(true);
      menu.pauseGate!.complete();
      await controller.settled;

      expect(menu.calls, ['prepare', 'playFromStart', 'pause', 'resume']);
      expect(controller.canRetry, isFalse);
      expect(controller.lastError, isNull);

      await controller.dispose();
    },
  );

  test(
    'stale pause rejection keeps a newer non-play request stoppable',
    () async {
      final menu = _FakeBgmPlayer();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      menu.pauseGate = Completer<void>();
      menu.pauseError = StateError('stale pause rejection');

      controller.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(menu.calls, ['prepare', 'playFromStart', 'pause']);

      // A newer non-play request must not trust the pending pause's result.
      controller.handlePhase(GamePhase.configuration);
      menu.pauseGate!.complete();
      await controller.settled;

      expect(menu.calls, [
        'prepare',
        'playFromStart',
        'pause',
        'pause',
        'stopAndReset',
      ]);
      expect(controller.isPlaying, isFalse);
      expect(controller.lastError, isNull);

      await controller.dispose();
    },
  );

  test(
    'stale play cleanup failure remains retryable while BGM is OFF',
    () async {
      final menu = _FakeBgmPlayer()..playGate = Completer<void>();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await Future<void>.delayed(Duration.zero);
      controller.setEnabled(false);
      menu.pauseError = StateError('stale cleanup pause failed');
      menu.stopAndResetError = StateError('stale cleanup stop failed');
      menu.playGate!.complete();
      await controller.settled;

      final firstPause = menu.calls.indexOf('pause');
      expect(firstPause, greaterThanOrEqualTo(0));
      expect(menu.calls[firstPause + 1], 'stopAndReset');
      expect(controller.isPlaying, isTrue);
      expect(controller.canRetry, isTrue);

      final stopCountBeforeRetry = menu.calls
          .where((call) => call == 'stopAndReset')
          .length;
      menu.pauseError = null;
      menu.stopAndResetError = null;
      controller.retry();
      await controller.settled;

      expect(
        menu.calls.where((call) => call == 'stopAndReset'),
        hasLength(stopCountBeforeRetry + 1),
      );
      expect(controller.isPlaying, isFalse);
      expect(controller.lastError, isNull);
      expect(controller.canRetry, isFalse);

      await controller.dispose();
    },
  );

  test(
    'stale play cleanup failure is retryable after hidden app returns',
    () async {
      final menu = _FakeBgmPlayer()..playGate = Completer<void>();
      final battle = _FakeBgmPlayer();
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await Future<void>.delayed(Duration.zero);
      controller.setAppVisible(false);
      menu.pauseError = StateError('stale cleanup pause failed');
      menu.stopAndResetError = StateError('stale cleanup stop failed');
      menu.playGate!.complete();
      await controller.settled;

      expect(menu.calls, containsAllInOrder(['pause', 'stopAndReset']));
      expect(controller.isPlaying, isTrue);
      expect(controller.canRetry, isFalse);

      controller.setAppVisible(true);
      await controller.settled;
      expect(controller.canRetry, isTrue);

      final stopCountBeforeRetry = menu.calls
          .where((call) => call == 'stopAndReset')
          .length;
      menu.pauseError = null;
      menu.stopAndResetError = null;
      controller.retry();
      await controller.settled;

      expect(
        menu.calls.where((call) => call == 'stopAndReset'),
        hasLength(stopCountBeforeRetry + 1),
      );
      expect(controller.isPlaying, isTrue);
      expect(controller.lastError, isNull);
      expect(controller.canRetry, isFalse);

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

  test(
    'failure serial stays monotonic when the failed track changes',
    () async {
      final menu = _FakeBgmPlayer()
        ..prepareError = StateError('missing menu asset');
      final battle = _FakeBgmPlayer()..playError = StateError('missing battle');
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
      );

      controller.handleSurface(AppBgmSurface.title);
      await controller.settled;
      expect(controller.failureSerial, 1);

      controller.handleSurface(AppBgmSurface.game);
      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;

      expect(controller.failureSerial, 2);
      expect(controller.canRetry, isTrue);

      await controller.dispose();
    },
  );

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

  test(
    'stale menu rejection does not block the current menu reconciliation',
    () async {
      final menu = _FakeBgmPlayer()
        ..playGate = Completer<void>()
        ..playErrors.add(StateError('stale autoplay rejection'))
        ..playErrors.add(null);
      final battle = _FakeBgmPlayer();
      final errors = <Object>[];
      final controller = AppBgmController(
        menuPlayer: menu,
        battlePlayer: battle,
        onError: (error, _) => errors.add(error),
      );

      controller.handleSurface(AppBgmSurface.title);
      await Future<void>.delayed(Duration.zero);
      controller.handleSurface(AppBgmSurface.game);
      menu.playGate!.complete();
      await controller.settled;

      expect(menu.calls, [
        'prepare',
        'playFromStart',
        'pause',
        'playFromStart',
      ]);
      expect(controller.canRetry, isFalse);
      expect(controller.lastError, isNull);
      expect(errors, hasLength(1));

      await controller.dispose();
    },
  );
}
