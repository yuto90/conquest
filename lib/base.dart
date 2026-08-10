import 'package:flutter/material.dart';

import 'faction_presentation.dart';
import 'game/game_state.dart';
import 'ui/tactical_theme.dart';

/// Tactical-chart renderer for one island.
///
/// Color, coastline, and the central structure communicate ownership without
/// adding letter markers. The semantic contract remains intentionally more
/// descriptive than the visible treatment.
class Base extends StatelessWidget {
  const Base({
    required this.base,
    required this.onPressed,
    this.presentation,
    this.selected = false,
    this.destinationCandidate = false,
    super.key,
  });

  final IslandState base;
  final VoidCallback? onPressed;
  final FactionPresentation? presentation;
  final bool selected;
  final bool destinationCandidate;

  @override
  Widget build(BuildContext context) {
    final isHeadquarters = base.size == IslandSize.headquarters;
    final numberColor = base.faction == Faction.neutral
        ? TacticalPalette.foreground
        : TacticalPalette.paper;
    final interactive = onPressed != null;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: interactive,
      enabled: interactive,
      selected: interactive && selected,
      onTap: onPressed,
      label: _semanticLabel,
      hint: interactive ? _semanticHint : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          excludeFromSemantics: true,
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _IslandPainter(
                    faction: base.faction,
                    coastlineIndex: base.id % 5,
                    isHeadquarters: isHeadquarters,
                    selected: selected,
                    destinationCandidate: destinationCandidate,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _effectivePresentation.marker,
                    style: TacticalTypography.mono(
                      fontSize: isHeadquarters ? 10 : 8,
                      fontWeight: FontWeight.w800,
                      color: numberColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    base.currentValue.toString(),
                    key: base.faction == Faction.neutral
                        ? ValueKey('island-${base.id}-value')
                        : ValueKey('island-${base.id}-current'),
                    style:
                        TacticalTypography.display(
                          fontSize: isHeadquarters ? 27 : 20,
                          fontWeight: FontWeight.w800,
                          color: numberColor,
                          height: 1,
                          letterSpacing: -0.8,
                        ).copyWith(
                          shadows: base.faction == Faction.neutral
                              ? null
                              : const <Shadow>[
                                  Shadow(
                                    color: Color(0x47001116),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                        ),
                  ),
                ],
              ),
              if (base.faction != Faction.neutral)
                Offstage(
                  offstage: true,
                  child: Text(
                    '/${base.capacity}',
                    key: ValueKey('island-${base.id}-capacity'),
                  ),
                ),
              if (selected)
                Positioned(
                  top: -14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TacticalPalette.surface,
                      border: Border.all(color: TacticalPalette.playerDeep),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        '出兵元',
                        style: TacticalTypography.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: TacticalPalette.playerDeep,
                          height: 1,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  FactionPresentation get _effectivePresentation =>
      presentation ??
      FactionPresentation.forMode(GameMode.playerVsCpu, base.faction);

  String get _sizeName => switch (base.size) {
    IslandSize.small => 'small island',
    IslandSize.medium => 'medium island',
    IslandSize.large => 'large island',
    IslandSize.headquarters => 'headquarters',
  };

  String get _semanticLabel {
    final value = base.faction == Faction.neutral
        ? 'durability ${base.currentDurability}'
        : 'forces ${base.currentForces} of ${base.capacity}';
    final identity =
        '${_effectivePresentation.semanticName} $_sizeName, '
        '$value, current value ${base.currentValue}';
    if (onPressed == null) return identity;
    final action = selected
        ? 'selected dispatch source'
        : destinationCandidate
        ? 'valid dispatch destination'
        : base.canDispatch
        ? 'available dispatch source'
        : 'not available as dispatch source';
    return '$identity, $action';
  }

  String? get _semanticHint {
    if (onPressed == null) return null;
    if (selected) {
      return 'Tap again to cancel selection, or choose a valid destination.';
    }
    if (destinationCandidate) return 'Tap to dispatch troops here.';
    if (base.canDispatch) {
      return 'Tap to select this island as a dispatch source.';
    }
    return 'This island cannot be selected as a dispatch source.';
  }
}

class _IslandPainter extends CustomPainter {
  const _IslandPainter({
    required this.faction,
    required this.coastlineIndex,
    required this.isHeadquarters,
    required this.selected,
    required this.destinationCandidate,
  });

  final Faction faction;
  final int coastlineIndex;
  final bool isHeadquarters;
  final bool selected;
  final bool destinationCandidate;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale, scale);

    if (selected) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TacticalPalette.playerDeep;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 4, 92, 92),
          const Radius.circular(20),
        ),
        ringPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 10, 80, 80),
          const Radius.circular(17),
        ),
        ringPaint..color = TacticalPalette.player,
      );
    }

    if (destinationCandidate) _paintDestinationBrackets(canvas);

    final paths = _coastlinePaths(coastlineIndex);
    canvas.drawPath(
      paths.$1,
      Paint()
        ..style = PaintingStyle.fill
        ..color = TacticalPalette.surface.withValues(alpha: 0.52),
    );
    canvas.drawPath(
      paths.$1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = TacticalPalette.border.withValues(alpha: 0.72),
    );

    final landColor = switch (faction) {
      Faction.player => TacticalPalette.player,
      Faction.cpu => TacticalPalette.cpu,
      Faction.neutral => Color.alphaBlend(
        TacticalPalette.neutral.withValues(alpha: 0.67),
        TacticalPalette.background,
      ),
    };
    final landStroke = switch (faction) {
      Faction.player => TacticalPalette.playerDeep,
      Faction.cpu => TacticalPalette.cpuDeep,
      Faction.neutral => TacticalPalette.neutral,
    };
    canvas.drawPath(paths.$2, Paint()..color = landColor);
    canvas.drawPath(
      paths.$2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = landStroke,
    );
    _paintStructure(canvas);
    canvas.restore();
  }

  void _paintDestinationBrackets(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TacticalPalette.seaDeep.withValues(alpha: 0.72);
    const inset = 1.0;
    const length = 14.0;
    for (final path in <Path>[
      Path()
        ..moveTo(inset, inset + length)
        ..lineTo(inset, inset)
        ..lineTo(inset + length, inset),
      Path()
        ..moveTo(100 - inset - length, inset)
        ..lineTo(100 - inset, inset)
        ..lineTo(100 - inset, inset + length),
      Path()
        ..moveTo(inset, 100 - inset - length)
        ..lineTo(inset, 100 - inset)
        ..lineTo(inset + length, 100 - inset),
      Path()
        ..moveTo(100 - inset - length, 100 - inset)
        ..lineTo(100 - inset, 100 - inset)
        ..lineTo(100 - inset, 100 - inset - length),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  void _paintStructure(Canvas canvas) {
    final fill = switch (faction) {
      Faction.player => TacticalPalette.playerDeep,
      Faction.cpu => TacticalPalette.cpuDeep,
      Faction.neutral => Color.alphaBlend(
        TacticalPalette.neutral.withValues(alpha: 0.54),
        TacticalPalette.background,
      ),
    };
    final mark = faction == Faction.neutral
        ? TacticalPalette.foreground
        : TacticalPalette.paper;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill.withValues(alpha: isHeadquarters ? 0.72 : 0.62);
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = mark.withValues(alpha: 0.78);

    switch (faction) {
      case Faction.player:
        final structure = isHeadquarters
            ? (Path()
                ..moveTo(22, 68)
                ..lineTo(22, 43)
                ..lineTo(36, 43)
                ..lineTo(36, 32)
                ..lineTo(64, 32)
                ..lineTo(64, 43)
                ..lineTo(78, 43)
                ..lineTo(78, 68)
                ..close())
            : (Path()
                ..moveTo(27, 64)
                ..lineTo(27, 45)
                ..lineTo(39, 45)
                ..lineTo(39, 36)
                ..lineTo(61, 36)
                ..lineTo(61, 45)
                ..lineTo(73, 45)
                ..lineTo(73, 64)
                ..close());
        canvas.drawPath(structure, fillPaint);
        canvas.drawPath(structure, outlinePaint);
        final chevrons = Path()
          ..moveTo(39, 55)
          ..lineTo(50, 63)
          ..lineTo(61, 55)
          ..moveTo(39, 31)
          ..lineTo(50, 39)
          ..lineTo(61, 31);
        canvas.drawPath(chevrons, outlinePaint..strokeWidth = 2.4);
      case Faction.cpu:
        final structure = Path()
          ..moveTo(isHeadquarters ? 21 : 27, isHeadquarters ? 69 : 66)
          ..lineTo(isHeadquarters ? 21 : 27, isHeadquarters ? 41 : 44)
          ..lineTo(isHeadquarters ? 31 : 35, isHeadquarters ? 32 : 37)
          ..lineTo(isHeadquarters ? 40 : 43, isHeadquarters ? 43 : 45)
          ..lineTo(50, isHeadquarters ? 27 : 34)
          ..lineTo(isHeadquarters ? 60 : 57, isHeadquarters ? 43 : 45)
          ..lineTo(isHeadquarters ? 69 : 65, isHeadquarters ? 32 : 37)
          ..lineTo(isHeadquarters ? 79 : 73, isHeadquarters ? 41 : 44)
          ..lineTo(isHeadquarters ? 79 : 73, isHeadquarters ? 69 : 66)
          ..close();
        canvas.drawPath(structure, fillPaint);
        canvas.drawPath(structure, outlinePaint);
        final triangle = Path()
          ..moveTo(isHeadquarters ? 39 : 42, isHeadquarters ? 59 : 57)
          ..lineTo(50, isHeadquarters ? 39 : 43)
          ..lineTo(isHeadquarters ? 61 : 58, isHeadquarters ? 59 : 57)
          ..close();
        canvas.drawPath(triangle, outlinePaint..strokeWidth = 2.2);
      case Faction.neutral:
        canvas.drawCircle(const Offset(50, 51), 17, fillPaint);
        canvas.drawCircle(const Offset(50, 51), 17, outlinePaint);
        canvas.drawCircle(
          const Offset(50, 51),
          9,
          outlinePaint..strokeWidth = 1.7,
        );
    }
  }

  (Path, Path) _coastlinePaths(int index) {
    return switch (index % 5) {
      0 => (
        Path()
          ..moveTo(7, 51)
          ..cubicTo(9, 34, 20, 22, 35, 18)
          ..cubicTo(47, 14, 54, 19, 64, 16)
          ..cubicTo(78, 18, 91, 31, 93, 48)
          ..cubicTo(94, 64, 84, 78, 68, 83)
          ..cubicTo(53, 88, 43, 81, 31, 84)
          ..cubicTo(17, 80, 8, 68, 7, 51)
          ..close(),
        Path()
          ..moveTo(13, 51)
          ..cubicTo(14, 37, 24, 27, 37, 23)
          ..cubicTo(48, 20, 55, 24, 64, 21)
          ..cubicTo(76, 23, 86, 34, 87, 48)
          ..cubicTo(88, 61, 79, 72, 66, 77)
          ..cubicTo(53, 81, 44, 75, 33, 78)
          ..cubicTo(22, 75, 14, 65, 13, 51)
          ..close(),
      ),
      1 => (
        Path()
          ..moveTo(17, 35)
          ..cubicTo(22, 20, 38, 10, 53, 13)
          ..cubicTo(68, 16, 80, 26, 82, 42)
          ..cubicTo(84, 53, 78, 62, 86, 75)
          ..cubicTo(76, 88, 62, 92, 48, 85)
          ..cubicTo(36, 80, 27, 85, 17, 73)
          ..cubicTo(9, 62, 12, 48, 17, 35)
          ..close(),
        Path()
          ..moveTo(23, 37)
          ..cubicTo(27, 25, 39, 18, 52, 19)
          ..cubicTo(65, 21, 74, 30, 76, 43)
          ..cubicTo(78, 54, 72, 62, 79, 72)
          ..cubicTo(70, 81, 60, 84, 49, 79)
          ..cubicTo(38, 75, 30, 80, 22, 70)
          ..cubicTo(16, 61, 18, 48, 23, 37)
          ..close(),
      ),
      2 => (
        Path()
          ..moveTo(10, 46)
          ..cubicTo(14, 31, 25, 19, 42, 17)
          ..cubicTo(56, 10, 73, 18, 82, 29)
          ..cubicTo(94, 42, 90, 59, 81, 71)
          ..cubicTo(72, 83, 57, 88, 43, 83)
          ..cubicTo(30, 88, 16, 79, 12, 66)
          ..cubicTo(8, 58, 17, 53, 10, 46)
          ..close(),
        Path()
          ..moveTo(17, 46)
          ..cubicTo(20, 34, 29, 25, 43, 24)
          ..cubicTo(56, 18, 69, 24, 76, 33)
          ..cubicTo(85, 43, 83, 57, 75, 66)
          ..cubicTo(68, 75, 56, 80, 44, 76)
          ..cubicTo(33, 80, 22, 73, 19, 63)
          ..cubicTo(16, 56, 23, 51, 17, 46)
          ..close(),
      ),
      3 => (
        Path()
          ..moveTo(13, 59)
          ..cubicTo(7, 45, 16, 31, 28, 25)
          ..cubicTo(38, 20, 42, 9, 55, 14)
          ..cubicTo(64, 9, 74, 17, 77, 27)
          ..cubicTo(90, 31, 95, 45, 88, 57)
          ..cubicTo(92, 70, 80, 81, 67, 83)
          ..cubicTo(54, 91, 42, 83, 33, 81)
          ..cubicTo(20, 79, 15, 69, 13, 59)
          ..close(),
        Path()
          ..moveTo(20, 57)
          ..cubicTo(15, 46, 22, 35, 32, 30)
          ..cubicTo(41, 26, 45, 18, 55, 21)
          ..cubicTo(63, 17, 70, 24, 72, 32)
          ..cubicTo(82, 34, 87, 45, 81, 55)
          ..cubicTo(84, 65, 75, 74, 65, 76)
          ..cubicTo(54, 82, 45, 75, 36, 74)
          ..cubicTo(27, 72, 22, 65, 20, 57)
          ..close(),
      ),
      _ => (
        Path()
          ..moveTo(12, 50)
          ..cubicTo(12, 34, 26, 20, 42, 18)
          ..cubicTo(55, 12, 71, 20, 81, 31)
          ..cubicTo(91, 42, 89, 59, 80, 70)
          ..cubicTo(70, 82, 55, 88, 41, 82)
          ..cubicTo(26, 84, 13, 70, 12, 50)
          ..close(),
        Path()
          ..moveTo(19, 50)
          ..cubicTo(19, 37, 30, 27, 43, 25)
          ..cubicTo(55, 20, 67, 27, 75, 35)
          ..cubicTo(82, 44, 81, 56, 74, 65)
          ..cubicTo(66, 74, 55, 79, 43, 75)
          ..cubicTo(31, 77, 20, 66, 19, 50)
          ..close(),
      ),
    };
  }

  @override
  bool shouldRepaint(covariant _IslandPainter oldDelegate) {
    return faction != oldDelegate.faction ||
        coastlineIndex != oldDelegate.coastlineIndex ||
        isHeadquarters != oldDelegate.isHeadquarters ||
        selected != oldDelegate.selected ||
        destinationCandidate != oldDelegate.destinationCandidate;
  }
}
