import 'dart:math';

import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class FixedClock extends GameClock {
  int value = 0;

  @override
  int nowMs() => value;
}

void main() {
  const rules = GameRules();

  test('configuration exposes the supported counts and default selection', () {
    expect(GameConfiguration.allowedIslandCounts, [6, 8, 10, 12]);
    expect(GameConfiguration.initial.totalIslandCount, 10);
    expect(const GameConfiguration(islandCount: 6).totalIslandCount, 6);
    expect(
      () => GameConfiguration(totalIslandCount: 7),
      throwsA(isA<AssertionError>()),
    );
  });

  test('value objects provide immutable copy updates', () {
    const position = IslandPosition(x: 0.25, y: -0.5);
    const island = IslandState(
      id: 4,
      position: position,
      faction: Faction.player,
      size: IslandSize.medium,
      currentForces: 12,
      capacity: 100,
    );

    final updated = island.copyWith(currentForces: 20);

    expect(island.currentForces, 12);
    expect(updated.currentForces, 20);
    expect(updated.position, position);
    expect(updated.capacity, 100);
    expect(IslandSize.medium.capacity, 100);
  });

  test('state holds multiple typed moving forces immutably', () {
    const forces = [
      MovingForce(
        id: 1,
        faction: Faction.player,
        sourceIslandId: 0,
        destinationIslandId: 2,
        strength: 10,
      ),
      MovingForce(
        id: 2,
        faction: Faction.cpu,
        sourceIslandId: 1,
        destinationIslandId: 3,
        strength: 12,
      ),
    ];
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      movingForces: forces,
    );

    expect(state.movingForces, hasLength(2));
    expect(state.movingForces, isA<List<MovingForce>>());
    expect(() => state.movingForces.add(forces.first), throwsUnsupportedError);
    expect(state.movement, forces.first);
  });

  test('valid and invalid phase transitions are explicit and immutable', () {
    final initial = rules.initialState(random: Random(3));
    expect(
      rules.canTransition(GamePhase.configuration, GamePhase.startCountdown),
      isTrue,
    );
    expect(
      rules.canTransition(GamePhase.configuration, GamePhase.paused),
      isFalse,
    );

    final countdown = rules.startCountdown(initial, durationMs: 100);
    expect(countdown.phase, GamePhase.startCountdown);
    expect(countdown.countdownRemainingMs, 100);
    expect(rules.pause(initial), same(initial));
    expect(rules.tick(countdown, deltaMs: 99).phase, GamePhase.startCountdown);
    expect(rules.tick(countdown, deltaMs: 100).phase, GamePhase.playing);
  });

  test(
    'fixed random seed reproduces initial state and fixed time reproduces ticks',
    () {
      final first = rules.initialState(random: Random(99));
      final second = rules.initialState(random: Random(99));

      expect(first, second);

      final playing = rules.tick(
        rules.startCountdown(first, durationMs: 0),
        deltaMs: 0,
      );
      final firstTick = rules.tick(playing, deltaMs: 1250);
      final secondTick = rules.tick(playing, deltaMs: 1250);

      expect(playing.phase, GamePhase.playing);
      expect(firstTick, secondTick);
      expect(firstTick.elapsedMs, 1250);
      expect(firstTick.islands.first.currentForces, 101);
    },
  );

  test('a moving force advances by time and arrives deterministically', () {
    const source = IslandState(
      id: 0,
      position: IslandPosition(x: -1, y: -1),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 40,
      capacity: 200,
    );
    const target = IslandState(
      id: 1,
      position: IslandPosition(x: 1, y: 1),
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 10,
      capacity: 200,
    );
    final force = rules.createMovingForce(
      id: 0,
      faction: Faction.player,
      source: source,
      destination: target,
      strength: 15,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      islands: [source, target],
      movingForces: [force],
    );

    final halfway = rules.tick(state, deltaMs: force.durationMs ~/ 2);
    expect(halfway.movingForces, hasLength(1));
    expect(halfway.movingForces.single.progress, closeTo(0.5, 0.01));

    final arrived = rules.tick(halfway, deltaMs: force.durationMs);
    expect(arrived.movingForces, isEmpty);
    expect(arrived.islands.last.currentForces, 32);
  });

  test('controller uses an injected clock with a manual loop', () {
    final clock = FixedClock();
    final loop = ManualGameLoop();
    final container = ProviderContainer(
      overrides: [
        gameClockProvider.overrideWithValue(clock),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(7)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    clock.value = 125;
    loop.tick();

    expect(container.read(gameControllerProvider).elapsedMs, 125);
  });
}
