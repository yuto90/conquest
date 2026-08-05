import 'dart:ui' show Offset, Rect;

import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'keeps a live iPhone board rendering and responsive for ten minutes',
    (tester) async {
      var collectFrames = true;
      var renderedFrameCount = 0;
      var timedFrameCount = 0;
      void observePostFrame(Duration _) {
        renderedFrameCount++;
        if (collectFrames) {
          SchedulerBinding.instance.addPostFrameCallback(observePostFrame);
        }
      }

      void observeTimings(List<FrameTiming> timings) {
        timedFrameCount += timings.length;
      }

      SchedulerBinding.instance.addPostFrameCallback(observePostFrame);
      SchedulerBinding.instance.addTimingsCallback(observeTimings);
      addTearDown(() {
        collectFrames = false;
        SchedulerBinding.instance.removeTimingsCallback(observeTimings);
      });

      final frameworkErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        frameworkErrors.add(details);
        previousErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousErrorHandler);

      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('island-count-12')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pump();

      // Keep this wall-clock wait real: the production periodic loop, CPU
      // deadline, rendering, and lifecycle callbacks must run on the device.
      await Future<void>.delayed(const Duration(seconds: 4));
      await tester.pump();
      expect(find.byKey(const ValueKey('pause-game')), findsOneWidget);
      expect(
        renderedFrameCount,
        greaterThan(10),
        reason: 'fullyLive must process app-requested frames during gameplay',
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      );
      var dispatchCount = 0;
      var pauseResumeCount = 0;
      var rematchCount = 0;
      var resultCount = 0;
      final observedPhases = <GamePhase>{};

      final pauseRect = tester.getRect(
        find.byKey(const ValueKey('pause-game')),
      );
      var obscuredIslandCount = 0;
      for (final island in container.read(gameControllerProvider).islands) {
        final islandFinder = find.byKey(ValueKey('island-button-${island.id}'));
        final islandRect = tester.getRect(islandFinder);
        if (islandRect.overlaps(pauseRect)) {
          obscuredIslandCount++;
        }
        expect(
          islandRect.overlaps(pauseRect),
          isFalse,
          reason: 'island ${island.id} must not overlap the pause control',
        );

        final islandRenderObject = tester.renderObject(islandFinder);
        final tapCandidates = <Offset>[
          islandRect.center,
          islandRect.topLeft + const Offset(2, 2),
          islandRect.topRight + const Offset(-2, 2),
          islandRect.bottomLeft + const Offset(2, -2),
          islandRect.bottomRight + const Offset(-2, -2),
        ];
        final hasIslandHit = tapCandidates.any(
          (point) => tester
              .hitTestOnBinding(point)
              .path
              .any((entry) => entry.target == islandRenderObject),
        );
        expect(
          hasIslandHit,
          isTrue,
          reason: 'island ${island.id} must retain a tappable hit area',
        );
      }
      expect(obscuredIslandCount, 0);
      debugPrint(
        'Issue #15 device QA geometry: islands='
        '${container.read(gameControllerProvider).islands.length} '
        'pauseRect=$pauseRect obscuredIslands=$obscuredIslandCount',
      );

      bool isCoveredByPause(Finder finder) {
        final pauseFinder = find.byKey(const ValueKey('pause-game'));
        if (pauseFinder.evaluate().isEmpty) {
          return false;
        }
        final Rect pauseRect = tester.getRect(pauseFinder);
        return pauseRect.contains(tester.getCenter(finder));
      }

      Future<bool> dispatchFromCurrentPlayer() async {
        final state = container.read(gameControllerProvider);
        if (state.phase != GamePhase.playing) {
          return false;
        }
        final source = state.islands.firstWhere(
          (island) => island.faction == Faction.player && island.canDispatch,
          orElse: () => state.islands.first,
        );
        if (source.faction != Faction.player || !source.canDispatch) {
          return false;
        }
        final sourceFinder = find.byKey(ValueKey('island-button-${source.id}'));
        if (sourceFinder.evaluate().isEmpty || isCoveredByPause(sourceFinder)) {
          return false;
        }
        final destinations = state.islands.where(
          (island) =>
              island.id != source.id && island.faction != Faction.player,
        );
        IslandState? destination;
        Finder? destinationFinder;
        for (final candidate in destinations) {
          final finder = find.byKey(ValueKey('island-button-${candidate.id}'));
          if (finder.evaluate().isNotEmpty && !isCoveredByPause(finder)) {
            destination = candidate;
            destinationFinder = finder;
            break;
          }
        }
        if (destination == null || destinationFinder == null) {
          return false;
        }
        final selectedDestination = destination;
        final selectedDestinationFinder = destinationFinder;
        final beforeIds = state.movingForces.map((force) => force.id).toSet();
        await tester.tap(sourceFinder);
        await tester.pump();
        expect(
          container.read(gameControllerProvider).selectedIslandId,
          source.id,
          reason: 'source tap must select a live player island',
        );
        await tester.tap(selectedDestinationFinder, warnIfMissed: false);
        await tester.pump();

        final afterDispatch = container.read(gameControllerProvider);
        final newPlayerForces = afterDispatch.movingForces
            .where(
              (force) =>
                  !beforeIds.contains(force.id) &&
                  force.faction == Faction.player &&
                  force.sourceIslandId == source.id &&
                  force.destinationIslandId == selectedDestination.id,
            )
            .toList();
        expect(
          newPlayerForces,
          hasLength(1),
          reason: 'destination tap must append one player moving force',
        );
        final dispatchedForce = newPlayerForces.single;
        expect(
          find.byKey(ValueKey('moving-force-${dispatchedForce.id}')),
          findsOneWidget,
          reason: 'newly dispatched force must be rendered on the device',
        );
        dispatchCount++;
        return true;
      }

      Future<void> recoverIfResult() async {
        if (find.byKey(const ValueKey('replay-game')).evaluate().isEmpty) {
          return;
        }
        resultCount++;
        await tester.tap(find.byKey(const ValueKey('replay-game')));
        await tester.pump();
        rematchCount++;
        await Future<void>.delayed(const Duration(seconds: 4));
        await tester.pump();
      }

      // Two dispatches exercise input and movement before the periodic
      // observation window begins.  Later rounds repeat this opportunistically
      // whenever the current board still has a dispatchable player island.
      expect(
        await dispatchFromCurrentPlayer(),
        isTrue,
        reason: 'first real device dispatch must succeed',
      );
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.pump();
      expect(
        await dispatchFromCurrentPlayer(),
        isTrue,
        reason: 'second real device dispatch must succeed',
      );

      final wallClockStart = DateTime.now();
      var previousFrameCount = renderedFrameCount;
      for (var interval = 0; interval < 60; interval++) {
        await Future<void>.delayed(const Duration(seconds: 10));
        await tester.pump();
        expect(
          renderedFrameCount,
          greaterThan(previousFrameCount),
          reason: 'fullyLive must keep producing frames at each observation',
        );
        previousFrameCount = renderedFrameCount;
        observedPhases.add(container.read(gameControllerProvider).phase);

        if (interval == 5 || interval == 30 || interval == 50) {
          if (find.byKey(const ValueKey('pause-game')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('pause-game')));
            await tester.pump();
            expect(find.text('Game Paused'), findsOneWidget);
            final pausedElapsed = container
                .read(gameControllerProvider)
                .elapsedMs;
            await Future<void>.delayed(const Duration(seconds: 2));
            await tester.pump();
            expect(
              container.read(gameControllerProvider).elapsedMs,
              pausedElapsed,
            );
            await tester.tap(find.byKey(const ValueKey('resume-game')));
            await tester.pump();
            pauseResumeCount++;
            await Future<void>.delayed(const Duration(seconds: 4));
            await tester.pump();
          }
        }

        await recoverIfResult();
        await dispatchFromCurrentPlayer();
      }

      final wallClockDuration = DateTime.now().difference(wallClockStart);
      expect(
        wallClockDuration,
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
      expect(dispatchCount, greaterThanOrEqualTo(2));
      expect(pauseResumeCount, greaterThanOrEqualTo(2));
      expect(observedPhases, contains(GamePhase.playing));
      expect(renderedFrameCount, greaterThan(100));
      // FrameTiming is engine-dependent in debug simulator runs; retain its
      // count as an additional diagnostic when the engine reports it.
      debugPrint(
        'Issue #15 device QA: duration=${wallClockDuration.inSeconds}s '
        'frames=$renderedFrameCount timings=$timedFrameCount '
        'dispatches=$dispatchCount pauseResume=$pauseResumeCount '
        'results=$resultCount rematches=$rematchCount '
        'frameworkErrors=${frameworkErrors.length}',
      );
      // A result is an expected game outcome, not a framework exception.  If
      // it occurred, the test rematched and continued observing the live app.
      expect(rematchCount, resultCount);
      expect(frameworkErrors, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 13)),
  );
}
