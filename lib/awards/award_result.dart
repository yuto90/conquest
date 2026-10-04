import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'award_catalog.dart';
import 'award_manager.dart';
import 'award_presentation.dart';

class AwardResultPanel extends StatelessWidget {
  const AwardResultPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.l10n,
  });
  final AwardMatchState state;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final evaluation = state.evaluation;
    final l = l10n;
    return Column(
      key: const ValueKey('result-awards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l.awardsThisMatch,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (state.phase == AwardSavePhase.saving) Text(l.awardsSaving),
        if (state.phase == AwardSavePhase.unsaved) ...[
          Text(l.awardsUnsaved),
          TextButton(onPressed: onRetry, child: Text(l.awardsRetry)),
        ],
        if (evaluation != null) ...[
          if (evaluation.ribbons.isEmpty &&
              evaluation.medals.isEmpty &&
              evaluation.assignments.isEmpty)
            Text(l.awardsEmpty),
          for (final entry in evaluation.ribbons.entries)
            _earned(
              context,
              AwardEmblemKind.ribbon,
              entry.key,
              '${ribbonName(l, entry.key)} · ${l.awardsRibbons} ×${entry.value}',
            ),
          for (final entry in evaluation.medals.entries)
            _earned(
              context,
              AwardEmblemKind.medal,
              entry.key,
              '${ribbonName(l, entry.key)} · ${l.awardsMedals} ×${entry.value}',
            ),
          for (final id in evaluation.assignments)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  AwardEmblem(
                    kind: AwardEmblemKind.assignment,
                    motif: AwardCatalog.assignments
                        .singleWhere((a) => a.id == id)
                        .track
                        .index,
                  ),
                  Text(
                    '${l.awardsCompleted}: ${assignmentName(l, id)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          for (final id in evaluation.progressed)
            ExpansionTile(
              key: ValueKey('result-progress-$id'),
              tilePadding: EdgeInsets.zero,
              title: Text(assignmentName(l, id)),
              children: [
                AssignmentConditions(
                  definition: AwardCatalog.assignments.singleWhere(
                    (a) => a.id == id,
                  ),
                  profile: evaluation.profile,
                  l10n: l,
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _earned(
    BuildContext context,
    AwardEmblemKind kind,
    String id,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AwardEmblem(
          kind: kind,
          motif: AwardCatalog.ribbons.indexWhere((r) => r.id == id),
        ),
        Text(
          label,
          style: TextStyle(
            fontWeight: kind == AwardEmblemKind.medal
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
