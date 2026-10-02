import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_identity.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
const otherProfileId = '00000000-0000-4000-8000-000000000002';
final startedAt = DateTime.utc(2026, 10, 2);
final endedAt = startedAt.add(const Duration(minutes: 2));
const summary = MatchSummary(
  elapsedMs: 180001,
  playerDispatchCount: 5,
  playerDispatchedForces: 500,
  playerCaptureCount: 6,
);

MatchContextFactory factory({UuidGenerator? ids, UtcClock? clock}) =>
    MatchContextFactory(
      ids: ids ?? SequenceIds(),
      clock: clock ?? FixedClock(startedAt),
      appVersion: '1.0.2+3',
      rulesVersion: '1',
    );

MatchStartContext start({MatchContextFactory? contexts}) =>
    (contexts ?? factory()).newMatch(
      profileId: profileId,
      configuration: GameConfiguration.initial,
      origin: SessionOrigin.gameplay,
    )!;

MatchCompletion completion({
  MatchStartContext? context,
  GameResultType type = GameResultType.victory,
  DateTime? end,
  MatchSummary metrics = summary,
  int xp = 0,
}) => MatchCompletion.fromGame(
  start: context ?? start(),
  result: GameResult(
    type: type,
    elapsedMs: metrics.elapsedMs,
    winner: switch (type) {
      GameResultType.victory => Faction.player,
      GameResultType.defeat => Faction.cpu,
      GameResultType.draw => null,
    },
    xpAwarded: xp,
  ),
  summary: metrics,
  endedAtUtc: end ?? endedAt,
);

void main() {
  test(
    'stable keys are explicit, independent of enum indexes and UI names',
    () {
      expect(MatchStatus.values.map((s) => s.storageKey), [
        'in_progress',
        'completed',
        'abandoned',
        'interrupted',
      ]);
      expect(MatchOutcome.values.map((o) => o.storageKey), [
        'win',
        'loss',
        'draw',
      ]);
      expect(SessionKind.values.map((k) => k.storageKey), ['normal', 'daily']);
      expect(CpuDifficulty.values.map(difficultyStorageKey), [
        'very_easy',
        'easy',
        'normal',
        'hard',
      ]);
      expect(GameMode.values.map(gameModeStorageKey), [
        'player_vs_cpu',
        'cpu_vs_cpu',
      ]);
      expect(() => requireUuid('match-1', 'matchId'), throwsArgumentError);
    },
  );

  test('UUID generator emits distinct canonical v4 IDs', () {
    final ids = SecureUuidGenerator();
    final generated = List.generate(100, (_) => ids.next());
    for (final id in generated) {
      requireUuid(id, 'id');
      expect(id[14], '4');
    }
    expect(generated.toSet(), hasLength(100));
    expect(SystemUtcClock().now().isUtc, isTrue);
  });

  test(
    'retained context survives notifications; rematch and execution are new',
    () {
      final ids = SequenceIds();
      final contexts = factory(ids: ids);
      final original = start(contexts: contexts);
      for (var i = 0; i < 10; i++) {
        final retry = completion(context: original);
        expect(retry.record.start.matchId, original.matchId);
        expect(retry, completion(context: original));
        expect(retry.hashCode, completion(context: original).hashCode);
      }
      expect(ids.issued, 2);
      final rematch = start(contexts: contexts);
      final newMap = start(contexts: contexts);
      expect({original.matchId, rematch.matchId, newMap.matchId}, hasLength(3));
      expect(rematch.executionId, original.executionId);
      expect(rematch.profileId, original.profileId);
      final restarted = start(contexts: factory(ids: ids));
      expect(restarted.executionId, isNot(original.executionId));
      expect(restarted.matchId, isNot(original.matchId));
    },
  );

  test(
    'explicit origins exclude normal-sized practice, preview and forecast',
    () {
      final ids = SequenceIds();
      final contexts = factory(ids: ids);
      for (final origin in SessionOrigin.values.where(
        (origin) => origin != SessionOrigin.gameplay,
      )) {
        expect(
          contexts.newMatch(
            profileId: profileId,
            configuration: GameConfiguration.initial,
            origin: origin,
          ),
          isNull,
        );
      }
      for (final config in [
        GameConfiguration.tutorial,
        GameConfiguration(gameMode: GameMode.cpuVsCpu),
      ]) {
        expect(
          contexts.newMatch(
            profileId: profileId,
            configuration: config,
            origin: SessionOrigin.gameplay,
          ),
          isNull,
        );
      }
      expect(
        contexts.newMatch(
          profileId: profileId,
          configuration: GameConfiguration(cpuDifficulty: CpuDifficulty.hard),
          origin: SessionOrigin.gameplay,
          kind: SessionKind.daily,
        ),
        isNull,
      );
      expect(ids.issued, 1);
    },
  );

  test('all outcomes copy exact summary counters, ignoring XP enrichment', () {
    for (final type in GameResultType.values) {
      final frozen = completion(type: type);
      expect(frozen.record.outcome, switch (type) {
        GameResultType.victory => MatchOutcome.win,
        GameResultType.defeat => MatchOutcome.loss,
        GameResultType.draw => MatchOutcome.draw,
      });
      expect(frozen.record.metrics.elapsedMs, 180001);
      expect(frozen.record.metrics.dispatchCount, 5);
      expect(frozen.record.metrics.forcesSent, 500);
      expect(frozen.record.metrics.captures, 6);
      expect(frozen, completion(type: type, xp: 1500));
    }
    expect(
      () => MatchCompletion.fromGame(
        start: start(),
        result: const GameResult.victory(elapsedMs: 180000),
        summary: summary,
        endedAtUtc: endedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => MatchCompletion.fromGame(
        start: start(),
        result: const GameResult.victory(
          elapsedMs: 180001,
          winner: Faction.cpu,
        ),
        summary: summary,
        endedAtUtc: endedAt,
      ),
      throwsArgumentError,
    );
  });

  test(
    'known zero and unknown NULL differ; every negative metric is rejected',
    () {
      expect(MatchMetrics().isUnknown, isTrue);
      expect(MatchMetrics.fromSummary(MatchSummary.empty).isKnown, isTrue);
      expect(
        MatchMetrics(),
        isNot(MatchMetrics.fromSummary(MatchSummary.empty)),
      );
      for (final invalid in <MatchMetrics Function()>[
        () => MatchMetrics(elapsedMs: -1),
        () => MatchMetrics(dispatchCount: -1),
        () => MatchMetrics(forcesSent: -1),
        () => MatchMetrics(captures: -1),
      ]) {
        expect(invalid, throwsArgumentError);
      }
    },
  );

  test(
    'terminal state constraints retain quit metrics and unknown recovery',
    () {
      final context = start();
      final active = MatchRecord(
        start: context,
        status: MatchStatus.inProgress,
      );
      expect(active.outcome, isNull);
      expect(active.isTerminal, isFalse);
      final quit = MatchRecord(
        start: context,
        status: MatchStatus.abandoned,
        endedAtUtc: endedAt,
        metrics: MatchMetrics.fromSummary(summary),
      );
      expect(quit.metrics.captures, 6);
      expect(quit.outcome, isNull);
      final recovered = MatchRecord(
        start: context,
        status: MatchStatus.interrupted,
        recoveredAtUtc: endedAt,
      );
      expect(recovered.endedAtUtc, isNull);
      expect(recovered.metrics.isUnknown, isTrue);
      expect(recovered.outcome, isNull);
      for (final status in MatchStatus.values) {
        expect(
          () => MatchRecord(
            start: context,
            status: status,
            outcome: MatchOutcome.win,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => MatchRecord(
          start: context,
          status: MatchStatus.interrupted,
          recoveredAtUtc: endedAt,
          metrics: MatchMetrics.fromSummary(summary),
        ),
        throwsArgumentError,
      );
      expect(
        () => requireSameFinalization(quit, recovered),
        throwsA(isA<MatchCommitConflict>()),
      );
    },
  );

  test('UTC is normalized and clock rollback never changes game duration', () {
    final rollback = startedAt.subtract(const Duration(hours: 1));
    final frozen = completion(end: rollback.toLocal());
    expect(frozen.record.endedAtUtc!.isUtc, isTrue);
    expect(frozen.record.endedAtUtc, rollback);
    expect(frozen.record.metrics.elapsedMs, summary.elapsedMs);
    expect(
      start(
        contexts: factory(clock: FixedClock(startedAt.toLocal())),
      ).startedAtUtc.isUtc,
      isTrue,
    );
  });

  test('versions and identity participate in immutable equality', () {
    final base = start();
    MatchStartContext changed({String? profile, String? rules, int? metrics}) =>
        MatchStartContext(
          matchId: base.matchId,
          profileId: profile ?? base.profileId,
          executionId: base.executionId,
          configuration: base.configuration,
          sessionKind: base.sessionKind,
          origin: base.origin,
          startedAtUtc: base.startedAtUtc,
          appVersion: base.appVersion,
          rulesVersion: rules ?? base.rulesVersion,
          metricsVersion: metrics ?? base.metricsVersion,
        );
    expect(base, changed());
    for (final different in [
      changed(profile: otherProfileId),
      changed(rules: '2'),
      changed(metrics: 2),
    ]) {
      expect(
        () => requireSameFinalization(
          completion(context: base).record,
          completion(context: different).record,
        ),
        throwsA(isA<MatchCommitConflict>()),
      );
    }
    expect(() => changed(metrics: 0), throwsArgumentError);
    expect(() => changed(rules: ''), throwsArgumentError);
  });

  test('millisecond storage roundtrip preserves retry identity', () {
    final precise = endedAt.add(const Duration(microseconds: 999));
    final captured = completion(end: precise);
    final restored = completion(
      end: DateTime.fromMillisecondsSinceEpoch(
        precise.millisecondsSinceEpoch,
        isUtc: true,
      ),
    );
    expect(captured, restored);
    requireSameFinalization(captured.record, restored.record);
    expect(storageUtc(startedAt.toLocal()).isUtc, isTrue);
  });

  test(
    'injectable service returns original receipt and rejects changed payload',
    () async {
      final MatchCompletionService service = ContractServiceFake();
      final frozen = completion();
      await service.recordStart(frozen.record.start);
      final receipt = await service.complete(frozen);
      for (var i = 0; i < 10; i++) {
        expect(await service.complete(completion(xp: 1500)), same(receipt));
      }
      await expectLater(
        service.complete(completion(type: GameResultType.defeat)),
        throwsA(isA<MatchCommitConflict>()),
      );
      await expectLater(
        service.complete(completion(metrics: summary.recordPlayerCapture())),
        throwsA(isA<MatchCommitConflict>()),
      );
      await expectLater(
        service.complete(
          completion(end: endedAt.add(const Duration(milliseconds: 1))),
        ),
        throwsA(isA<MatchCommitConflict>()),
      );
      expect(receipt.totalXpBefore, 3000);
      expect(receipt.totalXpAfter, 4500);
      expect(
        () => MatchCommitReceipt(
          record: completion(type: GameResultType.draw).record,
          xpAwarded: 1,
          totalXpBefore: 0,
          totalXpAfter: 1,
          rewardVersion: '1',
        ),
        throwsArgumentError,
      );
      expect(
        () => MatchCommitReceipt(
          record: frozen.record,
          xpAwarded: -1,
          totalXpBefore: 0,
          totalXpAfter: -1,
          rewardVersion: '1',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'empty/partial statistics and scoped cursor contracts support reads',
    () {
      expect(MatchStatistics().winRate, isNull);
      final stats = MatchStatistics(
        wins: 2,
        losses: 1,
        draws: 1,
        abandoned: 9,
        interrupted: 10,
      );
      expect(stats.completed, 4);
      expect(stats.winRate, 0.5);
      expect(() => MatchStatistics(captures: -1), throwsArgumentError);
      final filter = MatchHistoryFilter(
        difficulty: CpuDifficulty.hard,
        islandCount: 10,
        outcome: MatchOutcome.win,
      );
      expect(filter.status, MatchStatus.completed);
      final cursor = MatchHistoryCursor(
        profileId: profileId,
        filter: filter,
        startedAtUtc: startedAt,
        matchId: start().matchId,
      );
      cursor.requireScope(
        profileId,
        MatchHistoryFilter(
          difficulty: CpuDifficulty.hard,
          islandCount: 10,
          outcome: MatchOutcome.win,
        ),
      );
      expect(
        () => cursor.requireScope(otherProfileId, filter),
        throwsArgumentError,
      );
      expect(
        () => cursor.requireScope(profileId, MatchHistoryFilter()),
        throwsArgumentError,
      );
      expect(
        () => MatchHistoryFilter(
          status: MatchStatus.abandoned,
          outcome: MatchOutcome.loss,
        ),
        throwsArgumentError,
      );
      final source = <MatchHistoryEntry>[
        MatchHistoryEntry(record: completion().record, xpAwarded: 1500),
      ];
      final page = MatchHistoryPage(entries: source);
      source.clear();
      expect(page.entries, hasLength(1));
      expect(() => page.entries.clear(), throwsUnsupportedError);
      expect(
        ProfileEdit(displayName: '  艦長  ', avatarKey: 'anchor').displayName,
        '艦長',
      );
      expect(
        () => ProfileEdit(displayName: ' ', avatarKey: 'anchor'),
        throwsArgumentError,
      );
    },
  );
}

final class SequenceIds implements UuidGenerator {
  int issued = 0;
  @override
  String next() =>
      '10000000-0000-4000-8000-${(++issued).toString().padLeft(12, '0')}';
}

final class FixedClock implements UtcClock {
  FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

/// Contract consumer only; durable transaction tests belong to the DB issue.
final class ContractServiceFake implements MatchCompletionService {
  MatchCommitReceipt? saved;

  @override
  Future<void> recordStart(MatchStartContext start) async {}

  @override
  Future<MatchCommitReceipt> complete(MatchCompletion completion) async {
    final existing = saved;
    if (existing != null) {
      requireSameFinalization(existing.record, completion.record);
      return existing;
    }
    return saved = MatchCommitReceipt(
      record: completion.record,
      xpAwarded: 1500,
      totalXpBefore: 3000,
      totalXpAfter: 4500,
      rewardVersion: '1',
    );
  }

  @override
  Future<MatchCommitReceipt> abandon(MatchRecord abandoned) =>
      throw UnimplementedError();

  @override
  Future<void> recoverInterrupted({
    required String profileId,
    required String executionId,
    required DateTime recoveredAtUtc,
  }) => throw UnimplementedError();
}
