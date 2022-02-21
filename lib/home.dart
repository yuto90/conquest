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
                Align(
                  alignment: Alignment(0, -0.8),
                  child: ElevatedButton(
                    onPressed: () {
                      model.startGame();
                    },
                    child: Text('start'),
                  ),
                ),
                Align(
                  alignment: Alignment(-1, -1),
                  child: Container(
                    color: Colors.blue,
                    height: 100,
                    width: 100,
                  ),
                ),
                Align(
                  alignment: Alignment(1, 1),
                  child: Container(
                    color: Colors.red,
                    height: 100,
                    width: 100,
                  ),
                ),
                // * Tank
                Align(
                  alignment: Alignment(model.tankX, model.tankY),
                  child: Container(
                    color: Colors.green,
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
