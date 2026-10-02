import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../profile/match_contracts.dart';
import '../profile/profile_repository.dart';
import 'my_page.dart';
import 'tactical_theme.dart';

/// Integration destinations; issue 132 replaces their bodies without changing callers.
class MyPageHistoryTab extends StatelessWidget {
  const MyPageHistoryTab({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('my-page-history-scroll'),
    padding: const EdgeInsets.all(16),
    children: [
      ProfileCard(
        title: AppLocalizations.of(context).myPageHistory,
        child: Text(AppLocalizations.of(context).myPageHistoryPending),
      ),
    ],
  );
}

class MyPageMatchDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('my-page-match-detail'),
    backgroundColor: TacticalPalette.background,
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).myPageMatchDetail),
      backgroundColor: TacticalPalette.surface,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(AppLocalizations.of(context).myPageHistoryPending),
      ),
    ),
  );
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
    final status = switch (record.status) {
      MatchStatus.completed => switch (record.outcome!) {
        MatchOutcome.win => l10n.victory,
        MatchOutcome.loss => l10n.defeat,
        MatchOutcome.draw => l10n.draw,
      },
      MatchStatus.abandoned => l10n.myPageAbandoned,
      MatchStatus.interrupted => l10n.myPageInterrupted,
      MatchStatus.inProgress => l10n.myPageInProgress,
    };
    return ListTile(
      key: ValueKey('recent-match-${record.start.matchId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$status · ${DateFormat.yMd(l10n.localeName).add_Hm().format(record.start.startedAtUtc.toLocal())}',
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
