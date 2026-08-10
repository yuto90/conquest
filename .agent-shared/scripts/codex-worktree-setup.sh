#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[codex-worktree-setup] %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_fvm() {
  if ! command_exists fvm; then
    log "fvm が見つかりません。Flutter は .fvm/fvm_config.json のバージョンを使うため、fvm をインストールしてください。"
    exit 1
  fi
}

has_build_runner() {
  grep -Eq '^[[:space:]]*build_runner:' "$repo_root/pubspec.yaml"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

cd "$repo_root"

if [ ! -f "$repo_root/pubspec.yaml" ]; then
  log "pubspec.yaml が見つからないため、Flutter セットアップをスキップします。"
  exit 0
fi

require_fvm

log "Repository: $repo_root"
log "Flutter: $(fvm flutter --version 2>/dev/null | head -n 1 || printf 'not found')"
log "開発サーバーやシミュレーターは起動しません。"

log "Flutter 依存関係を取得します。"
fvm flutter pub get

if [ -f "$repo_root/l10n.yaml" ]; then
  log "gen-l10n で翻訳ソースを更新します。"
  fvm flutter gen-l10n
fi

if has_build_runner; then
  log "build_runner で生成ファイルを更新します。"
  fvm dart run build_runner build --delete-conflicting-outputs
else
  log "build_runner がないため、コード生成をスキップします。"
fi

log "セットアップが完了しました。"
