import 'dart:async';

import 'package:conquest/audio/battle_bgm_controller.dart';
import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeBgmPlayer implements BgmPlayer {
  final List<String> calls = <String>[];
  Completer<void>? prepareGate;
  Completer<void>? playGate;
  Object? prepareError;
  Object? playError;
  var disposeCount = 0;

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    final gate = prepareGate;
    if (gate != null) await gate.future;
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
  Future<void> dispose() async {
    calls.add('dispose');
    disposeCount++;
  }
}

void main() {
  test(
    'plays once per phase and resumes the same match from its position',
    () async {
      final player = FakeBgmPlayer();
      final controller = BattleBgmController(player: player);

      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;
      expect(player.calls, ['prepare']);

      controller.handlePhase(GamePhase.playing);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart']);

      controller.handlePhase(GamePhase.paused);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      controller.handlePhase(GamePhase.resumeCountdown);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

      await controller.dispose();
    },
  );

  test('pausing during the initial countdown never starts the track', () async {
    final player = FakeBgmPlayer()..prepareGate = Completer<void>();
    final controller = BattleBgmController(player: player);

    controller.handlePhase(GamePhase.startCountdown);
    await Future<void>.delayed(Duration.zero);
    controller.handlePhase(GamePhase.paused);
    player.prepareGate!.complete();
    await controller.settled;

    expect(player.calls, ['prepare']);
    controller.handlePhase(GamePhase.resumeCountdown);
    controller.handlePhase(GamePhase.playing);
    await controller.settled;
    expect(player.calls, ['prepare', 'playFromStart']);

    await controller.dispose();
  });

  test(
    'a replay resets the old match before playing from the beginning',
    () async {
      final player = FakeBgmPlayer();
      final controller = BattleBgmController(player: player);

      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      controller.handlePhase(GamePhase.result);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'stopAndReset']);

      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(player.calls, [
        'prepare',
        'playFromStart',
        'stopAndReset',
        'prepare',
        'playFromStart',
      ]);

      await controller.dispose();
    },
  );

  test('OFF pauses and ON resumes only while playing', () async {
    final player = FakeBgmPlayer();
    final controller = BattleBgmController(player: player);

    controller.handlePhase(GamePhase.startCountdown);
    controller.handlePhase(GamePhase.playing);
    await controller.settled;

    controller.setEnabled(false);
    await controller.settled;
    expect(player.calls, ['prepare', 'playFromStart', 'pause']);

    controller.handlePhase(GamePhase.paused);
    controller.setEnabled(true);
    await controller.settled;
    expect(player.calls, ['prepare', 'playFromStart', 'pause']);

    controller.handlePhase(GamePhase.resumeCountdown);
    controller.handlePhase(GamePhase.playing);
    await controller.settled;
    expect(player.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

    await controller.dispose();
  });

  test(
    'visibility return does not resume until the game is explicitly resumed',
    () async {
      final player = FakeBgmPlayer();
      final controller = BattleBgmController(player: player);

      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      controller.setAppVisible(false);
      await controller.settled;
      controller.setAppVisible(true);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      controller.handlePhase(GamePhase.paused);
      controller.handlePhase(GamePhase.resumeCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;
      expect(player.calls, ['prepare', 'playFromStart', 'pause', 'resume']);

      await controller.dispose();
    },
  );

  test('failed playback is contained and can be retried explicitly', () async {
    final player = FakeBgmPlayer()..prepareError = StateError('missing asset');
    final controller = BattleBgmController(player: player);

    controller.handlePhase(GamePhase.startCountdown);
    await controller.settled;
    controller.handlePhase(GamePhase.playing);
    await controller.settled;

    expect(controller.canRetry, isTrue);
    expect(player.calls, ['prepare']);

    player.prepareError = null;
    controller.retry();
    await controller.settled;
    expect(player.calls, ['prepare', 'prepare', 'playFromStart']);

    await controller.dispose();
  });

  test(
    'failed playback is paused in case the native player already started',
    () async {
      final player = FakeBgmPlayer()..playError = StateError('play rejected');
      final controller = BattleBgmController(player: player);

      controller.handlePhase(GamePhase.startCountdown);
      controller.handlePhase(GamePhase.playing);
      await controller.settled;

      expect(controller.canRetry, isTrue);
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      await controller.dispose();
    },
  );

  test('stale preparation cannot play after finish and disposal', () async {
    final player = FakeBgmPlayer()..prepareGate = Completer<void>();
    final controller = BattleBgmController(player: player);

    controller.handlePhase(GamePhase.startCountdown);
    await Future<void>.delayed(Duration.zero);
    controller.handlePhase(GamePhase.playing);
    controller.handlePhase(GamePhase.result);
    final disposal = controller.dispose();
    player.prepareGate!.complete();
    await disposal;

    expect(player.calls.where((call) => call == 'playFromStart'), isEmpty);
    expect(player.disposeCount, 1);
  });

  test(
    'terminal phase invalidates pending playback before reporting it as playing',
    () async {
      final player = FakeBgmPlayer()..playGate = Completer<void>();
      final controller = BattleBgmController(player: player);
      final statuses = <BattleBgmStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;
      controller.handlePhase(GamePhase.playing);
      await Future<void>.delayed(Duration.zero);

      controller.handlePhase(GamePhase.result);
      player.playGate!.complete();
      await controller.settled;

      expect(statuses, isNot(contains(BattleBgmStatus.playing)));
      expect(controller.status, BattleBgmStatus.idle);
      expect(player.calls, [
        'prepare',
        'playFromStart',
        'pause',
        'stopAndReset',
      ]);

      await controller.dispose();
    },
  );

  test(
    'disabling BGM invalidates pending playback before reporting it as playing',
    () async {
      final player = FakeBgmPlayer()..playGate = Completer<void>();
      final controller = BattleBgmController(player: player);
      final statuses = <BattleBgmStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;
      controller.handlePhase(GamePhase.playing);
      await Future<void>.delayed(Duration.zero);

      controller.setEnabled(false);
      player.playGate!.complete();
      await controller.settled;

      expect(statuses, isNot(contains(BattleBgmStatus.playing)));
      expect(controller.status, BattleBgmStatus.paused);
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      await controller.dispose();
    },
  );

  test(
    'hidden app invalidates pending playback before reporting it as playing',
    () async {
      final player = FakeBgmPlayer()..playGate = Completer<void>();
      final controller = BattleBgmController(player: player);
      final statuses = <BattleBgmStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      controller.handlePhase(GamePhase.startCountdown);
      await controller.settled;
      controller.handlePhase(GamePhase.playing);
      await Future<void>.delayed(Duration.zero);

      controller.setAppVisible(false);
      player.playGate!.complete();
      await controller.settled;

      expect(statuses, isNot(contains(BattleBgmStatus.playing)));
      expect(controller.status, BattleBgmStatus.paused);
      expect(player.calls, ['prepare', 'playFromStart', 'pause']);

      await controller.dispose();
    },
  );
}
