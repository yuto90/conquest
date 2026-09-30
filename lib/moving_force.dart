import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'faction_presentation.dart';
import 'game/game_rules.dart';
import 'game/game_state.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/generated/app_localizations_en.dart';
import 'ui/tactical_theme.dart';

/// Presentation-only silhouettes; never a unit type or movement modifier.
///
/// Keep the strength-to-illustration table here so both factions and game modes
/// use the same boundaries. The fixed 36 x 22 artwork canvas is shared by all.
enum AircraftIllustration {
  singleEngine,
  twinEngine,
  transport;

  static AircraftIllustration forStrength(int strength) => switch (strength) {
    < 25 => singleEngine,
    < 50 => twinEngine,
    _ => transport,
  };
}

/// Places the movement reference point independently of the aircraft artwork.
///
/// Both the game board and tutorial use this in their full-viewport [Stack].
/// The fixed layout box is the same 30dp footprint used by movement timing;
/// the illustration and labels may overflow it without changing the route.
class PositionedMovingForce extends StatelessWidget {
  const PositionedMovingForce({
    required this.force,
    required this.viewport,
    this.presentation,
    this.semanticsKey,
    super.key,
  });

  final MovingForce force;
  final IslandMapViewport viewport;
  final FactionPresentation? presentation;
  final Key? semanticsKey;

  @override
  Widget build(BuildContext context) {
    if (!viewport.isMovementValid || !force.x.isFinite || !force.y.isFinite) {
      return const SizedBox.shrink();
    }
    final center = viewport.movingForceCenter(force.position);
    if (!center.x.isFinite || !center.y.isFinite) {
      return const SizedBox.shrink();
    }
    const size = GameRules.movingForceWidgetSize;
    return Positioned(
      left: center.x - size / 2,
      top: center.y - size / 2,
      width: size,
      height: size,
      child: MovingForceWidget(
        force: force,
        boardSize: Size(viewport.width, viewport.height),
        presentation: presentation,
        semanticsKey: semanticsKey,
      ),
    );
  }
}

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
    final illustration = AircraftIllustration.forStrength(force.currentValue);
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
                        style: TacticalTypography.of(context).mono(
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
                        key: ValueKey(illustration),
                        painter: _AircraftPainter(
                          faction: force.faction,
                          illustration: illustration,
                        ),
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
                            style: TacticalTypography.of(context).mono(
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

    final viewport = IslandMapViewport(
      width: boardSize.width,
      height: boardSize.height,
    );
    if (!viewport.isMovementValid ||
        !force.deltaX.isFinite ||
        !force.deltaY.isFinite) {
      return 0;
    }

    final delta = viewport.movingForceDelta(
      const IslandPosition(x: 0, y: 0),
      IslandPosition(x: force.deltaX, y: force.deltaY),
    );
    if (!delta.x.isFinite ||
        !delta.y.isFinite ||
        (delta.x == 0 && delta.y == 0)) {
      return 0;
    }

    return math.atan2(delta.y, delta.x);
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
  const _AircraftPainter({required this.faction, required this.illustration});

  final Faction faction;
  final AircraftIllustration illustration;

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
    final fill = Paint()..color = bodyColor;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..color = deepColor;
    void drawBody(Path path) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
    }

    // Each silhouette has its own wing/tail geometry, rather than scaling one
    // image. All point right before the shared heading transform is applied.
    final body = switch (illustration) {
      AircraftIllustration.singleEngine =>
        Path()
          ..moveTo(3, 10.5)
          ..lineTo(5, 10)
          ..lineTo(5, 6)
          ..lineTo(8, 6)
          ..lineTo(9, 10)
          ..lineTo(17, 9.5)
          ..lineTo(16, 1.5)
          ..lineTo(20, 1.5)
          ..lineTo(22, 9.5)
          ..lineTo(29, 9.5)
          ..quadraticBezierTo(32, 9.5, 32, 11)
          ..quadraticBezierTo(32, 12.5, 29, 12.5)
          ..lineTo(22, 12.5)
          ..lineTo(20, 20.5)
          ..lineTo(16, 20.5)
          ..lineTo(17, 12.5)
          ..lineTo(9, 12)
          ..lineTo(8, 16)
          ..lineTo(5, 16)
          ..lineTo(5, 12)
          ..lineTo(3, 11.5)
          ..close(),
      AircraftIllustration.twinEngine =>
        Path()
          ..moveTo(2, 10.5)
          ..lineTo(4, 10)
          ..lineTo(4, 5)
          ..lineTo(7, 5)
          ..lineTo(10, 9.5)
          ..lineTo(17, 9)
          ..lineTo(13, 1)
          ..lineTo(18, 1)
          ..lineTo(23, 9)
          ..lineTo(30, 9)
          ..quadraticBezierTo(34, 9, 34, 11)
          ..quadraticBezierTo(34, 13, 30, 13)
          ..lineTo(23, 13)
          ..lineTo(18, 21)
          ..lineTo(13, 21)
          ..lineTo(17, 13)
          ..lineTo(10, 12.5)
          ..lineTo(7, 17)
          ..lineTo(4, 17)
          ..lineTo(4, 12)
          ..lineTo(2, 11.5)
          ..close(),
      AircraftIllustration.transport =>
        Path()
          ..moveTo(2, 10.5)
          ..lineTo(4, 9.5)
          ..lineTo(3, 4)
          ..lineTo(7, 4)
          ..lineTo(10, 9)
          ..lineTo(17, 8.5)
          ..lineTo(14, 1)
          ..lineTo(21, 1)
          ..lineTo(25, 8.5)
          ..lineTo(30, 8.5)
          ..quadraticBezierTo(34, 8.5, 34, 11)
          ..quadraticBezierTo(34, 13.5, 30, 13.5)
          ..lineTo(25, 13.5)
          ..lineTo(21, 21)
          ..lineTo(14, 21)
          ..lineTo(17, 13.5)
          ..lineTo(10, 13)
          ..lineTo(7, 18)
          ..lineTo(3, 18)
          ..lineTo(4, 12.5)
          ..lineTo(2, 11.5)
          ..close(),
    };
    drawBody(body);

    if (illustration == AircraftIllustration.singleEngine) {
      canvas.drawLine(const Offset(33, 6.5), const Offset(33, 15.5), outline);
    } else {
      // Pods sit along the wings, separate from the narrow fuselage. The
      // medium aircraft's propellers and transport's four engines distinguish
      // the silhouettes without turning the body into a rocket-like capsule.
      final engineRows = illustration == AircraftIllustration.twinEngine
          ? const [5.0, 17.0]
          : const [3.5, 6.5, 15.5, 18.5];
      for (final y in engineRows) {
        final nacelle = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(20, y), width: 6, height: 1.8),
          const Radius.circular(0.8),
        );
        canvas.drawRRect(nacelle, Paint()..color = deepColor);
        if (illustration == AircraftIllustration.twinEngine) {
          canvas.drawLine(Offset(23, y - 2), Offset(23, y + 2), outline);
        }
      }
    }

    // A light cockpit makes the nose legible in either faction color.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 9.8, 2, 2.4),
        const Radius.circular(0.8),
      ),
      Paint()..color = TacticalPalette.paper,
    );
    if (faction == Faction.cpu) {
      final emblem = Path()
        ..moveTo(20, 8.7)
        ..lineTo(22.3, 13.3)
        ..lineTo(17.7, 13.3)
        ..close();
      canvas.drawPath(emblem, Paint()..color = deepColor);
      canvas.drawPath(
        emblem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = TacticalPalette.paper,
      );
    } else {
      canvas.drawCircle(const Offset(20, 11), 2.3, Paint()..color = deepColor);
      canvas.drawCircle(
        const Offset(20, 11),
        2.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = TacticalPalette.paper,
      );
      final mark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = TacticalPalette.paper;
      canvas.drawLine(const Offset(18.8, 10.3), const Offset(20, 11.7), mark);
      canvas.drawLine(const Offset(20, 11.7), const Offset(21.2, 10.3), mark);
    }
  }

  @override
  bool shouldRepaint(covariant _AircraftPainter oldDelegate) {
    return faction != oldDelegate.faction ||
        illustration != oldDelegate.illustration;
  }
}

typedef MovingForceView = MovingForceWidget;
