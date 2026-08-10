#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_workflow="$repo_root/.github/workflows/build-ios-app-store.yml"
signing_script="$repo_root/script/configure-ios-signing.rb"
internal_group_script="$repo_root/script/testflight-internal-group.rb"
fvm_config="$repo_root/.fvm/fvm_config.json"

assert_file_exists() {
  [[ -f "$1" ]] || {
    printf 'expected file to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_contains() {
  grep -Fq -- "$2" "$1" || {
    printf 'expected %s to contain: %s\n' "$1" "$2" >&2
    exit 1
  }
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    printf 'expected %s not to contain: %s\n' "$1" "$2" >&2
    exit 1
  fi
}

for path in "$build_workflow" "$signing_script" "$internal_group_script" "$fvm_config"; do
  assert_file_exists "$path"
done

assert_contains "$build_workflow" 'DEVELOPER_DIR: /Applications/Xcode_26.3.app/Contents/Developer'
assert_contains "$build_workflow" 'Validate App Store Xcode requirements'
assert_contains "$build_workflow" 'Xcode 26 or later is required by App Store Connect'
assert_contains "$build_workflow" 'iOS SDK 26 or later is required by App Store Connect'
assert_contains "$build_workflow" '.fvm/fvm_config.json'
assert_contains "$build_workflow" '.flutterSdkVersion'
assert_contains "$build_workflow" '--config-only'
assert_contains "$build_workflow" '-archivePath "$RUNNER_TEMP/Runner.xcarchive"'
assert_contains "$build_workflow" 'ruby ../_release_automation/script/configure-ios-signing.rb'
assert_contains "$build_workflow" '-exportArchive'
assert_not_contains "$build_workflow" 'fvm flutter build ipa'
assert_contains "$build_workflow" 'security find-identity -v -p codesigning'
assert_contains "$build_workflow" 'TeamIdentifier'
assert_contains "$build_workflow" 'ApplicationIdentifierPrefix'
assert_contains "$build_workflow" 'ProvisionedDevices'
assert_contains "$build_workflow" '<key>method</key><string>app-store-connect</string>'
assert_contains "$build_workflow" '--skip_submission true'
assert_contains "$build_workflow" 'assign-build'
assert_contains "$build_workflow" 'assert-no-groups'
assert_contains "$build_workflow" 'app-store-build-provenance-${{ github.run_id }}'
assert_contains "$build_workflow" 'retention-days: 90'
assert_contains "$build_workflow" 'if: always()'
assert_contains "$build_workflow" 'ITSAppUsesNonExemptEncryption'
assert_contains "$build_workflow" 'info["ITSAppUsesNonExemptEncryption"] = False'
assert_contains "$build_workflow" 'plistlib'
assert_contains "$build_workflow" 'APP_BUNDLE_ID'
assert_contains "$build_workflow" 'APPLE_TEAM_ID'
assert_contains "$build_workflow" 'TESTFLIGHT_INTERNAL_GROUP'
assert_not_contains "$build_workflow" 'SUPABASE'
assert_not_contains "$build_workflow" '.env'
assert_not_contains "$build_workflow" '--dart-define-from-file'

assert_contains "$internal_group_script" 'hasAccessToAllBuilds'
assert_contains "$internal_group_script" 'add_build_to_beta_group'
assert_contains "$signing_script" 'PRODUCT_BUNDLE_IDENTIFIER'
assert_contains "$signing_script" 'APP_BUNDLE_ID'
assert_contains "$signing_script" 'APPLE_TEAM_ID'

ruby -ryaml -e '
  workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  triggers = workflow["on"] || workflow[true]
  raise "build workflow must only support workflow_call" unless triggers.keys == ["workflow_call"]
  call = triggers.fetch("workflow_call")
  %w[commit_sha distribute_internal submission_source caller_workflow_name caller_workflow_path].each do |name|
    input = call.fetch("inputs").fetch(name)
    raise "#{name} must be required" unless input.fetch("required") == true
  end
  raise "distribute_internal must be boolean" unless call.fetch("inputs").fetch("distribute_internal").fetch("type") == "boolean"
  outputs = call.fetch("outputs")
  %w[app_version build_number commit_sha build_id].each do |name|
    raise "missing common build output #{name}" unless outputs.key?(name)
  end
  jobs = workflow.fetch("jobs")
  preflight = jobs.fetch("preflight")
  build = jobs.fetch("build")
  raise "preflight must use Ubuntu" unless preflight.fetch("runs-on") == "ubuntu-24.04"
  raise "iOS build must wait for preflight" unless build.fetch("needs") == "preflight"
  raise "common build must use testflight environment" unless build.fetch("environment") == "testflight"
  preflight_commands = preflight.fetch("steps").filter_map { |step| step["run"] }.join("\n")
  build_commands = build.fetch("steps").filter_map { |step| step["run"] }.join("\n")
  raise "preflight must run analyze" unless preflight_commands.include?("fvm flutter analyze")
  raise "preflight must run tests" unless preflight_commands.include?("fvm flutter test")
  raise "macOS build must not rerun analyze" if build_commands.include?("fvm flutter analyze")
  raise "macOS build must not rerun tests" if build_commands.include?("fvm flutter test")
  names = build.fetch("steps").map { |step| step.fetch("name") }
  policy_index = names.index("Apply and verify TestFlight distribution policy")
  provenance_index = names.index("Write build provenance")
  raise "provenance must follow distribution verification" unless policy_index && provenance_index && policy_index < provenance_index
  compliance_index = names.index("Declare App Store export compliance")
  archive_index = names.index("Build signed IPA")
  raise "export compliance must be declared before archive" unless compliance_index < archive_index
  cleanup = build.fetch("steps").find { |step| step.fetch("name") == "Clean up signing materials" }
  raise "signing cleanup must always run" unless cleanup.fetch("if") == "always()"
  secrets = %w[
    IOS_DISTRIBUTION_CERTIFICATE_BASE64
    IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
    IOS_APP_STORE_PROVISIONING_PROFILE_BASE64
    APP_STORE_CONNECT_ISSUER_ID
    APP_STORE_CONNECT_KEY_ID
    APP_STORE_CONNECT_PRIVATE_KEY
  ]
  leaked = secrets & build.fetch("env", {}).keys
  raise "distribution secrets must not be job-scoped" unless leaked.empty?
' "$build_workflow"

printf 'TestFlight workflow tests passed\n'
