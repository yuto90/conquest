# Conquest 海図タクティカル UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open Design の `Conquest 海図タクティカル UI` を、既存のゲームルールと操作性を維持した Flutter UI として 390×844 に忠実に再現する。

**Architecture:** Riverpod の状態管理とゲームエンジンは変更せず、表示責務をテーマ、海図背景、島、移動部隊、画面状態オーバーレイへ分割する。既存のキー、コールバック、Semantics、SafeArea、リサイズ時の Provider 再生成契約を保ちながら、Open Design の色・寸法・日本語コピーへ置き換える。

**Tech Stack:** Flutter 3.44.8、Dart 3.12、Riverpod、CustomPainter、flutter_test

## Global Constraints

- Open Design のゲーム画面は 390×844、端末フレーム・OSクロームなし。
- プレイヤー本陣は右下、CPU本陣は左上。緑・赤・グレーの陣営色を維持する。
- 島数 6/8/10/12、CPU難易度 Easy/Normal/Hard、出兵、カウントダウン、一時停止、再戦、設定復帰の既存挙動を変えない。
- 既存の ValueKey と英語 Semantics 契約は回帰テストのため維持する。
- 既存の `lib/game/game_controller.g.dart` の未コミット差分へ触れない。
- 外部画像・新規依存・バックエンド・永続化を追加しない。

---

### Task 1: 表示契約をテストで固定する

**Files:**
- Create: `test/tactical_ui_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `MyApp`, `Home`, `gameControllerProvider`, `ManualWidgetGameLoop` 相当の手動ループ。
- Produces: 設定、プレイ、カウントダウン、一時停止、結果画面の日本語コピーと主要レイアウトキーを検証する失敗テスト。

- [x] 390×844 で設定画面の `対戦設定 / 01`、`対戦設定`、4島数、3難易度、`ゲーム開始` を検証するテストを書く。
- [x] 開始直後の `3`、`出撃準備` と、開始後の `CONQUEST`、`戦術海図 / 10島`、`pause-game` を検証するテストを書く。
- [x] 一時停止の `対戦を一時停止`、`一時停止`、`再開`、`設定へ戻る` を検証するテストを書く。
- [x] 勝利・敗北・引き分けを個別に注入し、日本語結果コピーと操作キーを検証するテストを書く。
- [x] `fvm flutter test test/tactical_ui_test.dart` を実行し、旧UIとの差分で失敗することを確認する。

### Task 2: テーマと海図背景を実装する

**Files:**
- Create: `lib/ui/tactical_theme.dart`
- Create: `lib/ui/tactical_map_background.dart`
- Modify: `lib/main.dart`
- Modify: `lib/home.dart`

**Interfaces:**
- Produces: `TacticalPalette` と `TacticalMapBackground`。盤面は薄い座標グリッドと等深線を描画し、各状態の共通背景として使う。

- [ ] Open Design の OKLch トークンを sRGB 値へ固定し、ThemeData と共通 TextStyle を定義する。
- [ ] CustomPainter で縦5本・横7本のグリッドと上下の等深線を描く。
- [ ] Scaffold/SafeArea 内の盤面背景を海図色へ変更し、390×844 と狭幅の双方でオーバーフローさせない。
- [ ] Task 1 の該当テストを通す。

### Task 3: 島と移動部隊をフラットベクター化する

**Files:**
- Modify: `lib/base.dart`
- Modify: `lib/moving_force.dart`

**Interfaces:**
- `Base` は既存 constructor と Semantics を維持し、島・浅瀬・施設・数値・選択二重リング・移動先ブラケットを描画する。
- `MovingForceWidget` は既存 constructor と Semantics を維持し、進行角へ回転する上面視飛行機と正立した兵力バッジを描画する。

- [ ] 島の海岸線5種を `CustomPainter` で描き、陣営別施設と数値を重ねる。
- [ ] 選択中は硬質な二重リングと `出兵元`、移動候補は四隅ブラケットを表示する。
- [ ] 部隊の `deltaX/deltaY` から進行角を求め、飛行機だけを回転し数値は正立させる。
- [ ] 既存サイズ、キー、タップ領域、Semantics テストを通す。

### Task 4: 設定・HUD・オーバーレイを再現する

**Files:**
- Modify: `lib/home.dart`

**Interfaces:**
- 設定は既存 controller の `selectIslandCount`, `selectCpuDifficulty`, `startGame` を呼ぶ。
- HUD とオーバーレイは `GamePhase` と `GameResultType` のみを表示条件にする。

- [ ] 設定画面を中央寄せの日本語フォーム、矩形選択タイル、濃色主ボタンへ変更する。
- [ ] プレイHUDへワードマーク、島数、円形一時停止、下部操作説明を追加する。
- [ ] カウントダウンを直径174の二重円と大数字、`出撃準備` で表示する。
- [ ] 一時停止と3結果を 248px シート、矩形ボタン、日本語コピーで表示する。
- [ ] エラー/操作フィードバックを海図配色へ合わせる。
- [ ] Task 1 と既存 widget/integration 単体テストを通す。

### Task 5: 視覚比較と完了検証を行う

**Files:**
- Create: `design-qa.md`
- Create: `design-qa-assets/implementation-*.png`

**Interfaces:**
- Source truth: `design-qa-assets/reference-*.png`（390×844, 1x）。
- Implementation: Flutter Web の同一 390×844 状態キャプチャ。

- [x] `fvm dart format --output=none --set-exit-if-changed lib test`、`fvm flutter analyze`、`fvm flutter test` を実行する。
- [x] Flutter Web を起動し、Chrome で設定・カウントダウン・プレイ・一時停止を同一サイズで撮影する。
- [x] 参照画像と実装画像を同じ比較入力で確認し、P0/P1/P2 を修正して再撮影する。
- [x] フォント、余白、色、島/部隊の画質、コピーを明示評価し、`design-qa.md` の `final result: passed` を満たす。
- [x] `git diff --check` と `git status --short` で対象外差分がないことを確認する。
