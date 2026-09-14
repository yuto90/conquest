import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'faction_presentation.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/generated/app_localizations_en.dart';
import 'ui/tactical_theme.dart';

/// Renders an in-flight group as a flat, top-view tactical aircraft.
class MovingForceWidget extends StatelessWidget {
  const MovingForceWidget({
    required this.force,
    required this.boardSize,
    this.presentation,
    this.semanticsKey,
    super.key,
  });

  static const size = GameRules.movingForceWidgetSize;

  final MovingForce force;
  final Size boardSize;
  final FactionPresentation? presentation;
  final Key? semanticsKey;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final angle = _headingAngle;
    return Semantics(
      key: semanticsKey,
      container: true,
      excludeSemantics: true,
      enabled: false,
      label: _semanticLabel(l10n),
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
                  left: 0,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        _effectivePresentation.marker,
                        style: TacticalTypography.mono(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
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

  FactionPresentation get _effectivePresentation =>
      presentation ??
      FactionPresentation.forMode(GameMode.playerVsCpu, force.faction);

  double get _headingAngle {
    if (force.deltaX == 0 && force.deltaY == 0) {
      return 0;
    }

    final width = boardSize.width;
    final height = boardSize.height;
    if (!size.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        !force.deltaX.isFinite ||
        !force.deltaY.isFinite) {
      return 0;
    }

    final horizontalSpan = width - size;
    final verticalSpan = height - size;
    if (horizontalSpan <= 0 || verticalSpan <= 0) {
      return 0;
    }

    final screenDeltaX = force.deltaX * horizontalSpan;
    final screenDeltaY = force.deltaY * verticalSpan;
    if (!screenDeltaX.isFinite ||
        !screenDeltaY.isFinite ||
        (screenDeltaX == 0 && screenDeltaY == 0)) {
      return 0;
    }

    return math.atan2(screenDeltaY, screenDeltaX);
  }

  String _factionName(AppLocalizations l10n) {
    if (_effectivePresentation.semanticName == '1P') {
      return l10n.factionPlayerOne;
    }
    if (_effectivePresentation.semanticName == '2P') {
      return l10n.factionPlayerTwo;
    }
    return switch (force.faction) {
      Faction.player => l10n.factionPlayer,
      Faction.cpu => l10n.factionCpu,
      Faction.neutral => l10n.factionNeutral,
    };
  }

  String _semanticLabel(AppLocalizations l10n) {
    return l10n.movingForceSemantics(
      faction: _factionName(l10n),
      strength: force.currentValue,
      value: force.currentValue,
      source: force.sourceIslandId,
      destination: force.destinationIslandId,
    );
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
