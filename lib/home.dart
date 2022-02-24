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

                // * 拠点(自動生成)
                for (int i = 0; i < model.allBaseDetails.length; i++) ...[
                  Align(
                    alignment: Alignment(
                      model.allBaseDetails['$i']!['x'],
                      model.allBaseDetails['$i']!['y'],
                    ),
                    child: SizedBox(
                      height: i == 0 || i == 1 ? 100 : 50,
                      width: i == 0 || i == 1 ? 100 : 50,
                      child: Provider<Map?>.value(
                        value: model.allBaseDetails['$i'],
                        child: Base(),
                      ),
                    ),
                  ),
                ],

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
