import 'package:flutter/foundation.dart';

/// The page-visibility boundary used by the web lifecycle bridge.
///
/// The interface keeps browser interop out of widgets and lets VM tests emit
/// visibility changes without depending on a DOM implementation.
abstract interface class WebVisibilitySource {
  bool get isHidden;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}
