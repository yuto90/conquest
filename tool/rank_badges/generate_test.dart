import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'crest_source.dart';

void main() {
  test('regenerate the shared original rank crest', () async {
    final recorder = ui.PictureRecorder();
    paintRankCrestSource(Canvas(recorder)..scale(1.92));
    final picture = recorder.endRecording();
    final image = await picture.toImage(192, 192);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'assets/rank_badges/chart-crest.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
