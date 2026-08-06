import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = IslandMapViewport(width: 320, height: 320);

IslandState _island({
  required int id,
  required Faction faction,
  required int forces,
  double x = 0,
  double y = 0,
  int? durability,
  int capacity = 200,
  IslandSize size = IslandSize.headquarters,
}) {
  return IslandState(
    id: id,
    position: IslandPosition(x: x, y: y),
    faction: faction,
    size: size,
    currentForces: forces,
    durability: durability ?? (faction == Faction.neutral ? forces : 0),
    capacity: capacity,
  );
}

GameState _playing({
  required List<IslandState> islands,
  List<MovingForce> movingForces = const [],
  int elapsedMs = 0,
}) {
  return GameState(
    phase: GamePhase.playing,
    elapsedMs: elapsedMs,
    islands: islands,
    movingForces: movingForces,
  );
}

final class _MinimumRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

final class _MaximumRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.9999999999999999;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  test('decision delays stay within the inclusive 1.5 to 3 second range', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);

    final delays = [
      for (var index = 0; index < 100; index++) strategy.nextDecisionDelayMs(),
    ];

    expect(delays, everyElement(inInclusiveRange(1500, 3000)));
  });

  test('each CPU difficulty uses its inclusive decision interval', () {
    const bounds = <CpuDifficulty, (int, int)>{
      CpuDifficulty.easy: (3000, 4500),
      CpuDifficulty.normal: (1500, 3000),
      CpuDifficulty.hard: (750, 1500),
    };

    for (final entry in bounds.entries) {
      final minimum = CpuStrategy(
        random: _MinimumRandom(),
        viewport: _viewport,
      ).nextDecisionDelayMs(difficulty: entry.key);
      final maximum = CpuStrategy(
        random: _MaximumRandom(),
        viewport: _viewport,
      ).nextDecisionDelayMs(difficulty: entry.key);

      expect(minimum, entry.value.$1, reason: '${entry.key} minimum');
      expect(maximum, entry.value.$2, reason: '${entry.key} maximum');
    }
  });

  test('the no-argument delay remains the seeded Normal profile', () {
    final implicitNormal = CpuStrategy(random: Random(42), viewport: _viewport);
    final explicitNormal = CpuStrategy(random: Random(42), viewport: _viewport);

    expect(
      [
        for (var index = 0; index < 20; index++)
          implicitNormal.nextDecisionDelayMs(),
      ],
      [
        for (var index = 0; index < 20; index++)
          explicitNormal.nextDecisionDelayMs(difficulty: CpuDifficulty.normal),
      ],
    );
  });

  test('the same seed reproduces delays for every difficulty', () {
    for (final difficulty in CpuDifficulty.values) {
      final first = CpuStrategy(random: Random(91), viewport: _viewport);
      final second = CpuStrategy(random: Random(91), viewport: _viewport);

      expect(
        [
          for (var index = 0; index < 40; index++)
            first.nextDecisionDelayMs(difficulty: difficulty),
        ],
        [
          for (var index = 0; index < 40; index++)
            second.nextDecisionDelayMs(difficulty: difficulty),
        ],
        reason: '$difficulty seed reproducibility',
      );
    }
  });

  test('defense has priority when a nearby reinforcement prevents capture', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.2, y: -0.2),
        _island(id: 2, faction: Faction.cpu, forces: 5, x: 0, y: 0),
        _island(id: 3, faction: Faction.player, forces: 100, x: 0.8, y: 0.8),
      ],
      movingForces: [
        MovingForce(
          id: 8,
          faction: Faction.player,
          sourceIslandId: 3,
          destinationIslandId: 2,
          strength: 10,
          departureTimeMs: 0,
          arrivalTimeMs: 1000,
          durationMs: 1000,
        ),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.kind, CpuDecisionKind.defense);
    expect(decision.sourceIslandId, 1);
    expect(decision.destinationIslandId, 2);
    expect(decision.strength, 10);
  });

  test('falls back to an attack when defense cannot prevent capture', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 4, x: -0.2, y: -0.2),
        _island(id: 2, faction: Faction.cpu, forces: 5, x: 0, y: 0),
        _island(id: 3, faction: Faction.player, forces: 100, x: 0.8, y: 0.8),
        _island(id: 4, faction: Faction.player, forces: 10, x: 0.4, y: 0.4),
      ],
      movingForces: [
        MovingForce(
          id: 8,
          faction: Faction.player,
          sourceIslandId: 3,
          destinationIslandId: 2,
          strength: 10,
          departureTimeMs: 0,
          arrivalTimeMs: 1000,
          durationMs: 1000,
        ),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.kind, CpuDecisionKind.attack);
    expect(decision.destinationIslandId, 4);
  });

  test('prefers capturable enemy islands before neutral islands', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.8, y: -0.8),
        _island(id: 2, faction: Faction.player, forces: 4, x: 0.2, y: 0.2),
        _island(
          id: 3,
          faction: Faction.neutral,
          forces: 3,
          durability: 3,
          x: 0.1,
          y: 0.1,
          size: IslandSize.small,
          capacity: 50,
        ),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.destinationIslandId, 2);
  });

  test('does not reprioritize an enemy already captured by a CPU troop', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20, x: 0, y: 0),
        _island(id: 4, faction: Faction.cpu, forces: 20, x: 0.2, y: 0.2),
        _island(id: 2, faction: Faction.player, forces: 10, x: 0.1, y: 0.1),
        _island(id: 3, faction: Faction.player, forces: 4, x: 0.8, y: 0.8),
      ],
      movingForces: [
        MovingForce(
          id: 90,
          faction: Faction.cpu,
          sourceIslandId: 4,
          destinationIslandId: 2,
          strength: 20,
          departureTimeMs: 0,
          arrivalTimeMs: 100,
          durationMs: 100,
        ),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.destinationIslandId, 3);
  });

  test('chooses the least-force sufficient source, then the nearer source', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.7, y: -0.7),
        _island(id: 2, faction: Faction.cpu, forces: 24, x: 0.1, y: 0.1),
        _island(id: 3, faction: Faction.player, forces: 10, x: 0.2, y: 0.2),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.sourceIslandId, 2);

    final equalForceState = state.copyWith(
      islands: [
        for (final island in state.islands)
          island.id == 1
              ? island.copyWith(
                  currentForces: 24,
                  position: const IslandPosition(x: -0.8, y: -0.8),
                )
              : island,
      ],
    );
    final nearerDecision = strategy.decide(equalForceState);
    expect(nearerDecision!.sourceIslandId, 2);
  });

  test(
    'uses the weakest enemy and strongest source when no capture is possible',
    () {
      final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
      final state = _playing(
        islands: [
          _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.8, y: -0.8),
          _island(id: 2, faction: Faction.cpu, forces: 40, x: 0.8, y: 0.8),
          _island(id: 3, faction: Faction.player, forces: 100, x: 0.2, y: 0.2),
          _island(id: 4, faction: Faction.player, forces: 101, x: 0.3, y: 0.3),
        ],
      );

      final decision = strategy.decide(state);

      expect(decision, isNotNull);
      expect(decision!.sourceIslandId, 2);
      expect(decision.destinationIslandId, 3);
      expect(decision.strength, 20);
    },
  );

  test('uses distance before id for equally weak fallback enemies', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 40, x: 0, y: 0),
        _island(id: 2, faction: Faction.player, forces: 100, x: 0.9, y: 0.9),
        _island(id: 3, faction: Faction.player, forces: 100, x: 0.1, y: 0.1),
      ],
    );

    final decision = strategy.decide(state);

    expect(decision, isNotNull);
    expect(decision!.destinationIslandId, 3);
  });

  test('applies exactly one CPU dispatch without changing its abilities', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.5, y: -0.5),
        _island(id: 2, faction: Faction.player, forces: 5, x: 0.5, y: 0.5),
      ],
    );
    final decision = strategy.decide(state)!;

    final next = strategy.applyDecision(state, decision);

    expect(next.movingForces, hasLength(1));
    expect(next.movingForces.single.faction, Faction.cpu);
    expect(next.movingForces.single.strength, 10);
    expect(next.islands.first.currentForces, 10);
  });

  test('does not decide outside the playing phase', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20),
        _island(id: 2, faction: Faction.player, forces: 5, x: 0.5, y: 0.5),
      ],
    );

    for (final phase in [
      GamePhase.configuration,
      GamePhase.startCountdown,
      GamePhase.paused,
      GamePhase.resumeCountdown,
      GamePhase.result,
    ]) {
      final nonPlaying = phase == GamePhase.result
          ? state.finishWithResult(const GameResult.draw(elapsedMs: 0))
          : state.copyWith(phase: phase);
      expect(strategy.decide(nonPlaying), isNull, reason: '$phase');
    }
  });

  test('same seed and state reproduce delays and decisions', () {
    final first = CpuStrategy(random: Random(42), viewport: _viewport);
    final second = CpuStrategy(random: Random(42), viewport: _viewport);
    final state = _playing(
      islands: [
        _island(id: 1, faction: Faction.cpu, forces: 20),
        _island(id: 2, faction: Faction.player, forces: 5, x: 0.5, y: 0.5),
      ],
    );

    expect(first.nextDecisionDelayMs(), second.nextDecisionDelayMs());
    expect(first.decide(state), second.decide(state));
  });
}
