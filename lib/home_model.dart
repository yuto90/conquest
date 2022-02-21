import 'dart:async';

import 'package:flutter/material.dart';

class HomeModel extends ChangeNotifier {
  bool gameHasStarted = false;

  double tankY = 1;
  double tankX = 1;

  void startGame() {
    gameHasStarted = true;
    Timer.periodic(
      Duration(milliseconds: 60),
      (timer) {
        if (tankX >= -1 && tankY >= -1) {
          tankY -= 0.01;
          tankX -= 0.01;
        } else {
          print('到着');
          timer.cancel();
        }

        notifyListeners();
      },
    );
  }
}
