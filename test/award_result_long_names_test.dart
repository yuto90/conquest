import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_manager.dart';
import 'package:conquest/awards/award_presentation.dart';
import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/awards/award_result.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/l10n/generated/app_localizations_en.dart';
import 'package:conquest/l10n/generated/app_localizations_ja.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LongEnglish extends AppLocalizationsEn {
  @override
  String get awardsCapture =>
      'Exceptionally long capture ribbon name for an international player';
  @override
  String get awardsCaptureBronze =>
      'Exceptionally long amphibious capture assignment name with multiple conditions';
}

class _LongJapanese extends AppLocalizationsJa {
  @override
  String get awardsCapture => 'とても長い名前の島の占領と戦闘への貢献を記念するリボン';
  @override
  String get awardsCaptureBronze => 'とても長い名前の島の占領と派遣兵力の活躍を記録する上陸訓練任務';
}

void main() {
  for (final l in <AppLocalizations>[_LongEnglish(), _LongJapanese()]) {
    testWidgets('long ${l.localeName} names remain readable in details at 3x', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(280, 500));
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });
      final semantics = tester.ensureSemantics();
      final before = AwardProfile();
      final evaluation = AwardEvaluator.evaluate(
        before,
        AwardMatch(
          id: 'long-names',
          difficulty: CpuDifficulty.hard,
          won: true,
          elapsedMs: 31000,
          summary: const MatchSummary(
            elapsedMs: 31000,
            playerCaptureCount: 30,
            playerDispatchCount: 100,
            playerDispatchedForces: 5000,
          ),
          endedAtUtc: DateTime.utc(2026, 10, 4),
        ),
        before.eligibleAssignments,
      );
      final state = AwardMatchState()
        ..evaluation = evaluation
        ..phase = AwardSavePhase.saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(l.localeName),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AwardResultSummary(state: state, l10n: l),
                  AwardResultPanel(
                    state: state,
                    l10n: l,
                    onRetry: () {},
                    showAllAssignments: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = '${l.awardsCapture} · ${l.awardsRibbons} ×10';
      expect(find.byTooltip(label), findsOneWidget);
      expect(find.bySemanticsLabel(label), findsWidgets);
      await tester.ensureVisible(find.text(label));
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      for (final assignment in AwardCatalog.assignments) {
        final tile = find.byKey(ValueKey('result-progress-${assignment.id}'));
        await tester.ensureVisible(tile);
        await tester.tapAt(tester.getTopLeft(tile) + const Offset(24, 32));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: tile,
            matching: find.byType(AssignmentConditions),
          ),
          findsOneWidget,
        );
        expect(find.text(assignmentName(l, assignment.id)), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    });
  }
}
