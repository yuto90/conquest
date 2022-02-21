import 'dart:async';
import 'package:flutter/material.dart';

class HomeModel extends ChangeNotifier {
  // ゲーム開始フラグ
  bool gameHasStarted = false;
  // ゲームスタートからの時間
  int gameTime = 0;

  // 移動オブジェクト
  double tankY = 1;
  double tankX = 1;

  // ------------------------------
  // 自分の基地の座標
  double baseY = 1;
  double baseX = 1;

  // 基地の兵力
  int baseScale = 0;

  bool baseTapFlg = false;
  // ------------------------------

  // 敵の基地の座標
  double enemyBaseY = -1;
  double enemyBaseX = -1;

  // 基地の兵力
  int enemyBaseScale = 0;

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

        // 1秒経過でScaleを上げる
        if (gameTime % 1000 == 0) {
          baseScale += 1;
          enemyBaseScale += 1;
        }

        notifyListeners();
      },
    );
  }

  void move() {}
}
