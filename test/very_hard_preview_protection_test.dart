import 'package:flutter_test/flutter_test.dart';

import '../tool/very_hard/preview_protection.dart';

void main() {
  test('maps an Automation Bypass environment secret to the Vercel header', () {
    final headers = previewProtectionHeaders(
      const <String, String>{
        vercelAutomationBypassSecretEnvironmentVariable: 'preview-secret',
      },
      previewUrl: Uri.parse(
        'https://conquest-ev80bbmfh-yuto90s-projects.vercel.app',
      ),
    );

    expect(headers, <String, String>{
      vercelProtectionBypassHeader: 'preview-secret',
    });
  });

  test('omits the Preview header when no usable secret is configured', () {
    final localPreview = Uri.parse('http://localhost:3000');
    expect(
      previewProtectionHeaders(
        const <String, String>{},
        previewUrl: localPreview,
      ),
      isEmpty,
    );
    expect(
      previewProtectionHeaders(const <String, String>{
        vercelAutomationBypassSecretEnvironmentVariable: '   ',
      }, previewUrl: localPreview),
      isEmpty,
    );
  });

  test('rejects a bypass secret for non-HTTPS and untrusted hosts', () {
    const environment = <String, String>{
      vercelAutomationBypassSecretEnvironmentVariable: 'preview-secret',
    };

    expect(
      () => previewProtectionHeaders(
        environment,
        previewUrl: Uri.parse(
          'http://conquest-ev80bbmfh-yuto90s-projects.vercel.app',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => previewProtectionHeaders(
        environment,
        previewUrl: Uri.parse('https://attacker.example'),
      ),
      throwsFormatException,
    );
    expect(
      () => previewProtectionHeaders(
        environment,
        previewUrl: Uri.parse(
          'https://conquest-ev80bbmfh-another-team.vercel.app',
        ),
      ),
      throwsFormatException,
    );
  });
}
