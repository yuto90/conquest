import 'dart:async';
import 'dart:developer' as developer;

import '../game/game_state.dart';
import 'bgm_player.dart';

enum BattleBgmStatus { idle, preparing, paused, playing, unavailable, disposed }

typedef BgmErrorReporter = void Function(Object error, StackTrace stackTrace);

/// Coordinates one match's music with the game phase without becoming part of
/// the game model or its tick loop.
final class BattleBgmController {
  BattleBgmController({required BgmPlayer player, BgmErrorReporter? onError})
    : _player = player,
      _onError = onError ?? _defaultErrorReporter;

  final BgmPlayer _player;
  final BgmErrorReporter _onError;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  Future<void> _operationTail = Future<void>.value();
  GamePhase _phase = GamePhase.configuration;
  BattleBgmStatus _status = BattleBgmStatus.idle;
  Object? _lastError;
  StackTrace? _lastErrorStackTrace;
  var _enabled = true;
  var _appVisible = true;
  var _visibilityPauseNeedsExplicitPhaseChange = false;
  var _disposed = false;
  var _sourcePrepared = false;
  var _preparePending = false;
  var _playPending = false;
  var _pausePending = false;
  var _isPlaying = false;
  var _hasPlayedThisMatch = false;
  var _resetPending = false;
  var _matchSerial = 0;
  var _playRequestSerial = 0;
  var _failureSerial = 0;

  BattleBgmStatus get status => _status;

  bool get isEnabled => _enabled;

  bool get isPlaying => _isPlaying;

  bool get canRetry =>
      !_disposed &&
      _enabled &&
      _appVisible &&
      _phase == GamePhase.playing &&
      _lastError != null;

  Object? get lastError => _lastError;

  /// Identifies each new failure without exposing the error object to the UI.
  /// Repeated notifications for the same unavailable state keep this value.
  int get failureSerial => _failureSerial;

  /// Completes after all currently queued player calls have settled.  It is
  /// useful to deterministic tests and does not form part of game timing.
  Future<void> get settled async {
    // An operation may enqueue its next phase reconciliation in its own
    // finally block. Follow the tail until no newer operation was appended.
    while (true) {
      final tail = _operationTail;
      await tail;
      if (identical(tail, _operationTail)) return;
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Delivers the latest phase. Repeated notifications of the same phase are
  /// harmless and do not issue another play/resume call.
  void handlePhase(GamePhase phase) {
    if (_disposed) return;
    final wasReadyToPlay = _shouldPlay;
    final previous = _phase;
    _phase = phase;

    if ((phase == GamePhase.configuration || phase == GamePhase.result) &&
        previous != phase) {
      // A terminal phase invalidates any platform call that is still waiting
      // to complete. It may still need to be paused/reset after completion,
      // but it must not publish a stale playing state for the next screen.
      _matchSerial++;
    }

    if (phase == GamePhase.startCountdown &&
        previous != GamePhase.startCountdown &&
        previous != GamePhase.resumeCountdown) {
      _beginNewMatch();
    } else if (phase == GamePhase.resumeCountdown) {
      // Resuming is an explicit user action. It may retry a failed preparation,
      // but it must not move the current playback position.
      _clearError();
    } else if (phase == GamePhase.playing && previous != GamePhase.playing) {
      _clearErrorIfExplicitResumeWasRequested(previous);
      if (_appVisible) _visibilityPauseNeedsExplicitPhaseChange = false;
    }

    if (phase == GamePhase.configuration || phase == GamePhase.result) {
      _stopAndReset();
    } else {
      _reconcile();
    }
    _invalidateStalePlayRequest(wasReadyToPlay);
  }

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    final wasReadyToPlay = _shouldPlay;
    _enabled = enabled;
    if (!enabled) {
      _reconcile();
    } else {
      // Turning music on is an explicit retry opportunity when the match is
      // already playing. It still never starts during a countdown or pause.
      _clearError();
      _reconcile();
    }
    _invalidateStalePlayRequest(wasReadyToPlay);
    _notifyListeners();
  }

  void setAppVisible(bool visible) {
    if (_disposed || _appVisible == visible) return;
    final wasReadyToPlay = _shouldPlay;
    _appVisible = visible;
    if (!visible) {
      _visibilityPauseNeedsExplicitPhaseChange = true;
    }
    _reconcile();
    _invalidateStalePlayRequest(wasReadyToPlay);
  }

  /// Retries the current failed request using this same player instance. The
  /// game remains playable when this is never called.
  void retry() {
    if (!canRetry) return;
    _clearError();
    _reconcile();
  }

  /// Stops the player, resets any loaded position, then releases the plugin
  /// player. Pending queued work is invalidated by the disposed flag.
  Future<void> dispose() async {
    if (_disposed) {
      await settled;
      return;
    }
    _disposed = true;
    _status = BattleBgmStatus.disposed;
    _notifyListeners();
    _enqueue(() async {
      try {
        if (_sourcePrepared || _isPlaying) {
          await _player.stopAndReset();
        }
      } finally {
        await _player.dispose();
      }
    });
    await settled;
  }

  bool get _shouldPrepare =>
      !_disposed &&
      !_resetPending &&
      (_phase == GamePhase.startCountdown ||
          _phase == GamePhase.resumeCountdown ||
          _phase == GamePhase.playing);

  bool get _shouldPlay =>
      _shouldPrepare &&
      _enabled &&
      _appVisible &&
      !_visibilityPauseNeedsExplicitPhaseChange &&
      _phase == GamePhase.playing &&
      _lastError == null;

  void _beginNewMatch() {
    _matchSerial++;
    // An older queued operation belongs to the previous match. Its callback
    // will still settle in order, but it must not keep a pending flag set for
    // the new match.
    _stopAndReset();
    _preparePending = false;
    _playPending = false;
    _pausePending = false;
    _hasPlayedThisMatch = false;
    _sourcePrepared = false;
    _isPlaying = false;
    _clearError();
    _reconcile();
  }

  void _reconcile() {
    if (_disposed) return;

    if (_shouldPrepare &&
        !_sourcePrepared &&
        !_preparePending &&
        _lastError == null) {
      _queuePrepare(_matchSerial);
    }

    if (_shouldPlay &&
        _sourcePrepared &&
        !_isPlaying &&
        !_playPending &&
        !_pausePending) {
      _queuePlay(_matchSerial, resume: _hasPlayedThisMatch);
    } else if (!_shouldPlay && _isPlaying && !_pausePending) {
      _queuePause(_matchSerial);
    }
  }

  void _queuePrepare(int matchSerial) {
    _preparePending = true;
    _setStatus(BattleBgmStatus.preparing);
    _enqueue(() async {
      try {
        if (!_isCurrentMatch(matchSerial) || !_shouldPrepare) return;
        await _player.prepare();
        if (!_isCurrentMatch(matchSerial)) return;
        _sourcePrepared = true;
        if (!_shouldPlay) {
          _setStatus(BattleBgmStatus.paused);
        }
      } catch (error, stackTrace) {
        if (_isCurrentMatch(matchSerial)) {
          _recordError(error, stackTrace);
        }
      } finally {
        if (_isCurrentMatch(matchSerial)) {
          _preparePending = false;
          _reconcile();
        }
      }
    });
  }

  void _queuePlay(int matchSerial, {required bool resume}) {
    final playRequestSerial = _playRequestSerial;
    _playPending = true;
    _enqueue(() async {
      try {
        if (!_isCurrentPlayRequest(matchSerial, playRequestSerial) ||
            !_shouldPlay) {
          return;
        }
        if (resume) {
          await _player.resume();
        } else {
          await _player.playFromStart();
        }
        if (!_isCurrentPlayRequest(matchSerial, playRequestSerial) ||
            !_shouldPlay) {
          // A new match or disposal arrived while the platform call was
          // pending. Do not leave the old request playing.
          await _player.pause();
          return;
        }
        _hasPlayedThisMatch = true;
        _isPlaying = true;
        _setStatus(BattleBgmStatus.playing);
        if (!_shouldPlay) {
          await _player.pause();
          _isPlaying = false;
          _setStatus(BattleBgmStatus.paused);
        }
      } catch (error, stackTrace) {
        if (_isCurrentMatch(matchSerial)) {
          if (playRequestSerial == _playRequestSerial) {
            _recordError(error, stackTrace);
          } else {
            _reportError(error, stackTrace);
          }
          try {
            // A platform implementation may reject after it has already
            // started the native player. Ensure a failed request cannot leave
            // music playing while the UI reports it as unavailable.
            await _player.pause();
          } catch (pauseError, pauseStackTrace) {
            _reportError(pauseError, pauseStackTrace);
          }
        }
      } finally {
        if (_isCurrentMatch(matchSerial)) {
          _playPending = false;
          _reconcile();
        }
      }
    });
  }

  void _queuePause(int matchSerial) {
    _pausePending = true;
    _enqueue(() async {
      try {
        if (!_isCurrentMatch(matchSerial) || !_isPlaying) return;
        await _player.pause();
        if (_isCurrentMatch(matchSerial)) {
          _isPlaying = false;
          _setStatus(BattleBgmStatus.paused);
        }
      } catch (error, stackTrace) {
        if (_isCurrentMatch(matchSerial)) {
          _recordError(error, stackTrace);
        }
      } finally {
        if (_isCurrentMatch(matchSerial)) {
          _pausePending = false;
          _reconcile();
        }
      }
    });
  }

  void _stopAndReset() {
    if (_disposed || _resetPending) return;
    final shouldReset = _sourcePrepared || _isPlaying || _preparePending;
    _sourcePrepared = false;
    _isPlaying = false;
    _hasPlayedThisMatch = false;
    _lastError = null;
    _lastErrorStackTrace = null;
    if (!shouldReset) {
      _setStatus(BattleBgmStatus.idle);
      return;
    }
    _resetPending = true;
    _enqueue(() async {
      try {
        await _player.stopAndReset();
      } catch (error, stackTrace) {
        // A stop failure must not prevent a later dispose or a new match. It
        // is diagnostic only while the target phase is non-playable.
        _reportError(error, stackTrace);
      } finally {
        _sourcePrepared = false;
        _isPlaying = false;
        _hasPlayedThisMatch = false;
        _resetPending = false;
        if (!_disposed) {
          _setStatus(BattleBgmStatus.idle);
          _reconcile();
        }
      }
    });
  }

  bool _isCurrentMatch(int matchSerial) =>
      !_disposed && matchSerial == _matchSerial;

  bool _isCurrentPlayRequest(int matchSerial, int playRequestSerial) {
    return _isCurrentMatch(matchSerial) &&
        playRequestSerial == _playRequestSerial;
  }

  void _invalidateStalePlayRequest(bool wasReadyToPlay) {
    if (wasReadyToPlay && !_shouldPlay) {
      _playRequestSerial++;
    }
  }

  void _enqueue(Future<void> Function() operation) {
    _operationTail = _operationTail.then<void>((_) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        // Every player operation is contained here so a plugin rejection can
        // never become an unhandled Future in the game UI.
        if (!_disposed) _recordError(error, stackTrace);
      }
    });
  }

  void _recordError(Object error, StackTrace stackTrace) {
    if (_lastError == null && _lastErrorStackTrace == null) {
      _failureSerial++;
    }
    _lastError ??= error;
    _lastErrorStackTrace ??= stackTrace;
    _isPlaying = false;
    _setStatus(BattleBgmStatus.unavailable);
    _reportError(error, stackTrace);
  }

  void _reportError(Object error, StackTrace stackTrace) {
    try {
      _onError(error, stackTrace);
    } catch (_) {
      // Diagnostics must never affect game state.
    }
  }

  void _clearError() {
    if (_lastError == null && _lastErrorStackTrace == null) return;
    _lastError = null;
    _lastErrorStackTrace = null;
    if (!_disposed && _status == BattleBgmStatus.unavailable) {
      _setStatus(
        _sourcePrepared ? BattleBgmStatus.paused : BattleBgmStatus.idle,
      );
    }
  }

  void _clearErrorIfExplicitResumeWasRequested(GamePhase previous) {
    if (previous == GamePhase.resumeCountdown) _clearError();
  }

  void _setStatus(BattleBgmStatus status) {
    if (_status == status) return;
    _status = status;
    _notifyListeners();
  }

  void _notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      try {
        listener();
      } catch (_) {
        // A view listener must not break audio serialization.
      }
    }
  }

  static void _defaultErrorReporter(Object error, StackTrace stackTrace) {
    developer.log(
      'Battle BGM is unavailable',
      name: 'conquest.audio',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

typedef VoidCallback = void Function();
