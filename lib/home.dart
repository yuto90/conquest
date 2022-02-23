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
                Align(
                  alignment: Alignment(0, -0.8),
                  child: ElevatedButton(
                    onPressed: () {
                      model.startGame();
                    },
                    child: Text('start'),
                  ),
                ),
                // * 敵の基地
                Align(
                  alignment: Alignment(model.enemyBaseX, model.enemyBaseY),
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        primary: Colors.red,
                        onPrimary: Colors.white,
                      ),
                      onPressed: () {
                        print(model.enemyBaseY);
                        print(model.enemyBaseX);
                      },
                      child: Text(model.enemyBaseScale.toString()),
                    ),
                  ),
                ),
                // * 自分の基地
                Align(
                  alignment: Alignment(model.baseX, model.baseY),
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
                        print(model.baseY);
                        print(model.baseX);
                      },
                      child: Text(model.baseScale.toString()),
                    ),
                  ),
                ),

                // * 拠点
                Align(
                  alignment:
                      Alignment(model.allBase['2']![0], model.allBase['2']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['3']![0], model.allBase['3']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['4']![0], model.allBase['4']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['5']![0], model.allBase['5']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['6']![0], model.allBase['6']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['7']![0], model.allBase['7']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['8']![0], model.allBase['8']![1]),
                  child: Base(),
                ),
                Align(
                  alignment:
                      Alignment(model.allBase['9']![0], model.allBase['9']![1]),
                  child: Base(),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
