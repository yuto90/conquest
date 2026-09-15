import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The single in-game music track.  The actual file is supplied only by an
/// approved build input; it is intentionally not checked into this public
/// repository.
const battleBgmAssetPath = 'audio/tense_tactics.mp3';

/// The application-level music volume.  This changes the player amplitude only
/// and never changes the device volume.
const battleBgmVolume = 0.35;

/// Small adapter around the concrete audioplayers object.
///
/// Keeping this seam separate from [BgmPlayer] lets platform lifecycle
/// behavior be tested without constructing a native or browser player.
abstract interface class BgmAudioPlayer {
  Future<void> setAudioContext(AudioContext context);

  Future<void> setReleaseMode(ReleaseMode mode);

  Future<void> setVolume(double volume);

  Future<void> setSource(String assetPath);

  Future<void> resume();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<Duration?> getCurrentPosition();

  Future<void> dispose();
}

/// Coordinates the pause/resume details that differ between audio platforms.
abstract interface class BgmAudioFocusController {
  Future<void> pause(BgmAudioPlayer player);

  Future<void> resume(BgmAudioPlayer player);
}

/// Android's audioplayers adapter abandons focus from its `stop` operation,
/// while `pause` intentionally keeps focus.  Save the position, use the
/// loop-mode stop to trigger the dependency's focus release, and restore the
/// position before the next resume requests focus again.
final class AndroidBgmAudioFocusController implements BgmAudioFocusController {
  const AndroidBgmAudioFocusController();

  @override
  Future<void> pause(BgmAudioPlayer player) async {
    await player.pause();
    Duration? position;
    try {
      position = await player.getCurrentPosition();
    } finally {
      await player.stop();
    }
    if (position != null) await player.seek(position);
  }

  @override
  Future<void> resume(BgmAudioPlayer player) => player.resume();
}

final class _NoopBgmAudioFocusController implements BgmAudioFocusController {
  const _NoopBgmAudioFocusController();

  @override
  Future<void> pause(BgmAudioPlayer player) => player.pause();

  @override
  Future<void> resume(BgmAudioPlayer player) => player.resume();
}

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
    BgmAudioPlayer? player,
    this.assetPath = battleBgmAssetPath,
    this.volume = battleBgmVolume,
    BgmAudioFocusController? audioFocusController,
    TargetPlatform? targetPlatform,
  }) : _player = player,
       _audioFocusController =
           audioFocusController ?? _defaultAudioFocusController(targetPlatform);

  BgmAudioPlayer? _player;
  final BgmAudioFocusController _audioFocusController;
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
      final player = _player ??= _AudioPlayerBgmAudioPlayer(AudioPlayer());
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
      await player.setSource(assetPath);
      _throwIfDisposed();
      _sourcePrepared = true;
    } finally {
      _preparing = null;
    }
  }

  @override
  Future<void> playFromStart() {
    _throwIfDisposed();
    final player = _player;
    if (player != null && _sourcePrepared) {
      // A prepared source starts at zero.  In particular, do not await a
      // seek here: on the web the seek-complete event can outlive the user
      // gesture that is retrying a rejected play request.
      return _audioFocusController.resume(player);
    }
    return _prepareAndPlayFromStart();
  }

  Future<void> _prepareAndPlayFromStart() async {
    await prepare();
    _throwIfDisposed();
    final player = _player;
    if (player == null || !_sourcePrepared) {
      throw StateError('BgmPlayer source was not prepared');
    }
    await _audioFocusController.resume(player);
  }

  @override
  Future<void> pause() async {
    _throwIfDisposed();
    final player = _player;
    if (player == null) return;
    await _audioFocusController.pause(player);
  }

  @override
  Future<void> resume() async {
    _throwIfDisposed();
    final player = _player;
    if (player == null) return;
    await _audioFocusController.resume(player);
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

  static BgmAudioFocusController _defaultAudioFocusController(
    TargetPlatform? targetPlatform,
  ) {
    if (!kIsWeb &&
        (targetPlatform ?? defaultTargetPlatform) == TargetPlatform.android) {
      return const AndroidBgmAudioFocusController();
    }
    return const _NoopBgmAudioFocusController();
  }
}

final class _AudioPlayerBgmAudioPlayer implements BgmAudioPlayer {
  _AudioPlayerBgmAudioPlayer(this._player);

  final AudioPlayer _player;

  @override
  Future<void> setAudioContext(AudioContext context) =>
      _player.setAudioContext(context);

  @override
  Future<void> setReleaseMode(ReleaseMode mode) => _player.setReleaseMode(mode);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSource(String assetPath) =>
      _player.setSource(AssetSource(assetPath));

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<Duration?> getCurrentPosition() => _player.getCurrentPosition();

  @override
  Future<void> dispose() => _player.dispose();
}
