import 'package:conquest/awards/award_catalog.dart';
import 'package:conquest/awards/award_progress.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

AwardMatch awardMatch({
  String id = 'match',
  int captures = 0,
  int dispatches = 0,
  int forces = 0,
  int elapsedMs = 180000,
  bool won = false,
  CpuDifficulty difficulty = CpuDifficulty.normal,
}) => AwardMatch(
  id: id,
  difficulty: difficulty,
  won: won,
  elapsedMs: elapsedMs,
  endedAtUtc: DateTime.utc(2026),
  summary: MatchSummary(
    playerCaptureCount: captures,
    playerDispatchCount: dispatches,
    playerDispatchedForces: forces,
  ),
);

void main() {
  test(
    'catalog has stable unique IDs, positive thresholds and acyclic prerequisites',
    () {
      final ids = AwardCatalog.assignments.map((a) => a.id).toSet();
      expect(ids.length, 9);
      expect(AwardCatalog.ribbons.map((r) => r.id).toSet().length, 6);
      expect(AwardCatalog.ribbons.map((r) => r.medalId).toSet().length, 6);
      for (final assignment in AwardCatalog.assignments) {
        expect(assignment.conditions.every((c) => c.target > 0), isTrue);
        final visited = <String>{assignment.id};
        var prerequisite = assignment.prerequisite;
        while (prerequisite != null) {
          expect(ids, contains(prerequisite));
          expect(visited.add(prerequisite), isTrue);
          prerequisite = AwardCatalog.assignments
              .singleWhere((a) => a.id == prerequisite)
              .prerequisite;
        }
      }
      expect(AwardCatalog.ribbons.every((r) => r.threshold > 0), isTrue);
    },
  );

  test('capture ribbons use per-match floors, never carry fractions', () {
    for (final (captures, expected) in [(2, 0), (3, 1), (6, 2)]) {
      final p = AwardProfile();
      expect(
        AwardEvaluator.evaluate(
              p,
              awardMatch(captures: captures),
              p.eligibleAssignments,
            ).ribbons['capture'] ??
            0,
        expected,
      );
    }
    var p = AwardProfile();
    for (final id in ['first', 'second']) {
      p = AwardEvaluator.evaluate(
        p,
        awardMatch(id: id, captures: 2),
        p.eligibleAssignments,
      ).profile;
    }
    expect(p.totals[AwardMetric.captures], 4);
    expect(p.ribbons['capture'] ?? 0, 0);
  });

  test('medals use before/after difference including multiple crossings', () {
    for (final (before, count, expected) in [
      (9, 1, 1),
      (10, 9, 0),
      (19, 1, 1),
      (20, 1, 0),
      (9, 12, 2),
    ]) {
      final p = AwardProfile(ribbons: {'capture': before});
      final e = AwardEvaluator.evaluate(
        p,
        awardMatch(captures: count * 3),
        p.eligibleAssignments,
      );
      expect(e.medals['capture'] ?? 0, expected);
      expect(e.profile.ribbons['capture'], before + count);
    }
  });

  test('maneuver and deployment floors do not carry across matches', () {
    for (final (dispatches, forces, count) in [
      (9, 499, 0),
      (10, 500, 1),
      (19, 999, 1),
      (20, 1000, 2),
    ]) {
      final profile = AwardProfile();
      final e = AwardEvaluator.evaluate(
        profile,
        awardMatch(dispatches: dispatches, forces: forces),
        profile.eligibleAssignments,
      );
      expect(e.ribbons['maneuver'] ?? 0, count);
      expect(e.ribbons['deployment'] ?? 0, count);
    }
    var profile = AwardProfile();
    for (final id in ['a', 'b']) {
      profile = AwardEvaluator.evaluate(
        profile,
        awardMatch(id: id, dispatches: 9, forces: 499),
        profile.eligibleAssignments,
      ).profile;
    }
    expect(profile.ribbons['maneuver'] ?? 0, 0);
    expect(profile.ribbons['deployment'] ?? 0, 0);
    expect(profile.totals[AwardMetric.forces], 998);
  });

  test('swift wins use exact result milliseconds, difficulty and outcome', () {
    for (final time in [179999, 180000, 180001]) {
      for (final difficulty in CpuDifficulty.values) {
        for (final won in [false, true]) {
          final p = AwardProfile();
          final e = AwardEvaluator.evaluate(
            p,
            awardMatch(elapsedMs: time, difficulty: difficulty, won: won),
            p.eligibleAssignments,
          );
          final qualifies =
              won &&
              time <= 180000 &&
              (difficulty == CpuDifficulty.normal ||
                  difficulty == CpuDifficulty.hard);
          expect(e.ribbons['swift_victory'] ?? 0, qualifies ? 1 : 0);
          expect(e.ribbons['victory'] ?? 0, won ? 1 : 0);
          expect(
            e.ribbons['hard_victory'] ?? 0,
            won && difficulty == CpuDifficulty.hard ? 1 : 0,
          );
        }
      }
    }
  });

  test('AND, start-time eligibility and no same-result tier cascade', () {
    var p = AwardProfile();
    final start = p.eligibleAssignments;
    final first = AwardEvaluator.evaluate(
      p,
      awardMatch(
        id: 'a',
        captures: 100,
        dispatches: 1,
        forces: 10000,
        won: true,
        difficulty: CpuDifficulty.hard,
      ),
      start,
    );
    expect(first.assignments, {'command_bronze'});
    p = first.profile;
    final second = AwardEvaluator.evaluate(
      p,
      awardMatch(id: 'b', dispatches: 9),
      p.eligibleAssignments,
    );
    expect(second.assignments, {'capture_bronze'});
    expect(second.profile.completed, isNot(contains('capture_silver')));
    final third = AwardEvaluator.evaluate(
      second.profile,
      awardMatch(id: 'c'),
      second.profile.eligibleAssignments,
    );
    expect(third.assignments, contains('capture_silver'));
    expect(third.assignments, isNot(contains('capture_gold')));
    final oldEligibility = AwardEvaluator.evaluate(
      second.profile,
      awardMatch(id: 'd'),
      start,
    );
    expect(oldEligibility.assignments, isNot(contains('capture_silver')));
  });

  test(
    'single-match progress never combines conditions from different matches',
    () {
      var p = AwardProfile();
      p = AwardEvaluator.evaluate(
        p,
        awardMatch(id: 'a', captures: 3),
        p.eligibleAssignments,
      ).profile;
      p = AwardEvaluator.evaluate(
        p,
        awardMatch(id: 'b', dispatches: 5),
        p.eligibleAssignments,
      ).profile;
      expect(p.completed, isNot(contains('tactics_bronze')));
      p = AwardEvaluator.evaluate(
        p,
        awardMatch(id: 'c', captures: 3, dispatches: 5),
        p.eligibleAssignments,
      ).profile;
      expect(p.completed, contains('tactics_bronze'));
      expect(p.completed, isNot(contains('tactics_silver')));
    },
  );

  test('duplicate ID is inert and non-victory actions still count', () {
    final p = AwardProfile();
    final match = awardMatch(captures: 6, dispatches: 20, forces: 1000);
    final e = AwardEvaluator.evaluate(p, match, p.eligibleAssignments);
    expect(e.ribbons, {'capture': 2, 'maneuver': 2, 'deployment': 2});
    expect(e.profile.completed, isNot(contains('command_bronze')));
    final duplicate = AwardEvaluator.evaluate(
      e.profile,
      match,
      e.profile.eligibleAssignments,
    );
    expect(duplicate.profile, same(e.profile));
    expect(duplicate.ribbons, isEmpty);
  });
}
