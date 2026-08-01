#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script_under_test="$script_dir/codex-worktree-cleanup.sh"

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    printf 'Expected to find: %s\n' "$expected" >&2
    printf 'Actual log:\n' >&2
    cat "$file" >&2
    return 1
  fi
}

test_cleanup_is_non_destructive() {
  local temp_dir repo sentinel log_file
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  repo="$temp_dir/repo"
  sentinel="$repo/keep-me"
  log_file="$temp_dir/cleanup.log"

  mkdir -p "$repo/.agent-shared/scripts"
  cp "$script_under_test" "$repo/.agent-shared/scripts/codex-worktree-cleanup.sh"
  chmod +x "$repo/.agent-shared/scripts/codex-worktree-cleanup.sh"
  git -C "$repo" init -q
  repo="$(cd "$repo" && pwd -P)"
  sentinel="$repo/keep-me"
  printf 'keep\n' > "$sentinel"

  (
    cd "$repo"
    bash .agent-shared/scripts/codex-worktree-cleanup.sh >"$log_file"
  )

  test -f "$sentinel"
  assert_contains "$log_file" "Repository: $repo"
  assert_contains "$log_file" "クリーンアップ前処理が完了しました。"
}

test_cleanup_is_non_destructive

printf 'codex-worktree-cleanup tests passed\n'
