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
    for (int i = 2; i <= 9; i++) {
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
  bool isReady = false;

  // 移動オブジェクトの戦力パラメータ
  int tankScale = 0;

  // 移動オブジェクトが拠点に到着するまでのディレイ
  int delay = 1;

  // 選択拠点とターゲット拠点を格納
  Map<String, String> tapBase = {
    'selectedBase': '',
    'targetBase': '',
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

  // ゲームを開始する
  void startGame() {
    gameHasStarted = true;
    Timer.periodic(
      Duration(milliseconds: 50),
      (timer) {
        gameTime += 50;

        if (isMove) {}

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

  // 拠点の勢力によって色を返す
  Color pickColor(baseIndex) {
    if (allBaseDetails['$baseIndex']!['control'] == 0) {
      return Colors.green;
    } else if (allBaseDetails['$baseIndex']!['control'] == 1) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  void resetMoveObject() {
    // todo 移動オブジェクトが着いた時の処理
    // 味方の拠点から味方の拠点に戦力を移動させた場合プラスする
    allBaseDetails[tapBase['targetBase']]!['scale'] += tankScale;

    isReady = false;
    isMove = false;

    tapBase = {
      'selectedBase': '',
      'targetBase': '',
    };
  }

  void move() {}
}
