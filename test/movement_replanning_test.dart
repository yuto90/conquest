import 'dart:math' as math;

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _rules = GameRules();
const _portrait = IslandMapViewport(width: 390, height: 844);
const _landscape = IslandMapViewport(width: 1000, height: 600);

IslandState _island(
  int id,
  Faction faction,
  double x,
  double y, {
  int forces = 100,
  IslandSize size = IslandSize.small,
  int durability = 0,
}) {
  return IslandState(
    id: id,
    faction: faction,
    position: IslandPosition(x: x, y: y),
    currentForces: forces,
    size: size,
    durability: durability,
    capacity: 200,
  );
}

Faction _opponent(Faction faction) =>
    faction == Faction.player ? Faction.cpu : Faction.player;

GameState _routes({
  Faction faction = Faction.player,
  GameMode mode = GameMode.playerVsCpu,
  int departureTimeMs = 317,
}) {
  final islands = [
    _island(0, faction, -0.8, -0.8),
    _island(2, Faction.neutral, 0.8, -0.8),
    _island(3, Faction.neutral, -0.8, 0.8),
    _island(4, Faction.neutral, 0.8, 0.8),
    _island(1, _opponent(faction), 0.5, 0),
  ];
  return GameState(
    configuration: GameConfiguration(gameMode: mode),
    phase: GamePhase.playing,
    elapsedMs: departureTimeMs,
    islands: islands,
    selectedIslandId: faction == Faction.player ? 0 : null,
    matchSummary: const MatchSummary(
      playerDispatchCount: 3,
      playerDispatchedForces: 18,
    ),
    movingForces: [
      for (var index = 1; index <= 3; index++)
        _rules.createMovingForce(
          id: 10 + index,
          faction: faction,
          source: islands.first,
          destination: islands[index],
          strength: 6,
          departureTimeMs: departureTimeMs,
          viewport: _portrait,
        ),
    ],
  );
}

// Deliberately calculate pixel displacement independently of the production
// geometry helpers so the speed regression cannot share their mistake.
double _pixelDistance(
  IslandPosition from,
  IslandPosition to,
  IslandMapViewport viewport,
) {
  final dx = (to.x - from.x) * (viewport.width - 30) / 2;
  final dy = (to.y - from.y) * (viewport.height - 30) / 2;
  return math.sqrt(dx * dx + dy * dy);
}

double _pixelsPerMs(IslandMapViewport viewport) {
  final width = viewport.width - 30;
  final height = viewport.height - 30;
  return math.sqrt(width * width + height * height) / 10000;
}

void _expectRouteIdentity(MovingForce actual, MovingForce original) {
  expect(actual.id, original.id);
  expect(actual.faction, original.faction);
  expect(actual.sourceIslandId, original.sourceIslandId);
  expect(actual.destinationIslandId, original.destinationIslandId);
  expect(actual.strength, original.strength);
  expect(actual.departureTimeMs, original.departureTimeMs);
  expect(actual.deltaX, original.deltaX);
  expect(actual.deltaY, original.deltaY);
  expect(actual.durationMs, actual.arrivalTimeMs - original.departureTimeMs);
}

void _expectContinuousReplan(GameState before, GameState after) {
  expect(after.elapsedMs, before.elapsedMs);
  expect(after.phase, before.phase);
  expect(after.configuration, before.configuration);
  expect(after.islands, before.islands);
  expect(after.selectedIslandId, before.selectedIslandId);
  expect(after.matchSummary, before.matchSummary);
  expect(after.result, before.result);
  expect(after.countdownRemainingMs, before.countdownRemainingMs);
  expect(after.movingForces, hasLength(before.movingForces.length));
  for (var index = 0; index < before.movingForces.length; index++) {
    final original = before.movingForces[index];
    final replanned = after.movingForces[index];
    _expectRouteIdentity(replanned, original);
    expect(replanned.progress, closeTo(original.progress, 1e-12));
    expect(replanned.x, closeTo(original.x, 1e-12));
    expect(replanned.y, closeTo(original.y, 1e-12));
    expect(replanned.segmentStartTimeMs, before.elapsedMs);
    expect(replanned.segmentStartProgress, original.progress);
    expect(replanned.arrivalTimeMs, greaterThan(before.elapsedMs));
  }
}

void main() {
  group('viewport movement replanning', () {
    for (final mode in GameMode.values) {
      for (final faction in [Faction.player, Faction.cpu]) {
        test(
          '${mode.name}/${faction.name}: old and new routes share pixel speed',
          () {
            final initial = _routes(faction: faction, mode: mode);
            final before = _rules.tick(initial, deltaMs: 1000);
            final replanned = _rules.replanMovingForces(
              before,
              viewport: _landscape,
            );
            _expectContinuousReplan(before, replanned);

            // A wide, shorter viewport must lengthen the horizontal route
            // and shorten the vertical route, rather than scale all ETAs.
            expect(
              replanned.movingForces[0].arrivalTimeMs,
              greaterThan(before.movingForces[0].arrivalTimeMs),
            );
            expect(
              replanned.movingForces[1].arrivalTimeMs,
              lessThan(before.movingForces[1].arrivalTimeMs),
            );

            final strategy = CpuStrategy(
              controlledFaction: faction,
              viewport: _landscape,
            );
            final source = replanned.islands.first;
            final dispatched = strategy.applyDecision(
              replanned,
              CpuDecision(
                kind: CpuDecisionKind.attack,
                sourceIslandId: source.id,
                destinationIslandId: 4,
                strength: source.currentForces ~/ 2,
              ),
              movingForceId: 99,
            );
            expect(dispatched.movingForces, hasLength(4));
            expect(
              dispatched.islands.first.currentForces,
              source.currentForces - source.currentForces ~/ 2,
            );
            final fresh = dispatched.movingForces.last;
            expect(fresh.id, 99);
            expect(fresh.faction, faction);
            expect(fresh.departureTimeMs, before.elapsedMs);
            expect(fresh.segmentStartTimeMs, before.elapsedMs);
            expect(fresh.segmentStartProgress, 0);
            expect(fresh.progress, 0);

            const deltaMs = 200;
            final advanced = _rules.tick(dispatched, deltaMs: deltaMs);
            expect(advanced.movingForces, hasLength(4));
            for (var index = 0; index < 4; index++) {
              final start = dispatched.movingForces[index];
              final end = advanced.movingForces[index];
              expect(
                _pixelDistance(start.position, end.position, _landscape),
                closeTo(_pixelsPerMs(_landscape) * deltaMs, 0.03),
                reason:
                    'route ${start.id} must share the resized speed; '
                    'the tolerance only permits millisecond ETA rounding',
              );
              _expectRouteIdentity(end, start);
              expect(end.segmentStartTimeMs, start.segmentStartTimeMs);
              expect(end.segmentStartProgress, start.segmentStartProgress);
            }

            // Forecasts must use the new segment, including the exact ETA.
            final arrival = replanned.movingForces[0].arrivalTimeMs;
            for (final atMs in [before.elapsedMs + 200, arrival - 1, arrival]) {
              final predicted = strategy.forecast(dispatched, atMs: atMs);
              final actual = _rules.tick(
                dispatched,
                deltaMs: atMs - dispatched.elapsedMs,
              );
              expect(predicted, actual);
              expect(
                predicted.movingForces.any((force) => force.id == 11),
                atMs < arrival,
              );
            }
          },
        );
      }
    }

    test(
      'repeated resizes retain progress without restarting or tick drift',
      () {
        var state = _rules.tick(_routes(), deltaMs: 701);
        final originals = state.movingForces;
        for (final viewport in const [
          _landscape,
          IslandMapViewport(width: 500, height: 900),
          IslandMapViewport(width: 1200, height: 700),
          _portrait,
        ]) {
          final replanned = _rules.replanMovingForces(
            state,
            viewport: viewport,
          );
          _expectContinuousReplan(state, replanned);
          for (var index = 0; index < originals.length; index++) {
            _expectRouteIdentity(
              replanned.movingForces[index],
              originals[index],
            );
          }
          // Repeating a layout notification at the same game time is stable.
          expect(
            _rules.replanMovingForces(replanned, viewport: viewport),
            replanned,
          );

          final singleTick = _rules.tick(replanned, deltaMs: 173);
          var splitTicks = replanned;
          for (final delta in [1, 7, 31, 134]) {
            splitTicks = _rules.tick(splitTicks, deltaMs: delta);
          }
          expect(splitTicks, singleTick);
          for (var index = 0; index < originals.length; index++) {
            final start = replanned.movingForces[index];
            final end = singleTick.movingForces[index];
            expect(end.progress, greaterThan(start.progress));
            expect(
              _pixelDistance(start.position, end.position, viewport),
              closeTo(_pixelsPerMs(viewport) * 173, 0.03),
            );
          }
          state = singleTick;
        }
      },
    );

    test(
      'replanning reads the segment clock rather than stale rendered progress',
      () {
        final initial = _routes();
        final clockOnly = initial.copyWith(elapsedMs: initial.elapsedMs + 500);
        final rendered = _rules.tick(initial, deltaMs: 500);
        expect(
          _rules.replanMovingForces(clockOnly, viewport: _landscape),
          _rules.replanMovingForces(
            rendered.copyWith(matchSummary: clockOnly.matchSummary),
            viewport: _landscape,
          ),
        );
      },
    );

    test(
      'pause and resume countdown exclude wall time from a resized segment',
      () {
        final playing = _rules.tick(_routes(), deltaMs: 701);
        final paused = _rules.pause(playing);
        final replanned = _rules.replanMovingForces(
          paused,
          viewport: _landscape,
        );
        _expectContinuousReplan(paused, replanned);
        expect(replanned.phase, GamePhase.paused);
        expect(_rules.tick(replanned, deltaMs: 60000), same(replanned));

        final countdown = _rules.resumeCountdown(replanned);
        final resizedCountdown = _rules.replanMovingForces(
          countdown,
          viewport: _portrait,
        );
        _expectContinuousReplan(countdown, resizedCountdown);
        final resumed = _rules.tick(resizedCountdown, deltaMs: 60000);
        expect(resumed.phase, GamePhase.playing);
        expect(resumed.elapsedMs, playing.elapsedMs);
        expect(resumed.islands, playing.islands);
        expect(resumed.movingForces, resizedCountdown.movingForces);
        final advanced = _rules.tick(resumed, deltaMs: 200);
        for (var index = 0; index < advanced.movingForces.length; index++) {
          expect(
            _pixelDistance(
              resumed.movingForces[index].position,
              advanced.movingForces[index].position,
              _portrait,
            ),
            closeTo(_pixelsPerMs(_portrait) * 200, 0.03),
          );
        }
      },
    );

    test(
      'new ETA resolves exactly once, with growth before same-time combat',
      () {
        const oldViewport = IslandMapViewport(width: 630, height: 630);
        const newViewport = IslandMapViewport(width: 630, height: 830);
        final source = _island(0, Faction.player, 0, 0);
        final target = _island(1, Faction.cpu, 0.3, 0, forces: 10);
        final force = _rules.createMovingForce(
          id: 20,
          faction: Faction.player,
          source: source,
          destination: target,
          strength: 11,
          viewport: oldViewport,
        );
        expect(force.arrivalTimeMs, 1061);
        final initial = GameState(
          phase: GamePhase.playing,
          elapsedMs: 0,
          islands: [source, target],
          movingForces: [force],
        );
        final beforeResize = _rules.tick(initial, deltaMs: 659);
        final replanned = _rules.replanMovingForces(
          beforeResize,
          viewport: newViewport,
        );
        expect(replanned.movingForces.single.arrivalTimeMs, 1000);
        expect(replanned.movingForces.single.durationMs, 1000);
        final beforeArrival = _rules.tick(replanned, deltaMs: 340);
        expect(beforeArrival.elapsedMs, 999);
        expect(beforeArrival.movingForces, hasLength(1));
        expect(beforeArrival.movingForces.single.progress, lessThan(1));
        expect(beforeArrival.islands.last.currentForces, 10);
        final arrived = _rules.tick(beforeArrival, deltaMs: 1);
        expect(arrived.elapsedMs, 1000);
        expect(arrived.movingForces, isEmpty);
        expect(arrived.islands.last.faction, Faction.cpu);
        expect(arrived.islands.last.currentForces, 0);
        expect(arrived.matchSummary.playerCaptureCount, 0);
        expect(_rules.tick(arrived, deltaMs: 0), arrived);

        // Crossing both the new and obsolete ETAs must not apply combat twice.
        final largeTick = _rules.tick(replanned, deltaMs: 3341);
        final splitTicks = _rules.tick(arrived, deltaMs: 3000);
        expect(largeTick, splitTicks);
        expect(largeTick.elapsedMs, 4000);
        expect(largeTick.movingForces, isEmpty);
        expect(largeTick.islands.last.faction, Faction.cpu);
        expect(largeTick.islands.last.currentForces, 3);
      },
    );

    test('due and overdue arrivals are never extended or resurrected', () {
      final initial = _routes();
      final force = initial.movingForces.first;
      for (final overdueMs in [0, 1000]) {
        final state = initial.copyWith(
          elapsedMs: force.arrivalTimeMs + overdueMs,
          movingForces: [force],
        );
        final replanned = _rules.replanMovingForces(
          state,
          viewport: _landscape,
        );
        expect(replanned.elapsedMs, state.elapsedMs);
        expect(replanned.movingForces.single, same(force));
        final arrived = _rules.tick(replanned, deltaMs: 0);
        expect(arrived.movingForces, isEmpty);
        expect(arrived.islands[1].faction, Faction.player);
        expect(arrived.islands[1].currentForces, force.strength);
        expect(arrived.matchSummary.playerCaptureCount, 1);
        expect(_rules.tick(arrived, deltaMs: 0), arrived);
        expect(
          _rules.replanMovingForces(arrived, viewport: _portrait),
          same(arrived),
        );
      }
    });

    test('tiny and zero routes retain the one millisecond minimum', () {
      for (final deltaX in [0.0, 1e-12]) {
        final source = _island(0, Faction.player, 0, 0);
        final target = _island(2, Faction.neutral, deltaX, 0);
        final force = _rules.createMovingForce(
          id: 30,
          faction: Faction.player,
          source: source,
          destination: target,
          strength: 3,
          departureTimeMs: 91,
          viewport: _portrait,
        );
        expect(force.durationMs, 1);
        expect(force.arrivalTimeMs, 92);
        final state = GameState(
          phase: GamePhase.playing,
          elapsedMs: 91,
          islands: [source, target, _island(1, Faction.cpu, 0.8, 0.8)],
          movingForces: [force],
        );
        final replanned = _rules.replanMovingForces(
          state,
          viewport: _landscape,
        );
        expect(replanned.movingForces.single.durationMs, 1);
        expect(replanned.movingForces.single.arrivalTimeMs, 92);
        expect(_rules.tick(replanned, deltaMs: 0).movingForces, hasLength(1));
        final arrived = _rules.tick(replanned, deltaMs: 1);
        expect(arrived.movingForces, isEmpty);
        expect(arrived.islands[1].faction, Faction.player);
        expect(arrived.islands[1].currentForces, 3);
      }
    });

    test(
      'a remaining route rounded to zero still arrives one millisecond later',
      () {
        final state = _rules.tick(_routes(), deltaMs: 1000);
        final horizontal = state.movingForces.first;
        final replanned = _rules.replanMovingForces(
          state.copyWith(movingForces: [horizontal]),
          viewport: const IslandMapViewport(width: 31, height: 1000000),
        );
        final force = replanned.movingForces.single;
        expect(force.arrivalTimeMs, state.elapsedMs + 1);
        expect(force.durationMs, state.elapsedMs + 1 - force.departureTimeMs);
        expect(force.progress, horizontal.progress);
        expect(_rules.tick(replanned, deltaMs: 0).movingForces, hasLength(1));
        expect(_rules.tick(replanned, deltaMs: 1).movingForces, isEmpty);
      },
    );

    test(
      'invalid viewports reject creation and leave every existing plan intact',
      () {
        final state = _rules.tick(_routes(), deltaMs: 701);
        for (final viewport in const [
          IslandMapViewport(width: 0, height: 844),
          IslandMapViewport(width: 390, height: 0),
          IslandMapViewport(width: -1, height: 844),
          IslandMapViewport(width: 30, height: 844),
          IslandMapViewport(width: 390, height: 30),
          IslandMapViewport(width: 29, height: 29),
          IslandMapViewport(width: double.nan, height: 844),
          IslandMapViewport(width: 390, height: double.infinity),
          IslandMapViewport(width: double.maxFinite, height: double.maxFinite),
        ]) {
          expect(viewport.isMovementValid, isFalse);
          expect(
            _rules.replanMovingForces(state, viewport: viewport),
            same(state),
          );
          expect(
            () => _rules.createMovingForce(
              id: 40,
              faction: Faction.player,
              source: state.islands.first,
              destination: state.islands[1],
              strength: 3,
              viewport: viewport,
            ),
            throwsArgumentError,
          );
          final strategy = CpuStrategy(viewport: viewport);
          expect(strategy.decide(state), isNull);
          expect(
            strategy.applyDecision(
              state,
              const CpuDecision(
                kind: CpuDecisionKind.attack,
                sourceIslandId: 1,
                destinationIslandId: 2,
                strength: 50,
              ),
            ),
            same(state),
          );
        }
        final recovered = _rules.replanMovingForces(
          state,
          viewport: _landscape,
        );
        _expectContinuousReplan(state, recovered);
      },
    );

    test('nonfinite routes reject creation and preserve an existing plan', () {
      final state = _rules.tick(_routes(), deltaMs: 701);
      final force = state.movingForces.first;
      for (final coordinate in [double.nan, double.infinity]) {
        final brokenTarget = state.islands[1].copyWith(x: coordinate);
        final broken = state.copyWith(
          islands: [
            state.islands.first,
            brokenTarget,
            ...state.islands.skip(2),
          ],
          movingForces: [force],
        );
        expect(
          _rules
              .replanMovingForces(broken, viewport: _landscape)
              .movingForces
              .single,
          same(force),
        );
        expect(
          () => _rules.createMovingForce(
            id: 41,
            faction: Faction.player,
            source: state.islands.first,
            destination: brokenTarget,
            strength: 3,
            viewport: _portrait,
          ),
          throwsArgumentError,
        );
      }
    });

    test('missing endpoints and completed matches are not replanned', () {
      final state = _rules.tick(_routes(), deltaMs: 701);
      final force = state.movingForces.first;
      for (final missingId in [
        force.sourceIslandId,
        force.destinationIslandId,
      ]) {
        final missingEndpoint = state.copyWith(
          islands: state.islands
              .where((island) => island.id != missingId)
              .toList(),
          movingForces: [force],
        );
        expect(
          _rules
              .replanMovingForces(missingEndpoint, viewport: _landscape)
              .movingForces
              .single,
          same(force),
        );
      }
      final finished = state.finishWithResult(
        GameResult.victory(elapsedMs: state.elapsedMs),
      );
      expect(
        _rules.replanMovingForces(finished, viewport: _landscape),
        same(finished),
      );
    });
  });

  test(
    'movement segment defaults, copies and equality preserve independent data',
    () {
      const original = MovingForce(
        id: 50,
        faction: Faction.cpu,
        sourceIslandId: 1,
        destinationIslandId: 2,
        strength: 7,
        departureTimeMs: 317,
        arrivalTimeMs: 2317,
        durationMs: 2000,
      );
      expect(original.segmentStartTimeMs, original.departureTimeMs);
      expect(original.segmentStartProgress, 0);
      final segment = original.copyWith(
        segmentStartTimeMs: 817,
        segmentStartProgress: 0.25,
        progress: 0.25,
        arrivalTimeMs: 1817,
        durationMs: 1500,
      );
      expect(original.segmentStartTimeMs, 317);
      expect(original.segmentStartProgress, 0);
      expect(segment.departureTimeMs, 317);
      expect(segment.segmentStartTimeMs, 817);
      expect(segment.segmentStartProgress, 0.25);
      expect(segment.copyWith(), segment);
      expect(segment.copyWith().hashCode, segment.hashCode);
      final moved = segment.copyWith(x: 0.2, progress: 0.4);
      expect(moved.segmentStartTimeMs, 817);
      expect(moved.segmentStartProgress, 0.25);
      final differentTime = segment.copyWith(segmentStartTimeMs: 818);
      final differentProgress = segment.copyWith(segmentStartProgress: 0.26);
      expect(differentTime, isNot(segment));
      expect(differentProgress, isNot(segment));
      expect({
        segment,
        segment.copyWith(),
        differentTime,
        differentProgress,
      }, hasLength(3));
    },
  );
}
