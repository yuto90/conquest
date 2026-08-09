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
  GameConfiguration configuration = GameConfiguration.initial,
}) {
  return GameState(
    configuration: configuration,
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

final class _SequenceRandom implements Random {
  _SequenceRandom(Iterable<int> values) : _values = [...values];

  final List<int> _values;

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1000) / 1000;

  @override
  int nextInt(int max) {
    if (_values.isEmpty) {
      throw StateError('sequence random exhausted');
    }
    final value = _values.removeAt(0);
    if (value < 0 || value >= max) {
      throw RangeError.range(value, 0, max - 1, 'value');
    }
    return value;
  }
}

GameState _multipleCandidateState({
  CpuDifficulty difficulty = CpuDifficulty.easy,
}) {
  return _playing(
    configuration: GameConfiguration(cpuDifficulty: difficulty),
    islands: [
      _island(id: 1, faction: Faction.cpu, forces: 20, x: -0.8, y: 0),
      _island(id: 2, faction: Faction.cpu, forces: 20, x: 0.8, y: 0),
      _island(id: 3, faction: Faction.player, forces: 100, x: 0, y: -0.8),
      _island(id: 4, faction: Faction.player, forces: 100, x: 0, y: 0.8),
    ],
  );
}

void main() {
  test('difficulty profiles match the approved four-tier gradient', () {
    const expected = <CpuDifficulty, CpuDifficultyProfile>{
      CpuDifficulty.veryEasy: CpuDifficultyProfile(
        difficulty: CpuDifficulty.veryEasy,
        minDecisionIntervalMs: 5000,
        maxDecisionIntervalMs: 6500,
        skipDecisionRatePercent: 50,
        primaryCandidateRatePercent: 25,
      ),
      CpuDifficulty.easy: CpuDifficultyProfile(
        difficulty: CpuDifficulty.easy,
        minDecisionIntervalMs: 4000,
        maxDecisionIntervalMs: 5500,
        skipDecisionRatePercent: 35,
        primaryCandidateRatePercent: 50,
      ),
      CpuDifficulty.normal: CpuDifficultyProfile(
        difficulty: CpuDifficulty.normal,
        minDecisionIntervalMs: 2750,
        maxDecisionIntervalMs: 4000,
        skipDecisionRatePercent: 15,
        primaryCandidateRatePercent: 80,
      ),
      CpuDifficulty.hard: CpuDifficultyProfile(
        difficulty: CpuDifficulty.hard,
        minDecisionIntervalMs: 1500,
        maxDecisionIntervalMs: 2750,
        skipDecisionRatePercent: 0,
        primaryCandidateRatePercent: 100,
      ),
    };

    expect(CpuDifficulty.values, expected.keys.toList());
    for (final entry in expected.entries) {
      expect(CpuDifficultyProfile.forDifficulty(entry.key), entry.value);
    }
  });

  test('difficulty profiles form a bounded monotonic gradient', () {
    final profiles = CpuDifficulty.values
        .map(CpuDifficultyProfile.forDifficulty)
        .toList();

    for (final profile in profiles) {
      expect(profile.minDecisionIntervalMs, greaterThan(0));
      expect(
        profile.maxDecisionIntervalMs,
        greaterThanOrEqualTo(profile.minDecisionIntervalMs),
      );
      expect(profile.skipDecisionRatePercent, inInclusiveRange(0, 100));
      expect(profile.primaryCandidateRatePercent, inInclusiveRange(0, 100));
    }

    for (var index = 0; index < profiles.length - 1; index += 1) {
      final easier = profiles[index];
      final harder = profiles[index + 1];
      final easierMidpoint =
          (easier.minDecisionIntervalMs + easier.maxDecisionIntervalMs) / 2;
      final harderMidpoint =
          (harder.minDecisionIntervalMs + harder.maxDecisionIntervalMs) / 2;
      final easierExpectedActionInterval =
          easierMidpoint / (1 - easier.skipDecisionRatePercent / 100);
      final harderExpectedActionInterval =
          harderMidpoint / (1 - harder.skipDecisionRatePercent / 100);

      expect(easierMidpoint, greaterThan(harderMidpoint));
      expect(easierMidpoint - harderMidpoint, lessThanOrEqualTo(1500));
      expect(
        easier.skipDecisionRatePercent,
        greaterThan(harder.skipDecisionRatePercent),
      );
      expect(
        easier.skipDecisionRatePercent - harder.skipDecisionRatePercent,
        lessThanOrEqualTo(20),
      );
      expect(
        easier.primaryCandidateRatePercent,
        lessThan(harder.primaryCandidateRatePercent),
      );
      expect(
        harder.primaryCandidateRatePercent - easier.primaryCandidateRatePercent,
        lessThanOrEqualTo(30),
      );
      expect(
        easierExpectedActionInterval / harderExpectedActionInterval,
        lessThan(2),
      );
    }
  });

  test('Easy can skip a due judgment with the injected quality random', () {
    final state = _multipleCandidateState();
    final strategy = CpuStrategy(
      timingRandom: _MinimumRandom(),
      qualityRandom: _SequenceRandom([0]),
      viewport: _viewport,
    );

    expect(strategy.decide(state), isNull);
  });

  test('Easy can select a legal alternative candidate', () {
    final state = _multipleCandidateState();
    final strategy = CpuStrategy(
      timingRandom: _MinimumRandom(),
      qualityRandom: _SequenceRandom([99, 99, 0]),
      viewport: _viewport,
    );

    final candidates = strategy.generateCandidates(state);
    expect(candidates, hasLength(greaterThan(1)));

    final decision = strategy.decide(state);
    expect(decision, isNotNull);
    expect(decision, isNot(candidates.first));
    expect(
      candidates,
      contains(decision),
      reason: 'quality noise must only choose generated legal candidates',
    );
  });

  test(
    'Normal and Hard keep deterministic strategy without quality RNG use',
    () {
      final state = _multipleCandidateState(difficulty: CpuDifficulty.normal);
      final qualityRandom = _SequenceRandom(const []);
      final strategy = CpuStrategy(
        timingRandom: _MinimumRandom(),
        qualityRandom: qualityRandom,
        viewport: _viewport,
      );

      expect(strategy.decide(state), strategy.generateCandidates(state).first);
      expect(
        () => strategy.decide(
          state.copyWith(
            configuration: GameConfiguration(
              totalIslandCount: 10,
              cpuDifficulty: CpuDifficulty.hard,
            ),
          ),
        ),
        returnsNormally,
      );
    },
  );

  test('timing and quality random streams remain independent', () {
    final state = _multipleCandidateState();
    final withQuality = CpuStrategy(
      timingRandom: Random(123),
      qualityRandom: _SequenceRandom([0]),
      viewport: _viewport,
    );
    final baseline = CpuStrategy(
      timingRandom: Random(123),
      qualityRandom: _SequenceRandom([99]),
      viewport: _viewport,
    );

    final firstDelay = withQuality.nextDecisionDelayMs(
      difficulty: CpuDifficulty.easy,
    );
    expect(
      firstDelay,
      baseline.nextDecisionDelayMs(difficulty: CpuDifficulty.easy),
    );
    expect(withQuality.decide(state), isNull);
    expect(
      withQuality.nextDecisionDelayMs(difficulty: CpuDifficulty.easy),
      baseline.nextDecisionDelayMs(difficulty: CpuDifficulty.easy),
    );
  });

  test('same timing and quality seeds reproduce the Easy decision column', () {
    final state = _multipleCandidateState();
    final first = CpuStrategy(
      timingRandom: Random(42),
      qualityRandom: Random(7),
      viewport: _viewport,
    );
    final second = CpuStrategy(
      timingRandom: Random(42),
      qualityRandom: Random(7),
      viewport: _viewport,
    );

    for (var index = 0; index < 20; index++) {
      expect(
        first.nextDecisionDelayMs(difficulty: CpuDifficulty.easy),
        second.nextDecisionDelayMs(difficulty: CpuDifficulty.easy),
      );
      expect(first.decide(state), second.decide(state));
    }
  });

  test(
    'candidate generation handles zero, one, and multiple legal choices',
    () {
      final strategy = CpuStrategy(
        timingRandom: _MinimumRandom(),
        qualityRandom: _SequenceRandom([99, 0]),
        viewport: _viewport,
      );
      final zero = _playing(
        configuration: GameConfiguration(
          totalIslandCount: 10,
          cpuDifficulty: CpuDifficulty.easy,
        ),
        islands: [
          _island(id: 1, faction: Faction.cpu, forces: 1),
          _island(id: 2, faction: Faction.player, forces: 5, x: 0.5),
        ],
      );
      final one = _playing(
        configuration: GameConfiguration(
          totalIslandCount: 10,
          cpuDifficulty: CpuDifficulty.easy,
        ),
        islands: [
          _island(id: 1, faction: Faction.cpu, forces: 20),
          _island(id: 2, faction: Faction.player, forces: 5, x: 0.5),
        ],
      );

      expect(strategy.generateCandidates(zero), isEmpty);
      expect(strategy.generateCandidates(one), hasLength(1));
      expect(
        strategy.generateCandidates(_multipleCandidateState()),
        hasLength(greaterThan(1)),
      );
    },
  );

  test('Easy decisions stay legal and dispatch at most one troop', () {
    for (final islandCount in GameConfiguration.allowedIslandCounts) {
      final configuration = GameConfiguration(
        totalIslandCount: islandCount,
        cpuDifficulty: CpuDifficulty.easy,
      );
      final initial = const GameRules().initialState(
        configuration: configuration,
        random: Random(200 + islandCount),
        viewport: _viewport,
      );
      final state = initial.copyWith(phase: GamePhase.playing);
      final strategy = CpuStrategy(
        timingRandom: _MinimumRandom(),
        qualityRandom: _MaximumRandom(),
        viewport: _viewport,
      );
      final decision = strategy.decide(state);

      if (decision == null) {
        continue;
      }
      final source = state.islands.firstWhere(
        (island) => island.id == decision.sourceIslandId,
      );
      final destination = state.islands.firstWhere(
        (island) => island.id == decision.destinationIslandId,
      );
      expect(source.faction, Faction.cpu, reason: 'islands=$islandCount');
      expect(
        source.currentForces,
        greaterThan(1),
        reason: 'islands=$islandCount',
      );
      expect(destination.id, isNot(source.id), reason: 'islands=$islandCount');
      expect(decision.strength, source.currentForces ~/ 2);
      expect(
        strategy.applyDecision(state, decision).movingForces,
        hasLength(1),
      );
    }
  });

  test('decision delays stay within the inclusive 1.5 to 3 second range', () {
    final strategy = CpuStrategy(random: Random(1), viewport: _viewport);

    final delays = [
      for (var index = 0; index < 100; index++) strategy.nextDecisionDelayMs(),
    ];

    expect(delays, everyElement(inInclusiveRange(1500, 3000)));
  });

  test('each CPU difficulty uses its inclusive decision interval', () {
    const bounds = <CpuDifficulty, (int, int)>{
      CpuDifficulty.veryEasy: (5000, 6500),
      CpuDifficulty.easy: (4000, 5500),
      CpuDifficulty.normal: (2750, 4000),
      CpuDifficulty.hard: (1500, 2750),
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
    final source = _island(
      id: 1,
      faction: Faction.cpu,
      forces: 20,
      x: -0.5,
      y: -0.5,
    );
    final destination = _island(
      id: 2,
      faction: Faction.player,
      forces: 5,
      x: 0.5,
      y: 0.5,
    );
    final state = _playing(islands: [source, destination]);
    final decision = strategy.decide(state)!;

    final next = strategy.applyDecision(state, decision);
    final playerForce = GameRules().createMovingForce(
      id: 99,
      faction: Faction.player,
      source: source,
      destination: destination,
      strength: 10,
      viewport: _viewport,
    );

    expect(next.movingForces, hasLength(1));
    expect(next.movingForces.single.faction, Faction.cpu);
    expect(next.movingForces.single.strength, 10);
    expect(next.movingForces.single.durationMs, playerForce.durationMs);
    expect(next.movingForces.single.arrivalTimeMs, playerForce.arrivalTimeMs);
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
