import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class HomeModel extends ChangeNotifier {
  HomeModel() {
    generateBasePosition();
  }

  // ランダムなdoubleを生成する(1 ~ -1)
  double randomDouble() {
    if (Random().nextBool()) {
      return Random().nextDouble();
    } else {
      return (Random().nextDouble() - 1);
    }
  }

  // 画面上のランダムな位置に拠点を生成する
  void generateBasePosition() {
    for (int i = 2; i <= 10; i++) {
      double x = randomDouble();
      double y = randomDouble();

      List position = [x, y];
      allBase[i.toString()] = position;
    }
    print(allBase);
  }

  // ゲーム開始フラグ
  bool gameHasStarted = false;
  // ゲームスタートからの時間
  int gameTime = 0;

  // 移動オブジェクト
  double tankY = 1;
  double tankX = 1;

  // ------------------------------

  Map<String, List> allBase = {
    '0': [1.0, 1.0], //　自分の本陣
    '1': [-1.0, -1.0], // 敵の本陣
  };

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
