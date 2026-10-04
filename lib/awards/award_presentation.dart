import 'package:flutter/material.dart';

import '../game/match_summary.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/tactical_theme.dart';
import 'award_catalog.dart';
import 'award_progress.dart';

String assignmentName(AppLocalizations l, String id) => switch (id) {
  'capture_bronze' => l.awardsCaptureBronze,
  'capture_silver' => l.awardsCaptureSilver,
  'capture_gold' => l.awardsCaptureGold,
  'command_bronze' => l.awardsCommandBronze,
  'command_silver' => l.awardsCommandSilver,
  'command_gold' => l.awardsCommandGold,
  'tactics_bronze' => l.awardsTacticsBronze,
  'tactics_silver' => l.awardsTacticsSilver,
  'tactics_gold' => l.awardsTacticsGold,
  _ => throw ArgumentError.value(id),
};

String ribbonName(AppLocalizations l, String id) => switch (id) {
  'capture' => l.awardsCapture,
  'maneuver' => l.awardsManeuver,
  'deployment' => l.awardsDeployment,
  'victory' => l.awardsVictory,
  'hard_victory' => l.awardsHardVictory,
  'swift_victory' => l.awardsSwiftVictory,
  _ => throw ArgumentError.value(id),
};

String metricName(AppLocalizations l, AwardMetric metric) => switch (metric) {
  AwardMetric.captures => l.awardsCapturesMetric,
  AwardMetric.dispatches => l.awardsDispatchesMetric,
  AwardMetric.forces => l.awardsForcesMetric,
  AwardMetric.wins => l.awardsWinsMetric,
  AwardMetric.normalWins => l.awardsNormalWinsMetric,
  AwardMetric.hardWins => l.awardsHardWinsMetric,
  AwardMetric.captureRibbons => l.awardsCaptureRibbonsMetric,
  AwardMetric.elapsedMs => throw ArgumentError.value(metric),
};

String ribbonCondition(AppLocalizations l, RibbonDefinition ribbon) =>
    ribbon.id == 'swift_victory'
    ? l.awardsWithin(seconds: ribbon.threshold ~/ 1000)
    : l.awardsPerMatch(
        count: ribbon.threshold,
        metric: metricName(l, ribbon.metric),
      );

String tierName(AppLocalizations l, AssignmentTier tier) => switch (tier) {
  AssignmentTier.bronze => l.awardsBronze,
  AssignmentTier.silver => l.awardsSilver,
  AssignmentTier.gold => l.awardsGold,
};

String trackName(AppLocalizations l, AssignmentTrack track) => switch (track) {
  AssignmentTrack.capture => l.awardsCaptureTrack,
  AssignmentTrack.command => l.awardsCommandTrack,
  AssignmentTrack.tactics => l.awardsTacticsTrack,
};

enum AwardEmblemKind { ribbon, medal, assignment }

class AwardEmblem extends StatelessWidget {
  const AwardEmblem({
    super.key,
    required this.kind,
    required this.motif,
    this.earned = true,
  });
  final AwardEmblemKind kind;
  final int motif;
  final bool earned;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(48, 48),
      painter: _AwardPainter(kind, motif, earned),
    ),
  );
}

class _AwardPainter extends CustomPainter {
  _AwardPainter(this.kind, this.motif, this.earned);
  final AwardEmblemKind kind;
  final int motif;
  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF388D89),
      Color(0xFF476F9A),
      Color(0xFFAD7948),
      Color(0xFF7B9652),
      Color(0xFFAB5960),
      Color(0xFF9471A8),
    ];
    final paint = Paint()
      ..color = earned ? colors[motif % colors.length] : TacticalPalette.muted;
    final w = size.width;
    final h = size.height;
    if (kind == AwardEmblemKind.ribbon) {
      canvas.drawRect(Rect.fromLTWH(2, h * .3, w - 4, h * .4), paint);
      paint.color = TacticalPalette.surface;
      for (var i = 0; i <= motif % 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(w * .25 + i * 7, h * .3, 3, h * .4),
          paint,
        );
      }
    } else if (kind == AwardEmblemKind.medal) {
      canvas.drawPath(
        Path()
          ..moveTo(12, 2)
          ..lineTo(36, 2)
          ..lineTo(28, 24)
          ..lineTo(20, 24)
          ..close(),
        paint,
      );
      paint.color = earned ? const Color(0xFFC4A66A) : TacticalPalette.muted;
      canvas.drawCircle(Offset(w / 2, h * .67), w * .28, paint);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(8, 8)
          ..lineTo(40, 8)
          ..lineTo(40, 32)
          ..lineTo(24, 46)
          ..lineTo(8, 32)
          ..close(),
        paint,
      );
    }
    if (kind != AwardEmblemKind.ribbon) {
      paint
        ..color = TacticalPalette.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final y = kind == AwardEmblemKind.medal ? h * .67 : h * .48;
      canvas.drawCircle(Offset(w / 2, y), 5 + motif % 3, paint);
      canvas.drawLine(Offset(w / 2 - 10, y), Offset(w / 2 + 10, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AwardPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.motif != motif ||
      oldDelegate.earned != earned;
}

class AssignmentConditions extends StatelessWidget {
  const AssignmentConditions({
    super.key,
    required this.definition,
    required this.profile,
    required this.l10n,
  });
  final AssignmentDefinition definition;
  final AwardProfile profile;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final values = profile.progressFor(definition);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          definition.singleMatch
              ? l10n.awardsSingleMatch
              : l10n.awardsCumulative,
          style: TextStyle(color: TacticalPalette.muted),
        ),
        for (final condition in definition.conditions)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${condition.satisfied(values) ? '✓ ' : ''}${condition.maximum ? l10n.awardsTimeCondition(time: values.containsKey(condition.metric) ? formatMatchDuration(values[condition.metric]!) : '—', seconds: condition.target ~/ 1000) : '${metricName(l10n, condition.metric)} ${values[condition.metric] ?? 0} / ${condition.target}'}',
            ),
          ),
      ],
    );
  }
}
