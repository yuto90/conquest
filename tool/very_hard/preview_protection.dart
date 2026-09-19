const vercelAutomationBypassSecretEnvironmentVariable =
    'VERCEL_AUTOMATION_BYPASS_SECRET';
const vercelProtectionBypassHeader = 'x-vercel-protection-bypass';
final _trustedConquestPreviewHost = RegExp(
  r'^conquest-[a-z0-9]+-yuto90s-projects\.vercel\.app$',
);

/// Returns the Preview Deployment Protection header for local automation.
///
/// The secret stays outside command arguments and report output. An absent or
/// blank value deliberately produces no header so unprotected Previews keep
/// working without extra setup.
Map<String, String> previewProtectionHeaders(
  Map<String, String> environment, {
  required Uri previewUrl,
}) {
  final secret = environment[vercelAutomationBypassSecretEnvironmentVariable];
  if (secret == null || secret.trim().isEmpty) {
    return const <String, String>{};
  }
  if (previewUrl.scheme != 'https' ||
      previewUrl.userInfo.isNotEmpty ||
      previewUrl.hasPort ||
      !_trustedConquestPreviewHost.hasMatch(previewUrl.host)) {
    throw const FormatException(
      'Automation Bypass secretはConquestのHTTPS Previewにのみ送信できます',
    );
  }
  return <String, String>{vercelProtectionBypassHeader: secret};
}
