import 'dart:math';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'match_setup.dart';
import 'profile_fixture.dart';
import 'profile_widget_io.dart';

final class RankBadgeFixture {
  RankBadgeFixture._(this.store, this.loop, this.controller);

  final ProfileFixture store;
  final ManualGameLoop loop;
  final GameController controller;

  static Future<RankBadgeFixture> mount(
    WidgetTester tester, {
    required int xp,
    Locale locale = const Locale('en'),
    int? presentedRank,
    GlobalKey? boundaryKey,
  }) async {
    final store = (await tester.runAsync(() async {
      final fixture = ProfileFixture(xp: xp);
      await fixture.ready();
      return fixture;
    }))!;
    final loop = ManualGameLoop();
    final app = ProviderScope(
      overrides: [
        matchPersistenceProvider.overrideWithValue(store.runtime),
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
        bgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
        menuBgmPlayerProvider.overrideWithValue(SilentBgmPlayer()),
        if (presentedRank != null)
          rankProgressProvider.overrideWith(
            (_) => Stream.value(
              RankProgress.fromTotalXp(RankCatalog.cumulativeXp[presentedRank]),
            ),
          ),
      ],
      child: MyApp(locale: locale),
    );
    await tester.pumpWidget(
      boundaryKey == null ? app : RepaintBoundary(key: boundaryKey, child: app),
    );
    await tester.pumpAndSettle();
    await openMatchSetup(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('rank-progress-card'))),
    );
    return RankBadgeFixture._(
      store,
      loop,
      container.read(gameControllerProvider.notifier),
    );
  }

  Future<void> finish(
    WidgetTester tester, {
    GameResult result = const GameResult.victory(elapsedMs: 100),
    CpuDifficulty difficulty = CpuDifficulty.hard,
    GameMode mode = GameMode.playerVsCpu,
  }) async {
    controller.selectGameMode(mode);
    controller.selectCpuDifficulty(difficulty);
    await runProfileIo(tester, () async {
      controller.startGame();
      for (var i = 0; i < 60; i++) {
        loop.tick();
      }
      controller.finish(result);
      await store.runtime.drain();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await runProfileIo(tester, store.runtime.close);
  }
}

final class SilentBgmPlayer implements BgmPlayer {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> playFromStart() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAndReset() async {}
  @override
  Future<void> dispose() async {}
}
