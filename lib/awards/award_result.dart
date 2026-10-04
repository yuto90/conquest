import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/tactical_theme.dart';
import 'award_catalog.dart';
import 'award_manager.dart';
import 'award_presentation.dart';

class AwardResultPanel extends StatelessWidget {
  const AwardResultPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.l10n,
    this.showAllAssignments = false,
  });
  final AwardMatchState state;
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  final bool showAllAssignments;

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
          if (showAllAssignments) ...[
            const SizedBox(height: 16),
            Text(
              l.awardsAssignments,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          for (final id
              in showAllAssignments
                  ? AwardCatalog.assignments.map((a) => a.id)
                  : evaluation.progressed)
            ExpansionTile(
              key: ValueKey('result-progress-$id'),
              tilePadding: EdgeInsets.zero,
              title: Text(assignmentName(l, id)),
              subtitle: showAllAssignments
                  ? Text(
                      evaluation.profile.completed.containsKey(id)
                          ? l.awardsCompleted
                          : evaluation.profile.eligibleAssignments.contains(id)
                          ? l.awardsInProgress
                          : l.awardsLocked,
                    )
                  : null,
              children: [
                if (showAllAssignments)
                  if (AwardCatalog.assignments
                          .singleWhere((a) => a.id == id)
                          .prerequisite
                      case final prerequisite?)
                    Text(
                      l.awardsPrerequisite(
                        name: assignmentName(l, prerequisite),
                      ),
                    ),
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

class AwardResultSummary extends StatelessWidget {
  const AwardResultSummary({
    super.key,
    required this.state,
    required this.l10n,
  });
  final AwardMatchState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final evaluation = state.evaluation;
    if (evaluation == null) return Text(l10n.awardsSaving);
    final empty =
        evaluation.ribbons.isEmpty &&
        evaluation.medals.isEmpty &&
        evaluation.assignments.isEmpty;
    return Container(
      key: const ValueKey('result-awards-summary'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: TacticalPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.awardsThisMatch,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (empty)
            Text(l10n.awardsEmpty, textAlign: TextAlign.center)
          else ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                Text(
                  '${l10n.awardsRibbons} ×${evaluation.ribbons.values.fold(0, (a, b) => a + b)}',
                ),
                if (evaluation.medals.isNotEmpty)
                  Text(
                    '${l10n.awardsMedals} ×${evaluation.medals.values.fold(0, (a, b) => a + b)}',
                  ),
                Text(
                  '${l10n.awardsAssignments} ×${evaluation.assignments.length}',
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = (constraints.maxWidth / (72 * scale))
                    .floor()
                    .clamp(1, 6);
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final entry in evaluation.ribbons.entries)
                      SizedBox(
                        width: constraints.maxWidth / columns,
                        child: Tooltip(
                          message:
                              '${ribbonName(l10n, entry.key)} · ${l10n.awardsRibbons} ×${entry.value}',
                          child: Semantics(
                            label:
                                '${ribbonName(l10n, entry.key)} · ${l10n.awardsRibbons} ×${entry.value}',
                            excludeSemantics: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AwardEmblem(
                                  kind: AwardEmblemKind.ribbon,
                                  motif: AwardCatalog.ribbons.indexWhere(
                                    (r) => r.id == entry.key,
                                  ),
                                ),
                                Text('×${entry.value}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
