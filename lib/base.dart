import 'package:flutter/material.dart';
import 'game/game_state.dart';

class Base extends StatelessWidget {
  const Base({required this.base, required this.onPressed, super.key});

  final BaseState base;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      //color: Colors.red,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: switch (base.control) {
            BaseControl.ally => Colors.green,
            BaseControl.enemy => Colors.red,
            BaseControl.neutral => Colors.grey,
          },
          foregroundColor: Colors.white,
          shape: base.id == 0 || base.id == 1
              ? null
              : const CircleBorder(
                  side: BorderSide(
                    color: Colors.black,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
        ),
        onPressed: onPressed,
        // controlが0か1の時のみscaleを表示
        child: base.control != BaseControl.neutral
            ? Text(base.scale.toString())
            : const Text(''),
      ),
    );
  }
}
