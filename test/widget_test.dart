import 'dart:ui' show SemanticsAction, Tristate;
import 'dart:math';

import 'package:conquest/base.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/faction_presentation.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ManualWidgetGameLoop implements GameLoop {
  void Function()? _onTick;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function() onTick) => _onTick = onTick;

  @override
  void stop() => _onTick = null;

  void tick() => _onTick?.call();
}

final class _WidgetZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

final class _WidgetMaxRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  testWidgets('offers every island-count preset with ten selected initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    for (final count in GameConfiguration.allowedIslandCounts) {
      expect(find.byKey(ValueKey('island-count-$count')), findsOneWidget);
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-count-10'))),
    );
    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      10,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('island-count-10')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('island-count-6')));
    await tester.pump();

    expect(
      container.read(gameControllerProvider).configuration.totalIslandCount,
      6,
    );
    expect(container.read(gameControllerProvider).islands, hasLength(6));
  });

  testWidgets('offers CPU difficulty choices with Normal selected initially', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );
    const expectedLabels = <CpuDifficulty, String>{
      CpuDifficulty.veryEasy: 'Very Easy',
      CpuDifficulty.easy: 'Easy',
      CpuDifficulty.normal: 'Normal',
      CpuDifficulty.hard: 'Hard',
    };
    for (final entry in expectedLabels.entries) {
      expect(
        find.byKey(ValueKey('cpu-difficulty-${entry.key.name}')),
        findsOneWidget,
      );
    }
    for (final entry in expectedLabels.entries) {
      final chip = find.byKey(ValueKey('cpu-difficulty-${entry.key.name}'));
      final semanticsNode = tester.getSemantics(chip);
      final data = semanticsNode.getSemanticsData();
      expect(semanticsNode.label, '${entry.value} CPU difficulty');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(
        data.flagsCollection.isSelected,
        entry.key == CpuDifficulty.normal ? Tristate.isTrue : Tristate.isFalse,
      );
    }
    final normalChip = find.byKey(const ValueKey('cpu-difficulty-normal'));
    expect(tester.widget<ChoiceChip>(normalChip).selected, isTrue);

    final mapBefore = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider).islands;
    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-veryEasy')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final selected = container.read(gameControllerProvider);
    expect(selected.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
    expect(selected.islands, orderedEquals(mapBefore));
    expect(tester.widget<ChoiceChip>(normalChip).selected, isFalse);
    final veryEasySemantics = tester.getSemantics(
      find.byKey(const ValueKey('cpu-difficulty-veryEasy')),
    );
    expect(veryEasySemantics.label, 'Very Easy CPU difficulty');
    expect(
      veryEasySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      veryEasySemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('選択中：10島 / Very Easy'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('start-game'))).label,
      'Start game with 10 islands on Very Easy CPU difficulty',
    );
    semantics.dispose();
  });

  testWidgets('switches between standard and spectator settings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    expect(
      find.byKey(const ValueKey('game-mode-player-vs-cpu')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player-cpu-difficulty-normal')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('cpu-difficulty-normal')), findsOneWidget);
    final standardMode = find.byKey(const ValueKey('game-mode-player-vs-cpu'));
    final spectatorMode = find.byKey(const ValueKey('game-mode-cpu-vs-cpu'));
    expect(tester.widget<ChoiceChip>(standardMode).selected, isTrue);
    expect(
      tester
          .getSemantics(standardMode)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.widget<ChoiceChip>(spectatorMode).selected, isFalse);

    await tester.tap(spectatorMode);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('player-cpu-difficulty-normal')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('player-cpu-difficulty-normal')),
          )
          .label,
      '1P Normal CPU difficulty',
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('cpu-difficulty-normal')))
          .label,
      '2P Normal CPU difficulty',
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('start-game'))).label,
      contains('Watch CPU versus CPU'),
    );
    semantics.dispose();
  });

  testWidgets('keeps spectator controls operable on a 280 by 500 screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
    await tester.tap(find.byKey(const ValueKey('player-cpu-difficulty-hard')));
    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-easy')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('start-game'))),
    );
    final configuration = container.read(gameControllerProvider).configuration;
    expect(configuration.gameMode, GameMode.cpuVsCpu);
    expect(configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(configuration.cpuDifficulty, CpuDifficulty.easy);
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves spectator deadlines across a viewport rebuild', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          playerCpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              controlledFaction: Faction.player,
              timingRandom: _WidgetZeroRandom(),
              qualityRandom: _WidgetMaxRandom(),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
          cpuStrategyProvider.overrideWithValue(
            CpuStrategy(
              controlledFaction: Faction.cpu,
              timingRandom: _WidgetZeroRandom(),
              qualityRandom: _WidgetMaxRandom(),
              viewport: GameRules.defaultMapViewport,
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('player-cpu-difficulty-hard')),
    );
    await tester.tap(find.byKey(const ValueKey('player-cpu-difficulty-hard')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('cpu-difficulty-easy')),
    );
    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-easy')));
    await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    for (var index = 0; index < 9; index++) {
      loop.tick();
    }
    await tester.pump();

    final before = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider);
    expect(before.elapsedMs, 450);
    expect(before.configuration.gameMode, GameMode.cpuVsCpu);
    expect(before.configuration.playerCpuDifficulty, CpuDifficulty.hard);
    expect(before.configuration.cpuDifficulty, CpuDifficulty.easy);

    await tester.binding.setSurfaceSize(const Size(321, 500));
    await tester.pump();
    final afterContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final after = afterContainer.read(gameControllerProvider);
    expect(after.elapsedMs, 450);
    expect(after.configuration, before.configuration);
    expect(loop.isRunning, isTrue);

    for (var index = 0; index < 20; index++) {
      loop.tick();
    }
    expect(
      afterContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.player),
      isEmpty,
    );
    loop.tick();
    expect(
      afterContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.player),
      hasLength(1),
    );
    expect(
      afterContainer
          .read(gameControllerProvider)
          .movingForces
          .where((force) => force.faction == Faction.cpu),
      isEmpty,
    );
  });

  testWidgets('shows the map before countdown and starts exactly at zero', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);
    expect(find.text('3'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);

    for (var index = 0; index < 59; index++) {
      loop.tick();
    }
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    loop.tick();
    await tester.pump();
    expect(find.text('START'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.playing);
    expect(state.elapsedMs, 0);
  });

  testWidgets('shows the generated map and configuration controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-9')), findsOneWidget);
  });

  testWidgets('exposes faction, size, and numeric values semantically', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-0'))).label,
      contains('Player headquarters, forces 100 of 200'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-1'))).label,
      contains('CPU headquarters, forces 100 of 200'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-2'))).label,
      contains('Neutral small island, durability 10'),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-2'))).width,
      50,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-6'))).width,
      64,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-8'))).width,
      80,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('island-button-0'))).width,
      100,
    );
    semantics.dispose();
  });

  testWidgets('uses 1P and 2P presentation only while spectating', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomProvider.overrideWithValue(Random(1)),
          gameConfigurationProvider.overrideWithValue(
            GameConfiguration(gameMode: GameMode.cpuVsCpu),
          ),
        ],
        child: const MyApp(key: ValueKey('spectator-presentation')),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-0'))).label,
      contains('1P'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-1'))).label,
      contains('2P'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomProvider.overrideWithValue(Random(1)),
          gameConfigurationProvider.overrideWithValue(
            GameConfiguration(gameMode: GameMode.playerVsCpu),
          ),
        ],
        child: const MyApp(key: ValueKey('standard-presentation')),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('island-button-0'))).label,
      contains('Player'),
    );
    semantics.dispose();
  });

  testWidgets('uses spectator presentation for moving troops', (tester) async {
    final semantics = tester.ensureSemantics();
    final force = const MovingForce(
      id: 7,
      faction: Faction.player,
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 20,
      arrivalTimeMs: 1000,
      durationMs: 1000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MovingForceWidget(
          force: force,
          presentation: FactionPresentation.forMode(
            GameMode.cpuVsCpu,
            Faction.player,
          ),
        ),
      ),
    );

    expect(find.text('1P'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(MovingForceWidget)).label,
      contains('1P'),
    );
    semantics.dispose();
  });

  testWidgets('spectator islands expose no actionable semantics', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          gameConfigurationProvider.overrideWithValue(
            GameConfiguration(gameMode: GameMode.cpuVsCpu),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    await tester.pump();

    final data = tester
        .getSemantics(find.byKey(const ValueKey('island-button-0')))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.hint, isEmpty);
    expect(data.label, isNot(contains('dispatch source')));
    semanticsHandle.dispose();
  });

  testWidgets(
    'does not advertise island actions while the board is not playable',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      final islandFinder = find.byKey(const ValueKey('island-button-0'));
      final container = ProviderScope.containerOf(tester.element(islandFinder));

      void expectDisabledIslandSemantics() {
        final node = tester.getSemantics(islandFinder);
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(node.hint, isNot(contains('Tap')));
        expect(node.label, isNot(contains('available dispatch source')));
        expect(node.label, isNot(contains('selected dispatch source')));
        expect(node.label, isNot(contains('valid dispatch destination')));
      }

      // Configuration state renders player-owned islands before interaction
      // is enabled, even though the island itself has enough forces.
      expectDisabledIslandSemantics();

      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pump();
      // The map remains visible during the start countdown, but callbacks are
      // still disabled until the countdown reaches the playing phase.
      expectDisabledIslandSemantics();

      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      await tester.pump();

      final playingNode = tester.getSemantics(islandFinder);
      final playingData = playingNode.getSemanticsData();
      expect(playingData.flagsCollection.isEnabled, Tristate.isTrue);
      expect(tester.widget<Base>(islandFinder).onPressed, isNotNull);
      expect(playingNode.label, contains('available dispatch source'));
      expect(playingNode.hint, contains('Tap to select'));

      final controller = container.read(gameControllerProvider.notifier);
      controller.tapBase(0);
      controller.pauseGame();
      await tester.pump();
      // Pausing disables the callback while preserving the selected state.
      expectDisabledIslandSemantics();
      semantics.dispose();
    },
  );

  testWidgets('shows the selected source and valid destination candidates', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('island-button-0')));
    await tester.pump();

    final source = tester.getSemantics(
      find.byKey(const ValueKey('island-button-0')),
    );
    final destination = tester.getSemantics(
      find.byKey(const ValueKey('island-button-2')),
    );
    expect(
      tester
          .widget<Base>(find.byKey(const ValueKey('island-button-0')))
          .selected,
      isTrue,
    );
    expect(source.label, contains('selected dispatch source'));
    expect(destination.label, contains('valid dispatch destination'));
    semantics.dispose();
  });

  testWidgets('shows unavailable interaction feedback on the board', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('island-button-1')));
    await tester.pump();

    expect(find.byKey(const ValueKey('interaction-feedback')), findsOneWidget);
    expect(find.textContaining('player island'), findsOneWidget);
  });

  testWidgets(
    'renders every moving force with faction and strength semantics',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      final islandFinder = find.byKey(const ValueKey('island-button-0'));
      final container = ProviderScope.containerOf(tester.element(islandFinder));
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      final state = container.read(gameControllerProvider);
      controller.state = state.copyWith(
        movingForces: [
          const MovingForce(
            id: 101,
            faction: Faction.player,
            sourceIslandId: 0,
            destinationIslandId: 2,
            strength: 17,
            position: IslandPosition(x: 0, y: 0),
          ),
          const MovingForce(
            id: 102,
            faction: Faction.cpu,
            sourceIslandId: 1,
            destinationIslandId: 3,
            strength: 9,
            position: IslandPosition(x: 0.25, y: -0.25),
          ),
        ],
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('moving-force-101')), findsOneWidget);
      expect(find.byKey(const ValueKey('moving-force-102')), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('moving-force-101')))
            .label,
        allOf(
          contains('Player'),
          contains('strength 17'),
          contains('not tappable'),
        ),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('moving-force-102')))
            .label,
        allOf(
          contains('CPU'),
          contains('strength 9'),
          contains('not tappable'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(MovingForceWidget).first).label,
        contains('Player moving troop'),
      );
      await tester.tap(
        find.byKey(const ValueKey('moving-force-101')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(container.read(gameControllerProvider).selectedIslandId, isNull);
      semantics.dispose();
    },
  );

  testWidgets('keeps every island-count preset physically operable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    for (final count in GameConfiguration.allowedIslandCounts) {
      controller.selectIslandCount(count);
      await tester.pump();
      final state = container.read(gameControllerProvider);
      expect(state.islands, hasLength(count));

      final rectangles = [
        for (final island in state.islands)
          (
            topLeft: tester.getTopLeft(
              find.byKey(ValueKey('island-button-${island.id}')),
            ),
            size: tester.getSize(
              find.byKey(ValueKey('island-button-${island.id}')),
            ),
          ),
      ];
      for (var first = 0; first < rectangles.length; first++) {
        final firstRect = Rect.fromLTWH(
          rectangles[first].topLeft.dx,
          rectangles[first].topLeft.dy,
          rectangles[first].size.width,
          rectangles[first].size.height,
        );
        for (var second = first + 1; second < rectangles.length; second++) {
          final secondRect = Rect.fromLTWH(
            rectangles[second].topLeft.dx,
            rectangles[second].topLeft.dy,
            rectangles[second].size.width,
            rectangles[second].size.height,
          );
          expect(firstRect.overlaps(secondRect), isFalse);
        }
      }
    }
  });

  testWidgets('keeps headquarters inside the SafeArea insets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 500),
              padding: EdgeInsets.only(top: 24, bottom: 16),
            ),
            child: const Home(),
          ),
        ),
      ),
    );

    final cpu = find.byKey(const ValueKey('island-button-1'));
    final player = find.byKey(const ValueKey('island-button-0'));
    final cpuTop = tester.getTopLeft(cpu).dy;
    final playerBottom = tester.getBottomRight(player).dy;
    expect(cpuTop, greaterThanOrEqualTo(24));
    expect(playerBottom, lessThanOrEqualTo(484));
    expect(cpuTop - 24, closeTo(484 - playerBottom, 1e-6));
  });

  testWidgets('generates using the actual sub-320 layout constraints', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    final button = tester.element(find.byType(ElevatedButton).first);
    final container = ProviderScope.containerOf(button);
    final state = container.read(gameControllerProvider);
    const viewport = IslandMapViewport(width: 280, height: 500);

    expect(state.islands, hasLength(10));
    expect(
      state.islands,
      const GameRules().generateIslands(random: Random(1), viewport: viewport),
    );
    final rectangles = [
      for (final island in state.islands) viewport.rectFor(island),
    ];
    for (final rectangle in rectangles) {
      expect(rectangle.isWithin(viewport), isTrue);
    }
    for (var first = 0; first < rectangles.length; first++) {
      for (var second = first + 1; second < rectangles.length; second++) {
        expect(rectangles[first].overlaps(rectangles[second]), isFalse);
      }
    }
  });

  testWidgets('keeps CPU difficulty controls operable on a 280 by 500 screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [randomProvider.overrideWithValue(Random(1))],
        child: const MyApp(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('cpu-difficulty-veryEasy')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cpu-difficulty-easy')), findsOneWidget);
    expect(find.byKey(const ValueKey('cpu-difficulty-normal')), findsOneWidget);
    expect(find.byKey(const ValueKey('cpu-difficulty-hard')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);

    final safeBounds = tester.getRect(
      find.byKey(const ValueKey('settings-view')),
    );
    final difficultyRects = [
      for (final difficulty in CpuDifficulty.values)
        tester.getRect(
          find.byKey(ValueKey('cpu-difficulty-${difficulty.name}')),
        ),
    ];
    for (final rectangle in [
      ...difficultyRects,
      tester.getRect(find.byKey(const ValueKey('start-game'))),
    ]) {
      expect(rectangle.left, greaterThanOrEqualTo(safeBounds.left));
      expect(rectangle.top, greaterThanOrEqualTo(safeBounds.top));
      expect(rectangle.right, lessThanOrEqualTo(safeBounds.right));
      expect(rectangle.bottom, lessThanOrEqualTo(safeBounds.bottom));
    }
    expect(difficultyRects.first.left, lessThan(difficultyRects.last.left));
    expect(
      difficultyRects
          .skip(1)
          .every((rectangle) => rectangle.top == difficultyRects.first.top),
      isTrue,
    );
    final startRect = tester.getRect(find.byKey(const ValueKey('start-game')));
    expect(startRect.top, greaterThan(difficultyRects.first.bottom));

    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-veryEasy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cpu-difficulty-hard')));
    await tester.pump();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      ).read(gameControllerProvider).configuration.cpuDifficulty,
      CpuDifficulty.hard,
    );
  });

  testWidgets('fails closed when the actual viewport cannot fit headquarters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(180, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(child: const MyApp()));

    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets(
    'preserves the selected island count in configuration on resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [randomProvider.overrideWithValue(Random(1))],
          child: const MyApp(),
        ),
      );

      final beforeButton = tester.element(find.byType(ElevatedButton).first);
      final beforeContainer = ProviderScope.containerOf(beforeButton);
      final controller = beforeContainer.read(gameControllerProvider.notifier);
      controller.selectIslandCount(6);
      controller.selectCpuDifficulty(CpuDifficulty.hard);
      await tester.pump();

      final before = beforeContainer.read(gameControllerProvider);
      expect(before.phase, GamePhase.configuration);
      expect(before.configuration.totalIslandCount, 6);
      expect(before.configuration.cpuDifficulty, CpuDifficulty.hard);
      expect(before.islands, hasLength(6));

      await tester.binding.setSurfaceSize(const Size(321, 500));
      await tester.pump();

      final afterButton = tester.element(find.byType(ElevatedButton).first);
      final afterContainer = ProviderScope.containerOf(afterButton);
      final after = afterContainer.read(gameControllerProvider);
      expect(after.phase, GamePhase.configuration);
      expect(after.configuration.totalIslandCount, 6);
      expect(after.configuration.cpuDifficulty, CpuDifficulty.hard);
      expect(after.islands, hasLength(6));
    },
  );

  testWidgets(
    'preserves a selected island count during an in-progress resize',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      final beforeButton = tester.element(find.byType(ElevatedButton).first);
      final beforeContainer = ProviderScope.containerOf(beforeButton);
      final controller = beforeContainer.read(gameControllerProvider.notifier);
      controller.selectIslandCount(6);
      await tester.pump();
      controller.startGame();
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      controller.tapBase(0);
      controller.tapBase(1);
      loop.tick();
      await tester.pump();

      final before = beforeContainer.read(gameControllerProvider);
      expect(before.phase, GamePhase.playing);
      expect(before.configuration.totalIslandCount, 6);
      expect(before.islands, hasLength(6));
      expect(before.elapsedMs, greaterThan(0));
      expect(before.movingForces, isNotEmpty);
      expect(before.selectedIslandId, isNull);

      await tester.binding.setSurfaceSize(const Size(321, 500));
      await tester.pump();

      final afterButton = tester.element(find.byType(ElevatedButton).first);
      final afterContainer = ProviderScope.containerOf(afterButton);
      final after = afterContainer.read(gameControllerProvider);
      expect(after.phase, GamePhase.playing);
      expect(after.configuration.totalIslandCount, 6);
      expect(after.islands, hasLength(6));
      expect(after.elapsedMs, before.elapsedMs);
      expect(after.movingForces, before.movingForces);
      expect(after.selectedIslandId, isNull);
      expect(loop.isRunning, isTrue);

      loop.tick();
      await tester.pump();
      final continued = afterContainer.read(gameControllerProvider);
      expect(continued.elapsedMs, greaterThan(after.elapsedMs));
      expect(continued.movingForces.first.progress, greaterThan(0));
    },
  );

  testWidgets(
    'preserves CPU difficulty and its pending deadline across a resize',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
            cpuStrategyProvider.overrideWithValue(
              CpuStrategy(
                random: _WidgetZeroRandom(),
                qualityRandom: _WidgetMaxRandom(),
                viewport: GameRules.defaultMapViewport,
              ),
            ),
          ],
          child: const MyApp(),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('cpu-difficulty-veryEasy')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('start-game')));
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      for (var index = 0; index < 9; index++) {
        loop.tick();
      }
      await tester.pump();

      final beforeContainer = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      );
      final before = beforeContainer.read(gameControllerProvider);
      expect(before.phase, GamePhase.playing);
      expect(before.elapsedMs, 450);
      expect(before.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(
        before.movingForces.where((force) => force.faction == Faction.cpu),
        isEmpty,
      );

      await tester.binding.setSurfaceSize(const Size(321, 500));
      await tester.pump();
      final afterContainer = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      );
      final after = afterContainer.read(gameControllerProvider);
      expect(after.phase, GamePhase.playing);
      expect(after.configuration.cpuDifficulty, CpuDifficulty.veryEasy);
      expect(after.elapsedMs, before.elapsedMs);
      expect(loop.isRunning, isTrue);

      for (var index = 0; index < 100; index++) {
        loop.tick();
      }
      expect(
        afterContainer
            .read(gameControllerProvider)
            .movingForces
            .where((force) => force.faction == Faction.cpu),
        isEmpty,
      );
      loop.tick();
      expect(
        afterContainer
            .read(gameControllerProvider)
            .movingForces
            .where((force) => force.faction == Faction.cpu),
        hasLength(1),
      );
    },
  );

  testWidgets('continues the start countdown after a viewport change', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    final beforeResize = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    expect(
      beforeResize.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(
      beforeResize.read(gameControllerProvider).countdownRemainingMs,
      3000,
    );
    expect(loop.isRunning, isTrue);

    await tester.binding.setSurfaceSize(const Size(321, 500));
    await tester.pump();

    final afterResize = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    expect(
      afterResize.read(gameControllerProvider).phase,
      GamePhase.startCountdown,
    );
    expect(afterResize.read(gameControllerProvider).countdownRemainingMs, 3000);
    expect(loop.isRunning, isTrue);

    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    expect(afterResize.read(gameControllerProvider).phase, GamePhase.playing);
  });

  testWidgets('preserves an in-progress game after the viewport changes', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('island-button-0')));
    await tester.tap(find.byKey(const ValueKey('island-button-1')));
    loop.tick();
    await tester.pump();

    final beforeButton = tester.element(find.byType(ElevatedButton).first);
    final beforeContainer = ProviderScope.containerOf(beforeButton);
    final before = beforeContainer.read(gameControllerProvider);
    expect(before.phase, GamePhase.playing);
    expect(before.elapsedMs, greaterThan(0));
    expect(before.movingForces, isNotEmpty);

    await tester.binding.setSurfaceSize(const Size(321, 500));
    await tester.pump();

    final afterButton = tester.element(find.byType(ElevatedButton).first);
    final afterContainer = ProviderScope.containerOf(afterButton);
    final after = afterContainer.read(gameControllerProvider);
    expect(after.phase, GamePhase.playing);
    expect(after.elapsedMs, before.elapsedMs);
    expect(after.islands, before.islands);
    expect(after.selectedIslandId, isNull);
    expect(after.movingForces, before.movingForces);
    expect(loop.isRunning, isTrue);

    loop.tick();
    await tester.pump();
    final continued = afterContainer.read(gameControllerProvider);
    expect(continued.elapsedMs, greaterThan(after.elapsedMs));
    expect(continued.movingForces.first.progress, greaterThan(0));
  });

  testWidgets(
    'pauses from the board and requires confirmation before quitting',
    (tester) async {
      final loop = ManualWidgetGameLoop();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('start-game')));
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      await tester.pump();

      expect(find.byKey(const ValueKey('pause-game')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pause-game')));
      await tester.pump();
      expect(find.text('一時停止'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-game')), findsOneWidget);
      expect(find.byKey(const ValueKey('quit-game')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quit-game')));
      await tester.pump();
      expect(find.text('Quit match?'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-quit')), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-quit')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cancel-quit')));
      await tester.pump();
      expect(find.text('一時停止'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quit-game')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-quit')));
      await tester.pump();
      expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
      expect(find.text('一時停止'), findsNothing);
    },
  );

  testWidgets('backgrounding a playing board pauses it automatically', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-game')));
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    loop.tick();
    await tester.pump();
    final before = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('一時停止'), findsOneWidget);
    expect(loop.isRunning, isFalse);

    loop.tick();
    await tester.pump();
    final after = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    ).read(gameControllerProvider);
    expect(after, before.copyWith(phase: GamePhase.paused));
  });

  testWidgets('result screen offers replay and settings actions', (
    tester,
  ) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );

    final islandFinder = find.byKey(const ValueKey('island-0'));
    final container = ProviderScope.containerOf(tester.element(islandFinder));
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    controller.finish(const GameResult.victory(elapsedMs: 1));
    await tester.pump();

    expect(find.text('勝利'), findsOneWidget);
    expect(find.byKey(const ValueKey('replay-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('return-settings')), findsOneWidget);
    expect(loop.isRunning, isFalse);

    await tester.tap(find.byKey(const ValueKey('return-settings')));
    await tester.pump();
    expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
    expect(find.text('勝利'), findsNothing);
  });

  testWidgets('labels spectator winners as 1P and 2P', (tester) async {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }

    controller.finish(
      const GameResult.victory(elapsedMs: 1, winner: Faction.player),
    );
    await tester.pump();
    expect(find.text('1P WIN'), findsOneWidget);

    controller.returnToConfiguration();
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    controller.finish(
      const GameResult.defeat(elapsedMs: 2, winner: Faction.cpu),
    );
    await tester.pump();
    expect(find.text('2P WIN'), findsOneWidget);
  });

  testWidgets('uses mode-specific draw labels', (tester) async {
    for (final entry in const [
      (mode: GameMode.playerVsCpu, title: '引き分け'),
      (mode: GameMode.cpuVsCpu, title: 'DRAW'),
    ]) {
      final loop = ManualWidgetGameLoop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameLoopProvider.overrideWithValue(loop),
            randomProvider.overrideWithValue(Random(1)),
            gameConfigurationProvider.overrideWithValue(
              GameConfiguration(gameMode: entry.mode),
            ),
          ],
          child: const MyApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('island-0'))),
      );
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame();
      for (var index = 0; index < 60; index++) {
        loop.tick();
      }
      controller.finish(const GameResult.draw(elapsedMs: 1));
      await tester.pump();

      expect(find.text(entry.title), findsOneWidget);
    }
  });
}
