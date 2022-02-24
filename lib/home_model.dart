import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class HomeModel extends ChangeNotifier {
  HomeModel() {
    generateBaseDetails();
  }

  // ランダムなdoubleを生成する(1 ~ -1)
  double randomDouble() {
    if (Random().nextBool()) {
      return Random().nextDouble();
    } else {
      return (Random().nextDouble() - 1);
    }
  }

  // 各拠点の詳細データを生成
  void generateBaseDetails() {
    for (int i = 2; i <= 3; i++) {
      double x = randomDouble();
      double y = randomDouble();

      allBaseDetails[i.toString()] = {
        'x': x,
        'y': y,
        'control': 2,
        'scale': 0,
        'selectedFlg': 0,
        'targetBase': 0,
      };
    }
    print(allBaseDetails);
  }

  // ゲーム開始フラグ
  bool gameHasStarted = false;
  // ゲームスタートからの時間
  int gameTime = 0;

  // 移動オブジェクト
  double tankY = 1;
  double tankX = 1;

// 全ての拠点の情報
  Map<String, Map> allBaseDetails = {
    '0': {
      'x': 1.0, // 拠点のX座標
      'y': 1.0, // 拠点のY座標
      'control': 0, // 拠点の支配下(0:味方, 1:敵)
      'scale': 100, // 拠点の戦力パラメータ
      'selectedFlg': 0, // 拠点選択中フラグ(0:false, 1:true)
      'targetBase': 0, // 被ターゲット指定フラグ(0:false, 1:true)
    }, //自分の本陣
    '1': {
      'x': -1.0,
      'y': -1.0,
      'control': 1,
      'scale': 100,
      'selectedFlg': 0,
      'targetBase': 0,
    }, //敵の本陣
  };

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
          allBaseDetails.forEach((key, value) {
            allBaseDetails[key]!['scale']++;
          });
        }

        notifyListeners();
      },
    );
  }

  void move() {}
}
