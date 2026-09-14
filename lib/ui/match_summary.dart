import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/match_summary.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import 'tactical_theme.dart';

/// Displays the short, non-persistent review of a player-versus-CPU match.
///
/// The caller decides whether the current mode is eligible for this panel;
/// this widget never presents CPU-versus-CPU results as a human player's
/// activity.
class MatchSummaryPanel extends StatelessWidget {
  const MatchSummaryPanel({
    required this.configuration,
    required this.summary,
    super.key,
  });

  final GameConfiguration configuration;
  final MatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final settings = l10n.matchSummarySettings(
      islandCount: configuration.totalIslandCount,
      difficulty: _difficultyLabel(l10n, configuration.cpuDifficulty),
    );
    final time = formatMatchDuration(summary.elapsedMs);
    final dispatches = l10n.matchSummaryDispatches(
      count: summary.playerDispatchCount,
    );
    final forces = l10n.matchSummaryForces(
      forces: summary.playerDispatchedForces,
    );
    final captures = l10n.matchSummaryCaptures(
      count: summary.playerCaptureCount,
    );

    return Semantics(
      key: const ValueKey('match-summary'),
      container: true,
      label: l10n.matchSummarySemantics(
        settings: settings,
        time: l10n.matchSummaryTime(time: time),
        dispatches: dispatches,
        forces: forces,
        captures: captures,
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: TacticalPalette.surface.withValues(alpha: 0.45),
            border: Border.all(color: TacticalPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.matchSummaryHeading,
                textAlign: TextAlign.center,
                style: TacticalTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: TacticalPalette.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _SummaryLine(label: settings),
              _SummaryLine(label: l10n.matchSummaryTime(time: time)),
              _SummaryLine(label: dispatches),
              _SummaryLine(label: forces),
              _SummaryLine(label: captures),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TacticalTypography.mono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: TacticalPalette.foreground,
          height: 1.25,
        ),
      ),
    );
  }
}

String _difficultyLabel(AppLocalizations l10n, CpuDifficulty difficulty) =>
    switch (difficulty) {
      CpuDifficulty.veryEasy => l10n.difficultyVeryEasy,
      CpuDifficulty.easy => l10n.difficultyEasy,
      CpuDifficulty.normal => l10n.difficultyNormal,
      CpuDifficulty.hard => l10n.difficultyHard,
    };
