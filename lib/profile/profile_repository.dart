import '../game/game_state.dart';
import 'match_contracts.dart';

final class PlayerProfile {
  PlayerProfile({
    required this.profileId,
    this.displayName,
    required this.avatarKey,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    required DateTime statsStartedAtUtc,
  }) : createdAtUtc = storageUtc(createdAtUtc),
       updatedAtUtc = storageUtc(updatedAtUtc),
       statsStartedAtUtc = storageUtc(statsStartedAtUtc) {
    requireUuid(profileId, 'profileId');
    requireVersion(avatarKey, 'avatarKey');
    if (displayName != null && displayName!.trim().isEmpty) {
      throw ArgumentError('Unset displayName must be null');
    }
  }

  final String profileId;
  final String? displayName;
  final String avatarKey;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime statsStartedAtUtc;
}

final class ProfileEdit {
  ProfileEdit({required String? displayName, required this.avatarKey})
    : displayName = displayName?.trim() {
    requireVersion(avatarKey, 'avatarKey');
    if (this.displayName != null &&
        (this.displayName!.isEmpty ||
            RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(this.displayName!))) {
      throw ArgumentError('Invalid displayName');
    }
  }

  final String? displayName;
  final String avatarKey;
}

final class MatchHistoryFilter {
  MatchHistoryFilter({
    this.difficulty,
    this.islandCount,
    MatchStatus? status,
    this.outcome,
    this.sessionKind = SessionKind.normal,
  }) : status = status ?? (outcome == null ? null : MatchStatus.completed) {
    if (islandCount != null &&
        !GameConfiguration.isValidIslandCount(islandCount!)) {
      throw ArgumentError.value(islandCount, 'islandCount');
    }
    if (outcome != null && this.status != MatchStatus.completed) {
      throw ArgumentError('Outcome filters require completed status');
    }
  }

  final CpuDifficulty? difficulty;
  final int? islandCount;
  final MatchStatus? status;
  final MatchOutcome? outcome;
  final SessionKind sessionKind;

  Object get _value => (difficulty, islandCount, status, outcome, sessionKind);

  @override
  bool operator ==(Object other) =>
      other is MatchHistoryFilter && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

final class MatchHistoryCursor {
  MatchHistoryCursor({
    required this.profileId,
    required this.filter,
    required DateTime startedAtUtc,
    required this.matchId,
  }) : startedAtUtc = storageUtc(startedAtUtc) {
    requireUuid(profileId, 'profileId');
    requireUuid(matchId, 'matchId');
  }

  final String profileId;
  final MatchHistoryFilter filter;
  final DateTime startedAtUtc;
  final String matchId;

  void requireScope(String profileId, MatchHistoryFilter filter) {
    if (this.profileId != profileId || this.filter != filter) {
      throw ArgumentError('Cursor belongs to a different history query');
    }
  }
}

final class MatchHistoryEntry {
  MatchHistoryEntry({required this.record, required this.xpAwarded}) {
    requireNonNegative(xpAwarded, 'xpAwarded');
    if (record.outcome != MatchOutcome.win && xpAwarded != 0) {
      throw ArgumentError('Only completed victories may have XP');
    }
  }

  final MatchRecord record;
  final int xpAwarded;
}

final class MatchHistoryPage {
  MatchHistoryPage({
    required Iterable<MatchHistoryEntry> entries,
    this.nextCursor,
  }) : entries = List.unmodifiable(entries);

  final List<MatchHistoryEntry> entries;
  final MatchHistoryCursor? nextCursor;
}

final class MatchStatistics {
  MatchStatistics({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.abandoned = 0,
    this.interrupted = 0,
    this.elapsedMs = 0,
    this.dispatchCount = 0,
    this.forcesSent = 0,
    this.captures = 0,
  }) {
    for (final value in [
      wins,
      losses,
      draws,
      abandoned,
      interrupted,
      elapsedMs,
      dispatchCount,
      forcesSent,
      captures,
    ]) {
      requireNonNegative(value, 'statistics');
    }
  }

  final int wins;
  final int losses;
  final int draws;
  final int abandoned;
  final int interrupted;
  final int elapsedMs;
  final int dispatchCount;
  final int forcesSent;
  final int captures;

  int get completed => wins + losses + draws;
  double? get winRate => completed == 0 ? null : wins / completed;
}

/// Read failures throw/emit errors; they never masquerade as empty data.
abstract interface class PlayerProfileRepository {
  Stream<PlayerProfile> watchProfile(String profileId);

  /// Validate 1–20 graphemes and bundled avatar keys before saving. Only these
  /// editable fields change; profile identity, XP and history are untouched.
  Future<PlayerProfile> editProfile(String profileId, ProfileEdit edit);

  /// The ledger is the source of truth; derive rank with existing RankCatalog.
  Stream<int> watchTotalXp(String profileId);

  /// Metrics sum completed matches only; abandoned/interrupted are separate.
  Stream<MatchStatistics> watchStatistics(
    String profileId, {
    MatchHistoryFilter? filter,
  });

  Stream<Map<CpuDifficulty, MatchStatistics>> watchDifficultyStatistics(
    String profileId,
  );

  /// MIN(elapsed_ms) for wins at the exact difficulty AND island count.
  Future<int?> fastestVictoryMs(
    String profileId, {
    required CpuDifficulty difficulty,
    required int islandCount,
  });

  /// Descending (started_at_utc, match_id), with strict keyset pagination.
  /// Enforce cursor scope and 1 <= limit <= 100. Default page: 20; recent: 5.
  Future<MatchHistoryPage> loadHistory(
    String profileId, {
    MatchHistoryFilter? filter,
    MatchHistoryCursor? before,
    int limit = 20,
  });

  /// Return null only for a genuinely missing match in this profile scope.
  Future<MatchHistoryEntry?> loadMatch(String profileId, String matchId);
}
