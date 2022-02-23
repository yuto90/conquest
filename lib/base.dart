import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../size_config.dart';

class Base extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int control = Provider.of<Map?>(context)!['control'];
    return Container(
      //color: Colors.red,
      child: SizedBox(
        height: 50,
        width: 50,
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
          child: Text(control.toString()),
        ),
      ),
    );
  }
}
