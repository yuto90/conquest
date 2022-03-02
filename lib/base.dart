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
          await model.onPressedBase('$baseIndex');

          print(model.isMove);
          print(model.tapBase);
        },
        child: Text(model.allBaseDetails['$baseIndex']!['scale'].toString()),
      ),
    );
  }
}
