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
                  color: Colors.green,
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
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: Colors.black,
                            width: 1,
                            style: BorderStyle.solid,
                          ),
                        ),
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
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: Colors.black,
                            width: 1,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      onPressed: () {
                        model.baseTapFlg = true;
                        print(model.baseY);
                        print(model.baseX);
                      },
                      child: Text(model.baseScale.toString()),
                    ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
