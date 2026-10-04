import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../profile/match_persistence.dart';
import '../ui/tactical_theme.dart';
import 'award_catalog.dart';
import 'award_presentation.dart';
import 'award_progress.dart';

class AwardsScreen extends ConsumerWidget {
  const AwardsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/awards'),
          builder: (_) => const AwardsScreen(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profilePersistenceStateProvider);
    final persistence = ref.watch(matchPersistenceProvider);
    final manager = persistence?.awards;
    final profile = manager?.profile;
    final l = AppLocalizations.of(context);
    return Scaffold(
      key: const ValueKey('awards-screen'),
      backgroundColor: TacticalPalette.background,
      appBar: AppBar(title: Text(l.awardsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: profile == null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        manager?.error != null ||
                                persistence?.initializationError != null ||
                                manager == null
                            ? l.awardsUnavailable
                            : l.awardsLoading,
                      ),
                      TextButton(
                        onPressed: () => persistence?.retryAwards(),
                        child: Text(l.awardsRetry),
                      ),
                    ],
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        if (manager!.dirty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(l.awardsUnsaved),
                          ),
                        TabBar(
                          tabs: [
                            Tab(
                              height:
                                  MediaQuery.textScalerOf(context).scale(16) +
                                  32,
                              text: l.awardsAssignments,
                            ),
                            Tab(
                              key: const ValueKey('awards-collection-tab'),
                              height:
                                  MediaQuery.textScalerOf(context).scale(16) +
                                  32,
                              text: l.awardsCollection,
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _Assignments(profile: profile, l: l),
                              _Collection(profile: profile, l: l),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Assignments extends StatelessWidget {
  const _Assignments({required this.profile, required this.l});
  final AwardProfile profile;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(l.awardsIntroduction),
      const SizedBox(height: 8),
      Text(l.awardsLocalOnly),
      for (final definition in AwardCatalog.assignments)
        Card(
          key: ValueKey('assignment-${definition.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AwardEmblem(
                      kind: AwardEmblemKind.assignment,
                      motif: definition.track.index,
                      earned: profile.completed.containsKey(definition.id),
                    ),
                    Text(
                      '${trackName(l, definition.track)} · ${tierName(l, definition.tier)}',
                    ),
                  ],
                ),
                Semantics(
                  header: true,
                  child: Text(
                    assignmentName(l, definition.id),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  profile.completed.containsKey(definition.id)
                      ? l.awardsCompleted
                      : profile.eligibleAssignments.contains(definition.id)
                      ? l.awardsInProgress
                      : l.awardsLocked,
                ),
                if (definition.prerequisite != null)
                  Text(
                    l.awardsPrerequisite(
                      name: assignmentName(l, definition.prerequisite!),
                    ),
                  ),
                const SizedBox(height: 8),
                AssignmentConditions(
                  definition: definition,
                  profile: profile,
                  l10n: l,
                ),
                const SizedBox(height: 8),
                Text(l.awardsBadgeReward),
                if (profile.completed[definition.id] case final completion?)
                  Text(
                    l.awardsCompletedAt(
                      date: DateFormat.yMd(
                        l.localeName,
                      ).format(completion.completedAtUtc.toLocal()),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _Collection extends StatefulWidget {
  const _Collection({required this.profile, required this.l});
  final AwardProfile profile;
  final AppLocalizations l;
  @override
  State<_Collection> createState() => _CollectionState();
}

class _CollectionState extends State<_Collection> {
  bool medals = false;
  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l.awardsRibbons),
              selected: !medals,
              onSelected: (_) => setState(() => medals = false),
            ),
            ChoiceChip(
              key: const ValueKey('awards-medals-toggle'),
              label: Text(l.awardsMedals),
              selected: medals,
              onSelected: (_) => setState(() => medals = true),
            ),
          ],
        ),
        for (final ribbon in AwardCatalog.ribbons) _card(context, ribbon, l),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    RibbonDefinition ribbon,
    AppLocalizations l,
  ) {
    final ribbons = widget.profile.ribbons[ribbon.id] ?? 0;
    final count = medals ? ribbons ~/ AwardCatalog.ribbonsPerMedal : ribbons;
    return Card(
      key: ValueKey('${medals ? 'medal' : 'ribbon'}-${ribbon.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AwardEmblem(
              kind: medals ? AwardEmblemKind.medal : AwardEmblemKind.ribbon,
              motif: AwardCatalog.ribbons.indexOf(ribbon),
              earned: count > 0,
            ),
            Semantics(
              header: true,
              child: Text(
                '${ribbonName(l, ribbon.id)} · ${medals ? l.awardsMedals : l.awardsRibbons}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(count == 0 ? l.awardsUnearned : l.awardsCount(count: count)),
            Text(ribbonCondition(l, ribbon)),
            if (medals) ...[
              Text(l.awardsMedalCondition(count: AwardCatalog.ribbonsPerMedal)),
              Text(
                l.awardsNextMedal(
                  count: ribbons % AwardCatalog.ribbonsPerMedal,
                  target: AwardCatalog.ribbonsPerMedal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
