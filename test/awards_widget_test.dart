import 'dart:math';

import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/awards/award_presentation.dart';
import 'package:conquest/awards/award_result.dart';
import 'package:conquest/awards/awards_screen.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/home.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/main.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/profile/drift_profile_store.dart';
import 'support/match_setup.dart';
import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';

class SilentBgm implements BgmPlayer {
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

Widget localized(Widget child, String locale) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<ProfileFixture> fixtureFor(
  WidgetTester tester,
  AwardManager awards, {
  StorageFaultHook? faultHook,
}) async {
  late ProfileFixture fixture;
  await runProfileIo(tester, () async {
    fixture = ProfileFixture(awards: awards, faultHook: faultHook);
    await fixture.ready();
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await runProfileIo(tester, fixture.runtime.close);
    awards.dispose();
  });
  return fixture;
}

void main() {
  for (final locale in ['en', 'ja']) {
    for (final size in [
      const Size(280, 500),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      testWidgets(
        'catalog, conditions, counts and back accessible in $locale at $size with 2x text',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.binding.setSurfaceSize(null);
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final awards = AwardManager();
          final f = await fixtureFor(tester, awards);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                matchPersistenceProvider.overrideWithValue(f.runtime),
              ],
              child: localized(
                Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => AwardsScreen.open(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
                locale,
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(AwardsScreen)),
          );
          for (final assignment in AwardCatalog.assignments) {
            expect(assignmentName(l, assignment.id), isNotEmpty);
            await tester.scrollUntilVisible(
              find.byKey(ValueKey('assignment-${assignment.id}')),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump();
            expect(find.text(assignmentName(l, assignment.id)), findsOneWidget);
            expect(
              tester
                  .getSemantics(find.text(assignmentName(l, assignment.id)))
                  .label,
              contains(assignmentName(l, assignment.id)),
            );
            expect(tester.takeException(), isNull);
          }
          expect(find.text(l.awardsLocked), findsWidgets);
          await tester.tap(find.byKey(const ValueKey('awards-collection-tab')));
          await tester.pumpAndSettle();
          for (final ribbon in AwardCatalog.ribbons) {
            expect(ribbonCondition(l, ribbon), isNotEmpty);
            await tester.scrollUntilVisible(
              find.byKey(ValueKey('ribbon-${ribbon.id}')),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump();
            expect(
              find.text('${ribbonName(l, ribbon.id)} · ${l.awardsRibbons}'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('awards-medals-toggle')),
            -200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.byKey(const ValueKey('awards-medals-toggle')));
          await tester.pump();
          for (final ribbon in AwardCatalog.ribbons) {
            await tester.scrollUntilVisible(
              find.byKey(ValueKey('medal-${ribbon.id}')),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pump();
            expect(
              find.text('${ribbonName(l, ribbon.id)} · ${l.awardsMedals}'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.tap(
            find.byTooltip(
              MaterialLocalizations.of(
                tester.element(find.byType(AwardsScreen)),
              ).backButtonTooltip,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('open'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'setup round trip preserves generated board and configuration in $locale',
      (tester) async {
        final awards = AwardManager();
        final f = await fixtureFor(tester, awards);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchPersistenceProvider.overrideWithValue(f.runtime),
              bgmPlayerProvider.overrideWithValue(SilentBgm()),
              menuBgmPlayerProvider.overrideWithValue(SilentBgm()),
              randomProvider.overrideWithValue(Random(1)),
            ],
            child: MyApp(locale: Locale(locale)),
          ),
        );
        await openMatchSetup(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('settings-view'))),
        );
        final before = container.read(gameControllerProvider);
        await tester.ensureVisible(find.byKey(const ValueKey('open-awards')));
        await tester.tap(find.byKey(const ValueKey('open-awards')));
        await tester.pumpAndSettle();
        expect(find.byType(AwardsScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final after = container.read(gameControllerProvider);
        expect(after.configuration, before.configuration);
        expect(after.islands, orderedEquals(before.islands));
        expect(after.phase, before.phase);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        await runProfileIo(tester, f.runtime.close);
      },
    );

    testWidgets(
      'result groups ribbons, medals, completed assignments, progress and unsaved retry in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 500));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        var fail = true;
        final awards = AwardManager();
        final f = await fixtureFor(
          tester,
          awards,
          faultHook: (point) async {
            if (fail && point == StorageFaultPoint.afterAwards)
              throw StateError('full');
          },
        );
        final id = f.runtime.begin(GameConfiguration.initial)!;
        await runProfileIo(
          tester,
          () => f.runtime.finish(
            id,
            result: const GameResult.victory(elapsedMs: 180000),
            summary: const MatchSummary(
              elapsedMs: 180000,
              playerCaptureCount: 30,
              playerDispatchCount: 10,
              playerDispatchedForces: 500,
            ),
          ),
        );
        var retries = 0;
        await tester.pumpWidget(
          localized(
            Scaffold(
              body: SingleChildScrollView(
                child: AwardResultPanel(
                  state: awards.stateFor(id)!,
                  onRetry: () => retries++,
                  l10n: await AppLocalizations.delegate.load(Locale(locale)),
                ),
              ),
            ),
            locale,
          ),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AwardResultPanel)),
        );
        expect(
          find.text('${ribbonName(l, 'capture')} · ${l.awardsRibbons} ×10'),
          findsOneWidget,
        );
        expect(
          find.text('${ribbonName(l, 'capture')} · ${l.awardsMedals} ×1'),
          findsOneWidget,
        );
        expect(
          find.text('${l.awardsCompleted}: ${l.awardsCaptureBronze}'),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('result-progress-capture_bronze')),
        );
        await tester.tap(
          find.byKey(const ValueKey('result-progress-capture_bronze')),
        );
        await tester.pumpAndSettle();
        expect(find.text('✓ ${l.awardsCapturesMetric} 30 / 5'), findsOneWidget);
        await tester.ensureVisible(find.text(l.awardsRetry));
        await tester.tap(find.text(l.awardsRetry));
        expect(retries, 1);
        expect(tester.takeException(), isNull);
        fail = false;
        await runProfileIo(tester, () => f.runtime.retryAwards(id));
        expect(awards.stateFor(id)!.phase, AwardSavePhase.saved);
      },
    );
  }
}
