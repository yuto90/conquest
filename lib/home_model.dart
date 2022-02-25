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
      };
    }
    print(allBaseDetails);
  }

  // ゲーム開始フラグ
  bool gameHasStarted = false;
  // ゲームスタートからの時間
  int gameTime = 0;

  // 画面スタータス
  String display = 'ready';

  // Tankオブジェクト動作フラグ
  bool isMove = false;

  // 移動オブジェクト(初期値は画面外)
  double tankY = 2;
  double tankX = 2;

  // 移動オブジェクトの戦力パラメータ
  int tankScale = 0;

  // 選択拠点とターゲット拠点を格納
  Map<String, Map> tapBase = {
    'selectedBase': {},
    'targetBase': {},
  };

// 全ての拠点の情報
  Map<String, Map> allBaseDetails = {
    '0': {
      'x': 1.0, // 拠点のX座標
      'y': 1.0, // 拠点のY座標
      'control': 0, // 拠点の支配下(0:味方, 1:敵)
      'scale': 100, // 拠点の戦力パラメータ
    }, //自分の本陣
    '1': {
      'x': -1.0,
      'y': -1.0,
      'control': 1,
      'scale': 100,
    }, //敵の本陣
  };

  // X座標の差分;
  double diffX = 0;
  double diffY = 0;

  // ゲームを開始する
  void startGame() {
    gameHasStarted = true;
    Timer.periodic(
      Duration(milliseconds: 50),
      (timer) {
        gameTime += 50;

        if (isMove) {
          // ターゲット拠点まで攻撃オブジェクトを動かす

          double selectedX = tapBase['selectedBase']!['x'];
          double selectedY = tapBase['selectedBase']!['y'];
          double targetX = tapBase['targetBase']!['x'];
          double targetY = tapBase['targetBase']!['y'];

          // diffXが初期値だったら座標の差分を計算
          if (diffX == 0) {
            diffX = calcDiff(selectedX, targetX);
          }
          if (diffY == 0) {
            diffY = calcDiff(selectedY, targetY);
          }

          // 座標の差分を少なくしながらオブジェクトを移動させる
          if (selectedX >= targetX) {
            tankX -= diffX / 100;
          } else {
            tankX += diffX / 100;
          }
          if (selectedY >= targetY) {
            tankY -= diffY / 100;
          } else {
            tankY += diffY / 100;
          }

          // ターゲット座標を超えたら移動オブジェクトを消す
          if (calcDiff(targetX, tankX) <= 0.01 ||
              calcDiff(targetY, tankY) <= 0.01) {
            isMove = false;

            tankY = 2;
            tankX = 2;

            diffX = 0;
            diffY = 0;

            tapBase = {
              'selectedBase': {},
              'targetBase': {},
            };
          }
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

  // 第一引数と第二引数の差分を計算
  double calcDiff(double elem1, double elem2) {
    double diff;

    if (elem1 >= elem2) {
      diff = elem1 - elem2;
    } else {
      diff = elem2 - elem1;
    }
    return diff;
  }

  void move() {}
}
