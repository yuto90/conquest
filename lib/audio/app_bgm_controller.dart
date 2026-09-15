import 'dart:async';
import 'dart:developer' as developer;

import '../game/game_state.dart';
import 'bgm_player.dart';

/// The part of the application that currently owns the visible surface.
enum AppBgmSurface { title, game }

enum AppBgmTrack { none, menu, battle }

enum AppBgmStatus { idle, preparing, paused, playing, unavailable, disposed }

typedef AppBgmErrorReporter =
    void Function(Object error, StackTrace stackTrace);

final class AppBgmController {
  AppBgmController({
    required BgmPlayer menuPlayer,
    required BgmPlayer battlePlayer,
    AppBgmErrorReporter? onError,
  }) : _menuPlayer = menuPlayer,
       _battlePlayer = battlePlayer,
       _onError = onError ?? _defaultErrorReporter;

  final BgmPlayer _menuPlayer;
  final BgmPlayer _battlePlayer;
  final AppBgmErrorReporter _onError;
  final _TrackState _menu = _TrackState();
  final _TrackState _battle = _TrackState();
  final Set<void Function()> _listeners = <void Function()>{};

  Future<void> _operationTail = Future<void>.value();
  AppBgmSurface _surface = AppBgmSurface.title;
  GamePhase _phase = GamePhase.configuration;
  AppBgmTrack _activeTrack = AppBgmTrack.none;
  var _enabled = true;
  var _appVisible = true;
  var _battleVisibilityPauseNeedsExplicitPhaseChange = false;
  var _surfaceInitialized = false;
  var _menuNeedsReset = false;
  var _battleNeedsReset = false;
  var _syncQueued = false;
  var _syncRunning = false;
  var _syncRequested = false;
  var _disposed = false;
  var _requestSerial = 0;
  var _failureSerial = 0;
  Object? _transitionError;

  AppBgmTrack get activeTrack => _activeTrack;

  AppBgmStatus get status {
    if (_disposed) return AppBgmStatus.disposed;
    if (_transitionError != null) return AppBgmStatus.unavailable;
    final state = _stateFor(_desiredTrack);
    return state?.status ?? AppBgmStatus.idle;
  }

  bool get isEnabled => _enabled;

  bool get isPlaying => _stateFor(_desiredTrack)?.isPlaying ?? false;

  bool get canRetry {
    final target = _desiredTrack;
    final state = _stateFor(target);
    return !_disposed &&
        _enabled &&
        _appVisible &&
        (_transitionError != null ||
            (target != AppBgmTrack.none && state?.lastError != null));
  }

  Object? get lastError =>
      _transitionError ?? _stateFor(_desiredTrack)?.lastError;

  /// Identifies each newly reported failure across the application.
  ///
  /// The value is application-wide rather than track-local so a notice that
  /// remains mounted across a menu-to-battle transition still restarts when
  /// the next track fails.
  int get failureSerial => _failureSerial;

  /// Completes after all currently queued player calls and reconciliations have
  /// settled. It is intended for deterministic tests, not game timing.
  Future<void> get settled async {
    while (true) {
      final tail = _operationTail;
      await tail;
      if (identical(tail, _operationTail)) return;
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void handleSurface(AppBgmSurface surface) {
    if (_disposed) return;
    if (_surfaceInitialized && _surface == surface) return;
    _surfaceInitialized = true;
    _surface = surface;
    // Leaving the title is an explicit user gesture. It is a valid retry
    // opportunity for a menu autoplay request rejected on the first frame.
    if (_desiredTrack == AppBgmTrack.menu) _clearError(_menu);
    _requestSerial++;
    _scheduleSync();
  }

  void handlePhase(GamePhase phase) {
    if (_disposed) return;
    final previous = _phase;
    _phase = phase;
    _requestSerial++;

    if (phase != GamePhase.configuration && phase != GamePhase.result) {
      // A non-configuration phase is always rendered by the game surface. The
      // explicit surface signal is still used for title/configuration
      // navigation, but phase updates remain safe if they arrive first.
      _surfaceInitialized = true;
      _surface = AppBgmSurface.game;
    }

    if (phase == GamePhase.startCountdown &&
        previous != GamePhase.startCountdown &&
        previous != GamePhase.resumeCountdown) {
      _menuNeedsReset = true;
      _battleNeedsReset = true;
    } else if (phase == GamePhase.configuration && previous != phase) {
      // Returning from a result or an interrupted match starts the menu track
      // at its beginning. Title <-> configuration keeps the current position
      // because both surfaces are part of the same menu context.
      _menuNeedsReset = true;
    }

    if (phase == GamePhase.result) {
      _battleNeedsReset = true;
    }
    if (phase == GamePhase.resumeCountdown) {
      _clearError(_battle);
    } else if (phase == GamePhase.playing && previous != GamePhase.playing) {
      _clearErrorIfExplicitResumeWasRequested(previous);
      if (_appVisible) _battleVisibilityPauseNeedsExplicitPhaseChange = false;
    }

    _scheduleSync();
  }

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    _requestSerial++;
    if (enabled) _clearError(_stateFor(_desiredTrack));
    _scheduleSync();
    _notifyListeners();
  }

  void setAppVisible(bool visible) {
    if (_disposed || _appVisible == visible) return;
    _appVisible = visible;
    _requestSerial++;
    if (!visible) _battleVisibilityPauseNeedsExplicitPhaseChange = true;
    _scheduleSync();
  }

  /// Retries the current target track using the same player instance.
  void retry() {
    if (!canRetry) return;
    _transitionError = null;
    _clearError(_stateFor(_desiredTrack));
    _requestSerial++;
    _scheduleSync();
  }

  Future<void> dispose() async {
    if (_disposed) {
      await settled;
      return;
    }
    _disposed = true;
    _requestSerial++;
    _notifyListeners();
    _enqueue(() async {
      await _disposeTrack(_menu, _menuPlayer);
      await _disposeTrack(_battle, _battlePlayer);
    });
    await settled;
  }

  AppBgmTrack get _desiredTrack {
    if (_phase == GamePhase.result) return AppBgmTrack.none;
    if (_phase == GamePhase.configuration || _surface == AppBgmSurface.title) {
      return AppBgmTrack.menu;
    }
    return AppBgmTrack.battle;
  }

  bool get _shouldPrepare {
    final target = _desiredTrack;
    if (target == AppBgmTrack.menu) return _enabled && _appVisible;
    if (target == AppBgmTrack.battle) {
      return _phase == GamePhase.startCountdown ||
          _phase == GamePhase.resumeCountdown ||
          _phase == GamePhase.playing;
    }
    return false;
  }

  bool get _shouldPlay {
    if (!_enabled || !_appVisible) return false;
    final target = _desiredTrack;
    if (target == AppBgmTrack.menu) return true;
    return target == AppBgmTrack.battle &&
        _phase == GamePhase.playing &&
        !_battleVisibilityPauseNeedsExplicitPhaseChange;
  }

  Future<void> _syncNow(int serial) async {
    var target = _desiredTrack;

    if (target == AppBgmTrack.none) {
      if (_activeTrack != AppBgmTrack.none) {
        final outgoingTrack = _activeTrack;
        if (!await _resetTrack(outgoingTrack)) return;
        _activeTrack = AppBgmTrack.none;
        _clearResetRequest(outgoingTrack);
      }
      if (_menuNeedsReset) {
        if (!await _resetTrack(AppBgmTrack.menu)) return;
        _menuNeedsReset = false;
      }
      if (_battleNeedsReset) {
        if (!await _resetTrack(AppBgmTrack.battle)) return;
        _battleNeedsReset = false;
      }
      return;
    }

    if (_activeTrack != target) {
      if (_activeTrack != AppBgmTrack.none) {
        final outgoingTrack = _activeTrack;
        if (!await _resetTrack(outgoingTrack)) return;
        _activeTrack = AppBgmTrack.none;
        _clearResetRequest(outgoingTrack);
      }
      if (target == AppBgmTrack.menu &&
          (_menuNeedsReset || _menu.needsHardReset)) {
        if (!await _resetTrack(AppBgmTrack.menu, requireHardReset: true)) {
          return;
        }
        _menuNeedsReset = false;
      }
      if (target == AppBgmTrack.battle &&
          (_battleNeedsReset || _battle.needsHardReset)) {
        if (!await _resetTrack(AppBgmTrack.battle, requireHardReset: true)) {
          return;
        }
        _battleNeedsReset = false;
      }
      if (target == AppBgmTrack.battle && _menuNeedsReset) {
        if (!await _resetTrack(AppBgmTrack.menu)) return;
        _menuNeedsReset = false;
      }
      _activeTrack = target;
    } else {
      if (target == AppBgmTrack.menu &&
          (_menuNeedsReset || _menu.needsHardReset)) {
        if (!await _resetTrack(AppBgmTrack.menu, requireHardReset: true)) {
          return;
        }
        _menuNeedsReset = false;
      }
      if (target == AppBgmTrack.battle &&
          (_battleNeedsReset || _battle.needsHardReset)) {
        if (!await _resetTrack(AppBgmTrack.battle, requireHardReset: true)) {
          return;
        }
        _battleNeedsReset = false;
      }
      if (target == AppBgmTrack.battle && _menuNeedsReset) {
        if (!await _resetTrack(AppBgmTrack.menu)) return;
        _menuNeedsReset = false;
      }
    }

    target = _desiredTrack;
    final state = _stateFor(target);
    if (target == AppBgmTrack.none || state == null) return;
    if (_shouldPrepare && !state.sourcePrepared && state.lastError == null) {
      await _prepareTrack(target, state);
    }
    if (serial != _requestSerial || target != _desiredTrack) return;

    if (!_shouldPlay) {
      if (state.isPlaying) await _pauseTrack(serial, target, state);
      return;
    }
    if (state.sourcePrepared && !state.isPlaying && state.lastError == null) {
      await _playTrack(serial, target, state);
    }
  }

  Future<void> _prepareTrack(AppBgmTrack track, _TrackState state) async {
    state.status = AppBgmStatus.preparing;
    _notifyListeners();
    try {
      await _playerFor(track).prepare();
      if (_disposed) return;
      state.sourcePrepared = true;
      state.status = AppBgmStatus.paused;
      _notifyListeners();
    } catch (error, stackTrace) {
      if (!_disposed) _recordError(state, error, stackTrace);
    }
  }

  Future<void> _playTrack(
    int serial,
    AppBgmTrack track,
    _TrackState state,
  ) async {
    final player = _playerFor(track);
    try {
      if (state.hasPlayed) {
        await player.resume();
      } else {
        await player.playFromStart();
      }
      if (!_isCurrentPlayback(serial, track)) {
        await player.pause();
        state.isPlaying = false;
        state.status = AppBgmStatus.paused;
        _notifyListeners();
        return;
      }
      state.hasPlayed = true;
      state.isPlaying = true;
      state.status = AppBgmStatus.playing;
      _notifyListeners();
    } catch (error, stackTrace) {
      if (!_disposed && _isCurrentPlayback(serial, track)) {
        _recordError(state, error, stackTrace);
      } else if (!_disposed) {
        // The request may have been rejected after the surface, phase, or
        // lifecycle changed. It is diagnostic only: recording it against the
        // current track would prevent the newer reconciliation from playing.
        _reportError(error, stackTrace);
      }
      if (!_disposed) {
        try {
          await player.pause();
        } catch (pauseError, pauseStackTrace) {
          _reportError(pauseError, pauseStackTrace);
        }
      }
    }
  }

  Future<void> _pauseTrack(
    int serial,
    AppBgmTrack track,
    _TrackState state,
  ) async {
    try {
      await _playerFor(track).pause();
      state.isPlaying = false;
      state.status = AppBgmStatus.paused;
      _notifyListeners();
    } catch (error, stackTrace) {
      if (_isCurrentTrack(serial, track)) {
        _recordError(state, error, stackTrace);
      } else if (!_disposed) {
        // A pause may finish after the user has turned BGM back on or moved
        // to another surface. The old failure must not block that newer
        // request from resuming its track.
        _reportError(error, stackTrace);
        state.isPlaying = false;
        state.status = AppBgmStatus.paused;
        _notifyListeners();
      }
    }
  }

  /// Stops an outgoing track before another track is allowed to own the
  /// application. A pause fallback is enough to guarantee silence when the
  /// plugin's stop/reset call fails; if both calls fail, ownership stays with
  /// the outgoing track until an explicit retry succeeds.
  Future<bool> _resetTrack(
    AppBgmTrack track, {
    bool requireHardReset = false,
  }) async {
    final state = _stateFor(track);
    if (state == null) return true;
    final shouldReset =
        state.sourcePrepared ||
        state.isPlaying ||
        state.hasPlayed ||
        state.needsHardReset;
    if (!shouldReset) {
      _clearTrackState(state);
      return true;
    }
    try {
      await _playerFor(track).stopAndReset();
      _clearTrackState(state);
      _transitionError = null;
      return true;
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      try {
        await _playerFor(track).pause();
        state.isPlaying = false;
        state.needsHardReset = true;
        state.lastError = null;
        state.status = AppBgmStatus.paused;
        _notifyListeners();
        _transitionError = null;
        if (requireHardReset) {
          _recordTransitionError(error, stackTrace);
          return false;
        }
        return true;
      } catch (pauseError, pauseStackTrace) {
        state.status = AppBgmStatus.unavailable;
        _notifyListeners();
        _recordTransitionError(pauseError, pauseStackTrace);
        return false;
      }
    }
  }

  void _clearTrackState(_TrackState state) {
    state.sourcePrepared = false;
    state.isPlaying = false;
    state.hasPlayed = false;
    state.needsHardReset = false;
    state.lastError = null;
    state.status = AppBgmStatus.idle;
    _notifyListeners();
  }

  void _clearResetRequest(AppBgmTrack track) {
    switch (track) {
      case AppBgmTrack.menu:
        _menuNeedsReset = false;
      case AppBgmTrack.battle:
        _battleNeedsReset = false;
      case AppBgmTrack.none:
        break;
    }
  }

  Future<void> _disposeTrack(_TrackState state, BgmPlayer player) async {
    final shouldReset =
        state.sourcePrepared || state.isPlaying || state.hasPlayed;
    state.sourcePrepared = false;
    state.isPlaying = false;
    state.hasPlayed = false;
    try {
      if (shouldReset) await player.stopAndReset();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } finally {
      try {
        await player.dispose();
      } catch (error, stackTrace) {
        _reportError(error, stackTrace);
      }
    }
  }

  bool _isCurrentPlayback(int serial, AppBgmTrack track) {
    return !_disposed &&
        serial == _requestSerial &&
        track == _desiredTrack &&
        _shouldPlay;
  }

  bool _isCurrentTrack(int serial, AppBgmTrack track) {
    return !_disposed && serial == _requestSerial && track == _desiredTrack;
  }

  BgmPlayer _playerFor(AppBgmTrack track) => switch (track) {
    AppBgmTrack.menu => _menuPlayer,
    AppBgmTrack.battle => _battlePlayer,
    AppBgmTrack.none => throw StateError('No BGM player for silent track'),
  };

  _TrackState? _stateFor(AppBgmTrack track) => switch (track) {
    AppBgmTrack.menu => _menu,
    AppBgmTrack.battle => _battle,
    AppBgmTrack.none => null,
  };

  void _clearError(_TrackState? state) {
    if (state == null || state.lastError == null) return;
    state.lastError = null;
    if (state.status == AppBgmStatus.unavailable) {
      state.status = state.sourcePrepared
          ? AppBgmStatus.paused
          : AppBgmStatus.idle;
    }
    _notifyListeners();
  }

  void _clearErrorIfExplicitResumeWasRequested(GamePhase previous) {
    if (previous == GamePhase.resumeCountdown) _clearError(_battle);
  }

  void _recordError(_TrackState state, Object error, StackTrace stackTrace) {
    if (state.lastError == null) _failureSerial++;
    state.lastError ??= error;
    state.isPlaying = false;
    state.status = AppBgmStatus.unavailable;
    _notifyListeners();
    _reportError(error, stackTrace);
  }

  void _recordTransitionError(Object error, StackTrace stackTrace) {
    if (_transitionError == null) _failureSerial++;
    _transitionError ??= error;
    _notifyListeners();
    _reportError(error, stackTrace);
  }

  void _reportError(Object error, StackTrace stackTrace) {
    try {
      _onError(error, stackTrace);
    } catch (_) {
      // Diagnostics must never alter the game state.
    }
  }

  void _scheduleSync() {
    if (_disposed) return;
    if (_syncQueued || _syncRunning) {
      _syncRequested = true;
      return;
    }
    _syncQueued = true;
    _enqueue(() async {
      _syncQueued = false;
      _syncRunning = true;
      final serial = _requestSerial;
      try {
        await _syncNow(serial);
      } finally {
        _syncRunning = false;
        if (!_disposed && (_syncRequested || serial != _requestSerial)) {
          _syncRequested = false;
          _scheduleSync();
        }
      }
    });
  }

  void _enqueue(Future<void> Function() operation) {
    _operationTail = _operationTail.then<void>((_) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        if (!_disposed) _reportError(error, stackTrace);
      }
    });
  }

  void _notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      try {
        listener();
      } catch (_) {
        // A view listener must not break serialized audio operations.
      }
    }
  }

  static void _defaultErrorReporter(Object error, StackTrace stackTrace) {
    developer.log(
      'Application BGM is unavailable',
      name: 'conquest.audio',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final class _TrackState {
  AppBgmStatus status = AppBgmStatus.idle;
  Object? lastError;
  var sourcePrepared = false;
  var hasPlayed = false;
  var isPlaying = false;
  var needsHardReset = false;
}
