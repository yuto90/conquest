import 'package:flutter/material.dart';
import '../size_config.dart';

class Base extends StatelessWidget {
  //final double heightSize;
  //final double widthSize;
  //Goal({required this.heightSize, required this.widthSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      //color: Colors.red,

      child: SizedBox(
        height: 80,
        width: 80,
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
          onPressed: () {},
          //child: Text(model.enemyBaseScale.toString()),
          child: Text('aaaa'),
        ),
      ),

      //child: Image(
      //image: AssetImage('lib/images/goal.png'),
      //fit: BoxFit.cover,
      //height: SizeConfig.blockSizeVertical! * heightSize,
      //width: SizeConfig.blockSizeVertical! * widthSize,
      //),
    );
  }
}
