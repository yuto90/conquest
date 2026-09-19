const vercelAutomationBypassSecretEnvironmentVariable =
    'VERCEL_AUTOMATION_BYPASS_SECRET';
const vercelProtectionBypassHeader = 'x-vercel-protection-bypass';

/// Returns the Preview Deployment Protection header for local automation.
///
/// The secret stays outside command arguments and report output. An absent or
/// blank value deliberately produces no header so unprotected Previews keep
/// working without extra setup.
Map<String, String> previewProtectionHeaders(Map<String, String> environment) {
  final secret = environment[vercelAutomationBypassSecretEnvironmentVariable];
  if (secret == null || secret.trim().isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{vercelProtectionBypassHeader: secret};
}
