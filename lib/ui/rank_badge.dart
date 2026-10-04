import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../rank_progression.dart';
import 'rank_badge_spec.dart';

const rankBadgeCrestAsset = 'assets/rank_badges/chart-crest.png';
const _ink = Color(0xFF153F44);
const _metal = Color(0xFFD5C794);

/// Decorative C-method badge. The adjacent localized text supplies semantics.
class RankBadge extends StatelessWidget {
  const RankBadge({required this.rank, this.size = 36, super.key})
    : assert(size > 0);

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = RankBadgeSpec.fromRank(rank);
    final fallback = CustomPaint(
      key: const ValueKey('rank-crest-fallback'),
      painter: RankBadgePainter(spec: spec, layer: RankBadgeLayer.fallback),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: RankBadgePainter(spec: spec, layer: RankBadgeLayer.base),
          foregroundPainter: RankBadgePainter(
            spec: spec,
            layer: RankBadgeLayer.details,
          ),
          child: spec.usesCrest
              ? Image.asset(
                  rankBadgeCrestAsset,
                  excludeFromSemantics: true,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  frameBuilder: (context, child, frame, synchronous) {
                    if (frame == null && !synchronous) return fallback;
                    final rect = rankBadgeCrestRect(spec);
                    return Stack(
                      children: [
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(
                            rect.left * size / 100,
                            rect.top * size / 100,
                            rect.width * size / 100,
                            rect.height * size / 100,
                          ),
                          child: child,
                        ),
                      ],
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => fallback,
                )
              : null,
        ),
      ),
    );
  }
}

/// Wraps the complete rank label and stacks the badge at narrow/large-text sizes.
class RankBadgeLabel extends StatelessWidget {
  const RankBadgeLabel({
    required this.progress,
    required this.style,
    this.badgeSize = 36,
    this.label,
    this.supporting,
    super.key,
  });

  final RankProgress progress;
  final TextStyle style;
  final double badgeSize;
  final String? label;
  final Widget? supporting;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final text = Text(
      label ??
          l10n.rankDisplay(
            rank: progress.rank,
            title: progress.localizedTitle(l10n),
          ),
      style: style,
      softWrap: true,
    );
    final rankText = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text,
        if (supporting != null) ...[const SizedBox(height: 4), supporting!],
      ],
    );
    final badge = RankBadge(rank: progress.rank, size: badgeSize);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = style.fontSize ?? 14;
        final largeText =
            MediaQuery.textScalerOf(context).scale(fontSize) > fontSize * 1.3;
        if (constraints.maxWidth < badgeSize + 130 || largeText) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: badge),
              const SizedBox(height: 6),
              rankText,
            ],
          );
        }
        return Row(
          children: [
            badge,
            const SizedBox(width: 10),
            Expanded(child: rankText),
          ],
        );
      },
    );
  }
}

enum RankBadgeLayer { base, fallback, details }

Rect rankBadgeCrestRect(RankBadgeSpec spec) =>
    spec.family == RankBadgeFamily.command
    ? const Rect.fromLTWH(23, 25, 54, 43)
    : const Rect.fromLTWH(21, 26, 58, 46);

class RankBadgePainter extends CustomPainter {
  const RankBadgePainter({required this.spec, required this.layer});

  final RankBadgeSpec spec;
  final RankBadgeLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(size.shortestSide / 100);
    final ink = Paint()..color = _ink;
    final metal = Paint()..color = _metal;
    final border = Paint()
      ..color = _metal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    switch (layer) {
      case RankBadgeLayer.base:
        canvas.drawPath(_shieldPath(), ink);
        canvas.save();
        canvas.translate(5, 4);
        canvas.scale(0.9);
        canvas.drawPath(_shieldPath(), border);
        canvas.restore();
        if (spec.secondBand) {
          canvas.drawLine(
            const Offset(28, 22),
            const Offset(72, 22),
            border..strokeWidth = 4,
          );
        }
        switch (spec.family) {
          case RankBadgeFamily.recruit:
            canvas.drawCircle(
              const Offset(50, 45),
              13,
              border..strokeWidth = 5,
            );
            canvas.drawLine(
              const Offset(50, 28),
              const Offset(50, 62),
              border..strokeWidth = 3,
            );
          case RankBadgeFamily.enlisted:
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
          case RankBadgeFamily.warrant:
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
          case RankBadgeFamily.officer:
            final bars = spec.groupIndex - 15;
            for (var i = 0; i < bars; i++) {
              canvas.drawRect(
                Rect.fromLTWH(50 - bars * 7 + i * 14, 29, 9, 34),
                metal,
              );
            }
          case RankBadgeFamily.command:
          case RankBadgeFamily.general:
            break;
        }
      case RankBadgeLayer.fallback:
        switch (spec.family) {
          case RankBadgeFamily.command:
            canvas.drawPath(_starPath(const Offset(50, 46), 23, 11, 4), metal);
            canvas.drawCircle(const Offset(50, 46), 6, ink);
          case RankBadgeFamily.general:
            canvas.drawCircle(const Offset(50, 48), 20, border);
            canvas.drawPath(_starPath(const Offset(50, 48), 14, 6, 5), metal);
          default:
            break;
        }
      case RankBadgeLayer.details:
        if (spec.family == RankBadgeFamily.command) {
          for (var i = 0; i < spec.groupIndex - 18; i++) {
            canvas.drawLine(
              Offset(32, 64.0 + i * 4),
              Offset(68, 64.0 + i * 4),
              border..strokeWidth = 2,
            );
          }
        } else if (spec.family == RankBadgeFamily.general) {
          final stars = spec.groupIndex - 21;
          for (var i = 0; i < stars; i++) {
            canvas.drawPath(
              _starPath(Offset(50 - (stars - 1) * 7 + i * 14, 30), 6, 2.8, 5),
              metal,
            );
          }
        }
        for (var i = 0; i < spec.pips; i++) {
          final left = 50 - (spec.pips * 8 - 3) / 2;
          canvas.drawRect(Rect.fromLTWH(left + i * 8, 75, 5, 4), metal);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RankBadgePainter oldDelegate) =>
      oldDelegate.spec.tier != spec.tier || oldDelegate.layer != layer;
}

Path _shieldPath() => Path()
  ..moveTo(13, 12)
  ..lineTo(87, 12)
  ..lineTo(87, 58)
  ..quadraticBezierTo(87, 78, 50, 94)
  ..quadraticBezierTo(13, 78, 13, 58)
  ..close();

Path _starPath(Offset center, double outer, double inner, int points) {
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
