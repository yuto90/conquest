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

  // Tankオブジェクト動作フラグ
  bool isMove = false;

  // 移動オブジェクト(初期値は画面外)
  double tankY = 2;
  double tankX = 2;

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
            diffX = calcDiffX(selectedX, targetX);
          }
          if (diffY == 0) {
            diffY = calcDiffY(selectedY, targetY);
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

          // todo ターゲット座標を超えたら移動オブジェクトを消す
          //if (targetX <= tankX && targetY <= tankY) {
          //isMove = false;
          //}
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

  // 選択拠点からターゲット拠点までのX座標の差分を計算
  double calcDiffX(selectedX, targetX) {
    double diff;

    if (selectedX >= targetX) {
      diff = selectedX - targetX;
    } else {
      diff = targetX - selectedX;
    }
    return diff;
  }

  // 選択拠点からターゲット拠点までのY座標の差分を計算
  double calcDiffY(selectedY, targetY) {
    double diff;

    if (selectedY >= targetY) {
      diff = selectedY - targetY;
    } else {
      diff = targetY - selectedY;
    }
    return diff;
  }

  void move() {}
}
