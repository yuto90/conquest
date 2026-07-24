# Codex App Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conquest の Codex App 管理 worktree を、FVM 2.8.1 とプロジェクト依存関係を利用できる状態へ自動セットアップする。

**Architecture:** `.codex/environments/default.toml` を Codex App の入口とし、`.agent-shared/scripts/` の setup/cleanup スクリプトへ処理を委譲する。setup は FVM による依存取得と build_runner のコード生成だけを行い、cleanup は外部資源を持たない現在の構成に合わせて非破壊的に正常終了する。

**Tech Stack:** TOML、Bash、FVM、Flutter 2.8.1、Dart build_runner

## Global Constraints

- 追加対象は `.codex/environments/default.toml`、setup、cleanup、cleanup テストの4ファイルとする。
- 既存のアプリコード、依存関係、FVM 設定は変更しない。
- setup は開発サーバーやシミュレーターを起動しない。
- cleanup はファイル削除、Docker 操作、Supabase 操作を行わない。
- 既存の未コミット変更をステージまたはコミットしない。

---

### Task 1: 非破壊的な worktree cleanup

**Files:**
- Create: `.agent-shared/scripts/codex-worktree-cleanup.test.sh`
- Create: `.agent-shared/scripts/codex-worktree-cleanup.sh`

**Interfaces:**
- Consumes: 現在の Git worktree。Git リポジトリでない場合は現在のディレクトリを利用する。
- Produces: 引数なしで実行でき、worktree を変更せず終了コード `0` を返す `codex-worktree-cleanup.sh`。

- [ ] **Step 1: cleanup の失敗テストを書く**

`.agent-shared/scripts/codex-worktree-cleanup.test.sh` を次の内容で作成する。

```bash
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
```

- [ ] **Step 2: テストが意図した理由で失敗することを確認する**

Run:

```bash
bash .agent-shared/scripts/codex-worktree-cleanup.test.sh
```

Expected: FAIL。`codex-worktree-cleanup.sh` が存在しないため `cp` が失敗する。

- [ ] **Step 3: cleanup の最小実装を書く**

`.agent-shared/scripts/codex-worktree-cleanup.sh` を次の内容で作成する。

```bash
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
```

両方のスクリプトへ実行権限を付与する。

```bash
chmod +x \
  .agent-shared/scripts/codex-worktree-cleanup.sh \
  .agent-shared/scripts/codex-worktree-cleanup.test.sh
```

- [ ] **Step 4: cleanup の構文検査とテストを実行する**

Run:

```bash
bash -n .agent-shared/scripts/codex-worktree-cleanup.sh
bash -n .agent-shared/scripts/codex-worktree-cleanup.test.sh
bash .agent-shared/scripts/codex-worktree-cleanup.test.sh
```

Expected: すべて終了コード `0`。最後に `codex-worktree-cleanup tests passed` と表示される。

- [ ] **Step 5: cleanup をコミットする**

```bash
git add -- \
  .agent-shared/scripts/codex-worktree-cleanup.sh \
  .agent-shared/scripts/codex-worktree-cleanup.test.sh
git commit -m "chore: Codex worktree cleanupを追加"
```

---

### Task 2: Flutter worktree setup と Codex 環境定義

**Files:**
- Create: `.agent-shared/scripts/codex-worktree-setup.sh`
- Create: `.codex/environments/default.toml`
- Test: `.agent-shared/scripts/codex-worktree-cleanup.test.sh`

**Interfaces:**
- Consumes: リポジトリ直下の `pubspec.yaml`、`.fvm/fvm_config.json`、PATH 上の `fvm`。
- Produces: 引数なしで依存取得と必要なコード生成を行う `codex-worktree-setup.sh`。Codex App が setup/cleanup を呼び出す `default.toml`。

- [ ] **Step 1: setup スクリプトを書く**

`.agent-shared/scripts/codex-worktree-setup.sh` を次の内容で作成する。

```bash
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

if has_build_runner; then
  log "build_runner で生成ファイルを更新します。"
  fvm dart run build_runner build --delete-conflicting-outputs
else
  log "build_runner がないため、コード生成をスキップします。"
fi

log "セットアップが完了しました。"
```

実行権限を付与する。

```bash
chmod +x .agent-shared/scripts/codex-worktree-setup.sh
```

- [ ] **Step 2: Codex App の環境定義を書く**

`.codex/environments/default.toml` を次の内容で作成する。

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "Conquest"

[setup]
script = "bash .agent-shared/scripts/codex-worktree-setup.sh"

[cleanup]
script = "bash .agent-shared/scripts/codex-worktree-cleanup.sh"
```

- [ ] **Step 3: 静的検証を実行する**

Run:

```bash
bash -n .agent-shared/scripts/codex-worktree-setup.sh
grep -F 'script = "bash .agent-shared/scripts/codex-worktree-setup.sh"' .codex/environments/default.toml
grep -F 'script = "bash .agent-shared/scripts/codex-worktree-cleanup.sh"' .codex/environments/default.toml
test -x .agent-shared/scripts/codex-worktree-setup.sh
test -x .agent-shared/scripts/codex-worktree-cleanup.sh
```

Expected: すべて終了コード `0`。`grep` は setup と cleanup の参照行を各1行出力する。

- [ ] **Step 4: setup を実環境で検証する**

Run:

```bash
bash .agent-shared/scripts/codex-worktree-setup.sh
```

Expected:

- FVM が Flutter 2.8.1 を選択する。
- `fvm flutter pub get` が成功する。
- build_runner が終了コード `0` で完了する。
- 最後に `[codex-worktree-setup] セットアップが完了しました。` と表示される。

setup により生成ファイルまたは lockfile に差分が生じた場合は、今回の環境定義コミットへ含めず、既存のユーザー変更として保持する。

- [ ] **Step 5: 全検証を再実行する**

Run:

```bash
bash -n .agent-shared/scripts/codex-worktree-setup.sh
bash -n .agent-shared/scripts/codex-worktree-cleanup.sh
bash -n .agent-shared/scripts/codex-worktree-cleanup.test.sh
bash .agent-shared/scripts/codex-worktree-cleanup.test.sh
git diff --check -- \
  .codex/environments/default.toml \
  .agent-shared/scripts/codex-worktree-setup.sh \
  .agent-shared/scripts/codex-worktree-cleanup.sh \
  .agent-shared/scripts/codex-worktree-cleanup.test.sh
```

Expected: すべて終了コード `0`。

- [ ] **Step 6: setup と環境定義をコミットする**

```bash
git add -- \
  .codex/environments/default.toml \
  .agent-shared/scripts/codex-worktree-setup.sh
git commit -m "chore: Codex App環境を追加"
```

- [ ] **Step 7: コミット範囲を確認する**

Run:

```bash
git status --short
git show --stat --oneline HEAD
git show --stat --oneline HEAD^
```

Expected:

- `lib/main.dart`、`pubspec.yaml`、`pubspec.lock` の既存変更は未コミットのまま残る。
- 直近2コミットには、計画で追加した Codex 環境関連4ファイルだけが含まれる。
