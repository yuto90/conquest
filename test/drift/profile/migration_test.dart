import 'dart:io';

import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/awards/award_storage.dart';
import 'package:conquest/profile/drift_profile_store.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/profile_database.dart' as db;
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide completion;
import 'package:sqlite3/sqlite3.dart';

import '../../award_progress_test.dart' show awardMatch;
import '../../award_storage_test.dart' show MemoryAwardStorage, completion;
import '../../profile_storage_test.dart' as fixture;
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

Future<Map<String, List<Map<String, Object?>>>> rows(
  GeneratedDatabase database,
) async => {
  for (final table in [
    'profiles',
    'match_records',
    'xp_entries',
    'storage_meta',
  ])
    table: [
      for (final row
          in await database
              .customSelect('SELECT * FROM $table ORDER BY 1')
              .get())
        Map<String, Object?>.of(row.data)..remove('award_required'),
    ],
};

Future<Map<String, List<Map<String, Object?>>>> seed(File file) async {
  final old = v1.DatabaseAtV1(NativeDatabase(file));
  final ms = fixture.now.millisecondsSinceEpoch;
  await old
      .into(old.profiles)
      .insert(
        v1.ProfilesData(
          profileId: fixture.profile,
          displayName: 'Keep my name',
          avatarKey: 'island_02',
          createdAtUtc: ms,
          updatedAtUtc: ms + 1,
          statsStartedAtUtc: ms,
        ),
      );
  final frozen = completion(fixture.start(2)).record;
  for (final record in [
    frozen,
    MatchRecord(
      start: fixture.start(3),
      status: MatchStatus.abandoned,
      endedAtUtc: frozen.endedAtUtc,
      metrics: frozen.metrics,
    ),
    MatchRecord(start: fixture.start(4), status: MatchStatus.inProgress),
  ]) {
    final s = record.start;
    final terminal = record.isTerminal;
    final win = record.outcome == MatchOutcome.win;
    await old
        .into(old.matchRecords)
        .insert(
          v1.MatchRecordsData(
            matchId: s.matchId,
            profileId: s.profileId,
            executionId: s.executionId,
            sessionKind: s.sessionKind.storageKey,
            origin: s.origin.name,
            gameMode: gameModeStorageKey(s.configuration.gameMode),
            difficulty: difficultyStorageKey(s.configuration.cpuDifficulty),
            playerCpuDifficulty: difficultyStorageKey(
              s.configuration.playerCpuDifficulty,
            ),
            islandCount: s.configuration.totalIslandCount,
            status: record.status.storageKey,
            outcome: record.outcome?.storageKey,
            startedAtUtc: s.startedAtUtc.millisecondsSinceEpoch,
            endedAtUtc: record.endedAtUtc?.millisecondsSinceEpoch,
            elapsedMs: record.metrics.elapsedMs,
            dispatchCount: record.metrics.dispatchCount,
            forcesSent: record.metrics.forcesSent,
            captures: record.metrics.captures,
            appVersion: s.appVersion,
            rulesVersion: s.rulesVersion,
            metricsVersion: s.metricsVersion,
            receiptXp: terminal ? (win ? 1500 : 0) : null,
            receiptBefore: terminal ? (win ? 50 : 1550) : null,
            receiptAfter: terminal ? 1550 : null,
            receiptRewardVersion: terminal ? '1' : null,
          ),
        );
  }
  for (final entry in [
    v1.XpEntriesData(
      entryId: 'legacy:${fixture.profile}',
      profileId: fixture.profile,
      reason: 'legacy_import',
      amount: 50,
      rewardVersion: '1',
      totalXpBefore: 0,
      totalXpAfter: 50,
      createdAtUtc: ms,
    ),
    v1.XpEntriesData(
      entryId: 'victory:${frozen.start.matchId}',
      profileId: fixture.profile,
      matchId: frozen.start.matchId,
      reason: 'match_victory',
      amount: 1500,
      rewardVersion: '1',
      totalXpBefore: 50,
      totalXpAfter: 1550,
      createdAtUtc: frozen.endedAtUtc!.millisecondsSinceEpoch,
    ),
  ]) {
    await old.into(old.xpEntries).insert(entry);
  }
  for (final entry in {
    DriftProfileStore.legacyMarker: 'done',
    DriftProfileStore.activeProfileKey: fixture.profile,
    'execution_id': fixture.execution,
  }.entries) {
    await old
        .into(old.storageMeta)
        .insert(v1.StorageMetaData(key: entry.key, value: entry.value));
  }
  final before = await rows(old);
  await old.close();
  return before;
}

Future<File> databaseFile() async {
  final directory = await Directory.systemTemp.createTemp(
    'conquest-v1-upgrade-',
  );
  addTearDown(() => directory.delete(recursive: true));
  return File('${directory.path}/profile.sqlite');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 to v2 matches checked-in schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final database = db.ProfileDatabase(schema.newConnection());
    await verifier.migrateAndValidate(database, 2);
    await database.close();
  });

  for (final point in db.ProfileUpgradeFaultPoint.values) {
    test(
      'schema upgrade $point is atomic with its version and safely restarts',
      () async {
        final file = await databaseFile();
        final before = await seed(file);
        var database = db.ProfileDatabase(
          NativeDatabase(file),
          upgradeFaultHook: (p) async {
            if (p == point) throw StateError('injected upgrade failure');
          },
        );
        await expectLater(
          database.select(database.storageMeta).get(),
          throwsStateError,
        );
        await database.close();
        final raw = sqlite3.open(file.path);
        final committed = point == db.ProfileUpgradeFaultPoint.afterCommit;
        expect(raw.userVersion, committed ? 2 : 1);
        final tables = raw
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .map((r) => r['name'])
            .toSet();
        expect(tables.contains('award_profiles'), committed);
        expect(tables.contains('award_match_states'), committed);
        expect(
          raw.select('SELECT * FROM profiles').single['display_name'],
          'Keep my name',
        );
        expect(
          raw.select('SELECT SUM(amount) AS xp FROM xp_entries').single['xp'],
          1550,
        );
        raw.close();
        database = db.ProfileDatabase(NativeDatabase(file));
        expect(await rows(database), before);
        await database.validateDatabaseSchema();
        expect(await database.select(database.awardProfiles).get(), isEmpty);
        expect(
          (await database.select(database.matchRecords).get()).every(
            (r) => !r.awardRequired,
          ),
          isTrue,
        );
        await database.close();
      },
    );
  }

  for (final point in [
    null,
    StorageFaultPoint.beforeAwardImport,
    StorageFaultPoint.afterAwardImport,
    StorageFaultPoint.beforeCommit,
    StorageFaultPoint.afterCommit,
  ]) {
    test(
      'populated v1 migration and legacy awards preserve all records and XP at $point',
      () async {
        final file = await databaseFile();
        final before = await seed(file);
        final baseline = AwardEvaluator.evaluate(
          AwardProfile(),
          awardMatch(
            id: fixture.start(9).matchId,
            captures: 27,
            dispatches: 10,
          ),
          AwardProfile().eligibleAssignments,
        ).profile;
        final raw = AwardProfileCodec.encode(fixture.profile, baseline);
        final source = MemoryAwardStorage()..value = raw;
        var store = fixture.makeStore(
          executor: NativeDatabase(file),
          legacyAwards: source,
          faultHook: (p) async {
            if (p == point) throw StateError('injected import failure');
          },
        );
        if (point != null) {
          await expectLater(
            store.initialize(fixture.LegacyFixture(9999)),
            throwsStateError,
          );
          final committedMeta = [
            ...before['storage_meta']!,
            <String, Object?>{
              'key': DriftProfileStore.awardMarker,
              'value': fixture.profile,
            },
          ]..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
          expect(
            await rows(store.database),
            point == StorageFaultPoint.afterCommit
                ? {...before, 'storage_meta': committedMeta}
                : before,
          );
          expect(await store.totalXp(fixture.profile), 1550);
          expect(source.value, raw);
          await store.close();
          store = fixture.makeStore(
            executor: NativeDatabase(file),
            legacyAwards: source,
          );
        }
        addTearDown(() => store.close());
        await store.initializeAndRecover(fixture.LegacyFixture(9999));
        expect(await store.totalXp(fixture.profile), 1550);
        expect(
          (await store.loadProfile(fixture.profile)).displayName,
          'Keep my name',
        );
        expect(
          (await store.loadProfile(fixture.profile)).avatarKey,
          'island_02',
        );
        expect(
          (await store.loadProfile(fixture.profile)).statsStartedAtUtc,
          fixture.now,
        );
        final after = await rows(store.database);
        for (final table in ['profiles', 'match_records', 'xp_entries']) {
          expect(after[table], before[table]);
        }
        expect(await store.loadAwards(fixture.profile), baseline);
        expect(
          (await store.database.select(store.database.awardProfiles).get())
              .single
              .legacySnapshot,
          raw,
        );
        expect(
          await store.database.select(store.database.awardMatchStates).get(),
          isEmpty,
        );
        final historical = completion(fixture.start(2));
        final receipt = await store.complete(historical);
        expect(receipt.awards, isNull);
        expect(await store.complete(historical), receipt);
        expect(await store.totalXp(fixture.profile), 1550);
        expect(await store.loadAwards(fixture.profile), baseline);
        await store.recordStart(fixture.start(5));
        final fresh = await store.complete(completion(fixture.start(5)));
        expect(fresh.awards!.ribbons['capture'], 10);
        expect(await store.totalXp(fixture.profile), 3050);
        expect((await store.loadAwards(fixture.profile)).appliedMatches, {
          fixture.start(9).matchId,
          fixture.start(5).matchId,
        });
        expect(source.value, raw);
      },
    );
  }

  test(
    'invalid legacy awards after v1 upgrade preserve existing profile/history/XP through retry/restart',
    () async {
      final file = await databaseFile();
      final before = await seed(file);
      final source = MemoryAwardStorage()..value = 'broken original';
      var store = fixture.makeStore(
        executor: NativeDatabase(file),
        legacyAwards: source,
      );
      await expectLater(
        store.initializeAndRecover(fixture.LegacyFixture(0)),
        throwsA(isA<FormatException>()),
      );
      expect(await rows(store.database), before);
      await store.close();
      store = fixture.makeStore(
        executor: NativeDatabase(file),
        legacyAwards: source,
      );
      addTearDown(store.close);
      await expectLater(
        store.initializeAndRecover(fixture.LegacyFixture(0)),
        throwsA(isA<FormatException>()),
      );
      expect(await rows(store.database), before);
      expect(await store.totalXp(fixture.profile), 1550);
      expect(
        await store.database.select(store.database.awardProfiles).get(),
        isEmpty,
      );
      expect(source.value, 'broken original');
    },
  );
}
