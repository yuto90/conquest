import '../game/game_state.dart';
import '../game/match_summary.dart';
import '../awards/award_progress.dart';

enum SessionKind {
  normal('normal'),
  daily('daily');

  const SessionKind(this.storageKey);
  final String storageKey;
}

enum SessionOrigin { gameplay, spectator, practice, preview, cpuForecast, test }

enum MatchStatus {
  inProgress('in_progress'),
  completed('completed'),
  abandoned('abandoned'),
  interrupted('interrupted');

  const MatchStatus(this.storageKey);
  final String storageKey;
}

enum MatchOutcome {
  win('win'),
  loss('loss'),
  draw('draw');

  const MatchOutcome(this.storageKey);
  final String storageKey;
}

String gameModeStorageKey(GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => 'player_vs_cpu',
  GameMode.cpuVsCpu => 'cpu_vs_cpu',
};

String difficultyStorageKey(CpuDifficulty difficulty) => switch (difficulty) {
  CpuDifficulty.veryEasy => 'very_easy',
  CpuDifficulty.easy => 'easy',
  CpuDifficulty.normal => 'normal',
  CpuDifficulty.hard => 'hard',
};

bool isRecordableSession({
  required GameConfiguration configuration,
  required SessionOrigin origin,
  required SessionKind kind,
}) =>
    origin == SessionOrigin.gameplay &&
    kind == SessionKind.normal &&
    configuration.gameMode == GameMode.playerVsCpu &&
    GameConfiguration.isValidIslandCount(configuration.totalIslandCount);

void requireUuid(String value, String name) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value)) {
    throw ArgumentError.value(value, name, 'must be a canonical UUID');
  }
}

void requireNonNegative(int? value, String name) {
  if (value != null && value < 0) {
    throw ArgumentError.value(value, name, 'must be non-negative');
  }
}

void requireVersion(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}

DateTime storageUtc(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.millisecondsSinceEpoch,
  isUtc: true,
);

final class MatchStartContext {
  MatchStartContext({
    required this.matchId,
    required this.profileId,
    required this.executionId,
    required this.configuration,
    required this.sessionKind,
    required this.origin,
    required DateTime startedAtUtc,
    required this.appVersion,
    required this.rulesVersion,
    this.metricsVersion = currentMetricsVersion,
  }) : startedAtUtc = storageUtc(startedAtUtc) {
    requireUuid(matchId, 'matchId');
    requireUuid(profileId, 'profileId');
    requireUuid(executionId, 'executionId');
    requireVersion(appVersion, 'appVersion');
    requireVersion(rulesVersion, 'rulesVersion');
    if (metricsVersion < 1) {
      throw ArgumentError.value(metricsVersion, 'metricsVersion');
    }
  }

  static const currentMetricsVersion = 1;

  final String matchId;
  final String profileId;
  final String executionId;
  final GameConfiguration configuration;
  final SessionKind sessionKind;
  final SessionOrigin origin;
  final DateTime startedAtUtc;
  final String appVersion;
  final String rulesVersion;
  final int metricsVersion;

  bool get isRecordable => isRecordableSession(
    configuration: configuration,
    origin: origin,
    kind: sessionKind,
  );

  Object get _value => (
    matchId,
    profileId,
    executionId,
    configuration,
    sessionKind,
    origin,
    startedAtUtc,
    appVersion,
    rulesVersion,
    metricsVersion,
  );

  @override
  bool operator ==(Object other) =>
      other is MatchStartContext && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

final class MatchMetrics {
  MatchMetrics({
    this.elapsedMs,
    this.dispatchCount,
    this.forcesSent,
    this.captures,
  }) {
    requireNonNegative(elapsedMs, 'elapsedMs');
    requireNonNegative(dispatchCount, 'dispatchCount');
    requireNonNegative(forcesSent, 'forcesSent');
    requireNonNegative(captures, 'captures');
  }

  factory MatchMetrics.fromSummary(MatchSummary summary) => MatchMetrics(
    elapsedMs: summary.elapsedMs,
    dispatchCount: summary.playerDispatchCount,
    forcesSent: summary.playerDispatchedForces,
    captures: summary.playerCaptureCount,
  );

  final int? elapsedMs;
  final int? dispatchCount;
  final int? forcesSent;
  final int? captures;

  bool get isKnown =>
      elapsedMs != null &&
      dispatchCount != null &&
      forcesSent != null &&
      captures != null;

  bool get isUnknown =>
      elapsedMs == null &&
      dispatchCount == null &&
      forcesSent == null &&
      captures == null;

  Object get _value => (elapsedMs, dispatchCount, forcesSent, captures);

  @override
  bool operator ==(Object other) =>
      other is MatchMetrics && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

final class MatchRecord {
  MatchRecord({
    required this.start,
    required this.status,
    this.outcome,
    DateTime? endedAtUtc,
    DateTime? recoveredAtUtc,
    MatchMetrics? metrics,
  }) : endedAtUtc = endedAtUtc == null ? null : storageUtc(endedAtUtc),
       recoveredAtUtc = recoveredAtUtc == null
           ? null
           : storageUtc(recoveredAtUtc),
       metrics = metrics ?? MatchMetrics() {
    if (!start.isRecordable) {
      throw ArgumentError('Session is excluded from persistence');
    }
    final valid = switch (status) {
      MatchStatus.inProgress =>
        outcome == null &&
            endedAtUtc == null &&
            recoveredAtUtc == null &&
            this.metrics.isUnknown,
      MatchStatus.completed =>
        outcome != null &&
            endedAtUtc != null &&
            recoveredAtUtc == null &&
            this.metrics.isKnown,
      MatchStatus.abandoned =>
        outcome == null &&
            endedAtUtc != null &&
            recoveredAtUtc == null &&
            this.metrics.isKnown,
      MatchStatus.interrupted =>
        outcome == null &&
            endedAtUtc == null &&
            recoveredAtUtc != null &&
            this.metrics.isUnknown,
    };
    if (!valid) throw ArgumentError('Invalid match state payload');
  }

  final MatchStartContext start;
  final MatchStatus status;
  final MatchOutcome? outcome;
  final DateTime? endedAtUtc;
  final DateTime? recoveredAtUtc;
  final MatchMetrics metrics;

  bool get isTerminal => status != MatchStatus.inProgress;

  Object get _value =>
      (start, status, outcome, endedAtUtc, recoveredAtUtc, metrics);

  @override
  bool operator ==(Object other) =>
      other is MatchRecord && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

final class MatchCompletion {
  MatchCompletion.fromGame({
    required MatchStartContext start,
    required GameResult result,
    required MatchSummary summary,
    required DateTime endedAtUtc,
  }) : record = MatchRecord(
         start: start,
         status: MatchStatus.completed,
         outcome: switch (result.type) {
           GameResultType.victory => MatchOutcome.win,
           GameResultType.defeat => MatchOutcome.loss,
           GameResultType.draw => MatchOutcome.draw,
         },
         endedAtUtc: endedAtUtc,
         metrics: MatchMetrics.fromSummary(summary),
       ) {
    if (result.elapsedMs != summary.elapsedMs) {
      throw ArgumentError('Result and summary elapsedMs must agree');
    }
    final validWinner = switch (result.type) {
      GameResultType.victory => result.winner == Faction.player,
      GameResultType.defeat => result.winner == Faction.cpu,
      GameResultType.draw =>
        result.winner == null || result.winner == Faction.neutral,
    };
    if (!validWinner) throw ArgumentError('Result winner contradicts outcome');
  }

  final MatchRecord record;

  @override
  bool operator ==(Object other) =>
      other is MatchCompletion && other.record == record;

  @override
  int get hashCode => record.hashCode;
}

final class MatchCommitConflict implements Exception {
  const MatchCommitConflict(this.matchId);
  final String matchId;

  @override
  String toString() => 'Conflicting finalization for $matchId';
}

/// Call inside the transaction before returning a previously saved receipt.
void requireSameFinalization(MatchRecord existing, MatchRecord incoming) {
  if (!existing.isTerminal || !incoming.isTerminal || existing != incoming) {
    throw MatchCommitConflict(incoming.start.matchId);
  }
}

final class MatchCommitReceipt {
  MatchCommitReceipt({
    required this.record,
    required this.xpAwarded,
    required this.totalXpBefore,
    required this.totalXpAfter,
    required this.rewardVersion,
    this.awards,
  }) {
    if (!record.isTerminal)
      throw ArgumentError('Receipt requires finalization');
    requireNonNegative(xpAwarded, 'xpAwarded');
    requireNonNegative(totalXpBefore, 'totalXpBefore');
    requireNonNegative(totalXpAfter, 'totalXpAfter');
    requireVersion(rewardVersion, 'rewardVersion');
    if (totalXpAfter != totalXpBefore + xpAwarded ||
        (record.outcome != MatchOutcome.win && xpAwarded != 0)) {
      throw ArgumentError('Invalid XP receipt');
    }
  }

  final MatchRecord record;
  final int xpAwarded;
  final int totalXpBefore;
  final int totalXpAfter;
  final String rewardVersion;
  final AwardEvaluation? awards;

  Object get _value =>
      (record, xpAwarded, totalXpBefore, totalXpAfter, rewardVersion, awards);

  @override
  bool operator ==(Object other) =>
      other is MatchCommitReceipt && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

/// All writes are durable and serialized per profile; failures throw.
abstract interface class MatchCompletionService {
  /// Repeated identical starts are no-ops; a different payload conflicts.
  Future<void> recordStart(
    MatchStartContext start, {
    AwardEligibility? awardEligibility,
  });

  /// Atomically saves the final record, XP and awards, or the original receipt.
  /// Retries use the frozen DTO, including its original end timestamp.
  Future<MatchCommitReceipt> complete(MatchCompletion completion);

  Future<MatchCommitReceipt> abandon(MatchRecord abandoned);

  /// Caller must hold exclusive ownership and prove the execution is no longer
  /// live. Backgrounding or another live Web tab does not permit recovery.
  Future<void> recoverInterrupted({
    required String profileId,
    required String executionId,
    required DateTime recoveredAtUtc,
  });
}
