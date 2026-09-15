import 'package:audioplayers/audioplayers.dart';
import 'package:conquest/audio/bgm_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBgmAudioPlayer implements BgmAudioPlayer {
  final List<String> calls = <String>[];
  Duration currentPosition = const Duration(seconds: 12);
  double? volume;
  Object? resumeError;

  @override
  Future<void> setAudioContext(AudioContext context) async {
    calls.add('setAudioContext');
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    calls.add('setReleaseMode');
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume');
    this.volume = volume;
  }

  @override
  Future<void> setSource(String assetPath) async {
    calls.add('setSource:$assetPath');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    final error = resumeError;
    if (error != null) throw error;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    currentPosition = position;
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    calls.add('getCurrentPosition');
    return currentPosition;
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  test('menu player uses the supplied menu asset and volume', () async {
    final audio = _FakeBgmAudioPlayer();
    final player = AudioPlayersBgmPlayer(
      player: audio,
      assetPath: menuBgmAssetPath,
      volume: menuBgmVolume,
      targetPlatform: TargetPlatform.iOS,
    );

    await player.prepare();

    expect(audio.calls, contains('setSource:audio/metropolis_destruction.mp3'));
    expect(audio.volume, menuBgmVolume);
    await player.dispose();
  });

  test(
    'prepared playback retries with resume without waiting for a seek',
    () async {
      final audio = _FakeBgmAudioPlayer();
      final player = AudioPlayersBgmPlayer(
        player: audio,
        targetPlatform: TargetPlatform.iOS,
      );
      await player.prepare();

      audio.resumeError = StateError('autoplay rejected');
      await expectLater(player.playFromStart(), throwsStateError);

      audio.resumeError = null;
      await player.playFromStart();

      expect(audio.calls.where((call) => call == 'resume'), hasLength(2));
      expect(audio.calls.where((call) => call.startsWith('seek:')), isEmpty);

      await player.dispose();
    },
  );

  test(
    'Android focus seam releases and reacquires focus without losing position',
    () async {
      final audio = _FakeBgmAudioPlayer();
      final player = AudioPlayersBgmPlayer(
        player: audio,
        targetPlatform: TargetPlatform.android,
      );
      await player.prepare();
      await player.playFromStart();

      audio.currentPosition = const Duration(milliseconds: 1234);
      await player.pause();
      await player.resume();

      expect(audio.calls.sublist(4), [
        'resume',
        'pause',
        'getCurrentPosition',
        'stop',
        'seek:1234',
        'resume',
      ]);

      await player.dispose();
    },
  );
}
