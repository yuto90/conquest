import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../game/game_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../profile/match_contracts.dart';
import '../profile/profile_read_providers.dart';
import '../profile/profile_repository.dart';
import 'my_page.dart';
import 'tactical_theme.dart';

class MyPageHistoryTab extends ConsumerStatefulWidget {
  const MyPageHistoryTab({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<MyPageHistoryTab> createState() => _MyPageHistoryTabState();
}

class _MyPageHistoryTabState extends ConsumerState<MyPageHistoryTab>
    with AutomaticKeepAliveClientMixin {
  MatchHistoryFilter _filter = MatchHistoryFilter();

  @override
  bool get wantKeepAlive => true;

  void _change(MatchHistoryFilter filter) {
    ref.invalidate(
      matchHistoryProvider((profileId: widget.profileId, filter: filter)),
    );
    setState(() => _filter = filter);
  }

  @override
  void didUpdateWidget(MyPageHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) _filter = MatchHistoryFilter();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final query = (profileId: widget.profileId, filter: _filter);
    final provider = matchHistoryProvider(query);
    final value = ref.watch(provider);
    ref.listen(recentMatchesProvider(widget.profileId), (previous, next) {
      if (next.hasValue &&
          (previous?.hasValue == true || ref.read(provider).hasValue)) {
        ref.read(provider.notifier).refresh();
      }
    });
    final entries = value.asData?.value.entries ?? const <MatchHistoryEntry>[];
    return ListView.builder(
      key: PageStorageKey((widget.profileId, _filter)),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ProfileCard(
            title: l10n.myPageHistory,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HistoryChoice<CpuDifficulty>(
                  key: const ValueKey('history-difficulty'),
                  label: l10n.cpuDifficultyLabel,
                  value: _filter.difficulty,
                  choices: {
                    for (final d in CpuDifficulty.values)
                      d: profileDifficultyLabel(l10n, d),
                  },
                  onChanged: (difficulty) => _change(
                    MatchHistoryFilter(
                      difficulty: difficulty,
                      islandCount: _filter.islandCount,
                      status: _filter.status,
                      outcome: _filter.outcome,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _HistoryChoice<(MatchStatus, MatchOutcome?)>(
                  key: const ValueKey('history-result'),
                  label: l10n.myPageResult,
                  value: _filter.status == null
                      ? null
                      : (_filter.status!, _filter.outcome),
                  choices: {
                    (MatchStatus.completed, null): l10n.myPageCompleted,
                    for (final o in MatchOutcome.values)
                      (MatchStatus.completed, o): profileOutcomeLabel(l10n, o),
                    (MatchStatus.abandoned, null): l10n.myPageAbandoned,
                    (MatchStatus.interrupted, null): l10n.myPageInterrupted,
                  },
                  onChanged: (result) => _change(
                    MatchHistoryFilter(
                      difficulty: _filter.difficulty,
                      islandCount: _filter.islandCount,
                      status: result?.$1,
                      outcome: result?.$2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _HistoryChoice<int>(
                  key: const ValueKey('history-islands'),
                  label: l10n.myPageIslandCount,
                  value: _filter.islandCount,
                  choices: {
                    for (final count in GameConfiguration.allowedIslandCounts)
                      count: l10n.islandCountChoice(count: count),
                  },
                  onChanged: (count) => _change(
                    MatchHistoryFilter(
                      difficulty: _filter.difficulty,
                      islandCount: count,
                      status: _filter.status,
                      outcome: _filter.outcome,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _filter == MatchHistoryFilter()
                          ? null
                          : () => _change(MatchHistoryFilter()),
                      child: Text(l10n.myPageClearFilters),
                    ),
                    TextButton(
                      onPressed: () => ref.read(provider.notifier).refresh(),
                      child: Text(l10n.myPageRefresh),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        if (index <= entries.length) {
          return MyPageRecentMatchRow(
            key: ValueKey(
              'history-row-${entries[index - 1].record.start.matchId}',
            ),
            profileId: widget.profileId,
            entry: entries[index - 1],
          );
        }
        return ProfileAsyncSection(
          value: value,
          onRetry: () => ref.read(provider.notifier).refresh(),
          builder: (page) => Column(
            children: [
              if (page.entries.isEmpty)
                Text(
                  _filter == MatchHistoryFilter()
                      ? l10n.myPageNoMatches
                      : l10n.myPageNoMatchingMatches,
                ),
              if (page.loadingMore)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    semanticsLabel: l10n.myPageLoadingMore,
                  ),
                ),
              if (page.loadMoreError != null) Text(l10n.myPageLoadMoreError),
              if (page.nextCursor != null && !page.loadingMore)
                TextButton(
                  key: const ValueKey('history-load-more'),
                  onPressed: () => ref.read(provider.notifier).loadMore(),
                  child: Text(
                    page.loadMoreError == null
                        ? l10n.myPageLoadMore
                        : l10n.myPageRetry,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryChoice<T> extends StatelessWidget {
  const _HistoryChoice({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> choices;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey((label, value)),
    initialValue: value,
    hint: Text(AppLocalizations.of(context).myPageAll),
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      DropdownMenuItem(
        value: null,
        child: Text(AppLocalizations.of(context).myPageAll),
      ),
      for (final entry in choices.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: onChanged,
  );
}

class MyPageMatchDetailScreen extends ConsumerWidget {
  const MyPageMatchDetailScreen({
    super.key,
    required this.profileId,
    required this.matchId,
  });
  final String profileId;
  final String matchId;

  static Future<void> open(
    BuildContext context, {
    required String profileId,
    required String matchId,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/my-page/match',
        arguments: (profileId: profileId, matchId: matchId),
      ),
      builder: (_) =>
          MyPageMatchDetailScreen(profileId: profileId, matchId: matchId),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (profileId: profileId, matchId: matchId);
    final provider = matchDetailProvider(query);
    final value = ref.watch(provider);
    ref.listen(recentMatchesProvider(profileId), (previous, next) {
      if (next.hasValue &&
          (previous?.hasValue == true || ref.read(provider).hasValue))
        ref.invalidate(provider);
    });
    return Scaffold(
      key: const ValueKey('my-page-match-detail'),
      backgroundColor: TacticalPalette.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myPageMatchDetail),
        backgroundColor: TacticalPalette.surface,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ProfileAsyncSection(
                value: value,
                onRetry: () => ref.invalidate(provider),
                builder: (entry) => entry == null
                    ? Text(AppLocalizations.of(context).myPageMatchMissing)
                    : _MatchDetails(entry: entry),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchDetails extends StatelessWidget {
  const _MatchDetails({required this.entry});
  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final record = entry.record;
    final start = record.start;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final values = <(String, String)>[
      (l10n.myPageResult, profileMatchStatusLabel(l10n, record)),
      (l10n.myPageStartedAt, profileMatchDate(l10n, start.startedAtUtc)),
      (l10n.myPageEndedAt, profileMatchDate(l10n, record.endedAtUtc)),
      if (record.recoveredAtUtc != null)
        (l10n.myPageRecoveredAt, profileMatchDate(l10n, record.recoveredAtUtc)),
      (l10n.gameModeLabel, l10n.modePlayerVsCpu),
      (
        l10n.cpuDifficultyLabel,
        profileDifficultyLabel(l10n, start.configuration.cpuDifficulty),
      ),
      (
        l10n.myPageIslandCount,
        number.format(start.configuration.totalIslandCount),
      ),
      (l10n.myPageMatchTime, profileDuration(record.metrics.elapsedMs)),
      (
        l10n.myPageDispatches,
        record.metrics.dispatchCount == null
            ? '—'
            : number.format(record.metrics.dispatchCount),
      ),
      (
        l10n.myPageForces,
        record.metrics.forcesSent == null
            ? '—'
            : number.format(record.metrics.forcesSent),
      ),
      (
        l10n.myPageCaptures,
        record.metrics.captures == null
            ? '—'
            : number.format(record.metrics.captures),
      ),
      (l10n.myPageXpAwarded, number.format(entry.xpAwarded)),
      (l10n.myPageAppVersion, start.appVersion),
      (l10n.myPageRulesVersion, start.rulesVersion),
      (l10n.myPageMetricsVersion, number.format(start.metricsVersion)),
    ];
    return ProfileCard(
      title: l10n.myPageMatchDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                container: true,
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
          Text(l10n.myPageMetricDefinitions),
        ],
      ),
    );
  }
}

class MyPageRecentMatchRow extends StatelessWidget {
  const MyPageRecentMatchRow({
    super.key,
    required this.profileId,
    required this.entry,
  });
  final String profileId;
  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final record = entry.record;
    final status = profileMatchStatusLabel(l10n, record);
    return ListTile(
      key: ValueKey('recent-match-${record.start.matchId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$status · ${profileMatchDate(l10n, record.start.startedAtUtc)}',
      ),
      subtitle: Text(
        '${profileDifficultyLabel(l10n, record.start.configuration.cpuDifficulty)} · ${l10n.islandCountChoice(count: record.start.configuration.totalIslandCount)}\n${profileDuration(record.metrics.elapsedMs)} · ${l10n.myPageMatchXp(xp: entry.xpAwarded)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => MyPageMatchDetailScreen.open(
        context,
        profileId: profileId,
        matchId: record.start.matchId,
      ),
    );
  }
}

String profileOutcomeLabel(AppLocalizations l10n, MatchOutcome outcome) =>
    switch (outcome) {
      MatchOutcome.win => l10n.victory,
      MatchOutcome.loss => l10n.defeat,
      MatchOutcome.draw => l10n.draw,
    };

String profileMatchStatusLabel(AppLocalizations l10n, MatchRecord record) =>
    switch (record.status) {
      MatchStatus.completed => profileOutcomeLabel(l10n, record.outcome!),
      MatchStatus.abandoned => l10n.myPageAbandoned,
      MatchStatus.interrupted => l10n.myPageInterrupted,
      MatchStatus.inProgress => l10n.myPageInProgress,
    };

String profileMatchDate(AppLocalizations l10n, DateTime? utc) => utc == null
    ? l10n.myPageUnknown
    : DateFormat.yMd(l10n.localeName).add_Hm().format(utc.toLocal());
