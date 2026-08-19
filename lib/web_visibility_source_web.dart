import 'dart:js_interop';

import 'web_visibility_source.dart';

@JS('document')
external _WebDocument get _document;

extension type _WebDocument._(JSObject _) implements JSObject {
  external String get visibilityState;

  external void addEventListener(String type, JSFunction listener);

  external void removeEventListener(String type, JSFunction listener);
}

final class DomWebVisibilitySource implements WebVisibilitySource {
  final Map<void Function(), JSFunction> _listeners =
      <void Function(), JSFunction>{};

  @override
  bool get isHidden => _document.visibilityState == 'hidden';

  @override
  void addListener(void Function() listener) {
    if (_listeners.containsKey(listener)) return;
    final jsListener = ((JSAny? _) => listener()).toJS;
    _listeners[listener] = jsListener;
    _document.addEventListener('visibilitychange', jsListener);
  }

  @override
  void removeListener(void Function() listener) {
    final registeredListener = _listeners.remove(listener);
    if (registeredListener == null) return;
    _document.removeEventListener('visibilitychange', registeredListener);
  }
}

WebVisibilitySource createWebVisibilitySource() => DomWebVisibilitySource();
