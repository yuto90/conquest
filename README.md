# conquest

A new Flutter project.

## Documentation

- [ゲームルール](docs/game-rules.md)

## Web

ブラウザ向けの Flutter Web 版は、既存の縦向きスマホ UI を中央配置して公開する。横長画面では 390:844 の盤面を中央に置き、余白は海図色にする。

```bash
fvm flutter run -d chrome
fvm flutter build web --release
```

Vercel への公開は GitHub Actions の `Deploy Web` が `build/web` をデプロイする。初回は Vercel プロジェクトを作り、GitHub Secrets `VERCEL_TOKEN`、`VERCEL_ORG_ID`、`VERCEL_PROJECT_ID` を登録する。Vercel Git の自動ビルドは無効化する。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# conquest
