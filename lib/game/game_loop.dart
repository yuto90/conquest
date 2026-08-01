import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final gameLoopProvider = Provider<GameLoop>((ref) => PeriodicGameLoop());
