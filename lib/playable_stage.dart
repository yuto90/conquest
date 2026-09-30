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

/// Keeps compact portrait Web windows usable without shrinking their width.
/// Wide/landscape windows retain the centered 390:844 presentation, as do
/// unusually tall windows where fitting only removes unused vertical space.
Size fitWebStage(Size window) {
  final portrait = fitPortraitStage(window);
  if (window.width < 600 &&
      window.height > window.width &&
      portrait.width < window.width) {
    return window;
  }
  return portrait;
}
