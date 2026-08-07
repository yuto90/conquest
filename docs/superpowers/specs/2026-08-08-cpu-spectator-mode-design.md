# CPU対CPU観戦モード設計

## 位置づけ

- 対象Issue: [#32](https://github.com/yuto90/conquest/issues/32)
- 依存Issue: [#31](https://github.com/yuto90/conquest/issues/31)（PR #33で実装済み）
- 調査基準: `origin/main` の `3d2be0a7d19c83cb2f4e5f66de8b44cfc83a5927`
- 状態: 2026-08-08承認済み設計

本書はCPU対CPU観戦モードの実装境界を定義する。実装時はIssue #32、本書、`docs/game-rules.md`を仕様の正本とし、矛盾がある場合はIssue #32の明示要件を優先する。

## 目的

既存の1P対2P CPU戦を維持しながら、1P・2Pの両陣営をCPUが操作する観戦モードを追加する。観戦モードでは両CPUの難易度を個別設定でき、処理順による有利・不利のない決定論的な試合を、開始から結果まで操作せず観戦できるようにする。

## 現状

- `GameConfiguration`は島数と2P CPUの`cpuDifficulty`を保持する。
- `CpuStrategy`は`Faction.cpu`を自軍、`Faction.player`を敵軍としてハードコードしている。
- `GameController`は1つの`CpuStrategy`と1つのゲーム内絶対判断期限を管理する。
- CPU判断はルールtickの後に実行し、次回期限を現在のゲーム内時間から設定する。
- 一時停止と再開ではCPU判断期限を維持し、結果・途中終了・再戦では破棄する。
- 設定変更は`GameConfiguration`を正本とし、難易度変更では表示中マップを再生成しない。
- 盤面は`Faction.player`を`P / Player`、`Faction.cpu`を`C / CPU`として表示する。
- 島操作は`GamePhase.playing`で有効になり、`GameController.tapBase`は1P島から出兵する。

## スコープ

### 対象

- 通常CPU戦とCPU対CPU観戦モードの選択
- 1P CPUと2P CPUの個別難易度設定
- 既存CPU戦略の操作陣営に依存しない形への汎用化
- 両CPUの独立した乱数とゲーム内絶対判断期限
- 同時刻CPU判断の公平なスナップショット処理
- 観戦中のプレイヤー操作無効化
- 観戦モードだけに適用する1P・2P表示
- 一時停止、バックグラウンド停止、再開、途中終了、結果、再戦、設定復帰
- ゲームルールと統合QA文書の更新
- unit、controller integration、widget、統合QAテスト

### 対象外

- 観戦速度変更と早送り
- 観戦者による途中介入や出兵
- 試合履歴、戦績、リプレイの保存
- 大会、リーグ、複数試合の連続実行
- CPUアルゴリズムの自作や切り替え
- Issue #31の範囲を超える難易度別アルゴリズム
- 同一端末2人対戦とオンライン対戦
- `Faction.player` / `Faction.cpu`の全面的な名称変更
- `GameRules`の増加、移動、戦闘、勝敗アルゴリズム変更

## 採用アプローチ

既存モデルを最小拡張し、`Faction.player`と`Faction.cpu`を内部的な陣営IDとして維持する。`CpuStrategy`へ操作陣営を注入し、`GameController`がモードに応じて1つまたは2つの戦略を実行する。

次の案は採用しない。

- CPU参加者を汎用リストとして`GameState`へ追加する案: 2陣営固定の現状には過剰で、ルール状態と実行時スケジューラの責務が混ざる。
- `Faction`を1P / 2Pへ全面変更する案: ルール・描画・テストの変更量が大きく、観戦モードの実現に必要ない。
- 1P用CPU戦略を複製する案: 攻撃・防衛ロジックが将来乖離する。
- 盤面を反転して既存2P CPUへ渡す案: 島、移動部隊、勝敗、予測の相互変換が複雑になる。

## データモデル

### GameMode

`lib/game/game_state.dart`に次のenumを追加する。

```dart
enum GameMode { playerVsCpu, cpuVsCpu }
```

- `playerVsCpu`: 1Pを人間、2PをCPUが操作する既存モード。
- `cpuVsCpu`: 1P・2Pの両方をCPUが操作する観戦モード。

### GameConfiguration

`GameConfiguration`を次の設定の正本とする。

- `totalIslandCount`
- `gameMode`
- `cpuDifficulty`: 既存フィールドを2P CPU難易度として維持する。
- `playerCpuDifficulty`: 1P CPU難易度として追加する。

初期値は次のとおりとする。

- `gameMode`: `GameMode.playerVsCpu`
- `cpuDifficulty`: `CpuDifficulty.normal`
- `playerCpuDifficulty`: `CpuDifficulty.normal`

factory、`initial`、`copyWith`、等価比較、`hashCode`へ全フィールドを含める。既存の`cpuDifficulty`という名前と既定値を維持し、通常CPU戦と既存テストの意味を変えない。

モードを切り替えても非表示側の難易度を破棄しない。通常モードへ戻ったときは`playerCpuDifficulty`を非表示にするだけとし、再び観戦モードを選択した場合は以前の1P難易度を復元する。

CPU判断期限は`GameState`や`GameConfiguration`へ保存しない。既存どおり`GameController`の実行時状態として保持し、ルールエンジンのimmutable stateとスケジューラの責務を分離する。

## CPU戦略

### 操作陣営

`CpuStrategy`へ`controlledFaction`を追加する。既定値は`Faction.cpu`とし、既存の生成コードとテストを互換に保つ。

`controlledFaction`に指定できるのは`Faction.player`または`Faction.cpu`だけとする。敵陣営は次の対応から導出する。

| 操作陣営 | 敵陣営 |
| --- | --- |
| `Faction.player` | `Faction.cpu` |
| `Faction.cpu` | `Faction.player` |

`Faction.neutral`を操作陣営として構築した場合は引数エラーとする。

既存の以下の処理から`Faction.cpu` / `Faction.player`の固定判定を除去する。

- 防衛対象となる敵移動部隊と自軍島の検出
- 出兵可能な自軍島の検出
- 敵島と中立島の候補生成
- 到着予測後の所有陣営判定
- 既存部隊だけで占領済みになる対象の除外
- 候補部隊と確定部隊の陣営
- stale decision適用時の出兵元所有権検証

攻撃、防衛、距離、島IDによる同率解決、到着予測、1判断1部隊という既存アルゴリズムは変更しない。`CpuDecision`は既存どおり出兵元、移動先、兵力を持ち、判断を作成した`CpuStrategy`が自身の操作陣営として適用する。

### Provider

既存の`cpuStrategyProvider`を2P CPU用として維持する。1P CPU用に`playerCpuRandomProvider`と`playerCpuStrategyProvider`を追加する。

- 2P strategy providerは既存の`randomProvider`と`controlledFaction: Faction.cpu`を使用し、現在の注入経路を維持する。
- 1P random providerはviewportに依存しない1つの`Random`を提供し、strategy再構築後も同じ乱数列を継続する。
- 1P strategy providerは`playerCpuRandomProvider`と`controlledFaction: Faction.player`を使用する。
- 両providerは同じ`GameRules`と現在のviewportを使用する。
- 両providerは異なる乱数インスタンスを使用し、判断間隔の乱数列を共有しない。
- テストでは両providerを個別にoverrideできる。
- `CpuStrategy.noop`も操作陣営を指定でき、既定値は2Pとする。

## GameController

### 実行時状態

Controllerは次の実行時状態を保持する。

- 陣営別`CpuStrategy`
- `Map<Faction, int>`形式の次回判断期限
- 既存の`GameLoop`、`GameClock`、`GameRules`、map生成用乱数、初期状態キャッシュ

有効なCPU陣営は設定から導出する。

| モード | 有効CPU陣営 |
| --- | --- |
| `playerVsCpu` | `Faction.cpu` |
| `cpuVsCpu` | `Faction.player`, `Faction.cpu` |

strategy参照はviewport依存のprovider再構築時に更新する。判断期限mapは`build`で初期化し直さず、進行中の絶対期限を保持する。

### 設定操作

次のController APIを追加する。

- `selectGameMode(GameMode mode)`
- `selectPlayerCpuDifficulty(CpuDifficulty difficulty)`

両APIは設定フェーズだけで有効とし、既存の`selectCpuDifficulty`と同様に`GameConfiguration`と初期状態キャッシュを同時更新する。モード・難易度変更では表示中マップを再生成しない。島数変更だけは既存どおり新しい設定の初期状態を生成する。

`tapBase`は`GamePhase.playing`に加えて`GameMode.playerVsCpu`を要求する。観戦モードから直接呼び出された場合も状態を変更しない。

### 判断期限

開始カウントダウンが`playing`へ遷移したとき、有効な各CPUへ初回期限を設定する。期限は次の式で求める。

```text
state.elapsedMs + strategy.nextDecisionDelayMs(その陣営の難易度)
```

期限到来後は、判断結果がnullまたは適用不能でも、現在のゲーム内時間から次回期限を設定する。過去の期限に追いつくための連続判断は行わない。

難易度の対応は次のとおりとする。

- 1P CPU: `playerCpuDifficulty`
- 2P CPU: `cpuDifficulty`

### 同時判断

1回のルールtick後に期限を迎えたCPU陣営を列挙する。両CPUが同じtickで期限を迎えた場合は、次の順序を必須とする。

1. ルールtick後の`GameState`を判断用スナップショットとして固定する。
2. 期限を迎えた全CPUの`decide`を同じスナップショットへ実行する。
3. 判断結果を`Faction.player`、`Faction.cpu`の安定順で適用する。
4. 各適用時点の次の連番を移動部隊IDとして渡す。
5. 各CPUの次回期限を現在のゲーム内時間から設定する。

一方の出兵で同tick内に追加された移動部隊を、もう一方の`decide`へ見せない。判断適用時は出兵元の所有権と最新兵力を再検証する。両陣営は異なる出兵元を使用するため通常は両判断を適用できるが、適用不能な判断があっても他方の判断と両方の次回スケジュールを妨げない。

### ライフサイクル

- 開始カウントダウン: CPU判断を行わず、`playing`遷移時に初回期限を作る。
- 一時停止: GameLoopを停止し、全CPUの絶対期限を保持する。
- 再開カウントダウン: ゲーム内時間を進めず、既存期限を保持する。
- 結果: GameLoopを停止し、全CPU期限を破棄する。
- 途中終了: 全CPU期限を破棄し、同じ設定で新しい設定状態を生成する。
- 再戦: 全CPU期限を破棄し、同じ島数・モード・両難易度で新しいマップと開始カウントダウンを生成する。
- viewport再構築: `GameState`、設定、GameLoop、全CPU期限を保持し、戦略のviewport参照だけを更新する。

## UI

### 設定パネル

既存のChoiceChip、見出し、Semanticsパターンを使用する。表示順は次のとおりとする。

1. 島数
2. ゲームモード
3. CPU難易度
4. 開始ボタン

ゲームモードは次の2択とする。

- `PLAY VS CPU`
- `WATCH CPU VS CPU`

通常CPU戦では既存の2P CPU難易度行だけを表示し、見出しとSemanticsは既存の`CPU difficulty`を維持する。

観戦モードでは次の2行を表示する。

- `1P CPU difficulty`
- `2P CPU difficulty`

開始ボタンのSemanticsへ島数、ゲームモード、有効な難易度を含める。設定パネルは必要時に縦スクロールできる構成とし、280 x 500のSafe Area内で全設定と開始ボタンへ到達可能にする。

### 陣営表示

`Faction`の文字列表現をdomain modelへ追加しない。表示専用の小さな`FactionPresentation`を追加し、`Base`と`MovingForceWidget`で共有する。

| モード | `Faction.player` | `Faction.cpu` | `Faction.neutral` |
| --- | --- | --- | --- |
| 通常CPU戦 | `P` / `Player` | `C` / `CPU` | `N` / `Neutral` |
| 観戦モード | `1P` / `1P` | `2P` / `2P` | `N` / `Neutral` |

表の各値は`marker / semantic name`を示す。既存の色、輪郭、島形状、移動部隊形状は変更しない。1P・2P表記は観戦モードだけに適用し、通常CPU戦の表示を回帰させない。

### 操作とSemantics

島を操作可能にする条件は次の1か所で導出し、全島へ渡す。

```text
state.phase == GamePhase.playing &&
state.configuration.gameMode == GameMode.playerVsCpu
```

観戦中も島の所属、サイズ、兵力、上限、耐久力をSemanticsで読み取れるようにする。一方、操作不能な島にはtap action、button role、操作用hintを公開しない。`Base`は子`ElevatedButton`のSemanticsを除外して外側のSemanticsへ集約し、`onPressed != null`をtap action、button role、enabled、hint、label内の操作表現に共通する唯一の根拠とする。

移動部隊は既存どおり操作不能とし、観戦モードでは1P / 2Pの陣営名を読み上げる。

### 結果

`GameResult`の型と勝敗判定は変更しない。結果パネルへ`GameConfiguration`または`GameMode`を渡し、表示だけを切り替える。

通常CPU戦:

- `Victory`
- `Defeat`
- `Draw`

観戦モード:

- winnerが`Faction.player`: `1P WIN`
- winnerが`Faction.cpu`: `2P WIN`
- draw: `DRAW`

観戦モードの勝敗表示は`GameResultType.victory / defeat`ではなく`winner`を正本とする。通常CPU戦では既存の`GameResultType`表示を維持する。

## エラー処理と不変条件

- マップ生成に失敗した場合は設定フェーズに留まり、カウントダウン、GameLoop、CPU期限を開始しない。
- `Faction.neutral`を操作する`CpuStrategy`は構築しない。
- phaseまたはモードが不正な設定操作、島操作、CPU判断は状態を変更しない。
- stale decisionは出兵元、移動先、所有権、最新兵力を再検証し、不一致なら適用しない。
- 同時判断の一部が無効でも、他方の判断と次回期限更新を継続する。
- 移動部隊IDは既存部隊の最大IDに1を加え、同tick内の各適用後に再計算して重複を防ぐ。
- 結果フェーズへ入ったtickではCPU判断を実行せず、GameLoopと全CPU期限を停止する。
- 通常CPU戦では1P CPU providerを実行しない。
- 観戦モードではUIとControllerの両方で人間の出兵を拒否する。

## 影響範囲

| ファイル | 変更内容 |
| --- | --- |
| `lib/game/game_state.dart` | `GameMode`、1P難易度、設定のcopy/equality/hash |
| `lib/game/cpu_strategy.dart` | 操作陣営、敵陣営導出、陣営非依存の判断・適用 |
| `lib/game/game_controller.dart` | 1P strategy provider、モード設定、陣営別期限、同時判断、操作防御 |
| `lib/home.dart` | モードUI、条件付き難易度、開始Semantics、操作制御、結果表示 |
| `lib/base.dart` | 注入された陣営表示、操作可能性に一致するSemantics |
| `lib/moving_force.dart` | 注入された陣営表示とSemantics |
| `lib/faction_presentation.dart` | モード別markerとsemantic nameを持つUI専用値 |
| `docs/game-rules.md` | 観戦モード、両難易度、表示、ライフサイクル |
| `docs/integration-qa.md` | 自動・端末QAの観戦モード項目 |
| `test/game_rules_test.dart` | 設定値と互換性 |
| `test/cpu_strategy_test.dart` | 両陣営の戦略と対称性 |
| `test/game_controller_test.dart` | 設定、操作防御、ライフサイクル |
| `test/cpu_controller_integration_test.dart` | 独立期限、同時判断、1判断1部隊 |
| `test/widget_test.dart` | 設定UI、表示、Semantics、結果、狭幅 |
| `test/integration_qa_test.dart` | 全島数開始、決定論的CPU対CPU試合、停止 |

`GameRules`、`GameResult`、map生成、戦闘ロジックは原則として変更しない。実装中に変更が必要と判明した場合は、Issue #32の要件に直接必要な最小変更かを再評価する。

## テスト設計

テストは既存の`ManualGameLoop`、注入可能な乱数、Controller state差し替えを使用し、実時間待機を行わない。

### データモデル

- 初期モードと両難易度が仕様どおりである。
- `copyWith`、等価比較、`hashCode`に全設定が含まれる。
- モード切り替えで非表示側の難易度を保持する。
- 既存`cpuDifficulty`が2P難易度として互換性を維持する。

### CPU戦略

- `controlledFaction`省略時は既存2P CPUとして動作する。
- 1P CPUは1P島からだけ出兵し、1P部隊を生成する。
- 防衛、攻撃、到着予測が両陣営で同じ規則に従う。
- 陣営を反転した同一盤面から対称な判断を生成する。
- 異なる陣営、古い兵力、無効な出兵元のdecisionを拒否する。
- 全難易度の判断間隔と固定乱数再現性を両陣営で維持する。

### Controller

- モード・1P難易度変更でマップを再生成しない。
- 通常モードでは2Pだけ、観戦モードでは両CPUが判断する。
- 1P Hard / 2P Easyなど異なる期限を独立処理する。
- 1回の期限到来で各CPUが最大1部隊を生成する。
- 同時判断が同じ更新前スナップショットを参照する。
- 同時判断の部隊IDが一意である。
- 観戦モードの`tapBase`がno-opになる。
- 一時停止、再開、結果、途中終了、再戦、viewport再構築で設定と期限を仕様どおり扱う。

同時判断テストには、一方の出兵を先に観測すると、もう一方が攻撃から防衛へ選択を変える盤面を使う。両CPUが事前スナップショットに対する期待判断を行うことを検証し、結果の部隊数だけで公平性を代用しない。

### Widgetとアクセシビリティ

- モードChoiceChipの初期値、選択状態、Semanticsを確認する。
- モードに応じた難易度行と開始ボタンSemanticsを確認する。
- 280 x 500でオーバーフローせず、全設定へ到達できる。
- 観戦モードの島にtap action、button role、操作hintがない。
- 通常モードの既存島操作と表示を維持する。
- 島と移動部隊のP / C表示と1P / 2P表示をモード別に確認する。
- 通常結果と観戦結果を確認する。
- 再戦と設定復帰で島数、モード、両難易度を保持する。

### 統合

- 6・8・10・12島すべてで観戦モードを開始し、両CPUが出兵する。
- 固定マップ、固定乱数、手動LoopでCPU対CPU戦を結果まで進める。
- 同じ条件を2回実行し、勝者、経過時間、tick数が一致する。
- 結果確定後にループ、兵力、部隊、CPU判断が進行しない。
- map生成失敗時に両CPUが開始されない。
- 通常CPU戦の既存統合テストを維持する。

## 検証ゲート

- 変更対象のfocused tests
- Dart format
- `fvm flutter analyze`
- `fvm flutter test`
- `git diff --check`
- Riverpod生成物へ影響がある場合のみbuild runnerを実行し、生成差分を確認する。

## 完了条件

- Issue #32の全受け入れ条件をコードまたは自動テストへ対応付けられる。
- 通常CPU戦の設定、操作、CPU判断、結果表示が回帰していない。
- 観戦モードで1P・2P CPUが個別難易度と独立期限で動作する。
- 同時判断が同じスナップショットを参照することを自動テストで証明できる。
- 観戦中の島に操作可能なSemanticsがない。
- 再戦、設定復帰、一時停止、再開、resize、結果停止が両CPUで成立する。
- 文書、format、analyze、全テスト、diff checkが成功する。
