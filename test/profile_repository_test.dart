import 'dart:async';
import 'dart:io';

import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/awards/award_storage.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_database.dart' as db;
import 'package:conquest/profile/profile_read_providers.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_fixture.dart';

String uuid(int id) =>
    '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
final timestamp = DateTime.utc(2026, 10, 2);

MatchStartContext context(
  ProfileFixture fixture,
  int id, {
  CpuDifficulty difficulty = CpuDifficulty.normal,
  int islands = 8,
  DateTime? started,
  String? profileId,
}) => MatchStartContext(
  matchId: uuid(id),
  profileId: profileId ?? fixture.runtime.profile!.profileId,
  executionId: fixture.store.executionId,
  configuration: GameConfiguration(
    cpuDifficulty: difficulty,
    totalIslandCount: islands,
  ),
  sessionKind: SessionKind.normal,
  origin: SessionOrigin.gameplay,
  startedAtUtc: started ?? timestamp,
  appVersion: 'test',
  rulesVersion: '1',
);

Future<MatchRecord> finish(
  ProfileFixture fixture,
  int id, {
  CpuDifficulty difficulty = CpuDifficulty.normal,
  int islands = 8,
  DateTime? started,
  String? profileId,
  GameResultType type = GameResultType.victory,
  int elapsed = 1234,
}) async {
  final start = context(
    fixture,
    id,
    difficulty: difficulty,
    islands: islands,
    started: started,
    profileId: profileId,
  );
  await fixture.store.recordStart(start);
  return (await fixture.store.complete(
    MatchCompletion.fromGame(
      start: start,
      result: GameResult(
        type: type,
        winner: switch (type) {
          GameResultType.victory => Faction.player,
          GameResultType.defeat => Faction.cpu,
          GameResultType.draw => null,
        },
        elapsedMs: elapsed,
      ),
      summary: MatchSummary(
        elapsedMs: elapsed,
        playerDispatchCount: 4,
        playerDispatchedForces: 77,
        playerCaptureCount: 3,
      ),
      endedAtUtc: timestamp.subtract(const Duration(days: 1)),
    ),
  )).record;
}

Future<void> seedLosses(ProfileFixture fixture, int count) =>
    fixture.store.database.batch((batch) {
      batch.insertAll(fixture.store.database.matchRecords, [
        for (var i = 0; i < count; i++)
          db.MatchRecordsCompanion.insert(
            matchId: uuid(1000 + i),
            profileId: fixture.runtime.profile!.profileId,
            executionId: fixture.store.executionId,
            sessionKind: 'normal',
            origin: 'gameplay',
            gameMode: 'player_vs_cpu',
            difficulty: i.isEven ? 'normal' : 'hard',
            playerCpuDifficulty: 'normal',
            islandCount: i.isEven ? 8 : 16,
            status: 'completed',
            outcome: const Value('loss'),
            startedAtUtc: timestamp.millisecondsSinceEpoch,
            endedAtUtc: Value(timestamp.millisecondsSinceEpoch - 1000),
            elapsedMs: const Value(123456789),
            dispatchCount: const Value(4),
            forcesSent: const Value(77),
            captures: const Value(3),
            appVersion: 'test',
            rulesVersion: '1',
            metricsVersion: 1,
            receiptXp: const Value(0),
            receiptBefore: const Value(0),
            receiptAfter: const Value(0),
            receiptRewardVersion: const Value('1'),
          ),
      ]);
    });

final class QueryProbe extends QueryInterceptor {
  int selectCount = 0;
  String sql = '';
  List<Object?> args = [];
  int returnedRows = 0;
  Object? historyError;
  Completer<void>? historyGate;
  Completer<void>? captured;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> arguments,
  ) async {
    selectCount++;
    final history = statement.contains('ORDER BY m.started_at_utc');
    if (history && historyError != null) {
      final error = historyError!;
      historyError = null;
      throw error;
    }
    final gate = history ? historyGate : null;
    if (history) historyGate = null;
    final rows = await executor.runSelect(statement, arguments);
    if (gate != null) {
      captured?.complete();
      await gate.future;
    }
    sql = statement;
    args = List.of(arguments);
    returnedRows = rows.length;
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'W2/L1/D1/A1/I1: ledger, totals, groups, recent and detail agree',
    () async {
      final fixture = ProfileFixture(xp: 9876);
      addTearDown(fixture.store.close);
      await fixture.ready();
      final repo = fixture.repository;
      final profileId = fixture.runtime.profile!.profileId;
      final records = [
        await finish(fixture, 200, elapsed: 9000000000),
        await finish(
          fixture,
          201,
          difficulty: CpuDifficulty.hard,
          islands: 16,
          elapsed: 900,
        ),
        await finish(fixture, 202, type: GameResultType.defeat),
        await finish(fixture, 203, type: GameResultType.draw),
      ];
      final quit = context(fixture, 204);
      await fixture.store.recordStart(quit);
      records.add(
        (await fixture.store.abandon(
          MatchRecord(
            start: quit,
            status: MatchStatus.abandoned,
            endedAtUtc: timestamp,
            metrics: MatchMetrics(
              elapsedMs: 99999,
              dispatchCount: 999,
              forcesSent: 999,
              captures: 999,
            ),
          ),
        )).record,
      );
      final interrupted = context(fixture, 205);
      await fixture.store.recordStart(interrupted);
      await fixture.store.database.customStatement(
        'UPDATE match_records SET execution_id = ? WHERE match_id = ?',
        [uuid(999), interrupted.matchId],
      );
      await fixture.store.recoverInterrupted(
        profileId: profileId,
        executionId: uuid(999),
        recoveredAtUtc: timestamp,
      );
      records.add((await fixture.store.loadRecord(interrupted.matchId))!);
      await fixture.store.recordStart(context(fixture, 206));

      final stats = await repo.watchStatistics(profileId).first;
      expect(
        (
          stats.wins,
          stats.losses,
          stats.draws,
          stats.completed,
          stats.winRate,
          stats.abandoned,
          stats.interrupted,
        ),
        (2, 1, 1, 4, .5, 1, 1),
      );
      expect(
        (
          stats.elapsedMs,
          stats.dispatchCount,
          stats.forcesSent,
          stats.captures,
        ),
        (9000000000 + 900 + 2468, 16, 308, 12),
      );
      final groups = await repo.watchDifficultyStatistics(profileId).first;
      expect(groups[CpuDifficulty.normal]!.completed, 3);
      expect(groups[CpuDifficulty.hard]!.wins, 1);
      expect(groups[CpuDifficulty.easy]!.winRate, isNull);
      expect(
        await repo.fastestVictoryMs(
          profileId,
          difficulty: CpuDifficulty.normal,
          islandCount: 8,
        ),
        9000000000,
      );
      expect(
        await repo.fastestVictoryMs(
          profileId,
          difficulty: CpuDifficulty.normal,
          islandCount: 16,
        ),
        isNull,
      );
      expect(
        await repo.fastestVictoryMs(
          profileId,
          difficulty: CpuDifficulty.hard,
          islandCount: 16,
        ),
        900,
      );
      expect(await repo.watchTotalXp(profileId).first, 9876 + 1500 + 3000);
      final page = await repo.loadHistory(profileId);
      expect(page.entries.map((e) => e.record), records.reversed);
      expect(page.entries.map((e) => e.xpAwarded), [0, 0, 0, 0, 3000, 1500]);
      expect(
        (await repo.watchRecentMatches(profileId).first).map((e) => e.record),
        records.reversed.take(5),
      );
      for (final entry in page.entries) {
        final detail = (await repo.loadMatch(
          profileId,
          entry.record.start.matchId,
        ))!;
        expect(detail.record, entry.record);
        expect(detail.xpAwarded, entry.xpAwarded);
      }
      expect(page.entries.first.record.metrics.elapsedMs, isNull);
      expect(page.entries.first.record.metrics.dispatchCount, isNull);
      expect(page.entries.first.record.endedAtUtc, isNull);
      expect(await repo.loadMatch(profileId, uuid(206)), isNull);
      expect(await repo.loadMatch(profileId, uuid(9999)), isNull);
      expect(
        page.entries.last.record.endedAtUtc!.isBefore(
          page.entries.last.record.start.startedAtUtc,
        ),
        isTrue,
      );
    },
  );

  for (final count in [0, 1, 20, 21]) {
    test(
      '$count records: exact page boundaries and empty legacy-only stats',
      () async {
        final fixture = ProfileFixture(xp: 999999);
        addTearDown(fixture.store.close);
        await fixture.ready();
        await seedLosses(fixture, count);
        final id = fixture.runtime.profile!.profileId;
        final repo = fixture.repository;
        final first = await repo.loadHistory(id);
        expect(first.entries.length, count > 20 ? 20 : count);
        expect(first.nextCursor != null, count > 20);
        final stats = await repo.watchStatistics(id).first;
        expect(stats.completed, count);
        expect(stats.winRate, count == 0 ? null : 0);
        expect(stats.elapsedMs, count * 123456789);
        expect(await repo.watchTotalXp(id).first, 999999);
        if (first.nextCursor != null) {
          final second = await repo.loadHistory(id, before: first.nextCursor);
          expect(second.entries.length, 1);
          expect(second.nextCursor, isNull);
        }
      },
    );
  }

  test(
    'combined filters and multiple profiles cannot share cursors or details',
    () async {
      final fixture = ProfileFixture();
      addTearDown(fixture.store.close);
      await fixture.ready();
      await seedLosses(fixture, 21);
      final id = fixture.runtime.profile!.profileId;
      final other = uuid(2);
      await fixture.store.database
          .into(fixture.store.database.profiles)
          .insert(
            db.ProfilesCompanion.insert(
              profileId: other,
              avatarKey: 'island_01',
              createdAtUtc: 0,
              updatedAtUtc: 0,
              statsStartedAtUtc: 0,
            ),
          );
      await fixture.store.database
          .into(fixture.store.database.awardProfiles)
          .insert(
            db.AwardProfilesCompanion.insert(
              profileId: other,
              snapshot: AwardProfileCodec.encode(other, AwardProfile()),
            ),
          );
      await finish(
        fixture,
        300,
        profileId: other,
        difficulty: CpuDifficulty.hard,
        islands: 16,
      );
      final repo = fixture.repository;
      final filter = MatchHistoryFilter(
        difficulty: CpuDifficulty.hard,
        islandCount: 16,
        status: MatchStatus.completed,
        outcome: MatchOutcome.loss,
      );
      final page = await repo.loadHistory(id, filter: filter, limit: 5);
      expect(page.entries.length, 5);
      expect((await repo.watchStatistics(id, filter: filter).first).losses, 10);
      expect(
        (await repo.loadHistory(other)).entries.single.record.start.matchId,
        uuid(300),
      );
      expect((await repo.watchStatistics(other).first).wins, 1);
      expect((await fixture.store.loadAwards(other)).ribbons['capture'], 1);
      expect((await fixture.store.loadAwards(id)).ribbons, isEmpty);
      expect(await fixture.store.totalXp(other), 3000);
      expect(await fixture.store.totalXp(id), 0);
      expect(await repo.loadMatch(id, uuid(300)), isNull);
      expect(await repo.loadMatch(other, uuid(1000)), isNull);
      await expectLater(
        repo.loadHistory(other, filter: filter, before: page.nextCursor),
        throwsArgumentError,
      );
      await expectLater(
        repo.loadHistory(id, before: page.nextCursor),
        throwsArgumentError,
      );
      await expectLater(repo.loadHistory(id, limit: 0), throwsArgumentError);
      await expectLater(repo.loadHistory(id, limit: 101), throwsArgumentError);
      await expectLater(
        repo.fastestVictoryMs(
          id,
          difficulty: CpuDifficulty.hard,
          islandCount: 7,
        ),
        throwsArgumentError,
      );
      expect(
        (await repo.loadHistory(
          id,
          filter: MatchHistoryFilter(
            difficulty: CpuDifficulty.hard,
            islandCount: 8,
          ),
        )).entries,
        isEmpty,
      );
    },
  );

  test(
    'keysets tolerate ties, new heads and reversed-clock insertion',
    () async {
      final fixture = ProfileFixture();
      addTearDown(fixture.store.close);
      await fixture.ready();
      await seedLosses(fixture, 21);
      final id = fixture.runtime.profile!.profileId;
      final repo = fixture.repository;
      final first = await repo.loadHistory(id);
      await finish(
        fixture,
        500,
        started: timestamp.add(const Duration(days: 1)),
      );
      await finish(
        fixture,
        501,
        started: timestamp.subtract(const Duration(days: 1)),
      );
      final second = await repo.loadHistory(id, before: first.nextCursor);
      final ids = [
        ...first.entries,
        ...second.entries,
      ].map((e) => e.record.start.matchId).toList();
      expect(ids.toSet().length, 22);
      expect(ids, contains(uuid(501)));
      expect(ids, isNot(contains(uuid(500))));
      final refreshed = await repo.loadHistory(id);
      expect(refreshed.entries.first.record.start.matchId, uuid(500));
    },
  );

  test(
    'profile edit, aggregate and recent streams update from real transactions',
    () async {
      final fixture = ProfileFixture();
      addTearDown(fixture.store.close);
      await fixture.ready();
      final id = fixture.runtime.profile!.profileId;
      final repo = fixture.repository;
      final profiles = StreamIterator(repo.watchProfile(id));
      final stats = StreamIterator(repo.watchStatistics(id));
      final recent = StreamIterator(repo.watchRecentMatches(id));
      addTearDown(profiles.cancel);
      addTearDown(stats.cancel);
      addTearDown(recent.cancel);
      await profiles.moveNext();
      await stats.moveNext();
      await recent.moveNext();
      expect(recent.current, isEmpty);
      final original = profiles.current;
      await repo.editProfile(
        id,
        ProfileEdit(displayName: '  航海者👩‍🚀  ', avatarKey: 'island_02'),
      );
      await profiles.moveNext();
      expect(profiles.current.displayName, '航海者👩‍🚀');
      expect(profiles.current.profileId, original.profileId);
      expect(profiles.current.statsStartedAtUtc, original.statsStartedAtUtc);
      await expectLater(
        repo.editProfile(
          id,
          ProfileEdit(displayName: 'a' * 21, avatarKey: 'island_01'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.editProfile(
          id,
          ProfileEdit(displayName: 'valid', avatarKey: 'foreign'),
        ),
        throwsArgumentError,
      );
      await repo.editProfile(
        id,
        ProfileEdit(displayName: null, avatarKey: 'island_01'),
      );
      await profiles.moveNext();
      expect(profiles.current.displayName, isNull);
      final saved = await finish(fixture, 300);
      await stats.moveNext();
      await recent.moveNext();
      expect(stats.current.completed, 1);
      expect(recent.current.single.record, saved);
    },
  );

  test(
    'provider root shares store, reports initialization error and recovers on retry',
    () async {
      final fixture = ProfileFixture(xp: 99)
        ..openError = StateError('unavailable');
      final container = ProviderContainer(
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      addTearDown(fixture.store.close);
      await expectLater(
        container.read(playerProfileRepositoryProvider.future),
        throwsStateError,
      );
      expect(container.read(playerProfileRepositoryProvider).hasError, isTrue);
      fixture.openError = null;
      await fixture.runtime.retry();
      final repo = await container.read(playerProfileRepositoryProvider.future);
      expect(identical(repo, fixture.repository), isTrue);
      final id = await container.read(activeProfileIdProvider.future);
      final edited = Completer<PlayerProfile>();
      final profileSubscription = container.listen(playerProfileProvider(id), (
        _,
        next,
      ) {
        if (next.asData?.value.displayName == 'Captain' &&
            !edited.isCompleted) {
          edited.complete(next.requireValue);
        }
      });
      addTearDown(profileSubscription.close);
      expect(
        (await container.read(playerProfileProvider(id).future)).profileId,
        id,
      );
      await repo.editProfile(
        id,
        ProfileEdit(displayName: 'Captain', avatarKey: 'island_02'),
      );
      expect((await edited.future).displayName, 'Captain');
    },
  );

  test(
    'providers initialize the root once and react to committed gameplay',
    () async {
      final fixture = ProfileFixture(xp: 999);
      addTearDown(fixture.store.close);
      final container = ProviderContainer(
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
        ],
      );
      addTearDown(container.dispose);
      expect(
        identical(
          await container.read(playerProfileRepositoryProvider.future),
          fixture.repository,
        ),
        isTrue,
      );
      final id = await container.read(activeProfileIdProvider.future);
      expect(fixture.legacy.reads, 1);
      final statsProvider = profileStatisticsProvider((
        profileId: id,
        filter: MatchHistoryFilter(),
      ));
      final statsChanged = Completer<MatchStatistics>();
      final fastestChanged = Completer<int>();
      final recentChanged = Completer<List<MatchHistoryEntry>>();
      final fastest = fastestVictoryProvider((
        profileId: id,
        difficulty: CpuDifficulty.normal,
        islandCount: 8,
      ));
      final statsSub = container.listen(statsProvider, (_, next) {
        if (next.asData?.value.completed == 1 && !statsChanged.isCompleted)
          statsChanged.complete(next.requireValue);
      });
      final fastestSub = container.listen(fastest, (_, next) {
        if (next.asData?.value != null && !fastestChanged.isCompleted)
          fastestChanged.complete(next.requireValue!);
      });
      final recentSub = container.listen(recentMatchesProvider(id), (_, next) {
        if (next.asData?.value.length == 1 && !recentChanged.isCompleted)
          recentChanged.complete(next.requireValue);
      });
      addTearDown(statsSub.close);
      addTearDown(fastestSub.close);
      addTearDown(recentSub.close);
      expect((await container.read(statsProvider.future)).winRate, isNull);
      expect(await container.read(fastest.future), isNull);
      expect(await container.read(recentMatchesProvider(id).future), isEmpty);
      final record = await finish(fixture, 200);
      expect((await statsChanged.future).wins, 1);
      expect(await fastestChanged.future, 1234);
      expect((await recentChanged.future).single.record, record);
      final groupsProvider = difficultyStatisticsProvider(id);
      final groupsSub = container.listen(groupsProvider, (_, _) {});
      addTearDown(groupsSub.close);
      expect(
        (await container.read(
          groupsProvider.future,
        ))[CpuDifficulty.normal]!.wins,
        1,
      );
      expect(
        (await container.read(
          matchDetailProvider((profileId: id, matchId: uuid(200))).future,
        ))!.record,
        record,
      );
      expect(fixture.legacy.reads, 1);
    },
  );

  test(
    'history cold-start reports root failure and retries into successful empty data',
    () async {
      final fixture = ProfileFixture()..openError = StateError('unavailable');
      addTearDown(fixture.store.close);
      final container = ProviderContainer(
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final provider = matchHistoryProvider((
        profileId: uuid(101),
        filter: MatchHistoryFilter(),
      ));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await expectLater(
        container.read(provider.notifier).firstPage,
        throwsStateError,
      );
      expect(container.read(provider).hasError, isTrue);
      expect(container.read(provider).hasValue, isFalse);
      fixture.openError = null;
      await fixture.runtime.retry();
      await container.pump();
      expect(
        (await container.read(provider.notifier).firstPage).entries,
        isEmpty,
      );
      expect(container.read(provider).hasError, isFalse);
      expect(container.read(provider).hasValue, isTrue);
    },
  );

  test(
    'history controller preserves rows on error, ignores duplicate loads and stale refresh/filter responses',
    () async {
      final probe = QueryProbe();
      final fixture = ProfileFixture(
        database: db.ProfileDatabase(
          NativeDatabase.memory().interceptWith(probe),
        ),
      );
      addTearDown(fixture.store.close);
      await fixture.ready();
      await seedLosses(fixture, 41);
      final container = ProviderContainer(
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final scope = (
        profileId: fixture.runtime.profile!.profileId,
        filter: MatchHistoryFilter(),
      );
      final provider = matchHistoryProvider(scope);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.notifier).firstPage;
      expect(initial.entries.length, 20);
      var controller = container.read(provider.notifier);
      probe.historyError = StateError('read failed');
      await controller.loadMore();
      expect(container.read(provider).requireValue.entries.length, 20);
      expect(
        container.read(provider).requireValue.loadMoreError,
        isA<StateError>(),
      );
      final gate = Completer<void>();
      probe.historyGate = gate;
      probe.captured = Completer<void>();
      final pending = controller.loadMore();
      await probe.captured!.future;
      await controller.loadMore();
      expect(container.read(provider).requireValue.loadingMore, isTrue);
      final refreshGate = Completer<void>();
      probe.historyGate = refreshGate;
      probe.captured = Completer<void>();
      controller.refresh();
      expect(container.read(provider).isLoading, isTrue);
      expect(container.read(provider).value?.entries ?? [], isEmpty);
      expect(container.read(provider).value?.nextCursor, isNull);
      final refreshed = container.read(provider.notifier).firstPage;
      await probe.captured!.future;
      gate.complete();
      await pending;
      expect(container.read(provider).value?.entries ?? [], isEmpty);
      expect(container.read(provider).value?.nextCursor, isNull);
      refreshGate.complete();
      expect((await refreshed).entries.length, 20);
      expect(container.read(provider).requireValue.entries.length, 20);
      await controller.loadMore();
      expect(container.read(provider).requireValue.entries.length, 40);
      await controller.loadMore();
      expect(container.read(provider).requireValue.entries.length, 41);
      expect(container.read(provider).requireValue.nextCursor, isNull);

      final reloadGate = Completer<void>();
      final manualGate = Completer<void>();
      addTearDown(() {
        for (final gate in [reloadGate, manualGate]) {
          if (!gate.isCompleted) gate.complete();
        }
      });
      probe.historyGate = reloadGate;
      probe.captured = Completer<void>();
      container.invalidate(provider);
      controller = container.read(provider.notifier);
      final reloaded = controller.firstPage;
      var reloadCompleted = false;
      reloaded.then((_) => reloadCompleted = true);
      await probe.captured!.future;
      expect(container.read(provider).hasValue, isFalse);
      probe.historyGate = manualGate;
      probe.captured = Completer<void>();
      controller.refresh();
      await probe.captured!.future;
      expect(container.read(provider).hasValue, isFalse);
      reloadGate.complete();
      await container.pump();
      expect(reloadCompleted, isFalse);
      manualGate.complete();
      expect((await reloaded).entries.length, 20);

      final oldScope = (
        profileId: scope.profileId,
        filter: MatchHistoryFilter(difficulty: CpuDifficulty.normal),
      );
      final oldProvider = matchHistoryProvider(oldScope);
      final oldSubscription = container.listen(oldProvider, (_, _) {});
      final oldGate = Completer<void>();
      probe.historyGate = oldGate;
      probe.captured = Completer<void>();
      final oldFuture = container.read(oldProvider.notifier).firstPage;
      await probe.captured!.future;
      final newProvider = matchHistoryProvider((
        profileId: scope.profileId,
        filter: MatchHistoryFilter(difficulty: CpuDifficulty.hard),
      ));
      final newSubscription = container.listen(newProvider, (_, _) {});
      addTearDown(newSubscription.close);
      final newPage = await container.read(newProvider.notifier).firstPage;
      oldSubscription.close();
      oldGate.complete();
      await oldFuture;
      expect(
        newPage.entries.every(
          (e) =>
              e.record.start.configuration.cpuDifficulty == CpuDifficulty.hard,
        ),
        isTrue,
      );
      expect(container.read(newProvider).requireValue.entries, newPage.entries);
      probe.historyError = StateError('first page failed');
      controller.refresh();
      await expectLater(
        container.read(provider.notifier).firstPage,
        throwsStateError,
      );
      expect(container.read(provider).hasError, isTrue);
      expect(container.read(provider).value?.entries ?? [], isEmpty);
      expect(container.read(provider).value?.nextCursor, isNull);
    },
  );

  test(
    'refresh during initial/repeated loads never completes a pending future with an empty page',
    () async {
      final probe = QueryProbe();
      final fixture = ProfileFixture(
        database: db.ProfileDatabase(
          NativeDatabase.memory().interceptWith(probe),
        ),
      );
      addTearDown(fixture.store.close);
      await fixture.ready();
      await seedLosses(fixture, 21);
      final container = ProviderContainer(
        overrides: [
          matchPersistenceProvider.overrideWithValue(fixture.runtime),
        ],
      );
      addTearDown(container.dispose);
      final provider = matchHistoryProvider((
        profileId: fixture.runtime.profile!.profileId,
        filter: MatchHistoryFilter(),
      ));
      final gates = List.generate(3, (_) => Completer<void>());
      addTearDown(() {
        for (final gate in gates) {
          if (!gate.isCompleted) gate.complete();
        }
      });
      probe.historyGate = gates[0];
      probe.captured = Completer<void>();
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = container.read(provider.notifier).firstPage;
      var completed = false;
      initial.then((_) => completed = true);
      await probe.captured!.future;
      await finish(
        fixture,
        200,
        started: timestamp.add(const Duration(days: 1)),
      );
      final controller = container.read(provider.notifier);
      for (var i = 1; i < gates.length; i++) {
        probe.historyGate = gates[i];
        probe.captured = Completer<void>();
        controller.refresh();
        container.read(provider.notifier).firstPage;
        await probe.captured!.future;
        expect(completed, isFalse);
        expect(container.read(provider).isLoading, isTrue);
        expect(container.read(provider).value?.entries ?? [], isEmpty);
        gates[i - 1].complete();
        await container.pump();
        expect(completed, isFalse);
      }
      gates.last.complete();
      final page = await initial;
      expect(page.entries.length, 20);
      expect(page.entries.first.record.start.matchId, uuid(200));
      expect(container.read(provider).requireValue.entries, page.entries);
    },
  );

  test(
    'SQL read failures remain errors, not empty history/statistics/details',
    () async {
      final fixture = ProfileFixture();
      addTearDown(fixture.store.close);
      await fixture.ready();
      final id = fixture.runtime.profile!.profileId;
      await fixture.store.database.customStatement('DROP TABLE match_records');
      await expectLater(
        fixture.repository.loadHistory(id),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        fixture.repository.loadMatch(id, uuid(200)),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        fixture.repository.watchStatistics(id).first,
        throwsA(isA<Exception>()),
      );
      await expectLater(
        fixture.repository.watchRecentMatches(id).first,
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    '10000 persisted rows: bounded reads, plans, time and process memory',
    () async {
      final probe = QueryProbe();
      final fixture = ProfileFixture(
        database: db.ProfileDatabase(
          NativeDatabase.memory().interceptWith(probe),
        ),
      );
      addTearDown(fixture.store.close);
      await fixture.ready();
      final rssBeforeSeed = ProcessInfo.currentRss;
      await seedLosses(fixture, 10000);
      final rssAfterSeed = ProcessInfo.currentRss;
      final repo = fixture.repository;
      final id = fixture.runtime.profile!.profileId;
      Future<void> measure(String label, Future<void> Function() read) async {
        final samples = <int>[];
        for (var i = 0; i < 25; i++) {
          await Future<void>.delayed(Duration.zero);
          final readsBefore = probe.selectCount;
          final timer = Stopwatch()..start();
          await read();
          samples.add(timer.elapsedMicroseconds);
          expect(probe.selectCount, greaterThan(readsBefore));
        }
        final sql = probe.sql;
        final args = probe.args;
        final rows = probe.returnedRows;
        final plan = await fixture.store.database.executor.runSelect(
          'EXPLAIN QUERY PLAN $sql',
          args,
        );
        samples.sort();
        // Reproducible measurements, not a performance gate across machines.
        print(
          '$label median_us=${samples[12]} p95_us=${samples[23]} rows=$rows plan=${plan.map((p) => p['detail']).join(' | ')}',
        );
        expect(sql, isNot(contains('OFFSET')));
      }

      MatchHistoryCursor? cursor;
      await measure('history_first', () async {
        final page = await repo.loadHistory(id);
        expect(page.entries.length, 20);
        expect(probe.returnedRows, 21);
        cursor = page.nextCursor;
      });
      await measure('history_next', () async {
        expect((await repo.loadHistory(id, before: cursor)).entries.length, 20);
        expect(probe.returnedRows, 21);
      });
      await measure('history_deep', () async {
        final page = await repo.loadHistory(
          id,
          before: MatchHistoryCursor(
            profileId: id,
            filter: MatchHistoryFilter(),
            startedAtUtc: timestamp,
            matchId: uuid(1100),
          ),
        );
        expect(page.entries.length, 20);
      });
      await measure('history_combined', () async {
        final page = await repo.loadHistory(
          id,
          filter: MatchHistoryFilter(
            difficulty: CpuDifficulty.hard,
            islandCount: 16,
            outcome: MatchOutcome.loss,
          ),
        );
        expect(page.entries.length, 20);
      });
      await measure('statistics', () async {
        final stats = await repo.watchStatistics(id).first;
        expect(stats.losses, 10000);
        expect(stats.elapsedMs, 1234567890000);
      });
      await measure('difficulty_groups', () async {
        final groups = await repo.watchDifficultyStatistics(id).first;
        expect(groups[CpuDifficulty.normal]!.losses, 5000);
        expect(groups[CpuDifficulty.hard]!.losses, 5000);
      });
      await measure('recent', () async {
        expect((await repo.watchRecentMatches(id).first).length, 5);
      });
      await measure('detail', () async {
        expect(
          (await repo.loadMatch(id, uuid(5000)))!.record.start.matchId,
          uuid(5000),
        );
      });
      await measure('fastest', () async {
        expect(
          await repo.fastestVictoryMs(
            id,
            difficulty: CpuDifficulty.normal,
            islandCount: 8,
          ),
          isNull,
        );
      });
      print(
        'rss_bytes before_seed=$rssBeforeSeed after_seed=$rssAfterSeed after_reads=${ProcessInfo.currentRss} sqlite=${(await fixture.store.database.customSelect('SELECT sqlite_version() AS version').getSingle()).read<String>('version')}',
      );
      final ids = <String>{};
      MatchHistoryCursor? before;
      do {
        final page = await repo.loadHistory(id, before: before);
        expect(page.entries.length, lessThanOrEqualTo(20));
        for (final entry in page.entries) {
          expect(ids.add(entry.record.start.matchId), isTrue);
        }
        before = page.nextCursor;
      } while (before != null);
      expect(ids.length, 10000);
    },
  );
}
