import 'package:conquest/base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';
import 'size_config.dart';

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeModel>(
      create: (_) => HomeModel(),
      child: Consumer<HomeModel>(
        builder: (context, model, child) {
          return GestureDetector(
            onTap: () {
              if (!model.gameHasStarted) {
                model.display = 'start';
                model.startGame();
              }
            },
            child: Scaffold(
              body: Stack(
                children: [
                  // * 背景
                  Container(
                    height: double.infinity,
                    color: Colors.blue,
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
                        child: MultiProvider(
                          providers: [
                            Provider<Map?>.value(
                              value: model.allBaseDetails['$i'],
                              child: Base(),
                            ),
                            Provider<int>.value(value: i),
                          ],
                          child: Base(),
                        ),
                      ),
                    ),
                  ],

                  // * Tank
                  model.isReady
                      ? AnimatedAlign(
                          alignment: model.isMove
                              ? Alignment(
                                  model.allBaseDetails[
                                      model.tapBase['targetBase']]!['x'],
                                  model.allBaseDetails[
                                      model.tapBase['targetBase']]!['y'],
                                )
                              : Alignment(
                                  model.allBaseDetails[
                                      model.tapBase['selectedBase']]!['x'],
                                  model.allBaseDetails[
                                      model.tapBase['selectedBase']]!['y'],
                                ),
                          duration: Duration(seconds: model.delay),
                          curve: Curves.linear,
                          child: const FlutterLogo(size: 30.0),
                        )
                      : const SizedBox(),

                  // * Ready画面
                  model.display == 'ready'
                      ? Align(
                          alignment: Alignment(0, -0.2),
                          child: model.gameHasStarted
                              ? const SizedBox()
                              : Text(
                                  'T A P  T O  P L A Y',
                                  style: TextStyle(
                                    //fontSize: SizeConfig.blockSizeVertical! * 2,
                                    color: Colors.white,
                                  ),
                                ),
                        )
                      : const SizedBox(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
