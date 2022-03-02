import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class HomeModel extends ChangeNotifier {
  HomeModel() {
    generateBaseDetails();
  }

  // 生成拠点の座標組み合わせ格納用
  List positionSetAll = [];

  // 拠点の座標を生成して返却する
  // todo もっと効率いい記述あるかも
  List<double> generateXY() {
    List<double> positionIntX = [-0.2, -0.5, -0.7, 0.2, 0.5, 0.7];
    List<double> positionIntY = [
      -0.1,
      -0.2,
      -0.3,
      -0.4,
      -0.5,
      -0.6,
      -0.7,
      0.1,
      0.2,
      0.3,
      0.4,
      0.5,
      0.6,
      0.7,
    ];
    List<double> positionSet = [];
    bool reloop = true;

    while (reloop) {
      // 初期化
      positionSet = [];
      reloop = false;

      // XYの組み合わせリストを作る
      positionSet.add(positionIntX[Random().nextInt(positionIntX.length - 1)]);
      positionSet.add(positionIntY[Random().nextInt(positionIntY.length - 1)]);

      // 作成した組み合わせが重複していないかを調べる
      for (List position in positionSetAll) {
        // 組み合わせがかぶっていれば再度作り直し
        if (position[0] == positionSet[0] && position[1] == positionSet[1]) {
          reloop = true;
          break;
        }
      }
    }

    positionSetAll.add(positionSet);
    return positionSet;
  }

  int generateScale() {
    List<int> scaleList = [50, 50, 100, 200, 300];
    return scaleList[Random().nextInt(scaleList.length - 1)];
  }

  // 各拠点の詳細データを生成
  void generateBaseDetails() {
    for (int i = 2; i <= 9; i++) {
      // 一意の座標を生成
      List<double> xy = generateXY();

      allBaseDetails[i.toString()] = {
        'x': xy[0],
        'y': xy[1],
        'control': 2,
        'scale': generateScale(),
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
      'x': 0.8, // 拠点のX座標
      'y': 0.9, // 拠点のY座標
      'control': 0, // 拠点の支配下(0:味方, 1:敵, 2:中立)
      'scale': 100, // 拠点の戦力パラメータ
    }, //自分の本陣
    '1': {
      'x': -0.8,
      'y': -0.9,
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

        //if (isMove) {}

        // 中立拠点以外は1秒経過でScaleを上げる
        if (gameTime % 1000 == 0) {
          allBaseDetails.forEach((key, value) {
            if (allBaseDetails[key]!['control'] != 2) {
              allBaseDetails[key]!['scale']++;
            }
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

  // todo 移動オブジェクトが着いた時の処理
  void calcAttack(String targetIndex) {
    Map? target = allBaseDetails[targetIndex];

    if (target!['control'] == 0) {
      // 味方の拠点から味方の拠点にscaleを移動させた場合プラスする
      target['scale'] += tankScale;
    } else {
      // 味方の拠点から敵または中立の拠点にscaleを移動させた場合マイナスする
      target['scale'] -= tankScale;
      // 敵または中立の拠点のscaleが0を下回ったら味方の拠点にする
      if (target['scale'] <= 0) {
        target['control'] = 0;
        target['scale'] = 0;
      }
    }
  }

  // フラグと選択拠点情報をリセット
  void resetMoveObject() {
    isReady = false;
    isMove = false;

    tapBase = {
      'selectedBase': '',
      'targetBase': '',
    };
  }

  void move() {}
}
