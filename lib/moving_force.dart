import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game/game_rules.dart';
import 'game/game_state.dart';
import 'ui/tactical_theme.dart';

/// Renders an in-flight group as a flat, top-view tactical aircraft.
class MovingForceWidget extends StatelessWidget {
  const MovingForceWidget({required this.force, this.semanticsKey, super.key});

  static const size = GameRules.movingForceWidgetSize;

  final MovingForce force;
  final Key? semanticsKey;

  @override
  Widget build(BuildContext context) {
    final angle = force.deltaX == 0 && force.deltaY == 0
        ? 0.0
        : math.atan2(force.deltaY, force.deltaX);
    return Semantics(
      key: semanticsKey,
      container: true,
      excludeSemantics: true,
      enabled: false,
      label: _semanticLabel,
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: size,
          child: OverflowBox(
            minWidth: 56,
            maxWidth: 56,
            minHeight: 32,
            maxHeight: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 1,
                  top: 5,
                  child: Transform.rotate(
                    angle: angle,
                    child: SizedBox(
                      width: 36,
                      height: 22,
                      child: CustomPaint(
                        painter: _AircraftPainter(faction: force.faction),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  top: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TacticalPalette.surface,
                      border: Border.all(
                        color: TacticalPalette.foreground.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 19,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            force.currentValue.toString(),
                            style: TacticalTypography.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _factionName => switch (force.faction) {
    Faction.player => 'Player',
    Faction.cpu => 'CPU',
    Faction.neutral => 'Neutral',
  };

  String get _semanticLabel {
    return '$_factionName moving troop, strength ${force.currentValue}, '
        'current value ${force.currentValue}, '
        'from island ${force.sourceIslandId} to island '
        '${force.destinationIslandId}, action unavailable, not tappable';
  }
}

class _AircraftPainter extends CustomPainter {
  const _AircraftPainter({required this.faction});

  final Faction faction;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyColor = faction == Faction.cpu
        ? TacticalPalette.cpu
        : faction == Faction.player
        ? TacticalPalette.player
        : TacticalPalette.neutral;
    final deepColor = faction == Faction.cpu
        ? TacticalPalette.cpuDeep
        : faction == Faction.player
        ? TacticalPalette.playerDeep
        : TacticalPalette.foreground;
    final body = Path()
      ..moveTo(2, 11)
      ..lineTo(12, 8)
      ..lineTo(17, 2)
      ..lineTo(21, 2)
      ..lineTo(19, 9)
      ..lineTo(34, 11)
      ..lineTo(19, 13)
      ..lineTo(21, 20)
      ..lineTo(17, 20)
      ..lineTo(12, 14)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.fill
        ..color = bodyColor,
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = deepColor,
    );

    if (faction == Faction.cpu) {
      final emblem = Path()
        ..moveTo(19.5, 8)
        ..lineTo(24, 17)
        ..lineTo(15, 17)
        ..close();
      canvas.drawPath(emblem, Paint()..color = TacticalPalette.cpuDeep);
    } else {
      canvas.drawCircle(
        const Offset(19.5, 14.5),
        4.5,
        Paint()..color = deepColor,
      );
      canvas.drawCircle(
        const Offset(19.5, 14.5),
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = TacticalPalette.paper,
      );
      final mark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TacticalPalette.paper;
      canvas.drawLine(const Offset(17.5, 13), const Offset(19.5, 15), mark);
      canvas.drawLine(const Offset(19.5, 15), const Offset(21.5, 13), mark);
      canvas.drawLine(const Offset(17.5, 15), const Offset(19.5, 17), mark);
      canvas.drawLine(const Offset(19.5, 17), const Offset(21.5, 15), mark);
    }
  }

  @override
  bool shouldRepaint(covariant _AircraftPainter oldDelegate) {
    return faction != oldDelegate.faction;
  }
}

typedef MovingForceView = MovingForceWidget;
