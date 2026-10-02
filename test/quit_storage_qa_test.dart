import 'dart:math';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/main.dart';
import 'package:conquest/profile/match_contracts.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';
import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';

final class _SilentBgm implements BgmPlayer {
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

void main() {
  for (final language in ['en', 'ja']) {
    for (final scenario in ['normal', 'failure', 'spectator']) {
      testWidgets(
        'quit copy and actual $scenario persistence agree in $language',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final fixture = (await tester.runAsync(() async {
            final f = ProfileFixture();
            await f.ready();
            return f;
          }))!;
          final loop = ManualGameLoop();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                matchPersistenceProvider.overrideWithValue(fixture.runtime),
                bgmPlayerProvider.overrideWithValue(_SilentBgm()),
                menuBgmPlayerProvider.overrideWithValue(_SilentBgm()),
                gameLoopProvider.overrideWithValue(loop),
                randomProvider.overrideWithValue(Random(1)),
                cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
                gameConfigurationProvider.overrideWithValue(
                  GameConfiguration(
                    gameMode: scenario == 'spectator'
                        ? GameMode.cpuVsCpu
                        : GameMode.playerVsCpu,
                  ),
                ),
              ],
              child: MyApp(locale: Locale(language)),
            ),
          );
          await openMatchSetup(tester);
          final container = ProviderScope.containerOf(
            tester.element(find.byKey(const ValueKey('island-0'))),
          );
          final controller = container.read(gameControllerProvider.notifier);
          await tester.runAsync(() async {
            controller.startGame();
            for (var i = 0; i < 60; i++) loop.tick();
            await fixture.runtime.drain();
          });
          await tester.pump();
          final id = controller.currentMatchId;
          await tester.tap(find.byKey(const ValueKey('pause-game')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('quit-game')));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          );
          expect(find.text(l10n.quitDescription), findsOneWidget);
          expect(
            l10n.quitDescription,
            contains(language == 'en' ? 'if saving succeeds' : '保存に成功すると'),
          );
          expect(
            l10n.quitDescription,
            contains(language == 'en' ? 'spectator and practice' : '観戦・練習'),
          );
          expect(
            find.byKey(const ValueKey('confirm-quit')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('cancel-quit')));
          await tester.pumpAndSettle();
          expect(controller.state.phase, GamePhase.paused);
          if (id != null) {
            await tester.runAsync(
              () async => expect(
                (await fixture.store.loadRecord(id))!.status,
                MatchStatus.inProgress,
              ),
            );
          }
          if (scenario == 'failure')
            fixture.saveError = StateError('disk full');
          await tester.tap(find.byKey(const ValueKey('quit-game')));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(find.byKey(const ValueKey('confirm-quit')));
            await fixture.runtime.drain();
          });
          await tester.pumpAndSettle();
          await runProfileIo(tester, fixture.runtime.drain);
          expect(controller.state.phase, GamePhase.configuration);
          await tester.pumpWidget(const SizedBox.shrink());
          await runProfileIo(tester, () async {
            final profile = fixture.runtime.profile!.profileId;
            final history = await fixture.repository.loadHistory(profile);
            expect(
              history.entries.where(
                (entry) => entry.record.status == MatchStatus.completed,
              ),
              isEmpty,
            );
            expect(await fixture.store.totalXp(profile), 0);
            if (scenario == 'normal') {
              expect(
                history.entries.single.record.status,
                MatchStatus.abandoned,
              );
              expect(fixture.runtime.saveFor(id)!.phase, MatchSavePhase.saved);
            } else if (scenario == 'failure') {
              expect(history.entries, isEmpty);
              expect(
                fixture.runtime.saveFor(id)!.phase,
                MatchSavePhase.unsaved,
              );
              fixture.saveError = null;
              await fixture.runtime.retry(id);
              expect(
                (await fixture.repository.loadHistory(
                  profile,
                )).entries.single.record.status,
                MatchStatus.abandoned,
              );
            } else {
              expect(id, isNull);
              expect(history.entries, isEmpty);
              expect(
                await fixture.store.database
                    .select(fixture.store.database.matchRecords)
                    .get(),
                isEmpty,
              );
            }
          });
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          await runProfileIo(tester, fixture.runtime.close);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
