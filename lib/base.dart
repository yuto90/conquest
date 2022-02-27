import 'package:conquest/home_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Base extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    HomeModel model = Provider.of<HomeModel>(context);
    int baseIndex = Provider.of<int>(context);
    return Container(
      //color: Colors.red,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: model.pickColor('$baseIndex'),
          onPrimary: Colors.white,
          shape: '$baseIndex' == '0' || '$baseIndex' == '1'
              ? null
              : const CircleBorder(
                  side: BorderSide(
                    color: Colors.black,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
        ),
        onPressed: () async {
          if (model.tapBase['selectedBase']!.isEmpty) {
            model.tapBase['selectedBase'] = '$baseIndex';
            // 移動準備フラグ
            model.isReady = true;
          } else {
            model.tapBase['targetBase'] = '$baseIndex';

            // 移動オブジェクトの戦力パラメータを設定
            model.tankScale =
                (model.allBaseDetails[model.tapBase['selectedBase']]!['scale'] /
                        2)
                    .floor();

            // 選択拠点の戦力パラメータを半分にする
            model.allBaseDetails[model.tapBase['selectedBase']]!['scale'] =
                model.tankScale;

            // 移動フラグ
            model.isMove = true;
            await Future.delayed(Duration(seconds: model.delay));
            model.resetMoveObject();
            print('リセット');
          }

          print(model.isMove);
          print(model.tapBase);
        },
        // controlが0か1の時のみscaleを表示
        child: model.allBaseDetails['$baseIndex']!['control'] != 2
            ? Text(model.allBaseDetails['$baseIndex']!['scale'].toString())
            : Text(''),
      ),
    );
  }
}
