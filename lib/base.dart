import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../size_config.dart';

class Base extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Map? baseDetail = Provider.of<Map?>(context);
    return Container(
      //color: Colors.red,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary:
              baseDetail!['selectedFlg'] == 1 ? Colors.pink : Colors.orange,
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
          baseDetail['selectedFlg'] == 0
              ? baseDetail['selectedFlg'] = 1
              : baseDetail['selectedFlg'] = 0;
        },
        child: Text(baseDetail['scale'].toString()),
      ),
    );
  }
}
