import 'dart:io';

import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/drift_profile_store.dart';
import 'package:conquest/profile/legacy_xp.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_identity.dart';
import 'package:conquest/profile/profile_database.dart' as db;
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/profile/storage_lease.dart';
import 'package:conquest/profile/storage_native.dart' as native;
import 'package:conquest/rank_progression.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'drift/profile/generated/schema.dart';

const execution = '00000000-0000-4000-8000-000000000010';
const nextExecution = '00000000-0000-4000-8000-000000000011';
const profile = '00000000-0000-4000-8000-000000000001';
const otherProfile = '00000000-0000-4000-8000-000000000002';
final now = DateTime.utc(2026, 10, 2);

final class TestLease implements StorageLease {
  @override
  bool isHeld = true;
  @override
  Future<void> release() async {
    isHeld = false;
  }
}

final class FixedIds implements UuidGenerator {
  FixedIds([this.id = profile]);
  final String id;
  @override
  String next() => id;
}

final class FixedClock implements UtcClock {
  @override
  DateTime now() => nowUtc;
  DateTime get nowUtc => DateTime.utc(2026, 10, 2);
}

final class LegacyFixture implements LegacyXpSource {
  LegacyFixture(this.value);
  Object? value;
  bool fail = false;
  int reads = 0;
  @override
  Future<Object?> read() async {
    reads++;
    if (fail) throw const StorageUnavailable('read failure');
    return value;
  }
}

DriftProfileStore makeStore({
  QueryExecutor? executor,
  String executionId = execution,
  StorageFaultHook? faultHook,
  StorageLease? lease,
}) => DriftProfileStore(
  database: db.ProfileDatabase(executor ?? NativeDatabase.memory()),
  executionId: executionId,
  lease: lease ?? TestLease(),
  ids: FixedIds(),
  clock: FixedClock(),
  faultHook: faultHook,
);

MatchStartContext start(
  int id, {
  String executionId = execution,
  CpuDifficulty difficulty = CpuDifficulty.normal,
}) => MatchStartContext(
  matchId: '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
  profileId: profile,
  executionId: executionId,
  configuration: GameConfiguration(cpuDifficulty: difficulty),
  sessionKind: SessionKind.normal,
  origin: SessionOrigin.gameplay,
  startedAtUtc: now,
  appVersion: '1.0.3+4',
  rulesVersion: '1',
);

MatchCompletion complete(
  MatchStartContext context, {
  GameResultType type = GameResultType.victory,
  int elapsed = 1234,
}) => MatchCompletion.fromGame(
  start: context,
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
  endedAtUtc: now.subtract(const Duration(seconds: 10)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SharedPreferences adapter preserves raw values and leaves legacy key read-only',
    () async {
      final key = legacyXpStorageKey;
      SharedPreferences.setMockInitialValues({key: 8700});
      final preferences = await SharedPreferences.getInstance();
      final store = makeStore();
      addTearDown(store.close);
      await store.initialize(
        SharedPreferencesLegacyXpSource(preferences: Future.value(preferences)),
      );
      expect(await store.totalXp(profile), 8700);
      expect(preferences.get(key), 8700);
      await preferences.setString(key, 'invalid');
      expect(
        await SharedPreferencesLegacyXpSource(
          preferences: Future.value(preferences),
        ).read(),
        'invalid',
      );
    },
  );

  test(
    'native opener isolates SQLite and rejects another same-process owner until close',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-owner-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final connection = await native.openStorageConnection(
        supportDirectory: directory,
      );
      final store = makeStore(
        executor: connection.executor,
        lease: connection.lease,
      );
      expect(connection.implementation, 'native-isolate');
      await store.initialize(LegacyFixture(765));
      await expectLater(
        native.openStorageConnection(supportDirectory: directory),
        throwsA(isA<StorageAlreadyOwned>()),
      );
      await store.close();
      final reopened = await native.openStorageConnection(
        supportDirectory: directory,
      );
      final next = makeStore(
        executor: reopened.executor,
        lease: reopened.lease,
      );
      addTearDown(next.close);
      expect(await next.totalXp(profile), 765);
    },
  );

  test(
    'concurrent distinct matches serialize before/after snapshots and close drains saves',
    () async {
      final lease = TestLease();
      final store = makeStore(lease: lease);
      await store.initialize(LegacyFixture(10));
      final contexts = List.generate(8, (i) => start(200 + i));
      await Future.wait(contexts.map(store.recordStart));
      final commits = contexts
          .map((context) => store.complete(complete(context)))
          .toList();
      final closing = store.close();
      expect(
        () => store.recordStart(start(999)),
        throwsA(isA<StorageUnavailable>()),
      );
      final receipts = await Future.wait(commits);
      expect(
        receipts.map((r) => r.totalXpBefore).toList(),
        List.generate(8, (i) => 10 + 1500 * i),
      );
      await closing;
      expect(lease.isHeld, isFalse);
      await store.close();
    },
  );

  test(
    'abandon preserves metrics and zero-XP receipt across subsequent rewards',
    () async {
      final store = makeStore();
      addTearDown(store.close);
      await store.initialize(LegacyFixture(100));
      final context = start(100);
      await store.recordStart(context);
      final abandoned = MatchRecord(
        start: context,
        status: MatchStatus.abandoned,
        endedAtUtc: now,
        metrics: MatchMetrics(
          elapsedMs: 120,
          dispatchCount: 0,
          forcesSent: 0,
          captures: 0,
        ),
      );
      final receipt = await store.abandon(abandoned);
      await store.recordStart(start(101));
      await store.complete(complete(start(101)));
      expect(await store.abandon(abandoned), receipt);
      expect(receipt.record.metrics.elapsedMs, 120);
      expect(receipt.totalXpAfter, 100);
      expect(await store.totalXp(profile), 1600);
    },
  );

  for (var version = 1; version <= 8; version++) {
    test(
      'canonical UUID v$version contract is accepted for every identity',
      () async {
        final profileId = profile.replaceFirst('-4000-', '-${version}000-');
        final executionId = execution.replaceFirst('-4000-', '-${version}000-');
        final store = DriftProfileStore(
          database: db.ProfileDatabase(NativeDatabase.memory()),
          executionId: executionId,
          lease: TestLease(),
          ids: FixedIds(profileId),
          clock: FixedClock(),
        );
        addTearDown(store.close);
        expect(
          (await store.initialize(LegacyFixture(500))).profileId,
          profileId,
        );
        final context = MatchStartContext(
          matchId: start(100).matchId.replaceFirst('-4000-', '-${version}000-'),
          profileId: profileId,
          executionId: executionId,
          configuration: GameConfiguration(),
          sessionKind: SessionKind.normal,
          origin: SessionOrigin.gameplay,
          startedAtUtc: now,
          appVersion: '1.0.2+3',
          rulesVersion: '1',
        );
        await store.recordStart(context);
        final receipt = await store.complete(complete(context));
        expect(receipt.totalXpAfter, 2000);
        expect((await store.loadRecord(context.matchId))!.start, context);
      },
    );
  }

  test('v1 snapshot validates against fresh and reopened schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final database = db.ProfileDatabase(connection);
    await verifier.migrateAndValidate(database, 1);
    await database.close();
    final fresh = db.ProfileDatabase(NativeDatabase.memory());
    await fresh.validateDatabaseSchema();
    await fresh.close();
  });

  for (final value in [null, 0, 14500, RankCatalog.stageXpTotal + 900000]) {
    test(
      'legacy $value survives repeated/concurrent initialization unchanged',
      () async {
        final store = makeStore();
        addTearDown(store.close);
        final source = LegacyFixture(value);
        final profiles = await Future.wait(
          List.generate(8, (_) => store.initialize(source)),
        );
        expect(profiles.map((p) => p.profileId).toSet(), {profile});
        expect(profiles.first.statsStartedAtUtc, now);
        expect(await store.totalXp(profile), value ?? 0);
        expect(
          (await store.database.select(store.database.xpEntries).get())
              .single
              .entryId,
          'legacy:$profile',
        );
        expect(source.reads, 1);
        source.value = 999999999;
        await store.initialize(source);
        expect(source.reads, 1);
        expect(await store.totalXp(profile), value ?? 0);
      },
    );
  }

  for (final invalid in [-1, '1200', 1.25, true]) {
    test('invalid legacy $invalid is never marked as zero', () async {
      final store = makeStore();
      addTearDown(store.close);
      final source = LegacyFixture(invalid);
      await expectLater(
        store.initialize(source),
        throwsA(isA<StorageUnavailable>()),
      );
      expect(
        await store.database.select(store.database.profiles).get(),
        isEmpty,
      );
      expect(
        await store.database.select(store.database.storageMeta).get(),
        isEmpty,
      );
      source.value = 4321;
      await store.initialize(source);
      expect(await store.totalXp(profile), 4321);
    });
  }

  test('read failure is retryable without profile/marker writes', () async {
    final store = makeStore();
    addTearDown(store.close);
    final source = LegacyFixture(8100)..fail = true;
    await expectLater(
      store.initialize(source),
      throwsA(isA<StorageUnavailable>()),
    );
    expect(
      await store.database.select(store.database.storageMeta).get(),
      isEmpty,
    );
    source.fail = false;
    await store.initialize(source);
    expect(await store.totalXp(profile), 8100);
  });

  for (final fault in [
    StorageFaultPoint.afterProfile,
    StorageFaultPoint.afterLegacyEntry,
    StorageFaultPoint.beforeCommit,
  ]) {
    test(
      'migration fault $fault rolls back all writes and retries once',
      () async {
        var fail = true;
        final store = makeStore(
          faultHook: (point) async {
            if (fail && point == fault) throw StateError('injected');
          },
        );
        addTearDown(store.close);
        final source = LegacyFixture(2400);
        await expectLater(store.initialize(source), throwsStateError);
        expect(
          await store.database.select(store.database.profiles).get(),
          isEmpty,
        );
        expect(
          await store.database.select(store.database.xpEntries).get(),
          isEmpty,
        );
        expect(
          await store.database.select(store.database.storageMeta).get(),
          isEmpty,
        );
        fail = false;
        await store.initialize(source);
        await store.initialize(source);
        expect(await store.totalXp(profile), 2400);
      },
    );
  }

  for (final fault in [
    StorageFaultPoint.beforeMatch,
    StorageFaultPoint.afterMatch,
    StorageFaultPoint.beforeXp,
    StorageFaultPoint.afterXp,
    StorageFaultPoint.beforeCommit,
  ]) {
    test(
      'finalization fault $fault rolls back match and XP before retry',
      () async {
        var fail = true;
        final store = makeStore(
          faultHook: (point) async {
            if (fail && point == fault) throw StateError('injected');
          },
        );
        addTearDown(store.close);
        fail = false;
        await store.initialize(LegacyFixture(500));
        final context = start(100);
        await store.recordStart(context);
        final frozen = complete(context);
        fail = true;
        await expectLater(store.complete(frozen), throwsStateError);
        expect(
          (await store.loadRecord(context.matchId))!.status,
          MatchStatus.inProgress,
        );
        expect(await store.totalXp(profile), 500);
        fail = false;
        final receipt = await store.complete(frozen);
        expect(receipt.totalXpBefore, 500);
        expect(receipt.totalXpAfter, 2000);
        expect(await store.complete(frozen), receipt);
      },
    );
  }

  test(
    'native opener preserves an ambiguous committed receipt across retry and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('conquest-ack-');
      addTearDown(() => directory.delete(recursive: true));
      final connection = await native.openStorageConnection(
        supportDirectory: directory,
      );
      var loseAcknowledgment = false;
      final store = makeStore(
        executor: connection.executor,
        lease: connection.lease,
        faultHook: (point) async {
          if (point == StorageFaultPoint.afterCommit && loseAcknowledgment) {
            loseAcknowledgment = false;
            throw StateError('commit succeeded, acknowledgment lost');
          }
        },
      );
      await store.initialize(LegacyFixture(500));
      final frozen = complete(start(100));
      await store.recordStart(frozen.record.start);
      loseAcknowledgment = true;
      await expectLater(store.complete(frozen), throwsStateError);
      expect(await store.loadRecord(start(100).matchId), frozen.record);
      expect(await store.totalXp(profile), 2000);
      final later = complete(start(101));
      await store.recordStart(later.record.start);
      await store.complete(later);
      final receipt = await store.complete(frozen);
      expect(receipt.totalXpBefore, 500);
      expect(receipt.totalXpAfter, 2000);
      expect(await store.totalXp(profile), 3500);
      expect(await store.complete(frozen), receipt);
      expect(
        await store.database.select(store.database.xpEntries).get(),
        hasLength(3),
      );
      await store.close();
      expect(connection.lease.isHeld, isFalse);
      final next = await native.openStorageConnection(
        supportDirectory: directory,
      );
      final reopened = makeStore(executor: next.executor, lease: next.lease);
      addTearDown(reopened.close);
      final legacy = LegacyFixture(999999)..fail = true;
      await reopened.initializeAndRecover(legacy);
      expect(legacy.reads, 0);
      expect(await reopened.complete(frozen), receipt);
      expect(await reopened.totalXp(profile), 3500);
    },
  );

  test(
    'migration acknowledgment failure never reimports after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-import-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final store = makeStore(
        executor: NativeDatabase(file),
        faultHook: (point) async {
          if (point == StorageFaultPoint.afterCommit)
            throw StateError('lost ack');
        },
      );
      await expectLater(
        store.initialize(LegacyFixture(8700)),
        throwsStateError,
      );
      await store.close();
      final reopened = makeStore(executor: NativeDatabase(file));
      addTearDown(reopened.close);
      final source = LegacyFixture(999)..fail = true;
      await reopened.initializeAndRecover(source);
      expect(source.reads, 0);
      expect(await reopened.totalXp(profile), 8700);
      expect(
        await reopened.database.select(reopened.database.xpEntries).get(),
        hasLength(1),
      );
      expect(
        await reopened.database.select(reopened.database.matchRecords).get(),
        isEmpty,
      );
    },
  );

  test(
    'serialized rewards and replay receipts retain original zero/nonzero snapshots',
    () async {
      final store = makeStore();
      addTearDown(store.close);
      await store.initialize(LegacyFixture(500));
      final defeat = complete(start(100), type: GameResultType.defeat);
      await store.recordStart(defeat.record.start);
      final zero = await store.complete(defeat);
      for (final difficulty in CpuDifficulty.values) {
        final context = start(101 + difficulty.index, difficulty: difficulty);
        await store.recordStart(context);
        final frozen = complete(context);
        final receipts = await Future.wait(
          List.generate(10, (_) => store.complete(frozen)),
        );
        expect(receipts.toSet().length, 1);
        expect(receipts.first.xpAwarded, victoryXpFor(difficulty));
      }
      expect(await store.totalXp(profile), 6500);
      expect(await store.complete(defeat), zero);
      expect(zero.totalXpAfter, 500);
      await store.recordStart(defeat.record.start);
      expect(
        (await store.loadRecord(defeat.record.start.matchId))!.status,
        MatchStatus.completed,
      );
      await expectLater(
        store.complete(complete(defeat.record.start)),
        throwsA(isA<MatchCommitConflict>()),
      );
      await expectLater(
        store.recordStart(start(100, difficulty: CpuDifficulty.hard)),
        throwsA(isA<MatchCommitConflict>()),
      );
    },
  );

  test(
    'file-backed isolated executor survives close/reopen with immutable receipts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-storage-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final first = makeStore(
        executor: NativeDatabase.createInBackground(file),
      );
      await first.initialize(LegacyFixture(200));
      final frozen = complete(start(100));
      await first.recordStart(frozen.record.start);
      final receipt = await first.complete(frozen);
      await first.close();
      final second = makeStore(
        executor: NativeDatabase.createInBackground(file),
      );
      addTearDown(second.close);
      final source = LegacyFixture(999)..fail = true;
      expect((await second.initialize(source)).profileId, profile);
      expect(source.reads, 0);
      expect(await second.totalXp(profile), 1700);
      expect(
        await second.loadRecord(frozen.record.start.matchId),
        frozen.record,
      );
      expect(await second.complete(frozen), receipt);
    },
  );

  test(
    'profile edits enforce grapheme length, bundled avatars and preserve scope/XP',
    () async {
      final store = makeStore();
      addTearDown(store.close);
      final original = await store.initialize(LegacyFixture(400));
      final name = List.filled(20, '👩‍🚀').join();
      final edited = await store.editProfile(
        profile,
        ProfileEdit(displayName: ' $name ', avatarKey: 'island_02'),
      );
      expect(edited.displayName, name);
      expect(edited.createdAtUtc, original.createdAtUtc);
      expect(edited.statsStartedAtUtc, original.statsStartedAtUtc);
      expect(await store.totalXp(profile), 400);
      await expectLater(
        store.editProfile(
          profile,
          ProfileEdit(displayName: '${name}a', avatarKey: 'island_02'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.editProfile(
          profile,
          ProfileEdit(displayName: 'a', avatarKey: 'remote_image'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ProfileEdit(displayName: 'a\n', avatarKey: 'island_01'),
        returnsNormally,
      );
      expect(
        () => ProfileEdit(displayName: 'a\nb', avatarKey: 'island_01'),
        throwsArgumentError,
      );
    },
  );

  test(
    'SQL rejects duplicate IDs, orphan FKs, profile mismatch and malformed payloads',
    () async {
      final store = makeStore();
      addTearDown(store.close);
      await store.initialize(LegacyFixture(0));
      await store.recordStart(start(100));
      final database = store.database;
      final row = (await database.select(database.matchRecords).get()).single;
      await expectLater(
        database.into(database.matchRecords).insert(row),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database
            .into(database.matchRecords)
            .insert(
              row.copyWith(
                matchId: start(101).matchId,
                profileId: otherProfile,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      for (final changes in <String>[
        "status = 'unknown'",
        "status = 'completed'",
        "outcome = 'win'",
        'elapsed_ms = -1',
        "difficulty = 'unknown'",
        'metrics_version = 0',
        "status = 'interrupted', recovered_at_utc = 123",
        'island_count = 6',
        "match_id = 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'",
        "execution_id = '00000000-0000-0000-8000-000000000010'",
      ]) {
        await expectLater(
          database.customStatement('UPDATE match_records SET $changes'),
          throwsA(isA<SqliteException>()),
        );
      }
      await database
          .into(database.profiles)
          .insert(
            db.ProfilesCompanion.insert(
              profileId: otherProfile,
              avatarKey: 'island_01',
              createdAtUtc: 1,
              updatedAtUtc: 1,
              statsStartedAtUtc: 1,
            ),
          );
      final receipt = await store.complete(complete(start(100)));
      final entry = (await database.select(database.xpEntries).get()).last;
      await expectLater(
        database
            .into(database.xpEntries)
            .insert(entry.copyWith(entryId: 'different')),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database
            .into(database.xpEntries)
            .insert(
              entry.copyWith(entryId: 'mismatch', profileId: otherProfile),
            ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database
            .into(database.xpEntries)
            .insert(
              db.XpEntriesCompanion.insert(
                entryId: 'not-deterministic',
                profileId: profile,
                reason: 'legacy_import',
                amount: 3,
                rewardVersion: 'legacy_v1',
                totalXpBefore: 0,
                totalXpAfter: 3,
                createdAtUtc: 1,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      expect(await store.totalXp(profile), receipt.totalXpAfter);
      final indices = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      expect(
        indices.map((r) => r.read<String>('name')),
        containsAll([
          'match_history',
          'match_statistics',
          'legacy_import_once',
        ]),
      );
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
    },
  );

  test(
    'recovery requires ownership and rejects live execution; unknown end/metrics stay null',
    () async {
      final database = db.ProfileDatabase(NativeDatabase.memory());
      final lease = TestLease();
      final first = DriftProfileStore(
        database: database,
        executionId: execution,
        lease: lease,
        ids: FixedIds(),
        clock: FixedClock(),
      );
      await first.initialize(LegacyFixture(0));
      await first.recordStart(start(100));
      await expectLater(
        first.recoverInterrupted(
          profileId: profile,
          executionId: execution,
          recoveredAtUtc: now,
        ),
        throwsA(isA<StorageUnavailable>()),
      );
      final next = DriftProfileStore(
        database: database,
        executionId: nextExecution,
        lease: lease,
      );
      addTearDown(next.close);
      await next.recoverInterrupted(
        profileId: profile,
        executionId: execution,
        recoveredAtUtc: now,
      );
      final record = (await next.loadRecord(start(100).matchId))!;
      expect(record.status, MatchStatus.interrupted);
      expect(record.endedAtUtc, isNull);
      expect(record.metrics.isUnknown, isTrue);
      await next.recoverInterrupted(
        profileId: profile,
        executionId: execution,
        recoveredAtUtc: now,
      );
      lease.isHeld = false;
      expect(
        () => next.recordStart(start(101, executionId: nextExecution)),
        throwsA(isA<StorageUnavailable>()),
      );
    },
  );

  for (final version in [0, 999]) {
    test(
      'unknown/unversioned existing DB $version is preserved on open failure',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'conquest-unknown-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/profile.sqlite');
        final raw = sqlite3.open(file.path);
        raw.execute('CREATE TABLE keep_me(value TEXT)');
        raw.execute("INSERT INTO keep_me VALUES ('original')");
        raw.userVersion = version;
        raw.close();
        final database = db.ProfileDatabase(NativeDatabase(file));
        await expectLater(
          database.select(database.storageMeta).get(),
          throwsStateError,
        );
        await database.close();
        final check = sqlite3.open(file.path);
        expect(check.userVersion, version);
        expect(
          check.select('SELECT value FROM keep_me').single['value'],
          'original',
        );
        check.close();
      },
    );
  }

  test(
    'existing version 1 with unknown tables is rejected without rewriting',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute('CREATE TABLE keep_me(value TEXT)');
      raw.userVersion = 1;
      final database = db.ProfileDatabase(NativeDatabase.opened(raw));
      await expectLater(
        database.select(database.storageMeta).get(),
        throwsStateError,
      );
      expect(
        raw
            .select("SELECT name FROM sqlite_master WHERE type='table'")
            .single['name'],
        'keep_me',
      );
      expect(raw.userVersion, 1);
      await database.close();
    },
  );

  test(
    'corrupt database is reported and original bytes are untouched',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-corrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final bytes = List<int>.generate(512, (i) => i % 255);
      await file.writeAsBytes(bytes);
      final database = db.ProfileDatabase(NativeDatabase(file));
      await expectLater(
        database.select(database.storageMeta).get(),
        throwsA(isA<SqliteException>()),
      );
      await database.close();
      expect(await file.readAsBytes(), bytes);
    },
  );
}
