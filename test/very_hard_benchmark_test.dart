import 'dart:math' as math;

import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/very_hard_cpu.dart';
import '../tool/very_hard/benchmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the approved 80 deterministic comparison cases', () {
    final cases = benchmarkCases().toList();

    expect(cases, hasLength(80));
    expect(cases.map((item) => item.islandCount).toSet(), {6, 8, 10, 12});
    for (final islandCount in VeryHardBenchmarkConfig.islandCounts) {
      final forIslandCount = cases
          .where((item) => item.islandCount == islandCount)
          .toList();
      expect(forIslandCount, hasLength(20));
      expect(
        forIslandCount.map((item) => item.seed).toSet(),
        VeryHardBenchmarkConfig.seedsByIslandCount[islandCount]!.toSet(),
      );
      expect(forIslandCount.map((item) => item.veryHardFaction).toSet(), {
        Faction.player,
        Faction.cpu,
      });
    }
  });

  test(
    'runs the fixed matrix through a fake gateway without live Jev',
    () async {
      final gateway = _FakeGateway();
      final report = await VeryHardBenchmarkRunner(gateway: gateway).run(
        pullRequestNumber: 99,
        expectedHead: 'head-99',
        localHead: 'head-99',
        maxGameTimeMs: 2_000,
      );

      expect(report.matches, hasLength(80));
      expect(gateway.preflightCalls, 1);
      expect(gateway.decisionCalls, greaterThan(0));
    },
  );

  test(
    'fails closed when local HEAD differs from the supplied PR HEAD',
    () async {
      final gateway = _FakeGateway();
      final runner = VeryHardBenchmarkRunner(gateway: gateway);

      expect(
        () => runner.run(
          pullRequestNumber: 99,
          expectedHead: 'expected-head',
          localHead: 'different-head',
          nowUtc: () => DateTime.utc(2026, 9, 19),
        ),
        throwsA(isA<BenchmarkHeadMismatch>()),
      );
      expect(gateway.preflightCalls, 0);
      expect(gateway.decisionCalls, 0);
    },
  );

  test(
    'uses the production rules and Very Hard candidate contract for all cases',
    () {
      const rules = GameRules();
      const generator = VeryHardCandidateGenerator(
        viewport: GameRules.referenceMapViewport,
      );

      for (final comparisonCase in benchmarkCases()) {
        final configuration = GameConfiguration(
          totalIslandCount: comparisonCase.islandCount,
          gameMode: GameMode.cpuVsCpu,
          playerCpuDifficulty: comparisonCase.veryHardFaction == Faction.player
              ? CpuDifficulty.veryHard
              : CpuDifficulty.hard,
          cpuDifficulty: comparisonCase.veryHardFaction == Faction.cpu
              ? CpuDifficulty.veryHard
              : CpuDifficulty.hard,
        );
        final initial = rules.initialState(
          configuration: configuration,
          random: math.Random(comparisonCase.seed),
          viewport: GameRules.referenceMapViewport,
        );
        final playing = rules.tick(
          rules.startCountdown(initial),
          deltaMs: GameRules.startCountdownDurationMs,
        );
        final candidates = generator.generate(
          playing,
          faction: comparisonCase.veryHardFaction,
        );

        expect(playing.phase, GamePhase.playing);
        expect(candidates, isNotEmpty);
        expect(candidates.length, lessThanOrEqualTo(133));
        expect(candidates.last.action, VeryHardAction.wait);
        for (final candidate in candidates.where((item) => item.isDispatch)) {
          expect(
            candidate.sourceIslandId,
            isNot(candidate.destinationIslandId),
          );
          expect(candidate.strength, candidate.sourceForcesBefore! ~/ 2);
        }
      }
    },
  );

  test(
    'advances game time by fake response latency and renders Japanese report',
    () async {
      final gateway = _FakeGateway(
        responseDelay: const Duration(milliseconds: 20),
      );
      final runner = VeryHardBenchmarkRunner(gateway: gateway);
      final report = await runner.run(
        pullRequestNumber: 99,
        expectedHead: 'head-99',
        localHead: 'head-99',
        nowUtc: () => DateTime.utc(2026, 9, 19, 1, 2, 3),
        cases: const [
          BenchmarkCase(
            islandCount: 6,
            seed: 6001,
            veryHardFaction: Faction.player,
          ),
        ],
        maxGameTimeMs: 4_000,
      );

      expect(gateway.preflightCalls, 1);
      expect(gateway.decisionCalls, greaterThanOrEqualTo(1));
      expect(report.matches, hasLength(1));
      expect(report.matches.single.decisionLatenciesMs, isNotEmpty);
      expect(report.matches.single.elapsedMs, greaterThanOrEqualTo(1_500));
      expect(report.matches.single.outcome, BenchmarkOutcome.uncompleted);

      final markdown = report.toJapaneseMarkdown();
      expect(markdown, contains('PR: #99'));
      expect(markdown, contains('2026-09-19T01:02:03.000Z'));
      expect(markdown, contains('勝利'));
      expect(markdown, contains('未完了'));
      expect(markdown, contains('フォールバック'));
      expect(markdown, contains('中央値'));
      expect(markdown, contains('95パーセンタイル'));
      expect(markdown, contains('観察事項'));
      expect(markdown, contains('残存リスク'));
      expect(markdown, isNot(contains('currentForces')));
      expect(markdown, contains('モデル（サーバー固定）: `typesafe-ai/jev`'));
      expect(markdown, contains('解決済みモデル: jev/provider-v1'));
    },
  );

  test('uses the Very Hard faction strategy for a Hard fallback', () async {
    final report =
        await VeryHardBenchmarkRunner(
          gateway: _FakeGateway(
            responseDelay: const Duration(milliseconds: 20),
          ),
        ).run(
          pullRequestNumber: 99,
          expectedHead: 'head-99',
          localHead: 'head-99',
          cases: const [
            BenchmarkCase(
              islandCount: 6,
              seed: 6001,
              veryHardFaction: Faction.player,
            ),
          ],
          maxGameTimeMs: 1_839,
          decisionTimeout: const Duration(milliseconds: 5),
          transportGrace: Duration.zero,
        );

    expect(report.matches.single.fallbackStrategyFactions, isNotEmpty);
    expect(
      report.matches.single.fallbackStrategyFactions,
      everyElement(Faction.player),
    );
  });

  test('clamps response latency at the game-time cap as uncompleted', () async {
    final report =
        await VeryHardBenchmarkRunner(
          gateway: _FakeGateway(
            responseDelay: const Duration(milliseconds: 20),
          ),
        ).run(
          pullRequestNumber: 99,
          expectedHead: 'head-99',
          localHead: 'head-99',
          cases: const [
            BenchmarkCase(
              islandCount: 6,
              seed: 6001,
              veryHardFaction: Faction.player,
            ),
          ],
          maxGameTimeMs: 1_839,
          decisionTimeout: const Duration(milliseconds: 100),
        );

    expect(report.matches.single.elapsedMs, 1_839);
    expect(report.matches.single.outcome, BenchmarkOutcome.uncompleted);
  });

  test('clamps timeout wait at the game-time cap as uncompleted', () async {
    final report =
        await VeryHardBenchmarkRunner(
          gateway: _FakeGateway(
            responseDelay: const Duration(milliseconds: 20),
          ),
        ).run(
          pullRequestNumber: 99,
          expectedHead: 'head-99',
          localHead: 'head-99',
          cases: const [
            BenchmarkCase(
              islandCount: 6,
              seed: 6001,
              veryHardFaction: Faction.player,
            ),
          ],
          maxGameTimeMs: 1_839,
          decisionTimeout: const Duration(milliseconds: 5),
          transportGrace: Duration.zero,
        );

    expect(report.matches.single.elapsedMs, 1_839);
    expect(report.matches.single.outcome, BenchmarkOutcome.uncompleted);
  });

  test('counts the product timeout as a classified fallback error', () async {
    final gateway = _FakeGateway(
      responseDelay: const Duration(milliseconds: 20),
    );
    final report = await VeryHardBenchmarkRunner(gateway: gateway).run(
      pullRequestNumber: 99,
      expectedHead: 'head-99',
      localHead: 'head-99',
      cases: const [
        BenchmarkCase(
          islandCount: 6,
          seed: 6001,
          veryHardFaction: Faction.player,
        ),
      ],
      maxGameTimeMs: 4_000,
      decisionTimeout: const Duration(milliseconds: 5),
      transportGrace: const Duration(milliseconds: 100),
    );

    expect(report.total.fallbackCount, greaterThanOrEqualTo(1));
    expect(report.total.providerApiErrors['timeout'], greaterThanOrEqualTo(1));
  });

  test(
    'scores uncompleted matches separately from draws and uses nearest-rank p95',
    () {
      final report = BenchmarkReport.fromMatches(
        pullRequestNumber: 99,
        headSha: 'head-99',
        executedAtUtc: DateTime.utc(2026, 9, 19),
        matches: const [
          BenchmarkMatchResult(
            islandCount: 6,
            seed: 6001,
            veryHardFaction: Faction.player,
            outcome: BenchmarkOutcome.win,
            elapsedMs: 100,
            fallbackCount: 1,
            decisionRequestCount: 5,
            decisionLatenciesMs: [100, 200],
          ),
          BenchmarkMatchResult(
            islandCount: 6,
            seed: 6002,
            veryHardFaction: Faction.cpu,
            outcome: BenchmarkOutcome.draw,
            elapsedMs: 200,
            decisionLatenciesMs: [300],
          ),
          BenchmarkMatchResult(
            islandCount: 6,
            seed: 6003,
            veryHardFaction: Faction.player,
            outcome: BenchmarkOutcome.loss,
            elapsedMs: 300,
            decisionLatenciesMs: [400],
          ),
          BenchmarkMatchResult(
            islandCount: 6,
            seed: 6004,
            veryHardFaction: Faction.cpu,
            outcome: BenchmarkOutcome.uncompleted,
            elapsedMs: 600_000,
            decisionLatenciesMs: [500],
          ),
        ],
      );

      final total = report.total;
      expect(total.wins, 1);
      expect(total.draws, 1);
      expect(total.losses, 1);
      expect(total.uncompleted, 1);
      expect(total.scoreRate, closeTo(0.375, 0.0001));
      expect(total.fallbackCount, 1);
      expect(total.fallbackRate, closeTo(0.2, 0.0001));
      expect(total.latencyMedianMs, 300);
      expect(total.latencyP95Ms, 500);
    },
  );
}

final class _FakeGateway implements VeryHardCpuGateway {
  _FakeGateway({this.responseDelay = Duration.zero});

  final Duration responseDelay;
  int preflightCalls = 0;
  int decisionCalls = 0;

  @override
  Future<VeryHardPreflightResult> preflight({required String matchId}) async {
    preflightCalls++;
    return const VeryHardPreflightResult.available();
  }

  @override
  Future<VeryHardDecisionResponse> decide(
    VeryHardDecisionRequest request,
  ) async {
    decisionCalls++;
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    return VeryHardDecisionResponse(
      requestId: request.requestId,
      candidateIdsByFaction: {
        for (final subject in request.subjects)
          subject.faction: subject.candidates.first.id,
      },
      model: VeryHardCpuConfig.model,
      resolvedModel: 'jev/provider-v1',
      promptVersion: VeryHardCpuConfig.promptVersion,
      latencyMs: responseDelay.inMilliseconds,
    );
  }
}
