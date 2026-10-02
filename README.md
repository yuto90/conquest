# conquest

Conquest は、島を占領しながら敵と戦うリアルタイム戦術ゲームです。

## Documentation

- [ゲームルール](docs/game-rules.md)

## Web

ブラウザ向けの Flutter Web 版は、既存の縦向きスマホ UI を中央配置して公開する。横長画面では 390:844 の盤面を中央に置き、余白は海図色にする。

```bash
fvm flutter run -d chrome
fvm flutter build web --release
```

Vercel への公開は GitHub Actions の `Deploy Web` が `build/web` をデプロイする。初回は Vercel プロジェクトを作り、GitHub Secrets `VERCEL_TOKEN`、`VERCEL_ORG_ID`、`VERCEL_PROJECT_ID` を登録する。Vercel Git の自動ビルドは無効化する。

正式WebとiOSのBGMは、Gitへ音源を追加せず、非公開のビルド入力から取り込む。[音源の設定手順](docs/audio-assets.md)を参照し、正式Webは`Production`、iOSは`testflight` Environmentへ取得URLとSHA-256を登録する。PRプレビューには音源を取り込まない。

## Getting Started

事前に [FVM](https://fvm.app/) をインストールし、リポジトリのルートで次のコマンドを実行してください。

```bash
fvm install
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run -d chrome
```
# conquest
