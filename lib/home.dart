import 'package:conquest/base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeModel>(
      create: (_) => HomeModel(),
      child: Consumer<HomeModel>(
        builder: (context, model, child) {
          return Scaffold(
            body: Stack(
              children: [
                // * 背景
                Container(
                  height: double.infinity,
                  color: Colors.white,
                ),

                // * 自分の基地
                Align(
                  alignment: Alignment(
                      model.allBase['0']!['x'], model.allBase['0']!['y']),
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        primary: model.baseTapFlg ? Colors.pink : Colors.orange,
                        onPrimary: Colors.white,
                      ),
                      onPressed: () {
                        model.baseTapFlg = !model.baseTapFlg;
                      },
                      child: Text(model.baseScale.toString()),
                    ),
                  ),
                ),

                // * 敵の基地
                Align(
                  alignment: Alignment(
                      model.allBase['1']!['x'], model.allBase['1']!['y']),
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        primary: Colors.red,
                        onPrimary: Colors.white,
                      ),
                      onPressed: () {},
                      child: Text(model.enemyBaseScale.toString()),
                    ),
                  ),
                ),

                // * 拠点
                Align(
                  alignment: Alignment(
                      model.allBase['2']!['x'], model.allBase['2']!['y']),
                  child: Provider<Map?>.value(
                    value: model.allBase['2'],
                    child: Base(),
                  ),
                ),
                Align(
                  alignment: Alignment(
                      model.allBase['3']!['x'], model.allBase['3']!['y']),
                  child: Provider<Map?>.value(
                    value: model.allBase['3'],
                    child: Base(),
                  ),
                ),

                // * Tank
                Align(
                  alignment: Alignment(model.tankX, model.tankY),
                  child: Container(
                    color: Colors.white,
                    height: 30,
                    width: 30,
                  ),
                ),
                Align(
                  alignment: Alignment(0, -0.8),
                  child: ElevatedButton(
                    onPressed: () {
                      model.startGame();
                    },
                    child: Text('start'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
