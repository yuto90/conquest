import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../game/game_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../profile/match_persistence.dart';
import '../profile/profile_read_providers.dart';
import '../profile/profile_repository.dart';
import '../rank_progression.dart';
import 'my_page_destinations.dart';
import 'profile_editor.dart';
import 'tactical_theme.dart';

enum MyPageTab { stats, history }

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key, this.initialTab = MyPageTab.stats});

  final MyPageTab initialTab;

  static Future<void> open(
    BuildContext context, {
    MyPageTab initialTab = MyPageTab.stats,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/my-page'),
      builder: (_) => MyPageScreen(initialTab: initialTab),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const ValueKey('my-page'),
      backgroundColor: TacticalPalette.background,
      appBar: AppBar(
        title: Text(l10n.myPageTitle),
        backgroundColor: TacticalPalette.surface,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ProfileAsyncSection(
              value: ref.watch(activeProfileIdProvider),
              onRetry: () async {
                await ref.read(matchPersistenceProvider)?.retry();
                ref.invalidate(playerProfileRepositoryProvider);
              },
              builder: (profileId) => DefaultTabController(
                length: MyPageTab.values.length,
                initialIndex: initialTab.index,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: _ProfileHeader(profileId: profileId),
                    ),
                    SliverToBoxAdapter(
                      child: TabBar(
                        labelColor: TacticalPalette.foreground,
                        unselectedLabelColor: TacticalPalette.muted,
                        tabs: [
                          Tab(
                            key: const ValueKey('my-page-stats-tab'),
                            height:
                                MediaQuery.textScalerOf(context).scale(16) + 32,
                            text: l10n.myPageStats,
                          ),
                          Tab(
                            key: const ValueKey('my-page-history-tab'),
                            height:
                                MediaQuery.textScalerOf(context).scale(16) + 32,
                            text: l10n.myPageHistory,
                          ),
                        ],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      _StatisticsTab(profileId: profileId),
                      MyPageHistoryTab(profileId: profileId),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAsyncSection<T> extends StatelessWidget {
  const ProfileAsyncSection({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: false,
    skipLoadingOnReload: false,
    loading: () => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          semanticsLabel: AppLocalizations.of(context).myPageLoading,
        ),
      ),
    ),
    error: (_, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context).myPageReadError),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).myPageRetry),
          ),
        ],
      ),
    ),
    data: builder,
  );
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: TacticalPalette.paper,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TacticalTypography.of(context).display(fontSize: 20),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profilePersistenceStateProvider);
    final runtime = ref.read(matchPersistenceProvider);
    final l10n = AppLocalizations.of(context);
    final unsaved =
        runtime?.saves.values.any((s) => s.phase == MatchSavePhase.unsaved) ??
        false;
    final saving =
        runtime?.saves.values.any((s) => s.phase == MatchSavePhase.saving) ??
        false;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileAsyncSection(
            value: ref.watch(playerProfileProvider(profileId)),
            onRetry: () => ref.invalidate(playerProfileProvider(profileId)),
            builder: (profile) => ProfileCard(
              title: profile.displayName ?? l10n.myPageDefaultName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ProfileAvatar(
                      avatarKey: profile.avatarKey,
                      size: 64,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('edit-profile'),
                    onPressed: () async {
                      final saved = await ProfileEditor.open(context, profile);
                      if (saved == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.myPageProfileSaved)),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.myPageEdit),
                  ),
                  ProfileAsyncSection(
                    value: ref.watch(rankProgressProvider),
                    onRetry: () => ref.invalidate(rankProgressProvider),
                    builder: (progress) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(Icons.military_tech_outlined),
                        ),
                        Text(
                          l10n.rankDisplay(
                            rank: progress.rank,
                            title: progress.localizedTitle(l10n),
                          ),
                        ),
                        Text(l10n.myPageTotalXp(xp: progress.totalXp)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.progressRatio,
                          semanticsLabel: progress.isMax
                              ? l10n.rankMax
                              : l10n.rankProgress(xp: progress.xpToNextRank),
                          semanticsValue:
                              '${(progress.progressRatio * 100).round()}%',
                        ),
                        Text(
                          progress.isMax
                              ? l10n.rankMax
                              : l10n.rankProgress(xp: progress.xpToNextRank),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.myPageLocalDevice),
                  Text(
                    l10n.myPageStatsSince(
                      date: DateFormat.yMd(
                        l10n.localeName,
                      ).format(profile.statsStartedAtUtc.toLocal()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (unsaved || saving) ...[
            Semantics(
              liveRegion: true,
              child: Text(unsaved ? l10n.matchUnsaved : l10n.matchSaving),
            ),
            if (unsaved)
              TextButton(
                onPressed: () => runtime!.retry(),
                child: Text(l10n.storageRetry),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatisticsTab extends ConsumerWidget {
  const _StatisticsTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = (profileId: profileId, filter: MatchHistoryFilter());
    return ListView(
      key: const PageStorageKey('my-page-stats-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        ProfileCard(
          title: l10n.myPageStats,
          child: ProfileAsyncSection(
            value: ref.watch(profileStatisticsProvider(query)),
            onRetry: () => ref.invalidate(profileStatisticsProvider(query)),
            builder: (statistics) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (statistics.completed == 0) Text(l10n.myPageNoCompleted),
                StatisticsValues(statistics: statistics),
              ],
            ),
          ),
        ),
        ProfileCard(
          title: l10n.myPageByDifficulty,
          child: ProfileAsyncSection(
            value: ref.watch(difficultyStatisticsProvider(profileId)),
            onRetry: () =>
                ref.invalidate(difficultyStatisticsProvider(profileId)),
            builder: (groups) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final difficulty in CpuDifficulty.values) ...[
                  Text(
                    profileDifficultyLabel(l10n, difficulty),
                    style: TacticalTypography.of(context).display(fontSize: 16),
                  ),
                  if (groups[difficulty] case final statistics?)
                    StatisticsValues(statistics: statistics)
                  else
                    Text('—'),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
        _FastestVictory(profileId: profileId),
        ProfileCard(
          title: l10n.myPageRecent,
          child: ProfileAsyncSection(
            value: ref.watch(recentMatchesProvider(profileId)),
            onRetry: () => ref.invalidate(recentMatchesProvider(profileId)),
            builder: (entries) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty) Text(l10n.myPageNoMatches),
                for (final entry in entries)
                  MyPageRecentMatchRow(profileId: profileId, entry: entry),
                OutlinedButton(
                  key: const ValueKey('my-page-view-history'),
                  onPressed: () => DefaultTabController.of(
                    context,
                  ).animateTo(MyPageTab.history.index),
                  child: Text(l10n.myPageViewHistory),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StatisticsValues extends StatelessWidget {
  const StatisticsValues({super.key, required this.statistics});
  final MatchStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final values = <(String, String)>[
      (l10n.myPageCompleted, number.format(statistics.completed)),
      (l10n.myPageWins, number.format(statistics.wins)),
      (l10n.myPageLosses, number.format(statistics.losses)),
      (l10n.myPageDraws, number.format(statistics.draws)),
      (
        l10n.myPageWinRate,
        statistics.winRate == null
            ? '—'
            : NumberFormat.percentPattern(
                l10n.localeName,
              ).format(statistics.winRate),
      ),
      (l10n.myPageCompletedTime, profileDuration(statistics.elapsedMs)),
      (
        l10n.myPageDispatches,
        statistics.dispatchCount == null
            ? '—'
            : number.format(statistics.dispatchCount),
      ),
      (
        l10n.myPageForces,
        statistics.forcesSent == null
            ? '—'
            : number.format(statistics.forcesSent),
      ),
      (
        l10n.myPageCaptures,
        statistics.captures == null ? '—' : number.format(statistics.captures),
      ),
      (l10n.myPageAbandoned, number.format(statistics.abandoned)),
      (l10n.myPageInterrupted, number.format(statistics.interrupted)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final (label, value) in values)
            SizedBox(
              width: constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 320
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth,
              child: Semantics(
                label: '$label: $value',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    Text(
                      value,
                      style: TacticalTypography.of(
                        context,
                      ).display(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FastestVictory extends ConsumerStatefulWidget {
  const _FastestVictory({required this.profileId});
  final String profileId;

  @override
  ConsumerState<_FastestVictory> createState() => _FastestVictoryState();
}

class _FastestVictoryState extends ConsumerState<_FastestVictory> {
  CpuDifficulty _difficulty = CpuDifficulty.normal;
  int _islandCount = GameConfiguration.defaultIslandCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (
      profileId: widget.profileId,
      difficulty: _difficulty,
      islandCount: _islandCount,
    );
    return ProfileCard(
      title: l10n.myPageFastest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<CpuDifficulty>(
            key: const ValueKey('fastest-difficulty'),
            initialValue: _difficulty,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: l10n.cpuDifficultyLabel),
            items: [
              for (final difficulty in CpuDifficulty.values)
                DropdownMenuItem(
                  value: difficulty,
                  child: Text(profileDifficultyLabel(l10n, difficulty)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _difficulty = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const ValueKey('fastest-islands'),
            initialValue: _islandCount,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: l10n.islandCountLabel),
            items: [
              for (final count in GameConfiguration.allowedIslandCounts)
                DropdownMenuItem(
                  value: count,
                  child: Text(l10n.islandCountChoice(count: count)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _islandCount = value);
            },
          ),
          const SizedBox(height: 16),
          ProfileAsyncSection(
            value: ref.watch(fastestVictoryProvider(query)),
            onRetry: () => ref.invalidate(fastestVictoryProvider(query)),
            builder: (elapsed) => Text(
              profileDuration(elapsed),
              style: TacticalTypography.of(context).display(fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }
}

String profileDifficultyLabel(
  AppLocalizations l10n,
  CpuDifficulty difficulty,
) => switch (difficulty) {
  CpuDifficulty.veryEasy => l10n.difficultyVeryEasy,
  CpuDifficulty.easy => l10n.difficultyEasy,
  CpuDifficulty.normal => l10n.difficultyNormal,
  CpuDifficulty.hard => l10n.difficultyHard,
};

String profileDuration(int? elapsedMs) {
  if (elapsedMs == null) return '—';
  final seconds = elapsedMs ~/ 1000;
  return '${seconds ~/ 3600}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
