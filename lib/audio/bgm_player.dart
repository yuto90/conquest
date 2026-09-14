import 'package:audioplayers/audioplayers.dart';

/// The single in-game music track.  The actual file is supplied only by an
/// approved build input; it is intentionally not checked into this public
/// repository.
const battleBgmAssetPath = 'audio/tense_tactics.mp3';

/// The application-level music volume.  This changes the player amplitude only
/// and never changes the device volume.
const battleBgmVolume = 0.35;

/// Small audio boundary used by the battle BGM controller.
///
/// Keeping the plugin out of the controller makes phase and lifecycle tests
/// deterministic and leaves the player implementation replaceable.
abstract interface class BgmPlayer {
  Future<void> prepare();

  Future<void> playFromStart();

  Future<void> pause();

  Future<void> resume();

  Future<void> stopAndReset();

  Future<void> dispose();
}

/// [BgmPlayer] backed by audioplayers' normal media player mode.
final class AudioPlayersBgmPlayer implements BgmPlayer {
  AudioPlayersBgmPlayer({
    AudioPlayer? player,
    this.assetPath = battleBgmAssetPath,
    this.volume = battleBgmVolume,
  }) : _player = player;

  AudioPlayer? _player;
  final String assetPath;
  final double volume;

  Future<void>? _preparing;
  var _sourcePrepared = false;
  var _disposed = false;

  @override
  Future<void> prepare() {
    _throwIfDisposed();
    if (_sourcePrepared) return Future<void>.value();
    return _preparing ??= _prepareSource();
  }

  Future<void> _prepareSource() async {
    try {
      _throwIfDisposed();
      final player = _player ??= AudioPlayer();
      // Ambient is deliberately used on iOS so the Ring/Silent switch is
      // respected.  stayAwake remains false: this game does not support
      // background or locked-screen playback.
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: false,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volume);
      await player.setSource(AssetSource(assetPath));
      _throwIfDisposed();
      _sourcePrepared = true;
    } finally {
      _preparing = null;
    }
  }

  @override
  Future<void> playFromStart() async {
    _throwIfDisposed();
    await prepare();
    _throwIfDisposed();
    await _player!.seek(Duration.zero);
    _throwIfDisposed();
    await _player!.resume();
  }

  @override
  Future<void> pause() async {
    _throwIfDisposed();
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    _throwIfDisposed();
    await _player?.resume();
  }

  @override
  Future<void> stopAndReset() async {
    _throwIfDisposed();
    final player = _player;
    if (player == null) return;
    await player.stop();
    if (_sourcePrepared) {
      await player.seek(Duration.zero);
    }
    _sourcePrepared = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sourcePrepared = false;
    await _player?.dispose();
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('BgmPlayer has been disposed');
    }
  }
}
