import 'dart:async';
import 'dart:convert';

import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/awards/award_storage.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'award_progress_test.dart' show awardMatch;
import 'match_persistence_controller_test.dart' show Harness;
import 'support/profile_fixture.dart';

const profileId = '00000000-0000-4000-8000-000000000001';
String matchId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

class MemoryAwardStorage implements AwardStorage {
  String? value;
  Object? readError;
  Object? writeError;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool loseAcknowledgment = false;
  int writes = 0;
  @override
  Future<String?> read() async {
    await readGate?.future;
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String next) async {
    writes++;
    await writeGate?.future;
    if (writeError != null) throw writeError!;
    value = next;
    if (loseAcknowledgment) throw StateError('Lost acknowledgment');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SharedPreferences award key never changes legacy XP, locale or audio keys',
    () async {
      SharedPreferences.setMockInitialValues({
        'conquest.rank.totalXp': 1234,
        'locale': 'ja',
        'bgm': false,
      });
      final storage = SharedPreferencesAwardStorage();
      await storage.write(AwardProfileCodec.encode(profileId, AwardProfile()));
      expect(
        AwardProfileCodec.decode((await storage.read())!, profileId).completed,
        isEmpty,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('conquest.rank.totalXp'), 1234);
      expect(preferences.getString('locale'), 'ja');
      expect(preferences.getBool('bgm'), false);
    },
  );

  test(
    'restart restores counters, coherent single-match progress, first completion and IDs',
    () async {
      final storage = MemoryAwardStorage();
      final manager = AwardManager(storage);
      final id = matchId(2);
      manager.begin(id, () async => profileId);
      await manager.complete(
        awardMatch(id: id, captures: 6, dispatches: 10, forces: 500, won: true),
      );
      final restored = AwardManager(storage);
      await restored.initialize(profileId);
      expect(restored.profile!.ribbons, manager.profile!.ribbons);
      expect(restored.profile!.completed.keys, manager.profile!.completed.keys);
      expect(restored.profile!.completed['capture_bronze']!.matchId, id);
      expect(
        restored.profile!.singleMatchProgress,
        manager.profile!.singleMatchProgress,
      );
      restored.begin(id, () async => profileId);
      await restored.complete(awardMatch(id: id, captures: 100));
      expect(restored.profile!.totals[AwardMetric.captures], 6);
      expect(restored.stateFor(id)!.evaluation!.ribbons, isEmpty);
    },
  );

  test(
    'delayed load freezes eligible assignments for already-started matches',
    () async {
      final storage = MemoryAwardStorage()..readGate = Completer<void>();
      final manager = AwardManager(storage);
      manager.begin(matchId(2), () async => profileId);
      manager.begin(matchId(3), () async => profileId);
      final first = manager.complete(
        awardMatch(id: matchId(2), captures: 100, dispatches: 100),
      );
      final second = manager.complete(awardMatch(id: matchId(3)));
      storage.readGate!.complete();
      await Future.wait([first, second]);
      expect(manager.profile!.completed, contains('capture_bronze'));
      expect(manager.profile!.completed, isNot(contains('capture_silver')));
      manager.begin(matchId(4), () async => profileId);
      await manager.complete(awardMatch(id: matchId(4)));
      expect(manager.profile!.completed, contains('capture_silver'));
    },
  );

  test(
    'failed write retains evaluation and retries latest whole snapshot without double grants',
    () async {
      final storage = MemoryAwardStorage()
        ..writeError = StateError('disk full');
      final manager = AwardManager(storage);
      final old = matchId(2);
      manager.begin(old, () async => profileId);
      await manager.complete(awardMatch(id: old, captures: 6));
      final evaluation = manager.stateFor(old)!.evaluation;
      expect(manager.stateFor(old)!.phase, AwardSavePhase.unsaved);
      expect(storage.value, isNull);
      final next = matchId(3);
      manager.begin(next, () async => profileId);
      await manager.complete(awardMatch(id: next, captures: 3));
      expect(manager.profile!.totals[AwardMetric.captures], 9);
      storage.writeError = null;
      await Future.wait(List.generate(10, (_) => manager.retry(old)));
      expect(manager.stateFor(old)!.evaluation, same(evaluation));
      expect(manager.stateFor(old)!.phase, AwardSavePhase.saved);
      expect(manager.stateFor(next)!.phase, AwardSavePhase.saved);
      expect(
        AwardProfileCodec.decode(storage.value!, profileId).ribbons['capture'],
        3,
      );
    },
  );

  test(
    'lost write acknowledgment remains idempotent on retry and restart',
    () async {
      final storage = MemoryAwardStorage()..loseAcknowledgment = true;
      final manager = AwardManager(storage);
      final id = matchId(2);
      manager.begin(id, () async => profileId);
      await manager.complete(awardMatch(id: id, captures: 30));
      expect(manager.stateFor(id)!.phase, AwardSavePhase.unsaved);
      storage.loseAcknowledgment = false;
      await manager.retry(id);
      expect(
        AwardProfileCodec.decode(storage.value!, profileId).ribbons['capture'],
        10,
      );
      expect(manager.stateFor(id)!.evaluation!.medals, {'capture': 1});
    },
  );

  test(
    'corruption, unknown schema/catalog, profile mismatch and negative counts never overwrite',
    () async {
      final valid =
          jsonDecode(AwardProfileCodec.encode(profileId, AwardProfile()))
              as Map<String, dynamic>;
      for (final raw in [
        'not json',
        jsonEncode({...valid, 'schemaVersion': 99}),
        jsonEncode({...valid, 'catalogVersion': 2}),
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
        final manager = AwardManager(storage);
        manager.begin(matchId(2), () async => profileId);
        await manager.complete(awardMatch(id: matchId(2), captures: 3));
        await manager.retry();
        expect(manager.error, isNotNull);
        expect(manager.profile, isNull);
        expect(storage.writes, 0);
        expect(storage.value, raw);
      }
    },
  );

  test(
    'read failure recovery retains frozen completion without inventing old XP statistics',
    () async {
      final storage = MemoryAwardStorage()..readError = StateError('read');
      final manager = AwardManager(storage);
      manager.begin(matchId(2), () async => profileId);
      await manager.complete(
        awardMatch(id: matchId(2), forces: 500, won: true),
      );
      expect(manager.stateFor(matchId(2))!.phase, AwardSavePhase.unsaved);
      storage.readError = null;
      await manager.retry();
      expect(manager.profile!.totals[AwardMetric.wins], 1);
      expect(manager.profile!.completed.length, 1);
    },
  );

  test(
    'terminal integration keeps XP independent and excludes abandoned and non-gameplay sessions',
    () async {
      final storage = MemoryAwardStorage()..value = 'broken';
      final awards = AwardManager(storage);
      final fixture = ProfileFixture(xp: 100, awards: awards);
      await fixture.ready();
      addTearDown(fixture.runtime.close);
      final h = Harness(fixture);
      addTearDown(h.dispose);
      h.play();
      final old = h.controller.currentMatchId!;
      await h.finish(const GameResult.victory(elapsedMs: 180000));
      expect(h.controller.currentSave!.phase, MatchSavePhase.saved);
      expect(h.controller.state.result!.xpAwarded, 1500);
      expect(awards.stateFor(old)!.phase, AwardSavePhase.unsaved);
      expect(storage.value, 'broken');
      h.controller.rematchGame();
      for (var i = 0; i < 60; i++) {
        h.loop.tick();
      }
      expect(h.controller.currentMatchId, isNot(old));
      h.controller.pauseGame();
      h.controller.returnToConfiguration();
      await fixture.runtime.drain();
      for (final origin in SessionOrigin.values.where(
        (o) => o != SessionOrigin.gameplay,
      )) {
        expect(
          fixture.runtime.begin(GameConfiguration.initial, origin: origin),
          isNull,
        );
      }
      expect(
        fixture.runtime.begin(
          GameConfiguration.initial.copyWith(gameMode: GameMode.cpuVsCpu),
        ),
        isNull,
      );
      expect(storage.writes, 0);
    },
  );

  test(
    'integration commits normal losses/draws, retry notifications, REMATCH and NEW MAP once',
    () async {
      final storage = MemoryAwardStorage();
      final awards = AwardManager(storage);
      final fixture = ProfileFixture(awards: awards);
      await fixture.ready();
      addTearDown(fixture.runtime.close);
      final summary = MatchSummary(
        playerCaptureCount: 3,
        playerDispatchCount: 10,
        playerDispatchedForces: 500,
      );
      final first = fixture.runtime.begin(GameConfiguration.initial)!;
      final result = const GameResult.defeat(elapsedMs: 1);
      await fixture.runtime.finish(first, result: result, summary: summary);
      await fixture.runtime.drain();
      await fixture.runtime.finish(first, result: result, summary: summary);
      await fixture.runtime.retry(first);
      expect(awards.profile!.ribbons['capture'], 1);
      expect(awards.profile!.ribbons['victory'] ?? 0, 0);
      final h = Harness(fixture);
      addTearDown(h.dispose);
      h.play();
      final id = h.controller.currentMatchId;
      await h.finish(const GameResult.draw(elapsedMs: 10));
      h.controller.rematchGame();
      for (var i = 0; i < 60; i++) {
        h.loop.tick();
      }
      expect(h.controller.currentMatchId, isNot(id));
      await h.finish(const GameResult.victory(elapsedMs: 10));
      h.controller.replayGame();
      for (var i = 0; i < 60; i++) {
        h.loop.tick();
      }
      await h.finish(const GameResult.victory(elapsedMs: 10));
      expect(awards.profile!.appliedMatches.length, 4);
      expect(awards.profile!.ribbons['victory'], 2);
    },
  );
}
