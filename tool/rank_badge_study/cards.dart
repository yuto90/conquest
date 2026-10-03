import 'dart:ui' as ui;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/rank_progression.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';

import 'badge.dart';

class StudyRankCard extends StatelessWidget {
  const StudyRankCard({
    super.key,
    required this.progress,
    this.crest,
    this.award,
  });

  final RankProgress progress;
  final ui.Image? crest;
  final int? award;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = TacticalTypography.of(context);
    final rankLabel = l10n.rankDisplay(
      rank: progress.rank,
      title: progress.localizedTitle(l10n),
    );
    final isResult = award != null;
    final badge = StudyBadge(
      spec: BadgeSpec.fromRank(progress.rank),
      method: BadgeMethod.composite,
      size: isResult ? 56 : 36,
      crest: crest,
    );
    final title = Semantics(
      label: rankLabel,
      child: ExcludeSemantics(
        child: Text(
          rankLabel,
          style: typography.mono(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 6),
        if (award != null)
          Text(
            l10n.xpEarned(xp: award!),
            style: typography.mono(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        Text(
          progress.isMax
              ? l10n.rankMax
              : l10n.rankProgress(xp: progress.xpToNextRank),
          style: typography.mono(fontSize: 10, color: TacticalPalette.muted),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.progressRatio,
          minHeight: 4,
          backgroundColor: TacticalPalette.border,
          color: TacticalPalette.player,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResult
            ? TacticalPalette.player.withValues(alpha: 0.10)
            : TacticalPalette.surface.withValues(alpha: 0.72),
        border: Border.all(color: TacticalPalette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: badge),
                const SizedBox(height: 8),
                details,
              ],
            );
          }
          return Row(
            children: [
              badge,
              const SizedBox(width: 12),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class StudyResultCard extends StatelessWidget {
  const StudyResultCard({super.key, required this.result, this.crest});

  final GameResult result;
  final ui.Image? crest;

  @override
  Widget build(BuildContext context) {
    if (result.xpAwarded <= 0 || result.totalXpAfter == null)
      return const SizedBox.shrink();
    return StudyRankCard(
      progress: RankProgress.fromTotalXp(result.totalXpAfter!),
      award: result.xpAwarded,
      crest: crest,
    );
  }
}
