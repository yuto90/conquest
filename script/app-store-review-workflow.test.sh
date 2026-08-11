#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/submit-app-store-review.yml"
deploy_workflow="$repo_root/.github/workflows/deploy-testflight.yml"
release_script="$repo_root/script/app_store_release.rb"

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
assert_file_exists "$deploy_workflow"
assert_file_exists "$release_script"

assert_contains "$deploy_workflow" 'workflow_dispatch:'
assert_contains "$deploy_workflow" 'commit_sha:'
assert_contains "$deploy_workflow" 'uses: ./.github/workflows/build-ios-app-store.yml'
assert_contains "$deploy_workflow" 'distribute_internal: true'
assert_contains "$deploy_workflow" 'submission_source: testflight'
assert_contains "$deploy_workflow" 'prepare-app-store-version:'
assert_contains "$deploy_workflow" 'ruby script/app_store_release.rb prepare'
assert_not_contains "$deploy_workflow" 'workflow_run:'
assert_contains "$workflow" 'name: Submit App Store Review'
assert_contains "$workflow" 'workflow_dispatch:'
assert_contains "$workflow" 'app_version:'
assert_contains "$workflow" 'build_number:'
assert_contains "$workflow" 'whats_new_ja:'
assert_contains "$workflow" 'review_notes:'
assert_contains "$workflow" 'contents: read'
assert_contains "$workflow" 'actions: read'
assert_contains "$workflow" 'environment: testflight'
assert_contains "$workflow" 'cancel-in-progress: false'
assert_contains "$workflow" 'ruby script/app_store_release.rb preflight'
assert_contains "$workflow" 'ruby script/app_store_release.rb update-metadata'
assert_contains "$workflow" 'app-store-build-provenance-$BUILD_NUMBER'
assert_contains "$workflow" 'app_version == $app_version'
assert_contains "$workflow" 'build_number == $build_number'
assert_contains "$workflow" '.submission_source == "testflight"'
assert_contains "$workflow" '.internal_distributed == true'
assert_contains "$workflow" '.event == "workflow_dispatch"'
assert_not_contains "$workflow" '.commit_sha == $head_sha'
assert_not_contains "$workflow" '--arg head_sha'
assert_contains "$workflow" '--distribution-mode internal'
assert_contains "$workflow" 'fastlane deliver submit_build'
assert_contains "$workflow" '--skip_binary_upload true'
assert_contains "$workflow" '--skip_screenshots true'
assert_contains "$workflow" '--skip_metadata true'
assert_contains "$workflow" '--automatic_release false'
assert_contains "$workflow" '--precheck_include_in_app_purchases false'
assert_contains "$workflow" '--submit_for_review true'
assert_contains "$workflow" 'GITHUB_STEP_SUMMARY'
assert_contains "$workflow" 'if: always()'
assert_contains "$workflow" 'ref: ${{ github.sha }}'
assert_not_contains "$workflow" 'flutter build ipa'
assert_not_contains "$workflow" 'pilot upload'
assert_not_contains "$workflow" '--ipa '

ruby -ryaml -e '
  workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  triggers = workflow["on"] || workflow[true]
  inputs = triggers.fetch("workflow_dispatch").fetch("inputs")
  %w[app_version build_number whats_new_ja].each do |name|
    input = inputs.fetch(name)
    raise "#{name} must be required" unless input.fetch("required") == true
    raise "#{name} must be a string" unless input.fetch("type") == "string"
  end
  notes = inputs.fetch("review_notes")
  raise "review_notes must be optional" unless notes.fetch("required") == false
  raise "review_notes must be a string" unless notes.fetch("type") == "string"
  permissions = workflow.fetch("permissions")
  raise "contents permission must be read" unless permissions.fetch("contents") == "read"
  raise "actions permission must be read" unless permissions.fetch("actions") == "read"
  concurrency = workflow.fetch("concurrency")
  raise "review submissions must not cancel" unless concurrency.fetch("cancel-in-progress") == false
  job = workflow.fetch("jobs").fetch("submit")
  quote = 39.chr
  expected_if = "${{ github.ref == #{quote}refs/heads/main#{quote} }}"
  raise "main guard must be evaluated before the job starts" unless job.fetch("if") == expected_if
  raise "wrong GitHub environment" unless job.fetch("environment") == "testflight"
  steps = job.fetch("steps").to_h { |step| [step.fetch("name"), step] }
  checkout = steps.fetch("Check out main")
  raise "submission checkout must pin the dispatch SHA" unless checkout.fetch("with").fetch("ref") == "${{ github.sha }}"
  key_step = steps.fetch("Create App Store Connect API key")
  %w[APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_PRIVATE_KEY].each do |name|
    raise "#{name} must be step-scoped" unless key_step.fetch("env").key?(name)
    raise "#{name} must not be job-scoped" if job.fetch("env", {}).key?(name)
  end
  cleanup = steps.fetch("Clean up App Store Connect key")
  raise "cleanup must always run" unless cleanup.fetch("if") == "always()"
  summary = steps.fetch("Write App Store review summary")
  raise "review summary must always run" unless summary.fetch("if") == "always()"
  commands = steps.values.filter_map { |step| step["run"] }.join("\n")
  raise "workflow must not build an IPA" if commands.include?("flutter build ipa")
  raise "workflow must not upload an IPA" if commands.include?("pilot upload")
' "$workflow"

ruby -rjson -e '
  workflow_path = ARGV.fetch(0)
  older_target = "a" * 40
  newer_dispatch_head = "b" * 40
  run = {
    "id" => 123,
    "name" => "Deploy TestFlight",
    "path" => ".github/workflows/deploy-testflight.yml",
    "event" => "workflow_dispatch",
    "head_branch" => "main",
    "conclusion" => "success",
    "head_sha" => newer_dispatch_head,
  }
  provenance = {
    "run_id" => 123,
    "repository" => "yuto90/conquest",
    "workflow_name" => "Deploy TestFlight",
    "workflow_path" => ".github/workflows/deploy-testflight.yml",
    "build_workflow_path" => ".github/workflows/build-ios-app-store.yml",
    "app_version" => "1.0.1",
    "build_number" => "123",
    "build_id" => "build-123",
    "commit_sha" => older_target,
    "submission_source" => "testflight",
    "internal_distributed" => true,
  }
  raise "fixture must represent an older target commit" unless provenance["commit_sha"] != run["head_sha"]
  source = File.read(workflow_path)
  raise "workflow must not bind provenance to dispatch head SHA" if source.include?(".commit_sha == $head_sha")
  raise "provenance fixture lost its target SHA" unless provenance["commit_sha"].match?(/\A[0-9a-f]{40}\z/)
' "$workflow"

ruby -ryaml -e '
  workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  triggers = workflow["on"] || workflow[true]
  input = triggers.fetch("workflow_dispatch").fetch("inputs").fetch("commit_sha")
  raise "commit_sha must be required" unless input.fetch("required") == true
  build = workflow.fetch("jobs").fetch("build")
  raise "wrong reusable workflow" unless build.fetch("uses") == "./.github/workflows/build-ios-app-store.yml"
  raise "TestFlight must distribute internally" unless build.fetch("with").fetch("distribute_internal") == true
  raise "wrong submission source" unless build.fetch("with").fetch("submission_source") == "testflight"
  prepare = workflow.fetch("jobs").fetch("prepare-app-store-version")
  raise "prepare must wait for build" unless prepare.fetch("needs") == "build"
' "$deploy_workflow"

printf 'App Store review workflow tests passed\n'
