import 'dart:math';

import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeded balance probes report real engine completions without storage', () {
    const rules = GameRules();
    const viewport = IslandMapViewport.reference;
    for (final count in [8, 12, 16]) {
      for (final difficulty in [CpuDifficulty.normal, CpuDifficulty.hard]) {
        var wins = 0;
        var swift = 0;
        var captureRibbons = 0;
        var maneuverRibbons = 0;
        var deploymentRibbons = 0;
        final times = <int>[];
        for (var seed = 1; seed <= 20; seed++) {
          final configuration = GameConfiguration(
            totalIslandCount: count,
            cpuDifficulty: difficulty,
          );
          var state = rules
              .initialState(
                configuration: configuration,
                random: Random(seed),
                viewport: viewport,
              )
              .copyWith(phase: GamePhase.playing);
          final player = CpuStrategy(
            viewport: viewport,
            controlledFaction: Faction.player,
            qualityRandom: Random(seed + 10),
            timingRandom: Random(seed + 20),
          );
          final cpu = CpuStrategy(
            viewport: viewport,
            qualityRandom: Random(seed + 30),
            timingRandom: Random(seed + 40),
          );
          var playerAt = 0;
          var cpuAt = cpu.nextDecisionDelayMs(difficulty: difficulty);
          while (state.phase == GamePhase.playing && state.elapsedMs < 600000) {
            if (state.elapsedMs >= playerAt) {
              final decision = player.decide(
                state,
                difficulty: CpuDifficulty.hard,
              );
              if (decision != null) {
                final next = player.applyDecision(state, decision);
                if (!identical(next, state)) {
                  state = next.copyWith(
                    matchSummary: state.matchSummary.recordDispatch(
                      decision.strength,
                    ),
                  );
                }
              }
              playerAt = state.elapsedMs + 500;
            }
            if (state.elapsedMs >= cpuAt) {
              final decision = cpu.decide(state, difficulty: difficulty);
              if (decision != null) state = cpu.applyDecision(state, decision);
              cpuAt =
                  state.elapsedMs +
                  cpu.nextDecisionDelayMs(difficulty: difficulty);
            }
            state = rules.tick(state, deltaMs: 100);
          }
          expect(
            state.phase,
            GamePhase.result,
            reason: '$count/$difficulty seed $seed',
          );
          final result = state.result!;
          final p = AwardProfile();
          final e = AwardEvaluator.evaluate(
            p,
            AwardMatch(
              id: '$seed',
              difficulty: difficulty,
              won: result.winner == Faction.player,
              elapsedMs: result.elapsedMs,
              summary: state.matchSummary,
              endedAtUtc: DateTime.utc(2026),
            ),
            p.eligibleAssignments,
          );
          if (result.winner == Faction.player) wins++;
          swift += e.ribbons['swift_victory'] ?? 0;
          captureRibbons += e.ribbons['capture'] ?? 0;
          maneuverRibbons += e.ribbons['maneuver'] ?? 0;
          deploymentRibbons += e.ribbons['deployment'] ?? 0;
          times.add(result.elapsedMs);
        }
        times.sort();
        // Scripted decisions do not estimate human win rates.
        expect(
          swift,
          greaterThan(0),
          reason: '$count/$difficulty reference viewport',
        );
        expect(captureRibbons, greaterThan(0));
        print(
          'AWARD BALANCE $count/${difficulty.name}: wins=$wins/20, swift=$swift/20, '
          'durationMs=${times.first}..${times.last}, ribbons capture=$captureRibbons '
          'maneuver=$maneuverRibbons deployment=$deploymentRibbons',
        );
      }
    }
  });
}
