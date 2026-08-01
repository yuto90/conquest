# Flutter 3.44 Upgrade Design

## Goal

Conquest を公式最新 stable の Flutter 3.44.8 / Dart 3.12.2 へ更新し、Android、iOS、Web の3環境でビルドできる状態にする。

## Current State

- FVM は Flutter 2.8.1 / Dart 2.15.1 を固定している。
- `pubspec.yaml` には Dart `>=2.12.0 <3.0.0` が指定されている。
- 未コミットで追加された Riverpod、hooks、codegen 依存は現在の SDK と互換性がない。
- Android は Gradle 6.7、Android Gradle Plugin 4.1.0、Kotlin 1.5.31 と imperative plugin apply を使用している。
- Android の最低 API は16、iOS deployment target は9.0である。
- widget test は削除済みのFlutter標準カウンター画面を期待しており、現在のConquest画面と一致しない。

## Scope

### Included

- FVM のプロジェクト固定バージョンを Flutter 3.44.8 へ更新する。
- Dart SDK 制約を Dart 3.12系へ更新する。
- Provider を維持し、Riverpod、hooks、codegen を含む依存をFlutter 3.44.8で解決可能な最新版へ更新する。
- `pubspec.lock` をFlutter 3.44.8で再生成する。
- Android、iOS、Web のプロジェクト構成を最新テンプレート準拠へ更新する。
- Flutter 3.44.8 / Dart 3.12.2でのコンパイルに必要な範囲だけDartコードを修正する。
- widget test をConquestの実画面に合わせて更新する。
- Android、iOS、Web のビルドを検証する。

### Excluded

- Provider / ChangeNotifier からRiverpodへの状態管理実装の移行。
- ゲームルール、画面構成、操作仕様の変更。
- SDK更新と無関係なリファクタリング。
- アプリID、Bundle Identifier、アイコン、画像資産の変更。

Riverpodへの状態管理移行はFlutterアップグレード完了後の別GitHub issueとして扱う。

## Upgrade Strategy

Flutter 3.44.8で参照用の新規プロジェクトを一時ディレクトリへ生成する。参照プロジェクトとConquestのAndroid、iOS、Web構成を比較し、必要なインフラ差分だけを選択して反映する。

`flutter create .` による一括上書きは行わない。既存の識別子、アイコン、Manifest設定、Xcode設定を保持しやすくし、意図しない変更を避けるためである。

## SDK and Dependencies

- Flutter はFVMで正確に `3.44.8` を固定する。
- Dart SDK 制約は `>=3.12.0 <4.0.0` とする。
- 依存パッケージは、Flutter 3.44.8のpub solverで同時解決できる最新版を採用する。
- 絶対最新版同士が競合する場合、解決可能な最新組み合わせを明示的に固定し、採用理由を記録する。
- 現在のアプリが使用する `provider` は残す。
- `flutter_riverpod`、`riverpod_annotation`、`riverpod_generator`、`flutter_hooks`、`build_runner` は残すが、今回のアプリコードでは使用を開始しない。
- build_runnerはCodex setupと手動検証の双方で実行する。

## Platform Migration

### Android

- 最新テンプレートのPlugin DSL構成へ移行する。
- 最新テンプレートに合わせてGradle wrapper、Android Gradle Plugin、Kotlin関連設定を更新する。
- `applicationId` とnamespaceは `com.conquest.conquest` を保持する。
- 最低OSはAndroid API 24とする。
- 最新テンプレートが管理するcompile SDKとtarget SDKの仕組みを採用する。
- 既存のアプリアイコンとAndroid Manifestのアプリ固有設定を保持する。

### iOS

- deployment targetをiOS 13へ更新する。
- Flutter 3.44.8の最新テンプレートとの差分を、Xcode project、workspace、Flutter設定へ選択適用する。
- Bundle Identifier `com.conquest.conquest`、アイコン、Launch Screenを保持する。
- Simulator向けにcodesignなしでビルドできることを確認する。

### Web

- 最新テンプレートに合わせてbootstrapとHTML構成を更新する。
- アプリ名、favicon、manifest、既存アイコンを保持する。

## Application Compatibility

Dartコードの変更は、削除・変更されたFlutter APIへの対応と静的解析エラーの解消に限定する。状態管理はProvider / ChangeNotifierのままとし、既存の拠点生成、ゲーム開始、移動、戦力更新の動作を変更しない。

古いカウンター用widget testは、Conquestの初期画面とゲーム開始操作を確認するsmoke testへ置き換える。ランダムな拠点座標やTimerの時間経過に依存しない安定した期待値を使用する。

## Error Handling

移行時の問題は次の境界に分けて調査する。

1. Flutter / Dart SDKの取得とFVM固定
2. pub依存解決
3. build_runnerコード生成
4. Dartコンパイルと静的解析
5. Android、iOS、Web固有のビルド
6. widget testと実行時smoke test

ある境界の修正に、別境界の無関係な変更を混ぜない。プラットフォームテンプレートの適用前後で識別子と資産を比較し、保持対象が変化していないことを確認する。

## Validation

以下を完了条件とする。

- `fvm flutter --version` が Flutter 3.44.8 / Dart 3.12.2を表示する。
- `fvm flutter pub get` が成功する。
- `fvm dart run build_runner build --delete-conflicting-outputs` が成功する。
- `fvm dart format --output=none --set-exit-if-changed .` が成功する。
- `fvm flutter analyze` がエラーなしで成功する。
- `fvm flutter test` が成功する。
- Android debug APKがビルドできる。
- iOS Simulator向けビルドがcodesignなしで成功する。
- Web release buildが成功する。
- Android API 24、iOS 13が最低バージョンとして設定されている。
- Android application IDとiOS Bundle Identifierが `com.conquest.conquest` のままである。
- 既存アイコンとWeb資産が保持されている。
- Codex setupスクリプトが依存取得とbuild_runnerを完走する。

## Safety

- 既存の未コミット `lib/main.dart` のアプリ名変更を保持する。
- `pubspec.yaml` と `pubspec.lock` の未コミット変更は、承認されたSDK・依存更新として統合する。
- 参照用プロジェクトは一時ディレクトリに生成し、リポジトリへそのままコピーしない。
- 変更はFlutterアップグレードに必要なファイルへ限定し、各段階で差分を確認する。
