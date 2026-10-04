import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/awards/award_storage.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/drift_profile_store.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'award_progress_test.dart' show awardMatch;
import 'profile_storage_test.dart' as fixture;
import 'match_persistence_controller_test.dart' show Harness;
import 'support/profile_fixture.dart';

const profileId = fixture.profile;
String matchId(int n) => fixture.start(n).matchId;

class MemoryAwardStorage implements AwardStorage {
  String? value;
  Object? readError;
  Completer<void>? readGate;
  int reads = 0;
  @override
  Future<String?> read() async {
    reads++;
    await readGate?.future;
    if (readError != null) throw readError!;
    return value;
  }
}

MatchCompletion completion(
  MatchStartContext start, {
  int captures = 30,
  GameResultType type = GameResultType.victory,
  DateTime? endedAtUtc,
}) => MatchCompletion.fromGame(
  start: start,
  result: GameResult(
    type: type,
    winner: switch (type) {
      GameResultType.victory => Faction.player,
      GameResultType.defeat => Faction.cpu,
      GameResultType.draw => null,
    },
    elapsedMs: 180000,
  ),
  summary: MatchSummary(
    elapsedMs: 180000,
    playerCaptureCount: captures,
    playerDispatchCount: 10,
    playerDispatchedForces: 500,
  ),
  endedAtUtc: endedAtUtc ?? fixture.now.add(const Duration(minutes: 3)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy SharedPreferences import is read-only for awards, XP, locale and audio',
    () async {
      final raw = AwardProfileCodec.encode(profileId, AwardProfile());
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAwardStorage.key: raw,
        'conquest.rank.totalXp': 1234,
        'locale': 'ja',
        'bgm': false,
      });
      final store = fixture.makeStore(
        legacyAwards: SharedPreferencesAwardStorage(),
      );
      addTearDown(store.close);
      await store.initialize(fixture.LegacyFixture(1234));
      expect(await store.loadAwards(profileId), AwardProfile());
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(SharedPreferencesAwardStorage.key), raw);
      expect(preferences.getInt('conquest.rank.totalXp'), 1234);
      expect(preferences.getString('locale'), 'ja');
      expect(preferences.getBool('bgm'), false);
    },
  );

  for (final restart in [false, true]) {
    for (final point in [
      StorageFaultPoint.beforeMatch,
      StorageFaultPoint.afterMatch,
      StorageFaultPoint.beforeXp,
      StorageFaultPoint.afterXp,
      StorageFaultPoint.beforeAwards,
      StorageFaultPoint.afterAwards,
      StorageFaultPoint.beforeCommit,
      StorageFaultPoint.afterCommit,
    ]) {
      test(
        'atomic finalization $point, restart=$restart, exact retry and repeated receipt',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'conquest-award-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = File('${directory.path}/profile.sqlite');
          var armed = false;
          var store = fixture.makeStore(
            executor: NativeDatabase(file),
            faultHook: (p) async {
              if (armed && p == point) throw StateError('injected $point');
            },
          );
          addTearDown(() => store.close());
          await store.initialize(fixture.LegacyFixture(50));
          final start = fixture.start(2);
          await store.recordStart(start);
          final frozen = completion(start);
          armed = true;
          await expectLater(store.complete(frozen), throwsStateError);
          final committed = point == StorageFaultPoint.afterCommit;
          expect(
            (await store.loadRecord(start.matchId))!.status,
            committed ? MatchStatus.completed : MatchStatus.inProgress,
          );
          expect(await store.totalXp(profileId), committed ? 1550 : 50);
          expect(
            (await store.loadAwards(profileId)).ribbons['capture'] ?? 0,
            committed ? 10 : 0,
          );
          final awardRow =
              (await store.database
                      .select(store.database.awardMatchStates)
                      .get())
                  .single;
          expect(awardRow.evaluationReceipt != null, committed);
          expect(awardRow.profileId, start.profileId);
          expect(awardRow.catalogVersion, AwardCatalog.version);
          armed = false;
          if (restart) {
            await store.close();
            store = fixture.makeStore(executor: NativeDatabase(file));
            await store.initialize(fixture.LegacyFixture(9999));
          }
          final receipt = await store.complete(frozen);
          expect(receipt.record, frozen.record);
          expect(receipt.xpAwarded, 1500);
          expect(receipt.totalXpBefore, 50);
          expect(receipt.totalXpAfter, 1550);
          expect(receipt.awards!.ribbons['capture'], 10);
          expect(receipt.awards!.medals['capture'], 1);
          expect(receipt.awards!.assignments, contains('capture_bronze'));
          expect(
            receipt.awards!.assignments,
            isNot(contains('capture_silver')),
          );
          final copies = await Future.wait(
            List.generate(12, (_) => store.complete(frozen)),
          );
          expect(copies, everyElement(receipt));
          expect(await store.totalXp(profileId), 1550);
          expect((await store.loadAwards(profileId)).ribbons['capture'], 10);
          expect((await store.loadAwards(profileId)).appliedMatches, {
            start.matchId,
          });
          expect(
            await store.database.select(store.database.xpEntries).get(),
            hasLength(2),
          );
          await expectLater(
            store.complete(completion(start, captures: 31)),
            throwsA(isA<MatchCommitConflict>()),
          );
          await expectLater(
            store.complete(completion(start, type: GameResultType.defeat)),
            throwsA(isA<MatchCommitConflict>()),
          );
          final changedEnd = completion(
            start,
            endedAtUtc: frozen.record.endedAtUtc!.add(
              const Duration(milliseconds: 1),
            ),
          );
          await expectLater(
            store.complete(changedEnd),
            throwsA(isA<MatchCommitConflict>()),
          );
          await expectLater(
            store.recordStart(start, awardEligibility: AwardEligibility({})),
            throwsA(isA<MatchCommitConflict>()),
          );
          expect(await store.totalXp(profileId), 1550);
        },
      );
    }
  }

  for (final point in [
    StorageFaultPoint.beforeAwardImport,
    StorageFaultPoint.afterAwardImport,
    StorageFaultPoint.beforeCommit,
    StorageFaultPoint.afterCommit,
  ]) {
    test(
      'validated legacy baseline migration preserves data across $point, restart and retry',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'conquest-award-import-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/profile.sqlite');
        final baseline = AwardEvaluator.evaluate(
          AwardProfile(),
          awardMatch(id: matchId(9), captures: 27, dispatches: 5),
          AwardProfile().eligibleAssignments,
        ).profile;
        final raw = AwardProfileCodec.encode(profileId, baseline);
        final legacy = MemoryAwardStorage()..value = raw;
        var fail = true;
        var store = fixture.makeStore(
          executor: NativeDatabase(file),
          legacyAwards: legacy,
          faultHook: (p) async {
            if (fail && p == point) throw StateError('migration failure');
          },
        );
        await expectLater(
          store.initialize(fixture.LegacyFixture(9876)),
          throwsStateError,
        );
        expect(legacy.value, raw);
        await store.close();
        fail = false;
        store = fixture.makeStore(
          executor: NativeDatabase(file),
          legacyAwards: legacy,
        );
        addTearDown(store.close);
        await store.initialize(fixture.LegacyFixture(9876));
        expect(await store.totalXp(profileId), 9876);
        expect(await store.loadAwards(profileId), baseline);
        final row =
            (await store.database.select(store.database.awardProfiles).get())
                .single;
        expect(row.legacySnapshot, raw);
        final reads = legacy.reads;
        legacy.value = 'bad subsequent SharedPreferences value';
        await store.initialize(fixture.LegacyFixture(1));
        expect(legacy.reads, reads);
        expect(await store.loadAwards(profileId), baseline);
        await store.recordStart(fixture.start(2));
        final receipt = await store.complete(
          completion(fixture.start(2), captures: 6),
        );
        expect(receipt.awards!.ribbons['capture'], 2);
        expect(receipt.awards!.medals['capture'], 1);
        expect((await store.loadAwards(profileId)).ribbons['capture'], 11);
        expect((await store.loadAwards(profileId)).appliedMatches, {
          matchId(9),
          matchId(2),
        });
        expect(await store.totalXp(profileId), 11376);
      },
    );
  }

  test(
    'invalid legacy formats are never imported or reset on repeated attempts',
    () async {
      final valid =
          jsonDecode(AwardProfileCodec.encode(profileId, AwardProfile()))
              as Map<String, dynamic>;
      for (final raw in [
        'not json',
        jsonEncode({...valid, 'schemaVersion': 99}),
        jsonEncode({...valid, 'catalogVersion': 2}),
        jsonEncode({...valid, 'unknownField': 1}),
        jsonEncode({...valid, 'profileId': matchId(9)}),
        jsonEncode({
          ...valid,
          'ribbons': {'capture': -1},
        }),
        jsonEncode({
          ...valid,
          'ribbons': {'unknown': 1},
        }),
        jsonEncode({
          ...valid,
          'totals': {'elapsedMs': 1},
        }),
        jsonEncode({
          ...valid,
          'totals': {'captureRibbons': 1},
        }),
        jsonEncode({
          ...valid,
          'appliedMatches': [matchId(2), matchId(2)],
        }),
        jsonEncode({
          ...valid,
          'appliedMatches': ['not-a-uuid'],
        }),
        jsonEncode({
          ...valid,
          'singleMatchProgress': {'unknown': {}},
        }),
        jsonEncode({
          ...valid,
          'singleMatchProgress': {'capture_bronze': {}},
        }),
        jsonEncode({
          ...valid,
          'completed': {'unknown': {}},
        }),
        jsonEncode({
          ...valid,
          'completed': {
            'capture_bronze': {
              'matchId': matchId(2),
              'atUtc': DateTime.utc(2026).toIso8601String(),
            },
          },
        }),
        jsonEncode({
          ...valid,
          'appliedMatches': [matchId(2)],
          'completed': {
            'capture_silver': {
              'matchId': matchId(2),
              'atUtc': DateTime.utc(2026).toIso8601String(),
            },
          },
        }),
      ]) {
        final storage = MemoryAwardStorage()..value = raw;
        final store = fixture.makeStore(legacyAwards: storage);
        await expectLater(
          store.initialize(fixture.LegacyFixture(500)),
          throwsA(anything),
        );
        await expectLater(
          store.initialize(fixture.LegacyFixture(500)),
          throwsA(anything),
        );
        expect(storage.value, raw);
        expect(
          await store.database.select(store.database.profiles).get(),
          isEmpty,
        );
        expect(
          await store.database.select(store.database.xpEntries).get(),
          isEmpty,
        );
        expect(
          await store.database.select(store.database.awardProfiles).get(),
          isEmpty,
        );
        expect(
          await store.database.select(store.database.storageMeta).get(),
          isEmpty,
        );
        await store.close();
      }
    },
  );

  test(
    'failed legacy read and wrong SharedPreferences value type are not empty baselines',
    () async {
      final source = MemoryAwardStorage()
        ..readError = StateError('unavailable');
      final store = fixture.makeStore(legacyAwards: source);
      addTearDown(store.close);
      await expectLater(
        store.initialize(fixture.LegacyFixture(100)),
        throwsStateError,
      );
      expect(
        await store.database.select(store.database.awardProfiles).get(),
        isEmpty,
      );
      source.readError = null;
      await store.initialize(fixture.LegacyFixture(100));
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAwardStorage.key: 123,
      });
      final other = fixture.makeStore(
        legacyAwards: SharedPreferencesAwardStorage(),
      );
      addTearDown(other.close);
      await expectLater(
        other.initialize(fixture.LegacyFixture(100)),
        throwsA(anything),
      );
      expect(
        (await SharedPreferences.getInstance()).get(
          SharedPreferencesAwardStorage.key,
        ),
        123,
      );
    },
  );

  test(
    'corrupt durable award snapshot blocks finalization without losing existing XP/history',
    () async {
      final store = fixture.makeStore();
      addTearDown(store.close);
      await store.initialize(fixture.LegacyFixture(100));
      await store.recordStart(fixture.start(2));
      final receipt = await store.complete(completion(fixture.start(2)));
      await store.database.customStatement(
        "UPDATE award_profiles SET snapshot = 'broken'",
      );
      await store.recordStart(fixture.start(2));
      await expectLater(
        store.initialize(fixture.LegacyFixture(0)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        store.recordStart(fixture.start(3)),
        throwsA(isA<FormatException>()),
      );
      expect(await store.totalXp(profileId), 1600);
      expect(await store.loadRecord(matchId(2)), receipt.record);
      expect(
        (await store.database.select(store.database.awardProfiles).get())
            .single
            .snapshot,
        'broken',
      );
      await store.database.customStatement(
        "UPDATE award_match_states SET evaluation_receipt = 'broken'",
      );
      await expectLater(
        store.complete(completion(fixture.start(2))),
        throwsA(isA<FormatException>()),
      );
      expect(await store.totalXp(profileId), 1600);
    },
  );

  test(
    'delayed recovery freezes eligibility for all already-started matches, never retroactive tiers',
    () async {
      final source = MemoryAwardStorage()
        ..readError = StateError('temporarily offline');
      final awards = AwardManager();
      final f = ProfileFixture(awards: awards, legacyAwards: source);
      addTearDown(f.runtime.close);
      await f.ready();
      expect(f.runtime.initializationError, isNotNull);
      source.readError = null;
      source.readGate = Completer<void>();
      final first = f.runtime.begin(GameConfiguration.initial)!;
      final second = f.runtime.begin(GameConfiguration.initial)!;
      final one = f.runtime.finish(
        first,
        result: const GameResult.defeat(elapsedMs: 1),
        summary: const MatchSummary(
          elapsedMs: 1,
          playerCaptureCount: 100,
          playerDispatchCount: 100,
        ),
      );
      final two = f.runtime.finish(
        second,
        result: const GameResult.defeat(elapsedMs: 1),
        summary: const MatchSummary(elapsedMs: 1, playerCaptureCount: 1),
      );
      source.readGate!.complete();
      await Future.wait([one, two]);
      expect(awards.profile!.completed, contains('capture_bronze'));
      expect(awards.profile!.completed, isNot(contains('capture_silver')));
      final third = f.runtime.begin(GameConfiguration.initial)!;
      await f.runtime.finish(
        third,
        result: const GameResult.defeat(elapsedMs: 1),
        summary: const MatchSummary(elapsedMs: 1),
      );
      expect(awards.profile!.completed, contains('capture_silver'));
    },
  );

  test(
    'result saved cannot coexist with failed awards; exact UI retry commits XP and awards once',
    () async {
      var fail = true;
      final awards = AwardManager();
      final f = ProfileFixture(
        xp: 100,
        awards: awards,
        faultHook: (p) async {
          if (fail && p == StorageFaultPoint.afterAwards)
            throw StateError('disk full');
        },
      );
      await f.ready();
      addTearDown(f.runtime.close);
      final id = f.runtime.begin(GameConfiguration.initial)!;
      const result = GameResult.victory(elapsedMs: 180000);
      const summary = MatchSummary(elapsedMs: 180000, playerCaptureCount: 30);
      await f.runtime.finish(id, result: result, summary: summary);
      final preview = awards.stateFor(id)!.evaluation;
      expect(f.runtime.saveFor(id)!.phase, MatchSavePhase.unsaved);
      expect(awards.stateFor(id)!.phase, AwardSavePhase.unsaved);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 100);
      expect(awards.profile!.ribbons, isEmpty);
      expect(preview!.medals['capture'], 1);
      fail = false;
      f.clock.time = f.clock.time.add(const Duration(days: 1));
      await Future.wait(List.generate(10, (_) => f.runtime.retryAwards(id)));
      expect(f.runtime.saveFor(id)!.phase, MatchSavePhase.saved);
      expect(awards.stateFor(id)!.phase, AwardSavePhase.saved);
      expect(awards.stateFor(id)!.evaluation, preview);
      expect(
        f.runtime.saveFor(id)!.receipt!.record.endedAtUtc,
        DateTime.utc(2026, 10, 2),
      );
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 1600);
      expect(awards.profile!.ribbons['capture'], 10);
      await f.runtime.finish(id, result: result, summary: summary);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 1600);
    },
  );

  test(
    'lost acknowledgment, newer commit, then old retry never regresses projection or doubles grants',
    () async {
      var finalized = false;
      var fail = true;
      final awards = AwardManager();
      final f = ProfileFixture(
        awards: awards,
        faultHook: (p) async {
          if (p == StorageFaultPoint.afterAwards) finalized = true;
          if (finalized && fail && p == StorageFaultPoint.afterCommit) {
            fail = false;
            throw StateError('lost response');
          }
        },
      );
      await f.ready();
      addTearDown(f.runtime.close);
      final old = f.runtime.begin(GameConfiguration.initial)!;
      await f.runtime.finish(
        old,
        result: const GameResult.victory(elapsedMs: 1),
        summary: const MatchSummary(elapsedMs: 1, playerCaptureCount: 30),
      );
      expect(awards.stateFor(old)!.phase, AwardSavePhase.unsaved);
      final next = f.runtime.begin(GameConfiguration.initial)!;
      await f.runtime.finish(
        next,
        result: const GameResult.victory(elapsedMs: 1),
        summary: const MatchSummary(elapsedMs: 1, playerCaptureCount: 6),
      );
      expect(awards.profile!.ribbons['capture'], 12);
      await f.runtime.retryAwards(old);
      expect(awards.profile!.ribbons['capture'], 12);
      expect(awards.stateFor(old)!.evaluation!.ribbons['capture'], 10);
      expect(awards.stateFor(next)!.evaluation!.ribbons['capture'], 2);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 3000);
    },
  );

  test(
    'corrupt migration blocks match and XP UI success instead of allowing a partial save',
    () async {
      final source = MemoryAwardStorage()..value = 'broken';
      final awards = AwardManager();
      final f = ProfileFixture(xp: 100, awards: awards, legacyAwards: source);
      await f.ready();
      addTearDown(f.runtime.close);
      final h = Harness(f);
      addTearDown(h.dispose);
      h.play();
      final id = h.controller.currentMatchId!;
      await h.finish(const GameResult.victory(elapsedMs: 180000));
      expect(h.controller.currentSave!.phase, MatchSavePhase.unsaved);
      expect(h.controller.state.result!.xpAwarded, 0);
      expect(awards.stateFor(id)!.phase, AwardSavePhase.unsaved);
      expect(source.value, 'broken');
      expect(
        await f.store.database.select(f.store.database.matchRecords).get(),
        isEmpty,
      );
      expect(
        await f.store.database.select(f.store.database.xpEntries).get(),
        isEmpty,
      );
      source.value = null;
      await f.runtime.retryAwards(id);
      expect(h.controller.currentSave!.phase, MatchSavePhase.saved);
      expect(h.controller.state.result!.xpAwarded, 1500);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 1600);
    },
  );

  test(
    'loss/draw actions persist, abandon and non-gameplay never grant awards; XP amounts unchanged',
    () async {
      final awards = AwardManager();
      final f = ProfileFixture(awards: awards);
      await f.ready();
      addTearDown(f.runtime.close);
      for (final result in [
        const GameResult.defeat(elapsedMs: 1),
        const GameResult.draw(elapsedMs: 1),
      ]) {
        final id = f.runtime.begin(GameConfiguration.initial)!;
        await f.runtime.finish(
          id,
          result: result,
          summary: const MatchSummary(
            elapsedMs: 1,
            playerCaptureCount: 3,
            playerDispatchCount: 10,
            playerDispatchedForces: 500,
          ),
        );
        await f.runtime.finish(
          id,
          result: result,
          summary: const MatchSummary(
            elapsedMs: 1,
            playerCaptureCount: 3,
            playerDispatchCount: 10,
            playerDispatchedForces: 500,
          ),
        );
        expect(f.runtime.saveFor(id)!.receipt!.xpAwarded, 0);
      }
      final id = f.runtime.begin(GameConfiguration.initial)!;
      await f.runtime.abandon(
        id,
        const MatchSummary(elapsedMs: 1, playerCaptureCount: 30),
      );
      expect(f.runtime.saveFor(id)!.receipt!.awards, isNull);
      expect(awards.stateFor(id), isNull);
      for (final origin in SessionOrigin.values.where(
        (o) => o != SessionOrigin.gameplay,
      )) {
        expect(
          f.runtime.begin(GameConfiguration.initial, origin: origin),
          isNull,
        );
      }
      expect(
        f.runtime.begin(
          GameConfiguration.initial.copyWith(gameMode: GameMode.cpuVsCpu),
        ),
        isNull,
      );
      expect(awards.profile!.appliedMatches, hasLength(2));
      expect(awards.profile!.ribbons['capture'], 2);
      expect(awards.profile!.ribbons['victory'] ?? 0, 0);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 0);
      for (final pair in [
        (CpuDifficulty.veryEasy, 500),
        (CpuDifficulty.easy, 1000),
        (CpuDifficulty.normal, 1500),
        (CpuDifficulty.hard, 3000),
      ]) {
        final id = f.runtime.begin(
          GameConfiguration.initial.copyWith(cpuDifficulty: pair.$1),
        )!;
        await f.runtime.finish(
          id,
          result: const GameResult.victory(elapsedMs: 180000),
          summary: const MatchSummary(elapsedMs: 180000),
        );
        expect(f.runtime.saveFor(id)!.receipt!.xpAwarded, pair.$2);
      }
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 6000);
    },
  );

  for (final point in [
    StorageFaultPoint.beforeCommit,
    StorageFaultPoint.afterCommit,
  ]) {
    test(
      'start context is atomic at $point and survives reopening with fixed eligibility',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'conquest-award-start-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/profile.sqlite');
        var armed = false;
        var store = fixture.makeStore(
          executor: NativeDatabase(file),
          faultHook: (p) async {
            if (armed && p == point) throw StateError('start failure');
          },
        );
        await store.initialize(fixture.LegacyFixture(500));
        final frozen = fixture.start(2);
        final eligibility = AwardEligibility(
          AwardProfile().eligibleAssignments,
        );
        armed = true;
        await expectLater(
          store.recordStart(frozen, awardEligibility: eligibility),
          throwsStateError,
        );
        expect(
          await store.database.select(store.database.matchRecords).get(),
          point == StorageFaultPoint.afterCommit ? hasLength(1) : isEmpty,
        );
        expect(
          await store.database.select(store.database.awardMatchStates).get(),
          point == StorageFaultPoint.afterCommit ? hasLength(1) : isEmpty,
        );
        await store.close();
        store = fixture.makeStore(executor: NativeDatabase(file));
        addTearDown(store.close);
        await store.initialize(fixture.LegacyFixture(0));
        await store.recordStart(frozen, awardEligibility: eligibility);
        final receipt = await store.complete(completion(frozen));
        expect(receipt.awards!.assignments, isNot(contains('capture_silver')));
        expect(await store.totalXp(profileId), 2000);
      },
    );
  }

  for (final committed in [false, true]) {
    test(
      'new execution recovers failed result safely; committed=$committed',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'conquest-award-execution-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/profile.sqlite');
        var armed = false;
        var store = fixture.makeStore(
          executor: NativeDatabase(file),
          faultHook: (p) async {
            if (armed &&
                p ==
                    (committed
                        ? StorageFaultPoint.afterCommit
                        : StorageFaultPoint.afterAwards))
              throw StateError('result failure');
          },
        );
        await store.initialize(fixture.LegacyFixture(500));
        final frozen = completion(fixture.start(2));
        await store.recordStart(frozen.record.start);
        armed = true;
        await expectLater(store.complete(frozen), throwsStateError);
        await store.close();
        store = fixture.makeStore(
          executor: NativeDatabase(file),
          executionId: fixture.nextExecution,
        );
        addTearDown(store.close);
        await store.initializeAndRecover(fixture.LegacyFixture(0));
        expect(
          (await store.loadRecord(matchId(2)))!.status,
          committed ? MatchStatus.completed : MatchStatus.interrupted,
        );
        expect(await store.totalXp(profileId), committed ? 2000 : 500);
        expect(
          (await store.loadAwards(profileId)).ribbons['capture'] ?? 0,
          committed ? 10 : 0,
        );
        if (committed) {
          await store.recordStart(frozen.record.start);
          final receipt = await store.complete(frozen);
          expect(receipt.awards!.ribbons['capture'], 10);
          expect(await store.complete(frozen), receipt);
        } else {
          await expectLater(
            store.complete(frozen),
            throwsA(isA<MatchCommitConflict>()),
          );
        }
        expect(await store.totalXp(profileId), committed ? 2000 : 500);
      },
    );
  }

  test(
    'missing new-match state and unknown catalog cannot masquerade as legacy receipts',
    () async {
      final store = fixture.makeStore();
      addTearDown(store.close);
      await store.initialize(fixture.LegacyFixture(0));
      final frozen = completion(fixture.start(2));
      await store.recordStart(frozen.record.start);
      await store.database.customStatement(
        'UPDATE award_match_states SET catalog_version = 99',
      );
      await expectLater(
        store.complete(frozen),
        throwsA(isA<FormatException>()),
      );
      expect(
        (await store.loadRecord(matchId(2)))!.status,
        MatchStatus.inProgress,
      );
      expect(await store.totalXp(profileId), 0);
      await store.database.customStatement(
        'UPDATE award_match_states SET catalog_version = 1',
      );
      await store.complete(frozen);
      await store.database.customStatement('DELETE FROM award_match_states');
      await expectLater(store.complete(frozen), throwsStateError);
      expect(await store.totalXp(profileId), 1500);
      expect((await store.loadAwards(profileId)).ribbons['capture'], 10);
    },
  );

  test(
    'SQL enforces award profile/match pairing and invalid eligible IDs fail atomically',
    () async {
      final store = fixture.makeStore();
      addTearDown(store.close);
      await store.initialize(fixture.LegacyFixture(0));
      await store.recordStart(fixture.start(2));
      await store.database.customStatement(
        'INSERT INTO profiles SELECT ?, display_name, avatar_key, created_at_utc, updated_at_utc, stats_started_at_utc FROM profiles',
        [fixture.otherProfile],
      );
      await store.database.customStatement(
        'INSERT INTO award_profiles(profile_id, snapshot) VALUES (?, ?)',
        [
          fixture.otherProfile,
          AwardProfileCodec.encode(fixture.otherProfile, AwardProfile()),
        ],
      );
      await expectLater(
        store.database.customStatement(
          'UPDATE award_match_states SET profile_id = ?',
          [fixture.otherProfile],
        ),
        throwsA(isA<SqliteException>()),
      );
      await store.database.customStatement(
        "UPDATE award_match_states SET eligible_assignments = '[\"unknown_assignment\"]'",
      );
      await expectLater(
        store.complete(completion(fixture.start(2))),
        throwsA(isA<FormatException>()),
      );
      expect(await store.totalXp(profileId), 0);
      expect(
        (await store.loadRecord(matchId(2)))!.status,
        MatchStatus.inProgress,
      );
    },
  );

  test(
    'mismatched/unknown receipt JSON is preserved and never replayed as another match',
    () async {
      final store = fixture.makeStore();
      addTearDown(store.close);
      await store.initialize(fixture.LegacyFixture(0));
      final frozen = completion(fixture.start(2));
      await store.recordStart(frozen.record.start);
      await store.complete(frozen);
      final state =
          (await store.database.select(store.database.awardMatchStates).get())
              .single;
      final valid =
          jsonDecode(state.evaluationReceipt!) as Map<String, dynamic>;
      for (final invalid in [
        {...valid, 'matchId': matchId(999)},
        {...valid, 'schemaVersion': 2},
        {...valid, 'unknownField': true},
        {
          ...valid,
          'medals': {'capture': 99},
        },
        {
          ...valid,
          'assignments': ['capture_gold'],
        },
      ]) {
        final raw = jsonEncode(invalid);
        await store.database.customStatement(
          'UPDATE award_match_states SET evaluation_receipt = ?',
          [raw],
        );
        await expectLater(
          store.complete(frozen),
          throwsA(isA<FormatException>()),
        );
        expect(await store.totalXp(profileId), 1500);
        expect((await store.loadAwards(profileId)).ribbons['capture'], 10);
        expect(
          (await store.database.select(store.database.awardMatchStates).get())
              .single
              .evaluationReceipt,
          raw,
        );
      }
    },
  );

  test(
    'storage close drains the transaction through award receipt before releasing ownership',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-award-close-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final entered = Completer<void>();
      final release = Completer<void>();
      var store = fixture.makeStore(
        executor: NativeDatabase(file),
        faultHook: (p) async {
          if (p == StorageFaultPoint.afterAwards) {
            entered.complete();
            await release.future;
          }
        },
      );
      await store.initialize(fixture.LegacyFixture(0));
      final frozen = completion(fixture.start(2));
      await store.recordStart(frozen.record.start);
      final saving = store.complete(frozen);
      await entered.future;
      var closed = false;
      final closing = store.close().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      expect(store.lease.isHeld, isTrue);
      release.complete();
      final receipt = await saving;
      await closing;
      expect(store.lease.isHeld, isFalse);
      store = fixture.makeStore(
        executor: NativeDatabase(file),
        executionId: fixture.nextExecution,
      );
      addTearDown(store.close);
      await store.initializeAndRecover(fixture.LegacyFixture(0));
      expect(await store.complete(frozen), receipt);
      expect(await store.totalXp(profileId), 1500);
      expect((await store.loadAwards(profileId)).ribbons['capture'], 10);
    },
  );
}
