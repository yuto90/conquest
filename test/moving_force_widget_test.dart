import 'dart:math' as math;

import 'package:conquest/game/game_state.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tallBoard = Size(390, 844);
const _squareBoard = Size(400, 400);

MovingForce _force({double deltaX = 1, double deltaY = 1}) {
  return MovingForce(
    sourceIslandId: 0,
    destinationIslandId: 1,
    strength: 20,
    deltaX: deltaX,
    deltaY: deltaY,
  );
}

Future<void> _pumpForce(
  WidgetTester tester, {
  required MovingForce force,
  required Size boardSize,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MovingForceWidget(force: force, boardSize: boardSize),
    ),
  );
}

Transform _aircraftTransform(WidgetTester tester) {
  return tester.widget<Transform>(
    find.descendant(
      of: find.byType(MovingForceWidget),
      matching: find.byType(Transform),
    ),
  );
}

void _expectHeading(
  Transform transform, {
  required double deltaX,
  required double deltaY,
  required Size boardSize,
}) {
  const size = 30.0;
  final screenDeltaX = deltaX * (boardSize.width - size);
  final screenDeltaY = deltaY * (boardSize.height - size);
  final length = math.sqrt(
    screenDeltaX * screenDeltaX + screenDeltaY * screenDeltaY,
  );
  final expectedCosine = length == 0 ? 1.0 : screenDeltaX / length;
  final expectedSine = length == 0 ? 0.0 : screenDeltaY / length;
  final matrix = transform.transform.storage;

  expect(matrix[0], closeTo(expectedCosine, 1e-10));
  expect(matrix[1], closeTo(expectedSine, 1e-10));
  expect(matrix[4], closeTo(-expectedSine, 1e-10));
  expect(matrix[5], closeTo(expectedCosine, 1e-10));
}

void main() {
  testWidgets('matches the rendered heading on a tall board', (tester) async {
    const cases = <({String name, double deltaX, double deltaY})>[
      (name: 'horizontal', deltaX: 1, deltaY: 0),
      (name: 'vertical', deltaX: 0, deltaY: 1),
      (name: 'diagonal', deltaX: 1, deltaY: 1),
      (name: 'reverse', deltaX: -1, deltaY: -1),
      (name: 'zero', deltaX: 0, deltaY: 0),
    ];

    for (final movement in cases) {
      final force = _force(
        deltaX: movement.deltaX,
        deltaY: movement.deltaY,
      );
      await _pumpForce(
        tester,
        force: force,
        boardSize: _tallBoard,
      );

      _expectHeading(
        _aircraftTransform(tester),
        deltaX: movement.deltaX,
        deltaY: movement.deltaY,
        boardSize: _tallBoard,
      );
    }
  });

  testWidgets('matches a diagonal heading on a square board', (tester) async {
    const force = MovingForce(
      sourceIslandId: 0,
      destinationIslandId: 1,
      strength: 20,
      deltaX: 1,
      deltaY: 1,
    );
    await _pumpForce(tester, force: force, boardSize: _squareBoard);

    _expectHeading(
      _aircraftTransform(tester),
      deltaX: force.deltaX,
      deltaY: force.deltaY,
      boardSize: _squareBoard,
    );
  });

  testWidgets('updates only the heading when the board is resized', (
    tester,
  ) async {
    final force = _force();
    await _pumpForce(tester, force: force, boardSize: _tallBoard);
    final before = _aircraftTransform(tester);
    _expectHeading(
      before,
      deltaX: force.deltaX,
      deltaY: force.deltaY,
      boardSize: _tallBoard,
    );

    await _pumpForce(tester, force: force, boardSize: _squareBoard);
    final after = _aircraftTransform(tester);
    _expectHeading(
      after,
      deltaX: force.deltaX,
      deltaY: force.deltaY,
      boardSize: _squareBoard,
    );
    expect(after.transform.storage[1], lessThan(before.transform.storage[1]));
    expect(force.arrivalTimeMs, MovingForce.movementDefaultArrivalTimeMs);
    expect(find.text(force.currentValue.toString()), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MovingForceWidget),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to zero for invalid board geometry', (tester) async {
    const invalidSizes = <Size>[
      Size(double.nan, 844),
      Size(390, double.infinity),
      Size(30, 844),
      Size(390, 30),
    ];

    for (final boardSize in invalidSizes) {
      await _pumpForce(tester, force: _force(), boardSize: boardSize);
      final matrix = _aircraftTransform(tester).transform.storage;

      expect(matrix[0], closeTo(1, 1e-10));
      expect(matrix[1], closeTo(0, 1e-10));
      expect(matrix[4], closeTo(0, 1e-10));
      expect(matrix[5], closeTo(1, 1e-10));
    }
  });
}
