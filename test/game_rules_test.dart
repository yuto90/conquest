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
    expect(GameConfiguration(islandCount: 6).totalIslandCount, 6);
    expect(
      () => GameConfiguration(totalIslandCount: 7),
      throwsA(isA<ArgumentError>()),
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

  test(
    'initial neutral island composition carries typed durability values',
    () {
      const expectedSizes = <int, List<IslandSize>>{
        6: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
        ],
        8: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
        10: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
        12: [
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.small,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.medium,
          IslandSize.large,
          IslandSize.large,
        ],
      };

      for (final entry in expectedSizes.entries) {
        final islands = rules
            .initialState(
              configuration: GameConfiguration(totalIslandCount: entry.key),
              random: Random(entry.key),
            )
            .islands
            .skip(2)
            .toList();

        expect(islands.map((island) => island.size), entry.value);
        for (final island in islands) {
          expect(island.durability, island.size.neutralDurability);
          expect(island.capacity, island.size.capacity);
        }
      }
    },
  );

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

  test('phase transition table and result invariant agree for every phase', () {
    final initial = rules.initialState(random: Random(4));
    final playing = initial.copyWith(phase: GamePhase.playing);
    final paused = rules.pause(playing);
    final resuming = rules.resumeCountdown(paused, durationMs: 100);
    final result = const GameResult.draw(elapsedMs: 10);

    const validTransitions = <GamePhase, Set<GamePhase>>{
      GamePhase.configuration: {
        GamePhase.configuration,
        GamePhase.startCountdown,
      },
      GamePhase.startCountdown: {GamePhase.startCountdown, GamePhase.playing},
      GamePhase.playing: {
        GamePhase.playing,
        GamePhase.paused,
        GamePhase.result,
      },
      GamePhase.paused: {
        GamePhase.paused,
        GamePhase.resumeCountdown,
        GamePhase.configuration,
      },
      GamePhase.resumeCountdown: {GamePhase.resumeCountdown, GamePhase.playing},
      GamePhase.result: {GamePhase.result, GamePhase.configuration},
    };
    for (final from in GamePhase.values) {
      for (final to in GamePhase.values) {
        expect(
          rules.canTransition(from, to),
          validTransitions[from]!.contains(to),
          reason: '$from -> $to',
        );
      }
    }

    expect(rules.transitionTo(playing, GamePhase.result), same(playing));
    expect(rules.transitionTo(playing, GamePhase.playing), same(playing));
    final finished = rules.finish(playing, result);
    expect(finished.phase, GamePhase.result);
    expect(finished.result, result);
    expect(rules.transitionTo(finished, GamePhase.result), same(finished));
    expect(rules.finish(paused, result), same(paused));
    expect(rules.finish(resuming, result), same(resuming));
    expect(
      rules.transitionTo(finished, GamePhase.configuration).result,
      isNull,
    );
    expect(
      () => GameState(phase: GamePhase.result, elapsedMs: 0),
      throwsStateError,
    );
  });

  test('countdown self-transitions preserve remaining time', () {
    final initial = rules.initialState(random: Random(5));
    final countdown = rules.startCountdown(initial, durationMs: 1000);
    final partialStart = rules.tick(countdown, deltaMs: 400);
    final paused = rules.pause(rules.tick(countdown, deltaMs: 1000));
    final resume = rules.resumeCountdown(paused, durationMs: 1200);
    final partialResume = rules.tick(resume, deltaMs: 500);

    expect(partialStart.countdownRemainingMs, 600);
    expect(
      rules.transitionTo(partialStart, GamePhase.startCountdown),
      same(partialStart),
    );
    expect(partialResume.countdownRemainingMs, 700);
    expect(
      rules.transitionTo(partialResume, GamePhase.resumeCountdown),
      same(partialResume),
    );
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

  test('nullable state values are cleared through typed APIs', () {
    const force = MovingForce(
      id: 1,
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 5,
    );
    final state = GameState(
      phase: GamePhase.playing,
      elapsedMs: 0,
      selectedIslandId: 0,
      movingForces: const [force],
    );
    final resultState = state.finishWithResult(
      const GameResult.draw(elapsedMs: 0),
    );

    expect(state.clearSelection().selectedIslandId, isNull);
    expect(state.clearMovingForces().movingForces, isEmpty);
    expect(state.clearResult().result, isNull);
    expect(state.copyWithMovement(null).movingForces, isEmpty);
    expect(resultState.phase, GamePhase.result);
    expect(resultState.result, isNotNull);
    expect(
      () => GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        result: const GameResult.draw(elapsedMs: 0),
      ),
      throwsStateError,
    );
    expect(
      () => state.copyWith(result: const GameResult.draw(elapsedMs: 0)),
      throwsStateError,
    );
    expect(
      () => resultState.copyWith(phase: GamePhase.playing),
      throwsStateError,
    );
    expect(() => resultState.clearResult(), throwsStateError);
  });

  test('controller ignores invalid island-count selections', () {
    final loop = ManualGameLoop();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(8)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.selectIslandCount(7);
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      10,
    );

    controller.selectIslandCount(6);
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      6,
    );
    expect(container.read(gameControllerProvider).islands, hasLength(6));
  });
}
