import 'dart:math' as math;

import 'package:conquest/faction_presentation.dart';
import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_controller.dart';
import 'package:conquest/game/game_loop.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _rules = GameRules();
const _boards = <Size>[Size(390, 844), Size(400, 400)];

IslandMapViewport _viewport(Size board) =>
    IslandMapViewport(width: board.width, height: board.height);

// These tests deliberately do not use the production distance/center helpers
// to obtain their expected values. The measured points are actual RenderBoxes
// from the same placement widget used by Home and the tutorial.
double _screenSpeed(Size board) {
  final width = board.width - 30;
  final height = board.height - 30;
  return math.sqrt(width * width + height * height) / 10000;
}

GameState _fixture(Size board, GameMode mode, CpuDifficulty difficulty) {
  final islands = <IslandState>[];
  final forces = <MovingForce>[];
  final diagonalUnit = math.sqrt(0.5);
  final directions = <Offset>[
    const Offset(1, 0),
    const Offset(0, 1),
    Offset(diagonalUnit, diagonalUnit),
    Offset(-diagonalUnit, -diagonalUnit),
  ];
  final shortestSpan = math.min(board.width - 30, board.height - 30);
  const lengths = <double>[0.2, 0.4, 0.7];
  const strengths = <int>[1, 25, 123456];
  for (final faction in [Faction.player, Faction.cpu]) {
    for (final direction in directions) {
      for (var index = 0; index < lengths.length; index++) {
        final vector = direction * (shortestSpan * lengths[index]);
        // Symmetric endpoints yield the requested pixel-length route under
        // the documented, existing 30dp Align placement contract.
        final source = IslandState(
          id: islands.length,
          faction: faction,
          size: IslandSize.small,
          position: IslandPosition(
            x: -vector.dx / (board.width - 30),
            y: -vector.dy / (board.height - 30),
          ),
        );
        final destination = IslandState(
          id: islands.length + 1,
          faction: faction,
          size: IslandSize.small,
          position: IslandPosition(x: -source.x, y: -source.y),
        );
        islands.addAll([source, destination]);
        forces.add(
          _rules.createMovingForce(
            id: forces.length,
            faction: faction,
            source: source,
            destination: destination,
            strength: strengths[index],
            viewport: _viewport(board),
          ),
        );
      }
    }
  }
  return GameState(
    configuration: GameConfiguration(
      gameMode: mode,
      playerCpuDifficulty: difficulty,
      cpuDifficulty: difficulty,
    ),
    phase: GamePhase.playing,
    elapsedMs: 0,
    islands: islands,
    movingForces: forces,
  );
}

Future<void> _pumpBoard(
  WidgetTester tester,
  GameState state,
  Size board, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Center(
          child: SizedBox(
            key: const ValueKey('movement-test-board'),
            width: board.width,
            height: board.height,
            child: Stack(
              children: [
                for (final force in state.movingForces)
                  PositionedMovingForce(
                    key: ValueKey('placement-${force.id}'),
                    force: force,
                    viewport: _viewport(board),
                    presentation: FactionPresentation.forMode(
                      state.configuration.gameMode,
                      force.faction,
                    ),
                    semanticsKey: ValueKey('reference-${force.id}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Map<int, Offset> _renderedCenters(WidgetTester tester, GameState state) {
  final board = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('movement-test-board')),
  );
  return {
    for (final force in state.movingForces)
      force.id: _centerInBoard(tester, board, force.id),
  };
}

Offset _centerInBoard(WidgetTester tester, RenderBox board, int forceId) {
  final marker = tester.renderObject<RenderBox>(
    find.byKey(ValueKey('reference-$forceId')),
  );
  expect(marker.size, const Size(30, 30));
  return board.globalToLocal(
    marker.localToGlobal(marker.size.center(Offset.zero)),
  );
}

void _expectCommonSpeed(
  Map<int, Offset> before,
  Map<int, Offset> after, {
  required Size board,
  required int intervalMs,
  required int minimumRemainingDurationMs,
  required String label,
}) {
  final expectedDistance = _screenSpeed(board) * intervalMs;
  // Integer rounding contributes at most half a millisecond per plan.
  // |ideal/rounded - 1| <= 0.5/rounded, independent of production helpers.
  final roundingBound = expectedDistance * 0.5 / minimumRemainingDurationMs;
  final distances = {
    for (final entry in before.entries)
      entry.key: (after[entry.key]! - entry.value).distance,
  };
  final minDistance = distances.values.reduce(math.min);
  final maxDistance = distances.values.reduce(math.max);
  debugPrint(
    '$label: board=$board, interval=${intervalMs}ms, '
    'displacement=${minDistance.toStringAsFixed(6)}..'
    '${maxDistance.toStringAsFixed(6)}dp, '
    'speed=${(minDistance * 1000 / intervalMs).toStringAsFixed(6)}..'
    '${(maxDistance * 1000 / intervalMs).toStringAsFixed(6)}dp/game-second, '
    'expected=${(_screenSpeed(board) * 1000).toStringAsFixed(6)}, '
    'spread=${((maxDistance / minDistance - 1) * 100).toStringAsFixed(6)}%',
  );
  for (final entry in distances.entries) {
    expect(
      entry.value,
      closeTo(expectedDistance, roundingBound + 1e-8),
      reason: 'force ${entry.key}, board $board, interval ${intervalMs}ms',
    );
  }
  expect(maxDistance / minDistance - 1, lessThan(0.01));
}

void main() {
  for (final board in _boards) {
    for (final mode in GameMode.values) {
      for (final difficulty in CpuDifficulty.values) {
        testWidgets(
          'rendered equal speed at $board in ${mode.name}/${difficulty.name}',
          (tester) async {
            // Extra chrome makes the stage intentionally different from the
            // enclosing window, as on a letterboxed Web board.
            await tester.binding.setSurfaceSize(
              Size(board.width + 80, board.height + 80),
            );
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final initial = _fixture(board, mode, difficulty);
            final minimumDuration = initial.movingForces
                .map((force) => force.durationMs)
                .reduce(math.min);
            expect(minimumDuration, greaterThan(500));

            // Equal pixel routes in all four directions take equal time;
            // doubling the distance doubles that time up to ms rounding.
            for (var index = 0; index < initial.movingForces.length; index++) {
              final force = initial.movingForces[index];
              expect(
                force.durationMs,
                closeTo(initial.movingForces[index % 3].durationMs, 1),
              );
              if (index % 3 == 1) {
                expect(
                  force.durationMs,
                  closeTo(initial.movingForces[index - 1].durationMs * 2, 1),
                );
              }
            }

            var state = _rules.tick(initial, deltaMs: 100);
            await _pumpBoard(tester, state, board);
            final first = _renderedCenters(tester, state);
            state = _rules.tick(state, deltaMs: 200);
            await _pumpBoard(tester, state, board);
            final middle = _renderedCenters(tester, state);
            state = _rules.tick(state, deltaMs: 200);
            await _pumpBoard(tester, state, board);
            final last = _renderedCenters(tester, state);
            expect(state.movingForces, hasLength(initial.movingForces.length));

            _expectCommonSpeed(
              first,
              last,
              board: board,
              intervalMs: 400,
              minimumRemainingDurationMs: minimumDuration,
              label: 'fixed/${mode.name}/${difficulty.name}',
            );
            for (final force in state.movingForces) {
              final firstLeg = middle[force.id]! - first[force.id]!;
              final secondLeg = last[force.id]! - middle[force.id]!;
              expect((secondLeg - firstLeg).distance, lessThan(1e-8));
              final transform = tester.widget<Transform>(
                find.descendant(
                  of: find.byKey(ValueKey('placement-${force.id}')),
                  matching: find.byType(Transform),
                ),
              );
              final direction = firstLeg / firstLeg.distance;
              expect(
                transform.transform.storage[0],
                closeTo(direction.dx, 1e-8),
              );
              expect(
                transform.transform.storage[1],
                closeTo(direction.dy, 1e-8),
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('artwork labels and text scaling do not move the reference box', (
    tester,
  ) async {
    const board = Size(390, 844);
    await tester.binding.setSurfaceSize(const Size(470, 924));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var state = _rules.tick(
      _fixture(board, GameMode.playerVsCpu, CpuDifficulty.normal),
      deltaMs: 300,
    );
    await _pumpBoard(tester, state, board);
    final before = _renderedCenters(tester, state);
    final plans = state.movingForces;
    state = state.copyWith(
      configuration: state.configuration.copyWith(gameMode: GameMode.cpuVsCpu),
      movingForces: [
        for (final force in state.movingForces)
          force.copyWith(strength: 123456789),
      ],
    );
    await _pumpBoard(tester, state, board, textScale: 2);
    expect(_renderedCenters(tester, state), before);
    for (var index = 0; index < state.movingForces.length; index++) {
      expect(state.movingForces[index].durationMs, plans[index].durationMs);
      expect(
        state.movingForces[index].arrivalTimeMs,
        plans[index].arrivalTimeMs,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final mode in GameMode.values) {
    testWidgets(
      'rendered existing and new routes agree after resize/${mode.name}',
      (tester) async {
        const beforeBoard = Size(390, 844);
        const afterBoard = Size(400, 400);
        await tester.binding.setSurfaceSize(const Size(500, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final flying = _rules.tick(
          _fixture(beforeBoard, mode, CpuDifficulty.normal),
          deltaMs: 200,
        );
        await _pumpBoard(tester, flying, beforeBoard);
        var resized = _rules.replanMovingForces(
          flying,
          viewport: _viewport(afterBoard),
        );
        for (var index = 0; index < flying.movingForces.length; index++) {
          expect(
            resized.movingForces[index].position,
            flying.movingForces[index].position,
          );
          expect(
            resized.movingForces[index].progress,
            flying.movingForces[index].progress,
          );
        }
        final islands = {
          for (final island in resized.islands) island.id: island,
        };
        resized = resized.copyWith(
          movingForces: [
            ...resized.movingForces,
            for (final force in resized.movingForces)
              _rules.createMovingForce(
                id: force.id + 1000,
                faction: force.faction,
                source: islands[force.sourceIslandId]!,
                destination: islands[force.destinationIslandId]!,
                strength: force.strength,
                departureTimeMs: resized.elapsedMs,
                viewport: _viewport(afterBoard),
              ),
          ],
        );
        final minimumRemainingDuration = resized.movingForces
            .map((force) => force.arrivalTimeMs - resized.elapsedMs)
            .reduce(math.min);
        expect(minimumRemainingDuration, greaterThan(250));
        // Begin after relayout; a jump of the board itself is not flight speed.
        var state = _rules.tick(resized, deltaMs: 50);
        await _pumpBoard(tester, state, afterBoard);
        final before = _renderedCenters(tester, state);
        state = _rules.tick(state, deltaMs: 200);
        await _pumpBoard(tester, state, afterBoard);
        final after = _renderedCenters(tester, state);
        expect(state.movingForces, hasLength(resized.movingForces.length));
        _expectCommonSpeed(
          before,
          after,
          board: afterBoard,
          intervalMs: 200,
          minimumRemainingDurationMs: minimumRemainingDuration,
          label: 'resized-existing-and-new/${mode.name}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('controller resize keeps rendered speed uniform', (tester) async {
    const oldBoard = Size(390, 844);
    const newBoard = Size(400, 400);
    await tester.binding.setSurfaceSize(const Size(500, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loop = ManualGameLoop();
    final random = math.Random(1);
    final cpu = CpuStrategy.noop();
    final container = ProviderContainer(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(random),
        cpuStrategyProvider.overrideWithValue(cpu),
        mapViewportProvider.overrideWithValue(_viewport(oldBoard)),
      ],
    );
    try {
      final controller = container.read(gameControllerProvider.notifier);
      const islands = <IslandState>[
        IslandState(
          id: 0,
          faction: Faction.player,
          size: IslandSize.small,
          position: IslandPosition(x: -0.65, y: -0.4),
        ),
        IslandState(
          id: 1,
          faction: Faction.cpu,
          size: IslandSize.small,
          position: IslandPosition(x: 0.65, y: -0.4),
        ),
        IslandState(
          id: 2,
          faction: Faction.player,
          size: IslandSize.small,
          position: IslandPosition(x: -0.65, y: 0.4),
        ),
        IslandState(
          id: 3,
          faction: Faction.cpu,
          size: IslandSize.small,
          position: IslandPosition(x: 0.65, y: 0.4),
        ),
      ];
      expect(_viewport(oldBoard).canRenderIslands(islands), isTrue);
      expect(_viewport(newBoard).canRenderIslands(islands), isTrue);
      final initial = GameState(
        phase: GamePhase.playing,
        elapsedMs: 0,
        islands: islands,
        movingForces: [
          for (var index = 0; index < 4; index++)
            _rules.createMovingForce(
              id: index,
              faction: index == 3 ? Faction.cpu : Faction.player,
              source: index == 3 ? islands[3] : islands[0],
              destination: index == 3 ? islands[0] : islands[index + 1],
              strength: 20,
              viewport: _viewport(oldBoard),
            ),
        ],
      );
      controller.state = _rules.tick(initial, deltaMs: 200);
      final original = controller.state;
      await _pumpBoard(tester, original, oldBoard);
      container.updateOverrides([
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(random),
        cpuStrategyProvider.overrideWithValue(cpu),
        mapViewportProvider.overrideWithValue(_viewport(newBoard)),
      ]);
      final resized = container.read(gameControllerProvider);
      expect(resized.viewportUnavailable, isFalse);
      expect(resized.elapsedMs, original.elapsedMs);
      final minimumDuration = resized.movingForces
          .map((force) => force.arrivalTimeMs - resized.elapsedMs)
          .reduce(math.min);
      var state = _rules.tick(resized, deltaMs: 50);
      await _pumpBoard(tester, state, newBoard);
      final before = _renderedCenters(tester, state);
      state = _rules.tick(state, deltaMs: 200);
      await _pumpBoard(tester, state, newBoard);
      final after = _renderedCenters(tester, state);
      _expectCommonSpeed(
        before,
        after,
        board: newBoard,
        intervalMs: 200,
        minimumRemainingDurationMs: minimumDuration,
        label: 'controller-resize',
      );
    } finally {
      container.dispose();
      // Drain the independent container's zero-delay Riverpod refresh timer
      // before Flutter verifies the widget test's timer invariants.
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
