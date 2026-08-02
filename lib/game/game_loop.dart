import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The scheduling boundary used by [GameController].  Production uses a
/// periodic timer, while tests can replace it with [ManualGameLoop] and call
/// [ManualGameLoop.tick] directly.
abstract interface class GameLoop {
  bool get isRunning;

  void start(void Function() onTick);

  void stop();
}

final class PeriodicGameLoop implements GameLoop {
  PeriodicGameLoop({Duration interval = const Duration(milliseconds: 50)})
    : _interval = interval;

  final Duration _interval;
  Timer? _timer;

  Duration get interval => _interval;

  @override
  bool get isRunning => _timer?.isActive ?? false;

  @override
  void start(void Function() onTick) {
    if (isRunning) {
      return;
    }
    _timer = Timer.periodic(_interval, (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// A public manual loop is useful to engine clients that do not want to use a
/// real timer.  It implements exactly the same callback contract as the
/// production loop.
final class ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  int startCount = 0;
  int stopCount = 0;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) {
    if (isRunning) {
      return;
    }
    startCount++;
    _onTick = onTick;
  }

  @override
  void stop() {
    stopCount++;
    _onTick = null;
  }

  void tick() => _onTick?.call();
}

/// Injectable wall-clock boundary.  A fake can subclass this class and
/// return a fixed or scripted millisecond value for deterministic controller
/// tests.
abstract class GameClock {
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

final class SystemGameClock extends GameClock {}

typedef Clock = GameClock;

final gameLoopProvider = Provider<GameLoop>((ref) => PeriodicGameLoop());

final gameClockProvider = Provider<GameClock>((ref) => SystemGameClock());
