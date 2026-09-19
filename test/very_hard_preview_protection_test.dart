import 'package:flutter_test/flutter_test.dart';

import '../tool/very_hard/preview_protection.dart';

void main() {
  test('maps an Automation Bypass environment secret to the Vercel header', () {
    final headers = previewProtectionHeaders(const <String, String>{
      vercelAutomationBypassSecretEnvironmentVariable: 'preview-secret',
    });

    expect(headers, <String, String>{
      vercelProtectionBypassHeader: 'preview-secret',
    });
  });

  test('omits the Preview header when no usable secret is configured', () {
    expect(previewProtectionHeaders(const <String, String>{}), isEmpty);
    expect(
      previewProtectionHeaders(const <String, String>{
        vercelAutomationBypassSecretEnvironmentVariable: '   ',
      }),
      isEmpty,
    );
  });
}
