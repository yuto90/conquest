import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'keeps a live iPhone board rendering and responsive for ten minutes',
    (tester) async {
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

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      );
      var dispatchCount = 0;
      var pauseResumeCount = 0;
      var rematchCount = 0;
      var resultCount = 0;
      final observedPhases = <GamePhase>{};

      Future<void> dispatchFromCurrentPlayer() async {
        final state = container.read(gameControllerProvider);
        if (state.phase != GamePhase.playing) {
          return;
        }
        final source = state.islands.firstWhere(
          (island) => island.faction == Faction.player && island.canDispatch,
          orElse: () => state.islands.first,
        );
        if (source.faction != Faction.player || !source.canDispatch) {
          return;
        }
        final destination = state.islands.firstWhere(
          (island) =>
              island.id != source.id && island.faction != Faction.player,
          orElse: () =>
              state.islands.firstWhere((island) => island.id != source.id),
        );
        final sourceFinder = find.byKey(ValueKey('island-button-${source.id}'));
        final destinationFinder = find.byKey(
          ValueKey('island-button-${destination.id}'),
        );
        if (sourceFinder.evaluate().isEmpty ||
            destinationFinder.evaluate().isEmpty) {
          return;
        }
        await tester.tap(sourceFinder);
        await tester.pump();
        await tester.tap(destinationFinder);
        await tester.pump();
        dispatchCount++;
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
      await dispatchFromCurrentPlayer();
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.pump();
      await dispatchFromCurrentPlayer();

      final wallClockStart = DateTime.now();
      for (var interval = 0; interval < 60; interval++) {
        await Future<void>.delayed(const Duration(seconds: 10));
        await tester.pump();
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
      // A result is an expected game outcome, not a framework exception.  If
      // it occurred, the test rematched and continued observing the live app.
      expect(rematchCount, resultCount);
      expect(frameworkErrors, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 13)),
  );
}
