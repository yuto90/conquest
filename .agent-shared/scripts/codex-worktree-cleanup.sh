#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[codex-worktree-cleanup] %s\n' "$*"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

cd "$repo_root"

log "Repository: $repo_root"
log "Codex がこの後 worktree ディレクトリ全体を削除します。"
log "worktree 内の .dart_tool やビルド成果物は、ディレクトリ削除に含まれます。"
log "クリーンアップ前処理が完了しました。"
