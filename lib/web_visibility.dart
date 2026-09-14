import 'package:flutter/foundation.dart';

import 'web_visibility_source.dart';
import 'web_visibility_source_stub.dart'
    if (dart.library.html) 'web_visibility_source_web.dart'
    as platform;

export 'web_visibility_source.dart';

WebVisibilitySource createWebVisibilitySource() =>
    platform.createWebVisibilitySource();

/// Pauses a match when the browser page becomes hidden.
///
/// The native [WidgetsBindingObserver] remains responsible for platform
/// lifecycle events. This bridge directly covers the browser visibility
/// boundary, which can be delivered independently of Flutter's lifecycle
/// observer on a deployed web page.
final class WebVisibilityBridge {
  WebVisibilityBridge({
    required WebVisibilitySource source,
    required VoidCallback onHidden,
    ValueChanged<bool>? onVisibilityChanged,
  }) : _source = source,
       _onHidden = onHidden,
       _onVisibilityChanged = onVisibilityChanged;

  final WebVisibilitySource _source;
  final VoidCallback _onHidden;
  final ValueChanged<bool>? _onVisibilityChanged;
  var _listening = false;

  void start() {
    if (_listening) return;
    _listening = true;
    _source.addListener(_handleVisibilityChanged);
    if (_source.isHidden) {
      _onHidden();
      _onVisibilityChanged?.call(true);
    } else {
      _onVisibilityChanged?.call(false);
    }
  }

  void dispose() {
    if (!_listening) return;
    _source.removeListener(_handleVisibilityChanged);
    _listening = false;
  }

  void _handleVisibilityChanged() {
    if (!_listening) return;
    final hidden = _source.isHidden;
    if (hidden) _onHidden();
    _onVisibilityChanged?.call(hidden);
  }
}
