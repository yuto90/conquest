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
          primary: model.allBaseDetails['$baseIndex']!['selectedFlg'] == 1
              ? Colors.pink
              : Colors.orange,
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
          model.allBaseDetails['$baseIndex']!['selectedFlg'] == 0
              ? model.allBaseDetails['$baseIndex']!['selectedFlg'] = 1
              : model.allBaseDetails['$baseIndex']!['selectedFlg'] = 0;
        },
        child: Text(model.allBaseDetails['$baseIndex']!['scale'].toString()),
      ),
    );
  }
}
