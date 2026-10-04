import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_widget_io.dart';
import 'support/rank_badge_fixture.dart';

const _example = MatchSummary(
  elapsedMs: 31000,
  playerDispatchCount: 14,
  playerDispatchedForces: 250,
  playerCaptureCount: 5,
);
const _victory = GameResult.victory(elapsedMs: 31000);
const _actions = ['rematch-game', 'replay-game', 'return-settings'];

Future<RankBadgeFixture> _mount(
  WidgetTester tester,
  String locale,
  AwardManager awards,
) async {
  final fixture = await RankBadgeFixture.mount(
    tester,
    xp: 0,
    locale: Locale(locale),
    awards: awards,
  );
  fixture.controller.selectIslandCount(12);
  addTearDown(() async {
    await fixture.close(tester);
    awards.dispose();
  });
  return fixture;
}

void _surface(WidgetTester tester, Size size, {double scale = 1}) {
  tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetPadding();
    await tester.binding.setSurfaceSize(null);
  });
}

Finder get _details => find.byKey(const ValueKey('result-details'));
Finder get _open => find.byKey(const ValueKey('result-details-button'));

Future<void> _closeDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('close-result-details')));
  await tester.pumpAndSettle();
  expect(_details, findsNothing);
}

void main() {
  for (final locale in ['ja', 'en']) {
    testWidgets('$locale example fits 402x874 with 746pt safe height', (
      tester,
    ) async {
      _surface(tester, const Size(402, 874));
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 66);
      final awards = AwardManager();
      final fixture = await _mount(tester, locale, awards);
      await fixture.finish(
        tester,
        result: _victory,
        difficulty: CpuDifficulty.normal,
        summary: _example,
      );
      final state = awards.stateFor(fixture.controller.currentMatchId)!;
      expect(state.evaluation!.ribbons.length, 4);
      expect(state.evaluation!.assignments.length, 2);
      expect(fixture.controller.currentSave!.phase, MatchSavePhase.saved);
      expect(find.text('+1500 XP').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('result-awards-summary')).hitTestable(),
        findsOneWidget,
      );
      for (final key in _actions) {
        final action = find.byKey(ValueKey(key));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(808));
      }
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('result-summary-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('result-sheet'))).width,
        greaterThan(350),
      );
      expect(tester.takeException(), isNull);

      final result = fixture.controller.state.result;
      final receipt = fixture.controller.currentSave!.receipt;
      final evaluation = state.evaluation;
      final writes = fixture.store.saveCount;
      final show = tester.widget<TextButton>(_open).onPressed!;
      show();
      show();
      await tester.pumpAndSettle();
      expect(_details, findsOneWidget);
      for (final definition in AwardCatalog.assignments) {
        expect(
          find.byKey(ValueKey('result-progress-${definition.id}')),
          findsOneWidget,
        );
      }
      await _closeDetails(tester);
      await tester.tap(_open);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_details, findsNothing);
      await runProfileIo(
        tester,
        () => fixture.store.runtime.finish(
          fixture.controller.currentMatchId!,
          result: _victory,
          summary: _example,
        ),
      );
      expect(fixture.controller.state.result, same(result));
      expect(fixture.controller.currentSave!.receipt, same(receipt));
      expect(state.evaluation, same(evaluation));
      expect(fixture.store.saveCount, writes);
      expect(tester.takeException(), isNull);
      await fixture.close(tester);
    });

    for (final result in const [
      GameResult.defeat(elapsedMs: 31000),
      GameResult.draw(elapsedMs: 31000),
      _victory,
    ]) {
      testWidgets('$locale ${result.type.name} zero awards / spectator', (
        tester,
      ) async {
        _surface(tester, const Size(402, 874));
        final awards = AwardManager();
        final fixture = await _mount(tester, locale, awards);
        final spectator = result.type == GameResultType.victory;
        await fixture.finish(
          tester,
          result: result,
          mode: spectator ? GameMode.cpuVsCpu : GameMode.playerVsCpu,
        );
        expect(fixture.controller.state.result!.xpAwarded, 0);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        expect(
          find.text(l.awardsEmpty),
          spectator ? findsNothing : findsOneWidget,
        );
        for (final key in _actions) {
          expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
        }
        await tester.tap(_open);
        await tester.pumpAndSettle();
        expect(_details, findsOneWidget);
        expect(
          find.byKey(const ValueKey('result-awards')),
          spectator ? findsNothing : findsOneWidget,
        );
        await _closeDetails(tester);
        expect(tester.takeException(), isNull);
        await fixture.close(tester);
      });
    }

    testWidgets('$locale atomic save failure, detail retry and repeated taps', (
      tester,
    ) async {
      _surface(tester, const Size(402, 874));
      final awards = AwardManager();
      final fixture = await _mount(tester, locale, awards);
      fixture.store.saveError = StateError('SQLite unavailable');
      await fixture.finish(
        tester,
        result: _victory,
        difficulty: CpuDifficulty.normal,
        summary: _example,
      );
      expect(fixture.controller.currentSave!.phase, MatchSavePhase.unsaved);
      expect(
        awards.stateFor(fixture.controller.currentMatchId)!.phase,
        AwardSavePhase.unsaved,
      );
      expect(
        find.byKey(const ValueKey('retry-match-save')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(_open);
      await tester.pumpAndSettle();
      final retry = find.descendant(
        of: _details,
        matching: find.byKey(const ValueKey('retry-match-save')),
      );
      final callback = tester.widget<TextButton>(retry).onPressed!;
      fixture.store.saveError = null;
      await runProfileIo(tester, () async {
        callback();
        callback();
        callback();
        await fixture.store.runtime.drain();
      });
      await tester.pumpAndSettle();
      expect(fixture.controller.currentSave!.phase, MatchSavePhase.saved);
      expect(
        awards.stateFor(fixture.controller.currentMatchId)!.phase,
        AwardSavePhase.saved,
      );
      final l = await AppLocalizations.delegate.load(Locale(locale));
      expect(
        find.descendant(of: _details, matching: find.text(l.matchSaved)),
        findsOneWidget,
      );
      expect(retry, findsNothing);
      expect(find.text(l.awardsUnsaved), findsNothing);
      await _closeDetails(tester);
      expect(find.text('+1500 XP'), findsOneWidget);
      expect(awards.profile!.ribbons.values.fold(0, (a, b) => a + b), 4);
      expect(awards.profile!.completed.length, 2);
      expect(fixture.store.saveCount, 2);
      expect(tester.takeException(), isNull);
      await fixture.close(tester);
    });

    for (final variant in [
      (const Size(280, 500), 1.0),
      (const Size(402, 874), 3.0),
      (const Size(600, 240), 1.0),
      (const Size(600, 240), 2.0),
    ]) {
      testWidgets('$locale many awards reachable at $variant', (tester) async {
        _surface(tester, const Size(402, 874));
        final awards = AwardManager();
        final fixture = await _mount(tester, locale, awards);
        await fixture.finish(
          tester,
          result: _victory,
          summary: const MatchSummary(
            elapsedMs: 31000,
            playerDispatchCount: 100,
            playerDispatchedForces: 5000,
            playerCaptureCount: 30,
          ),
        );
        final evaluation = awards
            .stateFor(fixture.controller.currentMatchId)!
            .evaluation!;
        expect(evaluation.ribbons.length, 6);
        expect(evaluation.medals.length, 3);
        await tester.binding.setSurfaceSize(variant.$1);
        tester.platformDispatcher.textScaleFactorTestValue = variant.$2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in _actions) {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
        }
        await tester.ensureVisible(_open);
        expect(_open.hitTestable(), findsOneWidget);
        await tester.tap(_open);
        await tester.pumpAndSettle();
        expect(_details, findsOneWidget);
        for (final definition in AwardCatalog.assignments) {
          final progress = find.byKey(
            ValueKey('result-progress-${definition.id}'),
          );
          await tester.ensureVisible(progress);
          await tester.tap(progress);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await _closeDetails(tester);
        expect(fixture.store.saveCount, 1);
        expect(tester.takeException(), isNull);
        await fixture.close(tester);
      });
    }
  }
}
