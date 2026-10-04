import 'package:flutter/foundation.dart';

import '../game/game_state.dart';
import '../game/match_summary.dart';
import 'award_catalog.dart';

class AssignmentCompletion {
  const AssignmentCompletion(this.matchId, this.completedAtUtc);
  final String matchId;
  final DateTime completedAtUtc;
  @override
  bool operator ==(Object other) =>
      other is AssignmentCompletion &&
      other.matchId == matchId &&
      other.completedAtUtc == completedAtUtc;
  @override
  int get hashCode => Object.hash(matchId, completedAtUtc);
}

class AwardEligibility {
  AwardEligibility(
    Set<String> assignments, {
    this.catalogVersion = AwardCatalog.version,
  }) : assignments = Set.unmodifiable(assignments) {
    if (catalogVersion != AwardCatalog.version ||
        !AwardCatalog.assignments
            .map((a) => a.id)
            .toSet()
            .containsAll(assignments)) {
      throw const FormatException('Unsupported award start context');
    }
  }
  final int catalogVersion;
  final Set<String> assignments;
  @override
  bool operator ==(Object other) =>
      other is AwardEligibility &&
      catalogVersion == other.catalogVersion &&
      setEquals(assignments, other.assignments);
  @override
  int get hashCode =>
      Object.hash(catalogVersion, Object.hashAllUnordered(assignments));
}

class AwardProfile {
  AwardProfile({
    Map<AwardMetric, int> totals = const {},
    Map<String, int> ribbons = const {},
    Map<String, AssignmentCompletion> completed = const {},
    Map<String, Map<AwardMetric, int>> singleMatchProgress = const {},
    Set<String> appliedMatches = const {},
  }) : totals = Map.unmodifiable(totals),
       ribbons = Map.unmodifiable(ribbons),
       completed = Map.unmodifiable(completed),
       singleMatchProgress = Map.unmodifiable({
         for (final entry in singleMatchProgress.entries)
           entry.key: Map<AwardMetric, int>.unmodifiable(entry.value),
       }),
       appliedMatches = Set.unmodifiable(appliedMatches);

  final Map<AwardMetric, int> totals;
  final Map<String, int> ribbons;
  final Map<String, AssignmentCompletion> completed;
  final Map<String, Map<AwardMetric, int>> singleMatchProgress;
  final Set<String> appliedMatches;

  Set<String> get eligibleAssignments => {
    for (final assignment in AwardCatalog.assignments)
      if (!completed.containsKey(assignment.id) &&
          (assignment.prerequisite == null ||
              completed.containsKey(assignment.prerequisite)))
        assignment.id,
  };

  Map<AwardMetric, int> progressFor(AssignmentDefinition assignment) =>
      assignment.singleMatch
      ? singleMatchProgress[assignment.id] ?? const {}
      : totals;

  @override
  bool operator ==(Object other) =>
      other is AwardProfile &&
      mapEquals(totals, other.totals) &&
      mapEquals(ribbons, other.ribbons) &&
      mapEquals(completed, other.completed) &&
      setEquals(appliedMatches, other.appliedMatches) &&
      setEquals(
        singleMatchProgress.keys.toSet(),
        other.singleMatchProgress.keys.toSet(),
      ) &&
      singleMatchProgress.keys.every(
        (id) =>
            mapEquals(singleMatchProgress[id], other.singleMatchProgress[id]),
      );
  @override
  int get hashCode => Object.hash(
    totals.length,
    ribbons.length,
    completed.length,
    singleMatchProgress.length,
    appliedMatches.length,
  );
}

class AwardMatch {
  const AwardMatch({
    required this.id,
    required this.difficulty,
    required this.won,
    required this.elapsedMs,
    required this.summary,
    required this.endedAtUtc,
  });
  final String id;
  final CpuDifficulty difficulty;
  final bool won;
  final int elapsedMs;
  final MatchSummary summary;
  final DateTime endedAtUtc;

  Map<AwardMetric, int> get values => {
    AwardMetric.captures: summary.playerCaptureCount,
    AwardMetric.dispatches: summary.playerDispatchCount,
    AwardMetric.forces: summary.playerDispatchedForces,
    AwardMetric.wins: won ? 1 : 0,
    AwardMetric.normalWins:
        won &&
            (difficulty == CpuDifficulty.normal ||
                difficulty == CpuDifficulty.hard)
        ? 1
        : 0,
    AwardMetric.hardWins: won && difficulty == CpuDifficulty.hard ? 1 : 0,
    AwardMetric.elapsedMs: elapsedMs,
  };
}

class AwardEvaluation {
  const AwardEvaluation(
    this.profile, {
    this.ribbons = const {},
    this.medals = const {},
    this.assignments = const {},
    this.progressed = const {},
  });
  final AwardProfile profile;
  final Map<String, int> ribbons;
  final Map<String, int> medals;
  final Set<String> assignments;
  final Set<String> progressed;
  @override
  bool operator ==(Object other) =>
      other is AwardEvaluation &&
      profile == other.profile &&
      mapEquals(ribbons, other.ribbons) &&
      mapEquals(medals, other.medals) &&
      setEquals(assignments, other.assignments) &&
      setEquals(progressed, other.progressed);
  @override
  int get hashCode => Object.hash(
    profile,
    ribbons.length,
    medals.length,
    assignments.length,
    progressed.length,
  );
}

abstract final class AwardEvaluator {
  static AwardEvaluation evaluate(
    AwardProfile before,
    AwardMatch match,
    Set<String> eligibleAtStart,
  ) {
    if (before.appliedMatches.contains(match.id))
      return AwardEvaluation(before);
    final values = match.values;
    final earnedRibbons = <String, int>{};
    final medals = <String, int>{};
    final ribbons = {...before.ribbons};
    for (final ribbon in AwardCatalog.ribbons) {
      final count = ribbon.id == 'swift_victory'
          ? (values[AwardMetric.normalWins] == 1 &&
                    match.elapsedMs <= ribbon.threshold
                ? 1
                : 0)
          : values[ribbon.metric]! ~/ ribbon.threshold;
      if (count == 0) continue;
      earnedRibbons[ribbon.id] = count;
      final previous = ribbons[ribbon.id] ?? 0;
      ribbons[ribbon.id] = previous + count;
      final earned =
          (previous + count) ~/ AwardCatalog.ribbonsPerMedal -
          previous ~/ AwardCatalog.ribbonsPerMedal;
      if (earned > 0) medals[ribbon.id] = earned;
    }
    final totals = {...before.totals};
    for (final entry in values.entries) {
      if (entry.key != AwardMetric.elapsedMs) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    totals[AwardMetric.captureRibbons] = ribbons['capture'] ?? 0;
    final completed = {...before.completed};
    final singleProgress = {...before.singleMatchProgress};
    final earnedAssignments = <String>{};
    final progressed = <String>{};
    for (final assignment in AwardCatalog.assignments) {
      if (!eligibleAtStart.contains(assignment.id) ||
          completed.containsKey(assignment.id) ||
          (assignment.prerequisite != null &&
              !before.completed.containsKey(assignment.prerequisite)))
        continue;
      final current = assignment.singleMatch ? values : totals;
      final satisfied = assignment.conditions.every(
        (c) => c.satisfied(current),
      );
      final previous = before.progressFor(assignment);
      if (assignment.singleMatch) {
        if (satisfied ||
            _score(assignment, current) > _score(assignment, previous)) {
          singleProgress[assignment.id] = current;
          progressed.add(assignment.id);
        }
      } else if (assignment.conditions.any(
        (c) =>
            (current[c.metric] ?? 0) > (previous[c.metric] ?? 0) &&
            (previous[c.metric] ?? 0) < c.target,
      )) {
        progressed.add(assignment.id);
      }
      if (satisfied) {
        completed[assignment.id] = AssignmentCompletion(
          match.id,
          match.endedAtUtc,
        );
        earnedAssignments.add(assignment.id);
      }
    }
    return AwardEvaluation(
      AwardProfile(
        totals: totals,
        ribbons: ribbons,
        completed: completed,
        singleMatchProgress: singleProgress,
        appliedMatches: {...before.appliedMatches, match.id},
      ),
      ribbons: Map.unmodifiable(earnedRibbons),
      medals: Map.unmodifiable(medals),
      assignments: Set.unmodifiable(earnedAssignments),
      progressed: Set.unmodifiable(progressed),
    );
  }

  static double _score(
    AssignmentDefinition definition,
    Map<AwardMetric, int> values,
  ) => definition.conditions.fold(
    0,
    (score, condition) =>
        score +
        (condition.maximum
            ? (condition.satisfied(values) ? 1 : 0)
            : ((values[condition.metric] ?? 0) / condition.target).clamp(0, 1)),
  );
}
