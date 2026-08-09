import 'package:flutter/material.dart';

import 'tactical_theme.dart';

class TacticalMapBackground extends StatelessWidget {
  const TacticalMapBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('tactical-map-background'),
      child: const CustomPaint(
        painter: _TacticalMapPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _TacticalMapPainter extends CustomPainter {
  const _TacticalMapPainter();

  static const _referenceWidth = 390.0;
  static const _referenceHeight = 844.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(TacticalPalette.background, BlendMode.src);
    canvas.save();
    canvas.scale(size.width / _referenceWidth, size.height / _referenceHeight);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = TacticalPalette.border.withValues(alpha: 0.30);
    for (final x in const <double>[48, 126, 204, 282, 360]) {
      canvas.drawLine(Offset(x, 0), Offset(x, _referenceHeight), gridPaint);
    }
    for (final y in const <double>[98, 206, 314, 422, 530, 638, 746]) {
      canvas.drawLine(Offset(0, y), Offset(_referenceWidth, y), gridPaint);
    }

    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TacticalPalette.border.withValues(alpha: 0.34);
    for (final path in <Path>[
      Path()
        ..moveTo(-46, 182)
        ..cubicTo(42, 126, 111, 151, 166, 132)
        ..cubicTo(225, 111, 302, 119, 438, 70),
      Path()
        ..moveTo(-55, 202)
        ..cubicTo(39, 146, 103, 171, 162, 152)
        ..cubicTo(226, 131, 315, 139, 441, 91),
      Path()
        ..moveTo(-45, 644)
        ..cubicTo(50, 588, 111, 609, 182, 594)
        ..cubicTo(248, 580, 328, 593, 439, 548),
      Path()
        ..moveTo(-34, 665)
        ..cubicTo(47, 615, 120, 632, 189, 616)
        ..cubicTo(262, 600, 336, 618, 431, 575),
    ]) {
      canvas.drawPath(path, contourPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
