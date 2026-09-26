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
}
