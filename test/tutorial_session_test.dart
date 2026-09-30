import 'dart:math';

import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/tutorial/tutorial_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a fixed six-island practice map that fits a compact board', () {
    final session = TutorialSession.create(
      viewport: const IslandMapViewport(width: 280, height: 325),
    );

    expect(session.gameState.islands, hasLength(6));
    expect(session.step, TutorialStep.selectSource);
    const viewport = IslandMapViewport(width: 280, height: 325);
    for (var index = 0; index < session.gameState.islands.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < session.gameState.islands.length;
        otherIndex++
      ) {
        expect(
          GameRules.islandRectanglesOverlap(
            session.gameState.islands[index],
            session.gameState.islands[otherIndex],
            viewport,
          ),
          isFalse,
          reason:
              'islands ${session.gameState.islands[index].id} and '
              '${session.gameState.islands[otherIndex].id} overlap',
        );
      }
    }
  });

  test('packs the fixed map into the narrow browser stage', () {
    const viewport = IslandMapViewport(width: 231, height: 310);
    final session = TutorialSession.create(viewport: viewport);

    for (var index = 0; index < session.gameState.islands.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < session.gameState.islands.length;
        otherIndex++
      ) {
        final first = session.gameState.islands[index];
        final second = session.gameState.islands[otherIndex];
        expect(
          GameRules.islandRectanglesOverlap(first, second, viewport),
          isFalse,
          reason: 'islands ${first.id} and ${second.id} overlap',
        );
      }
    }
  });

  test(
    'uses the real dispatch and arrival rules to capture the target island',
    () {
      final session = TutorialSession.create();

      session.tapIsland(TutorialSession.playerHeadquartersId);
      expect(session.step, TutorialStep.selectDestination);
      expect(
        session.gameState.selectedIslandId,
        TutorialSession.playerHeadquartersId,
      );

      session.tapIsland(TutorialSession.targetIslandId);
      expect(session.step, TutorialStep.watchCapture);
      expect(session.dispatchedStrength, 50);
      expect(session.sourceForcesAfterDispatch, 50);
      expect(session.gameState.movingForces.single.strength, 50);

      final arrivalTime = session.gameState.movingForces.single.durationMs;
      session.tick(arrivalTime + 2000);

      final target = session.gameState.islands.firstWhere(
        (island) => island.id == TutorialSession.targetIslandId,
      );
      expect(session.hasArrived, isTrue);
      expect(target.faction, Faction.player);
      expect(target.currentForces, 40);
      expect(session.gameState.movingForces, isEmpty);
      expect(session.gameState.elapsedMs, arrivalTime);
      expect(session.step, TutorialStep.watchCapture);
    },
  );

  test('demonstrates one growth tick then freezes the victory explanation', () {
    final session = TutorialSession.create();
    session.tapIsland(TutorialSession.playerHeadquartersId);
    session.tapIsland(TutorialSession.targetIslandId);
    session.tick(session.gameState.movingForces.single.durationMs);
    final before = session.gameState.elapsedMs;

    session.advanceAfterCapture();

    expect(session.step, TutorialStep.explainVictory);
    expect(session.growthDemonstrated, 1);
    expect(session.gameState.elapsedMs, before + 1000);

    session.tick(100000);
    expect(session.gameState.elapsedMs, before + 1000);
  });

  test(
    'rejects wrong taps and exposes a retry prompt without changing the map',
    () {
      final session = TutorialSession.create();
      final before = session.gameState;

      session.tapIsland(TutorialSession.targetIslandId);

      expect(session.gameState, same(before));
      expect(session.retryPrompt, TutorialStep.selectSource);
      expect(session.step, TutorialStep.selectSource);

      session.tapIsland(TutorialSession.playerHeadquartersId);
      session.tapIsland(3);

      expect(session.retryPrompt, TutorialStep.selectDestination);
      expect(session.gameState.movingForces, isEmpty);
      expect(
        session.gameState.selectedIslandId,
        TutorialSession.playerHeadquartersId,
      );
    },
  );

  test('lifecycle pause prevents movement until explicitly resumed', () {
    final session = TutorialSession.create();
    session.tapIsland(TutorialSession.playerHeadquartersId);
    session.tapIsland(TutorialSession.targetIslandId);
    final duration = session.gameState.movingForces.single.durationMs;

    session.pauseForLifecycle();
    session.tick(duration);
    expect(session.hasArrived, isFalse);

    session.resumeAfterLifecycle();
    session.tick(duration);
    expect(session.hasArrived, isTrue);
  });

  test('reflows an in-flight route before a resize can be resumed', () {
    final session = TutorialSession.create(
      viewport: const IslandMapViewport(width: 390, height: 500),
    );
    session.tapIsland(TutorialSession.playerHeadquartersId);
    session.tapIsland(TutorialSession.targetIslandId);
    final duration = session.gameState.movingForces.single.durationMs;
    session.tick(duration ~/ 2);
    final progressBeforeResize = session.gameState.movingForces.single.progress;

    const narrowViewport = IslandMapViewport(width: 231, height: 310);
    session.updateViewport(narrowViewport);
    session.pauseForLifecycle();

    expect(session.canResumeAfterLifecycle, isTrue);
    expect(
      session.gameState.movingForces.single.progress,
      closeTo(progressBeforeResize, 0.0001),
    );
    for (var index = 0; index < session.gameState.islands.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < session.gameState.islands.length;
        otherIndex++
      ) {
        expect(
          GameRules.islandRectanglesOverlap(
            session.gameState.islands[index],
            session.gameState.islands[otherIndex],
            narrowViewport,
          ),
          isFalse,
        );
      }
    }

    final pausedElapsed = session.gameState.elapsedMs;
    session.tick(duration);
    expect(session.gameState.elapsedMs, pausedElapsed);
    expect(session.hasArrived, isFalse);

    session.resumeAfterLifecycle();
    session.tick(duration);
    expect(session.hasArrived, isTrue);
    expect(session.gameState.movingForces, isEmpty);
  });

  test('keeps resume disabled until an unsafe viewport is enlarged', () {
    final session = TutorialSession.create(
      viewport: const IslandMapViewport(width: 231, height: 310),
    );
    session.pauseForLifecycle();
    session.updateViewport(const IslandMapViewport(width: 180, height: 200));

    expect(session.canResumeAfterLifecycle, isFalse);
    session.resumeAfterLifecycle();
    expect(session.lifecyclePaused, isTrue);

    session.updateViewport(const IslandMapViewport(width: 231, height: 310));
    expect(session.canResumeAfterLifecycle, isTrue);
    session.resumeAfterLifecycle();
    expect(session.lifecyclePaused, isFalse);
  });

  test('replans timing even when a resize keeps all normalized anchors', () {
    const portrait = IslandMapViewport(width: 800, height: 1200);
    const landscape = IslandMapViewport(width: 1200, height: 800);
    final session = TutorialSession.create(viewport: portrait);
    session.tapIsland(TutorialSession.playerHeadquartersId);
    session.tapIsland(TutorialSession.targetIslandId);
    session.tick(500);
    final before = session.gameState;
    final force = before.movingForces.single;

    session.pauseForLifecycle();
    session.updateViewport(landscape);

    final after = session.gameState;
    final replanned = after.movingForces.single;
    expect(after.islands, before.islands);
    expect(after.elapsedMs, before.elapsedMs);
    expect(replanned.progress, force.progress);
    expect(replanned.position, force.position);
    expect(replanned.departureTimeMs, force.departureTimeMs);
    expect(replanned.segmentStartTimeMs, before.elapsedMs);
    expect(replanned.segmentStartProgress, force.progress);
    final destination = after.islands.firstWhere(
      (island) => island.id == force.destinationIslandId,
    );
    final remainder = max(
      1,
      (GameRules.movementDurationMs *
              landscape.movingForceDistance(
                force.position,
                destination.position,
              ) /
              landscape.movingForceScreenDiagonal)
          .round(),
    );
    expect(replanned.arrivalTimeMs, before.elapsedMs + remainder);
    expect(replanned.arrivalTimeMs, isNot(force.arrivalTimeMs));
    expect(session.lifecyclePaused, isTrue);
    session.tick(100000);
    expect(session.gameState, same(after));

    session.resumeAfterLifecycle();
    session.tick(remainder - 1);
    expect(session.hasArrived, isFalse);
    session.tick(1);
    expect(session.hasArrived, isTrue);
    expect(session.gameState.elapsedMs, replanned.arrivalTimeMs);
  });

  test('same-size updates leave the in-flight segment untouched', () {
    const viewport = IslandMapViewport(width: 390, height: 500);
    final session = TutorialSession.create(viewport: viewport);
    session.tapIsland(TutorialSession.playerHeadquartersId);
    session.tapIsland(TutorialSession.targetIslandId);
    session.tick(500);
    final before = session.gameState;

    session.updateViewport(viewport);
    expect(session.gameState, same(before));
    session.pauseForLifecycle();
    session.resumeAfterLifecycle();
    expect(session.gameState, same(before));
  });

  test(
    'invalid sizes preserve the last plan and cannot resume the tutorial',
    () {
      final session = TutorialSession.create(
        viewport: const IslandMapViewport(width: 390, height: 500),
      );
      session.tapIsland(TutorialSession.playerHeadquartersId);
      session.tapIsland(TutorialSession.targetIslandId);
      session.tick(500);
      session.pauseForLifecycle();
      final before = session.gameState;

      for (final viewport in const [
        IslandMapViewport(width: 0, height: 800),
        IslandMapViewport(width: 30, height: 800),
        IslandMapViewport(width: double.nan, height: 800),
        IslandMapViewport(width: 800, height: double.infinity),
        IslandMapViewport(width: 180, height: 200),
      ]) {
        session.updateViewport(viewport);
        expect(session.canResumeAfterLifecycle, isFalse);
        session.resumeAfterLifecycle();
        session.tick(100000);
        expect(session.lifecyclePaused, isTrue);
        expect(session.gameState, same(before));
      }

      session.updateViewport(const IslandMapViewport(width: 231, height: 310));
      final recovered = session.gameState;
      final replanned = recovered.movingForces.single;
      expect(session.canResumeAfterLifecycle, isTrue);
      expect(session.lifecyclePaused, isTrue);
      expect(replanned.id, before.movingForces.single.id);
      expect(replanned.progress, before.movingForces.single.progress);
      expect(
        replanned.departureTimeMs,
        before.movingForces.single.departureTimeMs,
      );
      expect(replanned.segmentStartTimeMs, before.elapsedMs);
      final source = recovered.islands.firstWhere(
        (island) => island.id == replanned.sourceIslandId,
      );
      final target = recovered.islands.firstWhere(
        (island) => island.id == replanned.destinationIslandId,
      );
      expect(
        replanned.x,
        closeTo(source.x + (target.x - source.x) * replanned.progress, 1e-10),
      );
      expect(
        replanned.y,
        closeTo(source.y + (target.y - source.y) * replanned.progress, 1e-10),
      );
      expect(replanned.deltaX, target.x - source.x);
      expect(replanned.deltaY, target.y - source.y);
      session.tick(100000);
      expect(session.gameState, same(recovered));
      session.resumeAfterLifecycle();
      session.tick(replanned.arrivalTimeMs - recovered.elapsedMs);
      expect(session.hasArrived, isTrue);
      expect(session.gameState.elapsedMs, replanned.arrivalTimeMs);
    },
  );
}
