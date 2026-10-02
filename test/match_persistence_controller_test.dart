import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/legacy_xp.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_database.dart';
import 'package:conquest/profile/storage_lease.dart';
import 'package:conquest/rank_progression.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/profile_fixture.dart';

final class Harness {
  Harness(this.fixture, {SessionOrigin origin = SessionOrigin.gameplay}) {
    container = ProviderContainer(
      overrides: [
        matchPersistenceProvider.overrideWithValue(fixture.runtime),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        gameSessionOriginProvider.overrideWithValue(origin),
      ],
    );
    subscription = container.listen(gameControllerProvider, (_, _) {});
    controller = container.read(gameControllerProvider.notifier);
  }
  final ProfileFixture fixture;
  final ManualGameLoop loop = ManualGameLoop();
  late final ProviderContainer container;
  late final ProviderSubscription<GameState> subscription;
  late final GameController controller;
  void play() {
    controller.startGame();
    for (var i = 0; i < 60; i++) {
      loop.tick();
    }
    expect(controller.state.phase, GamePhase.playing);
  }

  Future<void> finish(GameResult result) async {
    controller.finish(result);
    await fixture.runtime.drain();
  }

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

Future<ProfileFixture> ready({int? xp}) async {
  final fixture = ProfileFixture(xp: xp);
  await fixture.ready();
  addTearDown(fixture.runtime.close);
  return fixture;
}

void main() {
  test(
    'result retry restores an initially failed rank stream from the ledger',
    () async {
      final f = ProfileFixture();
      addTearDown(f.runtime.close);
      f.openError = const StorageUnavailable('temporary open failure');
      await f.ready();
      final h = Harness(f);
      addTearDown(h.dispose);
      final subscription = h.container.listen(rankProgressProvider, (_, _) {});
      addTearDown(subscription.close);
      await expectLater(
        h.container.read(rankProgressProvider.future),
        throwsA(isA<StorageUnavailable>()),
      );
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 50));
      f.openError = null;
      await f.runtime.retry(h.controller.currentMatchId!);
      expect(
        (await h.container.read(rankProgressProvider.future)).totalXp,
        1500,
      );
    },
  );

  test(
    'transient initialization retry does not block result or rematch navigation',
    () async {
      final f = ProfileFixture();
      addTearDown(f.runtime.close);
      f.openError = const StorageUnavailable('temporary open failure');
      await f.ready();
      f.openError = null;
      f.legacy.gate = Completer<void>();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.play();
      await Future<void>.delayed(Duration.zero);
      expect(f.runtime.canStart, isTrue);
      final old = h.controller.currentMatchId!;
      h.controller.finish(const GameResult.victory(elapsedMs: 50));
      h.controller.rematchGame();
      expect(h.controller.state.phase, GamePhase.startCountdown);
      f.legacy.gate!.complete();
      await f.runtime.drain();
      expect(f.runtime.saveFor(old)!.receipt!.xpAwarded, 1500);
    },
  );

  test(
    'closing during failed migration releases the backend and is idempotent',
    () async {
      final f = ProfileFixture();
      f.legacy.gate = Completer<void>();
      f.legacy.error = StateError('legacy read failure');
      final preparing = f.runtime.prepare();
      await Future<void>.delayed(Duration.zero);
      final closing = f.runtime.close();
      expect(f.runtime.close(), same(closing));
      f.legacy.gate!.complete();
      await preparing;
      await closing;
      expect(f.runtime.initializationError, isA<StateError>());
      expect(f.runtime.canStart, isFalse);
    },
  );

  test(
    'root migrates once and gameplay never writes the legacy XP key',
    () async {
      SharedPreferences.setMockInitialValues({legacyXpStorageKey: 2500});
      final f = ProfileFixture(legacySource: SharedPreferencesLegacyXpSource());
      await f.ready();
      addTearDown(f.runtime.close);
      final h = Harness(f);
      addTearDown(h.dispose);
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 50));
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 4000);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.get(legacyXpStorageKey), 2500);
    },
  );

  test(
    'cold root recovers only prior execution, atomically and retryably',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final first = ProfileFixture(
        database: ProfileDatabase(NativeDatabase(file)),
      );
      await first.ready();
      final h = Harness(first);
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 10));
      final completed = h.controller.currentMatchId!;
      h.controller.rematchGame();
      for (var i = 0; i < 60; i++) h.loop.tick();
      h.controller.pauseGame();
      final unfinished = h.controller.currentMatchId!;
      await first.runtime.drain();
      await first.runtime.prepare();
      expect(
        (await first.store.loadRecord(unfinished))!.status,
        MatchStatus.inProgress,
      );
      h.dispose();
      await first.runtime.close();

      final ids = FixtureIds();
      for (var i = 0; i < 20; i++) ids.next();
      final next = ProfileFixture(
        database: ProfileDatabase(NativeDatabase(file)),
        ids: ids,
      );
      addTearDown(next.runtime.close);
      next.saveError = StateError('recovery write failed');
      await next.ready();
      expect(next.runtime.profile, isNull);
      expect(
        (await next.store.loadRecord(unfinished))!.status,
        MatchStatus.inProgress,
      );
      final meta = await next.store.database
          .select(next.store.database.storageMeta)
          .get();
      expect(
        meta.singleWhere((m) => m.key == 'execution_id').value,
        first.runtime.factory.executionId,
      );
      next.saveError = null;
      next.clock.time = DateTime.utc(2026, 10, 3);
      await next.runtime.retry();
      final recovered = (await next.store.loadRecord(unfinished))!;
      expect(recovered.status, MatchStatus.interrupted);
      expect(recovered.outcome, isNull);
      expect(recovered.endedAtUtc, isNull);
      expect(recovered.metrics, MatchMetrics());
      expect(recovered.recoveredAtUtc, next.clock.time);
      expect(
        (await next.store.loadRecord(completed))!.status,
        MatchStatus.completed,
      );
      expect(await next.store.totalXp(next.runtime.profile!.profileId), 1500);
      final current = Harness(next);
      addTearDown(current.dispose);
      current.play();
      await next.runtime.drain();
      await next.runtime.prepare();
      expect(
        (await next.store.loadRecord(
          current.controller.currentMatchId!,
        ))!.status,
        MatchStatus.inProgress,
      );
    },
  );

  test(
    'synchronous start-save listener finalizes without dropping the DTO',
    () async {
      final f = await ready();
      final h = Harness(f);
      addTearDown(h.dispose);
      void finishAfterStart() {
        final save = h.controller.currentSave;
        if (save?.phase == MatchSavePhase.saved &&
            save?.receipt == null &&
            h.controller.state.phase == GamePhase.playing) {
          h.controller.finish(const GameResult.victory(elapsedMs: 50));
        }
      }

      f.runtime.addListener(finishAfterStart);
      addTearDown(() => f.runtime.removeListener(finishAfterStart));
      h.play();
      await f.runtime.drain();
      expect(h.controller.currentSave!.receipt!.xpAwarded, 1500);
    },
  );

  test(
    'immediate rematch on result notification cannot discard finalization or stop the new loop',
    () async {
      final f = await ready();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.play();
      final id = h.controller.currentMatchId!;
      final subscription = h.container.listen(gameControllerProvider, (
        _,
        state,
      ) {
        if (state.phase == GamePhase.result) h.controller.rematchGame();
      });
      addTearDown(subscription.close);
      h.controller.finish(const GameResult.victory(elapsedMs: 50));
      expect(h.controller.state.phase, GamePhase.startCountdown);
      expect(h.loop.isRunning, isTrue);
      await f.runtime.drain();
      expect(f.runtime.saveFor(id)!.receipt!.xpAwarded, 1500);
      expect(h.controller.state.result, isNull);
    },
  );

  for (final difficulty in CpuDifficulty.values) {
    test(
      'real controller commits $difficulty reward and original receipt ten times',
      () async {
        final f = await ready(xp: 2500);
        final h = Harness(f);
        addTearDown(h.dispose);
        h.controller.selectCpuDifficulty(difficulty);
        h.play();
        final id = h.controller.currentMatchId!;
        await h.finish(const GameResult.victory(elapsedMs: 100));
        final receipt = f.runtime.saveFor(id)!.receipt!;
        expect(receipt.xpAwarded, victoryXpFor(difficulty));
        expect(receipt.totalXpBefore, 2500);
        expect(receipt.totalXpAfter, 2500 + victoryXpFor(difficulty));
        expect(
          h.controller.state.result!.rankAfter,
          RankProgress.fromTotalXp(receipt.totalXpAfter).rank,
        );
        final record = (await f.store.loadRecord(id))!;
        final completion = MatchCompletion.fromGame(
          start: record.start,
          result: const GameResult.victory(elapsedMs: 100),
          summary: h.controller.state.matchSummary,
          endedAtUtc: record.endedAtUtc!,
        );
        for (var i = 0; i < 10; i++) {
          h.controller.finish(const GameResult.victory(elapsedMs: 100));
          expect(await f.store.complete(completion), receipt);
        }
        expect(
          await f.store.totalXp(record.start.profileId),
          receipt.totalXpAfter,
        );
        expect(
          await f.store.database.select(f.store.database.matchRecords).get(),
          hasLength(1),
        );
        await expectLater(
          f.store.complete(
            MatchCompletion.fromGame(
              start: record.start,
              result: const GameResult.defeat(elapsedMs: 100),
              summary: h.controller.state.matchSummary,
              endedAtUtc: record.endedAtUtc!,
            ),
          ),
          throwsA(isA<MatchCommitConflict>()),
        );
      },
    );
  }

  test('rank MAX retains uncapped ledger and saved result snapshots', () async {
    final f = await ready(xp: RankCatalog.cumulativeXp.last + 123);
    final h = Harness(f);
    addTearDown(h.dispose);
    h.play();
    await h.finish(const GameResult.victory(elapsedMs: 0));
    expect(h.controller.state.result!.rankBefore, 140);
    expect(h.controller.state.result!.rankAfter, 140);
    expect(
      h.controller.state.result!.totalXpAfter,
      RankCatalog.cumulativeXp.last + 1623,
    );
  });

  test(
    'wins losses draws survive reopen; rematch/new map have distinct IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'conquest-controller',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/profile.sqlite');
      final f = ProfileFixture(
        database: ProfileDatabase(NativeDatabase(file)),
        xp: 2500,
      );
      await f.ready();
      final h = Harness(f);
      final ids = <String>[];
      for (final result in [
        const GameResult.victory(elapsedMs: 123),
        const GameResult.defeat(elapsedMs: 456),
        const GameResult.draw(elapsedMs: 789),
      ]) {
        if (ids.isEmpty) {
          h.play();
        } else {
          if (ids.length == 1) {
            h.controller.rematchGame();
          } else {
            h.controller.replayGame();
          }
          for (var i = 0; i < 60; i++) {
            h.loop.tick();
          }
        }
        ids.add(h.controller.currentMatchId!);
        await h.finish(result);
      }
      expect(ids.toSet(), hasLength(3));
      final profile = f.runtime.profile!.profileId;
      h.dispose();
      await f.runtime.close();
      final nextIds = FixtureIds();
      for (var i = 0; i < 10; i++) {
        nextIds.next();
      }
      final reopened = ProfileFixture(
        database: ProfileDatabase(NativeDatabase(file)),
        ids: nextIds,
        xp: 999999,
      );
      await reopened.ready();
      addTearDown(reopened.runtime.close);
      expect(reopened.runtime.profile!.profileId, profile);
      expect(reopened.legacy.reads, 0);
      expect(await reopened.store.totalXp(profile), 4000);
      expect(
        [for (final id in ids) (await reopened.store.loadRecord(id))!.outcome],
        [MatchOutcome.win, MatchOutcome.loss, MatchOutcome.draw],
      );
    },
  );

  test(
    'countdown cancel, background pause, rebuild, explicit abandon are distinct',
    () async {
      final f = await ready();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.controller.startGame();
      h.loop.tick();
      h.controller.pauseGame();
      h.controller.returnToConfiguration();
      await f.runtime.drain();
      expect(
        await f.store.database.select(f.store.database.matchRecords).get(),
        isEmpty,
      );
      h.play();
      final id = h.controller.currentMatchId!;
      h.controller.pauseGame();
      await f.runtime.drain();
      expect((await f.store.loadRecord(id))!.status, MatchStatus.inProgress);
      h.controller.resumeGame();
      for (var i = 0; i < 60; i++) {
        h.loop.tick();
      }
      h.container.invalidate(mapViewportProvider);
      h.container.read(gameControllerProvider);
      expect(h.controller.currentMatchId, id);
      h.controller.state = h.controller.state.copyWith(
        matchSummary: const MatchSummary(
          elapsedMs: 234,
          playerDispatchCount: 2,
          playerDispatchedForces: 9,
          playerCaptureCount: 1,
        ),
      );
      h.controller.pauseGame();
      h.controller.returnToSettings();
      await f.runtime.drain();
      final record = (await f.store.loadRecord(id))!;
      expect(record.status, MatchStatus.abandoned);
      expect(record.outcome, isNull);
      expect(
        record.metrics,
        MatchMetrics(
          elapsedMs: 234,
          dispatchCount: 2,
          forcesSent: 9,
          captures: 1,
        ),
      );
      expect(await f.store.totalXp(record.start.profileId), 0);
    },
  );

  for (final origin in SessionOrigin.values.where(
    (o) => o != SessionOrigin.gameplay,
  )) {
    test('$origin excludes controller persistence', () async {
      final f = await ready();
      final h = Harness(f, origin: origin);
      addTearDown(h.dispose);
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 10));
      expect(h.controller.currentMatchId, isNull);
      expect(
        await f.store.database.select(f.store.database.matchRecords).get(),
        isEmpty,
      );
    });
  }
  test('spectator excluded', () async {
    final f = await ready();
    final h = Harness(f);
    addTearDown(h.dispose);
    h.controller.selectGameMode(GameMode.cpuVsCpu);
    h.play();
    await h.finish(
      const GameResult.victory(elapsedMs: 100, winner: Faction.cpu),
    );
    expect(h.controller.currentMatchId, isNull);
    expect(
      await f.store.database.select(f.store.database.matchRecords).get(),
      isEmpty,
    );
  });

  test(
    'failure rolls back both match and XP; DTO survives result/controller disposal for retry',
    () async {
      final f = await ready(xp: 2500);
      f.saveError = StateError('disk full');
      final h = Harness(f);
      h.play();
      final id = h.controller.currentMatchId!;
      await h.finish(const GameResult.victory(elapsedMs: 432));
      expect(h.controller.state.result!.xpAwarded, 0);
      expect(f.runtime.saveFor(id)!.phase, MatchSavePhase.unsaved);
      expect((await f.store.loadRecord(id))!.status, MatchStatus.inProgress);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 2500);
      h.controller.rematchGame();
      h.dispose();
      f.clock.time = f.clock.time.add(const Duration(days: 1));
      f.saveError = null;
      await f.runtime.retry();
      expect(f.runtime.saveFor(id)!.receipt!.totalXpAfter, 4000);
      expect(
        (await f.store.loadRecord(id))!.endedAtUtc,
        DateTime.utc(2026, 10, 2),
      );
      await f.runtime.retry(id);
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 4000);
    },
  );

  for (final newMap in [false, true]) {
    test(
      'delayed old receipt never updates newer ${newMap ? "new map" : "rematch"} result',
      () async {
        final f = await ready();
        f.saveGates = [Completer<void>(), Completer<void>()];
        final h = Harness(f);
        addTearDown(h.dispose);
        h.controller.selectCpuDifficulty(CpuDifficulty.hard);
        h.play();
        final firstId = h.controller.currentMatchId!;
        h.controller.finish(const GameResult.victory(elapsedMs: 100));
        await pumpEventQueue(times: 20);
        expect(f.saveCount, 1);
        if (newMap) {
          h.controller.replayGame();
        } else {
          h.controller.rematchGame();
        }
        for (var i = 0; i < 60; i++) {
          h.loop.tick();
        }
        h.controller.finish(const GameResult.victory(elapsedMs: 200));
        final secondId = h.controller.currentMatchId!;
        expect(secondId, isNot(firstId));
        f.saveGates[0].complete();
        await pumpEventQueue(times: 20);
        expect(h.controller.state.result!.xpAwarded, 0);
        expect(h.controller.state.result!.totalXpAfter, isNull);
        f.saveGates[1].complete();
        await f.runtime.drain();
        expect(h.controller.state.result!.totalXpBefore, 3000);
        expect(h.controller.state.result!.totalXpAfter, 6000);
        expect(f.runtime.saveFor(firstId)!.receipt!.totalXpAfter, 3000);
      },
    );
  }

  test(
    'initial load delay prevents normal starts; old legacy XP cannot overwrite a later receipt',
    () async {
      final f = ProfileFixture(xp: 2500);
      addTearDown(f.runtime.close);
      f.legacy.gate = Completer<void>();
      final pending = f.runtime.prepare();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.controller.startGame();
      expect(h.controller.state.phase, GamePhase.configuration);
      f.legacy.gate!.complete();
      await pending;
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 0));
      expect(h.controller.state.result!.totalXpAfter, 4000);
      f.legacy.value = 100000;
      await f.runtime.prepare();
      expect(await f.store.totalXp(f.runtime.profile!.profileId), 4000);
      expect(f.legacy.reads, 1);
    },
  );

  test(
    'writer refusal blocks normal match while transient open failure preserves game and retry',
    () async {
      final f = ProfileFixture();
      addTearDown(f.runtime.close);
      f.openError = const StorageAlreadyOwned();
      await f.runtime.prepare();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.controller.startGame();
      expect(h.controller.state.phase, GamePhase.configuration);
      expect(h.controller.canStartMatch, isFalse);
      f.openError = const StorageUnavailable('wasm unavailable');
      await f.runtime.prepare();
      h.play();
      await h.finish(const GameResult.victory(elapsedMs: 0));
      final id = h.controller.currentMatchId!;
      expect(f.runtime.saveFor(id)!.phase, MatchSavePhase.unsaved);
      h.controller.returnToSettings();
      expect(h.controller.state.phase, GamePhase.configuration);
      f.openError = null;
      await f.runtime.retry();
      expect(f.runtime.saveFor(id)!.receipt!.xpAwarded, 1500);
    },
  );

  test(
    'production game-loop arrival commits the engine summary unchanged',
    () async {
      final f = await ready();
      final h = Harness(f);
      addTearDown(h.dispose);
      h.play();
      h.controller.state = GameState(
        configuration: h.controller.state.configuration,
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [
          IslandState(
            id: 0,
            faction: Faction.player,
            currentForces: 10,
            capacity: 50,
          ),
          IslandState(
            id: 1,
            faction: Faction.cpu,
            currentForces: 1,
            capacity: 50,
          ),
        ],
        movingForces: const [
          MovingForce(
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 2,
            arrivalTimeMs: 0,
            durationMs: 1,
          ),
        ],
      );
      h.loop.tick();
      await f.runtime.drain();
      final result = h.controller.state.result!;
      expect(result.type, GameResultType.victory);
      expect(result.xpAwarded, 1500);
      final record = (await f.store.loadRecord(h.controller.currentMatchId!))!;
      expect(
        record.metrics,
        MatchMetrics.fromSummary(h.controller.state.matchSummary),
      );
      expect(record.metrics.captures, 1);
    },
  );
}
