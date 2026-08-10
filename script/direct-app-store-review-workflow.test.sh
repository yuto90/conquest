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
assert_contains "$workflow" '--prepare-only'
assert_contains "$workflow" 'ruby script/app_store_release.rb preflight --prepare-only'
assert_contains "$workflow" 'build_allowed:'
assert_contains "$workflow" "needs.preflight-target.outputs.build_allowed == 'true'"
assert_contains "$workflow" 'would_create|reused'
assert_contains "$workflow" 'Unknown target preflight action'
assert_not_contains "$workflow" 'ruby script/app_store_release.rb prepare-check'
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
  outputs = target_preflight.fetch("outputs")
  raise "target preflight must expose build_allowed" unless outputs.fetch("build_allowed") == "${{ steps.target-state.outputs.build_allowed }}"
  build = jobs.fetch("build")
  raise "target preflight must run before build" unless build.fetch("needs") == "preflight-target"
  quote = 39.chr
  build_guard = "needs.preflight-target.outputs.build_allowed == #{quote}true#{quote}"
  raise "build must require an allowed target action" unless build.fetch("if").include?(build_guard)
  target_commands = target_preflight.fetch("steps").filter_map { |step| step["run"] }.join("\n")
  raise "target preflight must perform a read-only prepare check" unless target_commands.include?("--prepare-only")
  raise "target preflight must capture the action" unless target_commands.include?(".action | strings")
  raise "target preflight must allow only safe actions" unless target_commands.include?("would_create|reused")
  raise "unknown target actions must fail closed" unless target_commands.include?("Unknown target preflight action") && target_commands.include?("exit 1")
  raise "target preflight must not upload an IPA" if target_commands.include?("pilot upload")
  raise "wrong reusable workflow" unless build.fetch("uses") == "./.github/workflows/build-ios-app-store.yml"
  raise "direct review must not distribute internally" unless build.fetch("with").fetch("distribute_internal") == false
  raise "wrong direct source" unless build.fetch("with").fetch("submission_source") == "direct_review"
  submit = jobs.fetch("submit")
  raise "submit must wait for build" unless submit.fetch("needs") == "build"
  submit_guard = "needs.build.result == #{quote}success#{quote}"
  raise "submit must require a successful build" unless submit.fetch("if").include?(submit_guard)
  raise "wrong GitHub environment" unless submit.fetch("environment") == "testflight"
  quote = 39.chr
  expected_if = "${{ needs.build.result == #{quote}success#{quote} && github.ref == #{quote}refs/heads/main#{quote} }}"
  raise "direct submit must require a successful main build" unless submit.fetch("if") == expected_if
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

target_state_script="$(ruby -ryaml -e '
  workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  step = workflow.fetch("jobs").fetch("preflight-target").fetch("steps").find do |candidate|
    candidate["id"] == "target-state"
  end
  abort "target-state step is missing" unless step
  print step.fetch("run")
' "$workflow")"
[[ -n "$target_state_script" ]] || {
  printf 'target-state step must contain a run script\n' >&2
  exit 1
}

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
stub_bin="$fixture_root/bin"
mkdir -p "$stub_bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'case "$TARGET_PREFLIGHT_FIXTURE" in' \
  '  would_create) printf "%s" "{\"action\":\"would_create\"}" ;;' \
  '  reused) printf "%s" "{\"action\":\"reused\"}" ;;' \
  '  skipped) printf "%s" "{\"action\":\"skipped\"}" ;;' \
  '  unknown) printf "%s" "{\"action\":\"unexpected\"}" ;;' \
  '  non_string) printf "%s" "{\"action\":123}" ;;' \
  '  missing) printf "%s" "{}" ;;' \
  '  *) printf "unknown fixture: %s\\n" "$TARGET_PREFLIGHT_FIXTURE" >&2; exit 2 ;;' \
  'esac' > "$stub_bin/ruby"
chmod +x "$stub_bin/ruby"

run_target_state() {
  local fixture="$1"
  local expected_status="$2"
  local expected_output="$3"
  local run_dir="$fixture_root/$fixture"
  local status
  mkdir -p "$run_dir"
  : > "$run_dir/output"
  : > "$run_dir/summary"
  if TARGET_PREFLIGHT_FIXTURE="$fixture" \
    RUNNER_TEMP="$run_dir" \
    APP_BUNDLE_ID="com.example.conquest" \
    APP_VERSION="1.0.1" \
    GITHUB_OUTPUT="$run_dir/output" \
    GITHUB_STEP_SUMMARY="$run_dir/summary" \
    PATH="$stub_bin:$PATH" \
    bash -c "$target_state_script" > "$run_dir/stdout" 2> "$run_dir/stderr"; then
    status=0
  else
    status=$?
  fi
  if [[ "$expected_status" == "nonzero" ]]; then
    if [[ "$status" -eq 0 ]]; then
      printf '%s fixture unexpectedly succeeded\n' "$fixture" >&2
      cat "$run_dir/stderr" >&2
      return 1
    fi
  elif [[ "$status" -ne "$expected_status" ]]; then
    printf '%s fixture returned status %s, expected %s\n' "$fixture" "$status" "$expected_status" >&2
    cat "$run_dir/stderr" >&2
    return 1
  fi
  if [[ "$expected_status" == "0" ]]; then
    actual_output="$(<"$run_dir/output")"
    if [[ "$actual_output" != "$expected_output" ]]; then
      printf '%s fixture output was %q, expected %q\n' "$fixture" "$actual_output" "$expected_output" >&2
      return 1
    fi
  elif grep -Fq 'build_allowed=true' "$run_dir/output"; then
    printf '%s fixture must not allow a build\n' "$fixture" >&2
    return 1
  fi
}

run_target_state would_create 0 $'action=would_create\nbuild_allowed=true'
run_target_state reused 0 $'action=reused\nbuild_allowed=true'
run_target_state skipped 0 $'action=skipped\nbuild_allowed=false'
run_target_state unknown nonzero ''
run_target_state non_string nonzero ''
run_target_state missing nonzero ''

if compgen -G "$repo_root/.github/workflows/release-app-store.yml" >/dev/null; then
  printf 'unexpected automatic Release App Store workflow\n' >&2
  exit 1
fi

printf 'Direct App Store review workflow tests passed\n'
