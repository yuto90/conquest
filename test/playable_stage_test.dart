import 'package:conquest/playable_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a 390x844 window unchanged', () {
    const window = Size(390, 844);
    expect(fitPortraitStage(window), window);
  });

  test('letterboxes a 1920x1080 window to the portrait aspect', () {
    final stage = fitPortraitStage(const Size(1920, 1080));
    expect(stage.height, 1080);
    expect(stage.width, closeTo(1080 * 390 / 844, 0.001));
    expect(stage.width, lessThan(stage.height));
  });

  test('letterboxes a tall window using width as the limiting axis', () {
    final stage = fitPortraitStage(const Size(390, 2000));
    expect(stage.width, 390);
    expect(stage.height, closeTo(844, 0.001));
  });

  test('letterboxes a narrow window using width as the limiting axis', () {
    final stage = fitPortraitStage(const Size(200, 844));
    expect(stage.width, 200);
    expect(stage.height, closeTo(200 * 844 / 390, 0.001));
  });
}
