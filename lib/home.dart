import 'package:conquest/base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/game_controller.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return GestureDetector(
      onTap: () {
        if (state.phase == GamePhase.ready) {
          controller.startGame();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // * 背景
            Container(height: double.infinity, color: Colors.blue),

            // * 拠点(自動生成)
            for (final base in state.bases) ...[
              Align(
                alignment: Alignment(base.x, base.y),
                child: SizedBox(
                  height: GameRules.islandWidgetSize(base.size),
                  width: GameRules.islandWidgetSize(base.size),
                  child: Base(
                    base: base,
                    onPressed: () => controller.tapBase(base.id),
                  ),
                ),
              ),
            ],

            // * Tank
            state.movement != null
                ? Align(
                    alignment: Alignment(state.movement!.x, state.movement!.y),
                    child: Container(
                      key: const ValueKey('tank'),
                      color: Colors.red,
                      height: 30,
                      width: 30,
                      child: Center(
                        child: Text(state.movement!.scale.toString()),
                      ),
                    ),
                  )
                : const SizedBox(),

            // * Ready画面
            state.phase == GamePhase.ready
                ? const Align(
                    alignment: Alignment(0, -0.2),
                    child: Text(
                      'T A P  T O  P L A Y',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : const SizedBox(),
          ],
        ),
      ),
    );
  }
}
