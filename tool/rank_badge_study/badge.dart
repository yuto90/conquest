import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:conquest/rank_progression.dart';
import 'package:flutter/material.dart';

enum BadgeMethod { individual, geometry, composite }

enum BadgeFamily { recruit, enlisted, warrant, officer, command, general }

@immutable
final class BadgeSpec {
  const BadgeSpec._(this.tier, this.groupIndex, this.stage, this.stageCount);

  factory BadgeSpec.fromRank(int rank) {
    final tier = RankCatalog.tiers[rank];
    final group = RankTitleKey.values.indexOf(tier.titleKey);
    final end = group + 1 < RankTitleKey.values.length
        ? RankTitleKey.values[group + 1].firstRank
        : RankCatalog.tiers.length;
    return BadgeSpec._(
      tier,
      group,
      rank - tier.titleKey.firstRank,
      end - tier.titleKey.firstRank,
    );
  }

  final RankTier tier;
  final int groupIndex;
  final int stage;
  final int stageCount;

  BadgeFamily get family => switch (groupIndex) {
    0 => BadgeFamily.recruit,
    <= 10 => BadgeFamily.enlisted,
    <= 15 => BadgeFamily.warrant,
    <= 18 => BadgeFamily.officer,
    <= 21 => BadgeFamily.command,
    _ => BadgeFamily.general,
  };

  // Five pips per row; the upper rail distinguishes the second five-stage band.
  int get pips => stageCount == 1 ? 0 : stage % 5 + 1;
  bool get secondBand => stage >= 5;
}

const badgeInk = Color(0xFF153F44);
const badgeMetal = Color(0xFFD5C794);
const badgeLight = Color(0xFFFFF1C9);

class StudyBadge extends StatelessWidget {
  const StudyBadge({
    super.key,
    required this.spec,
    required this.method,
    required this.size,
    this.crest,
    this.individual,
  });

  final BadgeSpec spec;
  final BadgeMethod method;
  final double size;
  final ui.Image? crest;
  final ui.Image? individual;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: BadgePainter(
          spec: spec,
          method: method,
          crest: crest,
          individual: individual,
        ),
      ),
    ),
  );
}

class BadgePainter extends CustomPainter {
  const BadgePainter({
    required this.spec,
    required this.method,
    this.crest,
    this.individual,
    this.monochrome = false,
  });

  final BadgeSpec spec;
  final BadgeMethod method;
  final ui.Image? crest;
  final ui.Image? individual;
  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.shortestSide / 100;
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(scale);
    if (method == BadgeMethod.individual && individual != null) {
      canvas.drawImageRect(
        individual!,
        Rect.fromLTWH(
          0,
          0,
          individual!.width.toDouble(),
          individual!.height.toDouble(),
        ),
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      paintVectorBadge(
        canvas,
        spec,
        crest: method == BadgeMethod.composite ? crest : null,
        monochrome: monochrome,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BadgePainter oldDelegate) =>
      oldDelegate.spec.tier != spec.tier ||
      oldDelegate.method != method ||
      oldDelegate.crest != crest ||
      oldDelegate.individual != individual ||
      oldDelegate.monochrome != monochrome;
}

Path shieldPath() => Path()
  ..moveTo(13, 12)
  ..lineTo(87, 12)
  ..lineTo(87, 58)
  ..quadraticBezierTo(87, 78, 50, 94)
  ..quadraticBezierTo(13, 78, 13, 58)
  ..close();

void paintVectorBadge(
  Canvas canvas,
  BadgeSpec spec, {
  ui.Image? crest,
  bool monochrome = false,
}) {
  final ink = Paint()..color = badgeInk;
  final metal = Paint()
    ..color = monochrome ? const Color(0xFFD7D7D7) : badgeMetal;
  canvas.drawPath(shieldPath(), ink);
  final border = Paint()
    ..color = metal.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  canvas.save();
  canvas.translate(5, 4);
  canvas.scale(0.9);
  canvas.drawPath(shieldPath(), border);
  canvas.restore();
  if (spec.secondBand) {
    canvas.drawLine(
      const Offset(28, 22),
      const Offset(72, 22),
      border..strokeWidth = 4,
    );
  }
  switch (spec.family) {
    case BadgeFamily.recruit:
      canvas.drawCircle(const Offset(50, 45), 13, border..strokeWidth = 5);
      canvas.drawLine(
        const Offset(50, 28),
        const Offset(50, 62),
        border..strokeWidth = 3,
      );
    case BadgeFamily.enlisted:
      final chevrons = (spec.groupIndex - 1) % 5 + 1;
      for (var i = 0; i < chevrons; i++) {
        final y = 28.0 + i * 8;
        canvas.drawPath(
          Path()
            ..moveTo(29, y + 8)
            ..lineTo(50, y)
            ..lineTo(71, y + 8),
          border
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round,
        );
      }
      if (spec.groupIndex > 5) {
        canvas.drawArc(
          const Rect.fromLTWH(28, 41, 44, 28),
          0.2,
          math.pi - 0.4,
          false,
          border..strokeWidth = 4,
        );
      }
    case BadgeFamily.warrant:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 28, 36, 35),
          const Radius.circular(3),
        ),
        metal,
      );
      for (var i = 0; i < spec.groupIndex - 10; i++) {
        canvas.drawRect(Rect.fromLTWH(37, 31 + i * 6, 26, 3), ink);
      }
    case BadgeFamily.officer:
      final bars = spec.groupIndex - 15;
      for (var i = 0; i < bars; i++) {
        canvas.drawRect(
          Rect.fromLTWH(50 - bars * 7 + i * 14, 29, 9, 34),
          metal,
        );
      }
    case BadgeFamily.command:
      if (crest != null) {
        _drawCrest(canvas, crest, const Rect.fromLTWH(23, 25, 54, 43));
      } else {
        canvas.drawPath(starPath(const Offset(50, 46), 23, 11, 4), metal);
        canvas.drawCircle(const Offset(50, 46), 6, ink);
      }
      for (var i = 0; i < spec.groupIndex - 18; i++) {
        canvas.drawLine(
          Offset(32, 64.0 + i * 4),
          Offset(68, 64.0 + i * 4),
          border..strokeWidth = 2,
        );
      }
    case BadgeFamily.general:
      if (crest != null) {
        _drawCrest(canvas, crest, const Rect.fromLTWH(21, 26, 58, 46));
      } else {
        canvas.drawCircle(const Offset(50, 48), 20, border..strokeWidth = 3);
        canvas.drawPath(starPath(const Offset(50, 48), 14, 6, 5), metal);
      }
      final stars = spec.groupIndex - 21;
      for (var i = 0; i < stars; i++) {
        canvas.drawPath(
          starPath(Offset(50 - (stars - 1) * 7 + i * 14, 30), 6, 2.8, 5),
          metal,
        );
      }
  }
  for (var i = 0; i < spec.pips; i++) {
    final left = 50 - (spec.pips * 8 - 3) / 2;
    canvas.drawRect(Rect.fromLTWH(left + i * 8, 75, 5, 4), metal);
  }
}

void _drawCrest(Canvas canvas, ui.Image image, Rect target) =>
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );

Path starPath(Offset center, double outer, double inner, int points) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / points;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

// Original chart compass and curved fronds; only this source is edited, not its PNG.
void paintCrestSource(Canvas canvas) {
  final leaf = Paint()..color = badgeMetal;
  final stem = Paint()
    ..color = badgeMetal
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(50, 0);
    canvas.scale(side, 1);
    canvas.drawPath(
      Path()
        ..moveTo(3, 89)
        ..cubicTo(33, 75, 45, 47, 32, 15),
      stem,
    );
    for (var i = 0; i < 5; i++) {
      final y = 29.0 + i * 11;
      final x = 29.0 - (i - 1) * (i - 1) * 1.7;
      canvas.drawPath(
        Path()
          ..moveTo(x, y + 10)
          ..quadraticBezierTo(x + 20, y + 2, x + 12, y - 9)
          ..quadraticBezierTo(x - 2, y - 4, x, y + 10),
        leaf,
      );
    }
    canvas.restore();
  }
  canvas.drawPath(starPath(const Offset(50, 47), 30, 9, 4), leaf);
  canvas.drawPath(
    starPath(const Offset(50, 47), 19, 6, 4),
    Paint()..color = badgeLight,
  );
  canvas.drawCircle(const Offset(50, 47), 4, Paint()..color = badgeInk);
}

// Frozen complete-image references: individual art direction, not 141 finished assets.
void paintIndividualSource(Canvas canvas, BadgeSpec spec, ui.Image crest) {
  paintVectorBadge(canvas, spec, crest: crest);
  final rim = Paint()
    ..color = badgeLight
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  canvas.save();
  canvas.translate(9, 8);
  canvas.scale(0.82);
  canvas.drawPath(shieldPath(), rim);
  canvas.restore();
  for (final x in [20.0, 80.0]) {
    canvas.drawCircle(Offset(x, 20), 2, Paint()..color = badgeLight);
  }
  if (spec.family == BadgeFamily.general) {
    canvas.drawPath(
      Path()
        ..moveTo(33, 17)
        ..lineTo(39, 10)
        ..lineTo(50, 17)
        ..lineTo(61, 10)
        ..lineTo(67, 17),
      rim..strokeWidth = 3,
    );
  }
}
