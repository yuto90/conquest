#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/build-submit-app-store-review.yml"

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

assert_file_exists "$workflow"
assert_contains "$workflow" 'name: Build and Submit App Store Review'
assert_contains "$workflow" 'workflow_dispatch:'
assert_contains "$workflow" 'commit_sha:'
assert_contains "$workflow" 'whats_new_ja:'
assert_contains "$workflow" 'review_notes:'
assert_contains "$workflow" 'uses: ./.github/workflows/build-ios-app-store.yml'
assert_contains "$workflow" 'distribute_internal: false'
assert_contains "$workflow" 'submission_source: direct_review'
assert_contains "$workflow" '--distribution-mode none'
assert_contains "$workflow" 'fastlane deliver submit_build'
assert_contains "$workflow" '--automatic_release false'
assert_contains "$workflow" '--precheck_include_in_app_purchases false'
assert_contains "$workflow" 'App Store build ID does not match build provenance'
assert_contains "$workflow" 'preflight-target:'
assert_contains "$workflow" 'prepare-check'
assert_contains "$workflow" 'Internal TestFlight distribution: \`false\`'
assert_contains "$workflow" 'if: always()'
assert_not_contains "$workflow" 'flutter build ipa'
assert_not_contains "$workflow" 'pilot upload'
assert_not_contains "$workflow" '--ipa '
assert_not_contains "$workflow" 'automatic_release true'

ruby -ryaml -e '
  workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  triggers = workflow["on"] || workflow[true]
  inputs = triggers.fetch("workflow_dispatch").fetch("inputs")
  commit = inputs.fetch("commit_sha")
  raise "commit_sha must be required" unless commit.fetch("required") == true
  raise "commit_sha must be a string" unless commit.fetch("type") == "string"
  %w[whats_new_ja].each do |name|
    input = inputs.fetch(name)
    raise "#{name} must be required" unless input.fetch("required") == true
    raise "#{name} must be a string" unless input.fetch("type") == "string"
  end
  notes = inputs.fetch("review_notes")
  raise "review_notes must be optional" unless notes.fetch("required") == false
  raise "review_notes must be a string" unless notes.fetch("type") == "string"
  permissions = workflow.fetch("permissions")
  raise "contents permission must be read" unless permissions.fetch("contents") == "read"
  concurrency = workflow.fetch("concurrency")
  raise "direct review must not cancel" unless concurrency.fetch("cancel-in-progress") == false
  jobs = workflow.fetch("jobs")
  target_preflight = jobs.fetch("preflight-target")
  raise "target preflight must run on Ubuntu" unless target_preflight.fetch("runs-on") == "ubuntu-24.04"
  raise "target preflight must use testflight environment" unless target_preflight.fetch("environment") == "testflight"
  build = jobs.fetch("build")
  raise "target preflight must run before build" unless build.fetch("needs") == "preflight-target"
  target_commands = target_preflight.fetch("steps").filter_map { |step| step["run"] }.join("\n")
  raise "target preflight must perform a read-only prepare check" unless target_commands.include?("prepare-check")
  raise "target preflight must not upload an IPA" if target_commands.include?("pilot upload")
  raise "wrong reusable workflow" unless build.fetch("uses") == "./.github/workflows/build-ios-app-store.yml"
  raise "direct review must not distribute internally" unless build.fetch("with").fetch("distribute_internal") == false
  raise "wrong direct source" unless build.fetch("with").fetch("submission_source") == "direct_review"
  submit = jobs.fetch("submit")
  raise "submit must wait for build" unless submit.fetch("needs") == "build"
  raise "wrong GitHub environment" unless submit.fetch("environment") == "testflight"
  quote = 39.chr
  expected_if = "${{ github.ref == #{quote}refs/heads/main#{quote} }}"
  raise "direct submit must run from main" unless submit.fetch("if") == expected_if
  steps = submit.fetch("steps").to_h { |step| [step.fetch("name"), step] }
  key_step = steps.fetch("Create App Store Connect API key")
  %w[APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_PRIVATE_KEY].each do |name|
    raise "#{name} must be step-scoped" unless key_step.fetch("env").key?(name)
    raise "#{name} must not be job-scoped" if submit.fetch("env", {}).key?(name)
  end
  cleanup = steps.fetch("Clean up App Store Connect key")
  raise "cleanup must always run" unless cleanup.fetch("if") == "always()"
  commands = steps.values.filter_map { |step| step["run"] }.join("\n")
  raise "direct workflow must not upload an IPA" if commands.include?("pilot upload")
  raise "direct workflow must use manual release" unless commands.include?("--automatic_release false")
' "$workflow"

if compgen -G "$repo_root/.github/workflows/release-app-store.yml" >/dev/null; then
  printf 'unexpected automatic Release App Store workflow\n' >&2
  exit 1
fi

printf 'Direct App Store review workflow tests passed\n'
