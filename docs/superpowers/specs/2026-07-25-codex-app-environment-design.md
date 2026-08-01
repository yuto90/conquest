# Codex App Environment Design

## Goal

Conquest の Codex App 管理 worktree を、リポジトリに固定された Flutter SDK と依存関係を使える状態へ自動セットアップする。

## Scope

次の4ファイルを追加する。

- `.codex/environments/default.toml`
- `.agent-shared/scripts/codex-worktree-setup.sh`
- `.agent-shared/scripts/codex-worktree-cleanup.sh`
- `.agent-shared/scripts/codex-worktree-cleanup.test.sh`

既存のアプリコード、依存関係、FVM 設定は変更しない。

## Environment Entry Point

`default.toml` は環境名を `Conquest` とし、setup と cleanup の各スクリプトを登録する。

Conquest には Makefile、Docker Compose、Supabase の構成がないため、`up`、`down` などの action は定義しない。

## Setup

setup スクリプトは以下を順に行う。

1. Git のトップレベルをリポジトリルートとして取得する。
2. `pubspec.yaml` がなければ、対象外の worktree として正常終了する。
3. `fvm` が利用できることを確認する。利用できなければ、必要な対応を示して失敗する。
4. FVM が管理する Flutter バージョンをログへ出力する。
5. `fvm flutter pub get` で依存関係を取得する。
6. `pubspec.yaml` に `build_runner` がある場合、`fvm dart run build_runner build --delete-conflicting-outputs` を実行する。

セットアップ処理では、開発サーバーやシミュレーターを起動しない。

## Cleanup

Conquest は worktree 外部に永続する Docker Compose や Supabase のローカル資源を作成しない。そのため cleanup スクリプトは、Codex が後続処理で worktree ディレクトリを削除することをログへ出力し、正常終了する。

cleanup スクリプト自身は、ファイル削除、Docker 操作、Supabase 操作などの破壊的処理を行わない。

## Validation

cleanup テストは一時 Git リポジトリ内でスクリプトを実行し、次を検証する。

- 正常終了する。
- worktree 内に用意した既存ファイルを削除しない。
- cleanup の完了ログを出力する。

実装後は次も確認する。

- Shell の構文検査が成功する。
- cleanup テストが成功する。
- `default.toml` が想定した setup/cleanup スクリプトを参照している。
- setup スクリプトが現在の FVM 2.8.1 構成で依存取得とコード生成を完了する。

## Safety

既存の未コミット変更には触れない。設計書、環境定義、環境スクリプト、テストだけを変更対象とする。
