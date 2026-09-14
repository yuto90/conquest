import 'dart:math';

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ManualGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tick() => _onTick?.call();
}

void main() {
  test(
    'counts only established player dispatches, including reinforcements',
    () {
      final loop = _ManualGameLoop();
      final container = ProviderContainer(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      controller.state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [
          IslandState(
            id: 0,
            faction: Faction.player,
            size: IslandSize.headquarters,
            currentForces: 5,
            capacity: 200,
          ),
          IslandState(
            id: 1,
            faction: Faction.cpu,
            size: IslandSize.headquarters,
            currentForces: 10,
            capacity: 200,
          ),
          IslandState(
            id: 2,
            faction: Faction.player,
            size: IslandSize.small,
            currentForces: 4,
            capacity: 50,
          ),
        ],
      );

      controller.tapBase(1); // CPU island cannot be a source.
      controller.tapBase(0);
      controller.tapBase(0); // Selecting the same island cancels.
      expect(
        container.read(gameControllerProvider).matchSummary,
        const MatchSummary(),
      );

      controller.tapBase(0);
      controller.tapBase(2); // 5 ~/ 2 == 2; this is a reinforcement.

      final summary = container.read(gameControllerProvider).matchSummary;
      expect(summary.playerDispatchCount, 1);
      expect(summary.playerDispatchedForces, 2);
    },
  );

  test('does not advance summary during pause or resume countdown', () {
    final loop = _ManualGameLoop();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(2)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 700,
      matchSummary: const MatchSummary(elapsedMs: 700),
      islands: const [
        IslandState(
          id: 0,
          faction: Faction.player,
          size: IslandSize.headquarters,
          currentForces: 20,
          capacity: 200,
        ),
        IslandState(
          id: 1,
          faction: Faction.cpu,
          size: IslandSize.headquarters,
          currentForces: 20,
          capacity: 200,
        ),
      ],
    );

    final before = container.read(gameControllerProvider).matchSummary;
    controller.pauseGame();
    expect(container.read(gameControllerProvider).matchSummary, before);
    controller.resumeGame();
    loop.tick();
    expect(container.read(gameControllerProvider).matchSummary, before);
  });
}
