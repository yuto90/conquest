import 'dart:math' as math;

import 'package:flutter/material.dart';

// Original compass and curved fronds, frozen from the approved C study.
void paintRankCrestSource(Canvas canvas) {
  const metal = Color(0xFFD5C794);
  final leaf = Paint()..color = metal;
  final stem = Paint()
    ..color = metal
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
  canvas.drawPath(_star(const Offset(50, 47), 30, 9), leaf);
  canvas.drawPath(
    _star(const Offset(50, 47), 19, 6),
    Paint()..color = const Color(0xFFFFF1C9),
  );
  canvas.drawCircle(
    const Offset(50, 47),
    4,
    Paint()..color = const Color(0xFF153F44),
  );
}

Path _star(Offset center, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final radius = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / 4;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}
