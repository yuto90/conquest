import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchSummary', () {
    test('records only positive established dispatch values', () {
      const summary = MatchSummary();

      expect(summary.recordDispatch(0), same(summary));
      expect(summary.recordDispatch(-1), same(summary));
      expect(
        summary.recordDispatch(2).recordDispatch(3),
        const MatchSummary(
          playerDispatchCount: 2,
          playerDispatchedForces: 5,
        ),
      );
    });

    test('formats truncated seconds and long matches without overflow', () {
      expect(formatMatchDuration(0), '0:00');
      expect(formatMatchDuration(59_999), '0:59');
      expect(formatMatchDuration(60_000), '1:00');
      expect(formatMatchDuration(3_723_999), '1:02:03');
    });

    test('keeps the summary immutable when elapsed time is fixed', () {
      const summary = MatchSummary(
        elapsedMs: 99,
        playerDispatchCount: 2,
        playerDispatchedForces: 7,
        playerCaptureCount: 1,
      );

      final fixed = summary.withElapsedMs(1_234);

      expect(summary.elapsedMs, 99);
      expect(fixed, isNot(same(summary)));
      expect(fixed.playerDispatchCount, 2);
      expect(fixed.playerDispatchedForces, 7);
      expect(fixed.playerCaptureCount, 1);
    });
  });

  group('GameRules match summary ownership events', () {
    const playerSource = IslandState(
      id: 0,
      faction: Faction.player,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );
    const target = IslandState(
      id: 1,
      faction: Faction.neutral,
      size: IslandSize.small,
      durability: 1,
      capacity: 50,
    );
    const cpuSource = IslandState(
      id: 2,
      faction: Faction.cpu,
      size: IslandSize.headquarters,
      currentForces: 100,
      capacity: 200,
    );

    test('counts capture, recapture, and capture again in one rules tick', () {
      const state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [playerSource, target, cpuSource],
        movingForces: const [
          MovingForce(
            id: 1,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 2,
            arrivalTimeMs: 100,
            durationMs: 100,
          ),
          MovingForce(
            id: 2,
            faction: Faction.cpu,
            sourceIslandId: 2,
            destinationIslandId: 1,
            strength: 3,
            arrivalTimeMs: 200,
            durationMs: 100,
          ),
          MovingForce(
            id: 3,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 4,
            arrivalTimeMs: 300,
            durationMs: 300,
          ),
        ],
      );

      final next = const GameRules().tick(state, deltaMs: 300);

      expect(next.islands[1].faction, Faction.player);
      expect(next.matchSummary.playerCaptureCount, 2);
      expect(next.matchSummary.elapsedMs, 300);
    });

    test('does not count equal simultaneous attacks as a capture', () {
      final state = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: const [playerSource, target, cpuSource],
        movingForces: const [
          MovingForce(
            id: 1,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 1,
            strength: 3,
            arrivalTimeMs: 100,
            durationMs: 100,
          ),
          MovingForce(
            id: 2,
            faction: Faction.cpu,
            sourceIslandId: 2,
            destinationIslandId: 1,
            strength: 3,
            arrivalTimeMs: 100,
            durationMs: 100,
          ),
        ],
      );

      final next = const GameRules().tick(state, deltaMs: 100);

      expect(next.islands[1].faction, Faction.neutral);
      expect(next.matchSummary.playerCaptureCount, 0);
    });
  });
}
