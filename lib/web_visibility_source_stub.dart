import 'web_visibility_source.dart';

final class _NoopWebVisibilitySource implements WebVisibilitySource {
  const _NoopWebVisibilitySource();

  @override
  bool get isHidden => false;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}
}

WebVisibilitySource createWebVisibilitySource() =>
    const _NoopWebVisibilitySource();
