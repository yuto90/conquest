import 'dart:async';

import 'package:flutter/material.dart';

class HomeModel extends ChangeNotifier {
  // ゲーム開始フラグ
  bool gameHasStarted = false;
  // ゲームスタートからの時間
  int gameTime = 0;

  //
  double tankY = 1;
  double tankX = 1;

  double baseY = 1;
  double baseX = 1;

  // 基地の兵力
  int baseScale = 0;

  // ゲームを開始する
  void startGame() {
    gameHasStarted = true;
    Timer.periodic(
      Duration(milliseconds: 50),
      (timer) {
        gameTime += 50;

        if (tankX >= -1 && tankY >= -1) {
          tankY -= 0.005;
          tankX -= 0.005;
        } else {
          print('到着');
          timer.cancel();
        }

        if (gameTime % 1000 == 0) {
          baseScale += 1;
        }

        notifyListeners();
      },
    );
  }
}
