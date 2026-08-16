import 'dart:ui' show Size;

/// Fits the largest 390:844 portrait rectangle that still fits in [window].
///
/// Web uses this so a landscape desktop window does not stretch the map
/// viewport. Native layouts keep the full SafeArea and do not call this.
Size fitPortraitStage(Size window, {Size aspect = const Size(390, 844)}) {
  final targetAspect = aspect.width / aspect.height;
  final windowAspect = window.width / window.height;
  if (windowAspect > targetAspect) {
    return Size(window.height * targetAspect, window.height);
  }
  return Size(window.width, window.width / targetAspect);
}
