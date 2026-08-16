# 同一端末2人対戦モード設計

## 位置づけ

- 対象Issue: [#4](https://github.com/yuto90/conquest/issues/4)
- 関連Issue: [#5](https://github.com/yuto90/conquest/issues/5)（オンライン対戦。対象外）
- 依存: Issue #32 のCPU対CPU観戦モード（実装済み）
- 調査基準: `origin/main` の `2d0460f65a4a3b935be6690e77199d7bcae88ddc`
- 状態: 2026-08-16設計（実装前の決定事項）
- 実装プラン: [同一端末2人対戦モード Implementation Plan](../plans/2026-08-16-local-two-player.md)

本書は同一端末2人対戦の実装境界を定義する。実装時はIssue #4、本書、`docs/game-rules.md`を仕様の正本とし、矛盾がある場合はIssue #4の明示要件を優先する。タスク分割とred-green手順は実装プランに従う。

## 目的

既存の1P対CPU戦とCPU対CPU観戦を維持しながら、同一端末の1画面で両陣営を人が操作できるモードを追加する。兵力増加、出兵量、中立占領、相殺、全滅勝敗など既存ルールは変更しない。

## 現状

- `GameMode`は`playerVsCpu`と`cpuVsCpu`の2値である。
- `GameState.selectedIslandId`は1P専用の出兵元で、`GameRules`は所有者が`Faction.player`かつ兵力2以上のときだけ選択を維持する。
- `GameController.tapBase`は`GamePhase.playing`かつ`GameMode.playerVsCpu`のときだけ有効で、出兵部隊の陣営は常に`Faction.player`である。
- 島操作は各`Base`の`InkWell.onTap`で、ポインター識別を持たない。
- 盤面は通常CPU戦で`P / Player`と`C / CPU`、観戦モードで`1P / 1P`と`2P / 2P`を`FactionPresentation`が表示する。
- 結果表示は通常CPU戦が`Victory / Defeat / Draw`、それ以外は`winner`を正本に`1P WIN / 2P WIN / DRAW`である。
- 本陣は1Pが画面右下、2P相当（`Faction.cpu`）が画面左上。色は緑と赤のままである。
- 設定パネルは島数、ゲームモード2択、CPU難易度、開始ボタンで、280 x 500のSafe Area内に収まる。

## スコープ

### 対象

- 通常CPU戦・観戦モードに加えた同一端末2人対戦の選択と開始
- 1P（緑・右下）と2P（赤・左上）の独立した島選択と出兵
- 1画面共有、同一向き、マルチタッチ入力
- 同時入力の逐次適用と操作競合の定義
- 両プレイヤーの選択状態・出兵先候補・ドラッグ中ルートの表示
- 勝敗判定の既存ロジック維持と、1P / 2P向け結果・再戦・設定復帰
- 2人対戦中のCPU判断停止
- 一時停止、バックグラウンド停止、再開、途中終了
- ゲームルールと統合QA文書の更新
- unit、controller、widget、統合QAテスト

### 対象外

- ネットワークを介したオンライン対戦（Issue #5）
- 2P向け180度回転HUD、対面着席専用レイアウト、画面分割
- ホットシート（交互操作）やターン制
- 3人以上、チーム戦、ハンデ、陣営入れ替え
- ゲームパッド、キーボード、外部ポインターの専用割り当て
- 観戦速度、試合履歴、戦績、リプレイ保存
- `Faction.player` / `Faction.cpu`の全面的な名称変更
- `GameRules`の増加、移動、戦闘、勝敗アルゴリズム変更
- VoiceOverだけで成立する2人同時プレイ

## 採用アプローチ

既存の2陣営モデルを最小拡張する。`Faction.player`を1P、`Faction.cpu`を2Pの内部IDとして維持し、`GameMode.playerVsPlayer`を追加する。人間入力は陣営付きコマンドへ一般化し、2人対戦のポインター帰属はウィジェット層が解決する。

次の案は採用しない。

- 所有島タップだけで出兵先まで決める案: 敵島タップが「相手の出兵元選択」にも「自分の攻撃」にも読める。同一画面ではタップにプレイヤーIDがない。
- 画面の上半分を2P、下半分を1Pとする領域帰属案: 中央の中立島と相手陣営への攻撃が領域境界で不安定になる。
- 曖昧な中立タップを両軍出兵にする案: 意図しない同時出兵が多発する。
- 直近に選択したプレイヤーへすべての宛先タップを渡す案: 他方の操作を奪い、同時プレイと両立しない。
- 出兵をホールド＋もう一方の指で目標タップにする案: 1人あたり2指、同時なら最大4指になり、縦向きスマートフォンでは狭い。
- 1Pと同じ2タップ出兵を2人対戦の唯一の操作にする案: 敵島への攻撃と相手の出兵元選択を区別できない。
- 180度回転した2P HUD案: 一時停止・結果・設定・Semantics・既存海図レイアウトの変更量が、同一端末対戦の実現に必要ない。
- 参加者リストを`GameState`へ追加する案: 2陣営固定の現状には過剰である。

## 1画面の操作方式

縦向きの同一画面を共有し、向きは回転しない。

| 席 | 内部陣営 | 本陣 | 色 | 表示 |
| --- | --- | --- | --- | --- |
| 1P | `Faction.player` | 画面右下 | 緑 | `1P` |
| 2P | `Faction.cpu` | 画面左上 | 赤 | `2P` |

二人は同じ向きで画面を見る。1Pは右下本陣側、2Pは左上本陣側を主に操作する前提とし、着席位置の強制はしない。

### 2人対戦のジェスチャー

ポインター（指）の開始島が操作者を決める。1人1指で、2本まで同時に追跡する。

1. 自軍島（兵力2以上）でダウンする。その陣営の出兵元として選択する。
2. 同じ島でアップする。ダウン前から選択済みなら解除、今回選択しただけなら選択を維持する。
3. 別の島の上でアップする。選択中の自軍島から、その島へ兵力の半分を出兵する。
4. 島以外でアップする、ポインターがキャンセルされる、一時停止または結果へ入る。出兵せず、ダウン時に付けた選択は維持する。ただし解除トグルの対象だった場合はアップまで確定しない。

通常CPU戦の2タップ（自軍タップで選択、別島タップで出兵）は変更しない。2人対戦では、開始島のない単独タップを宛先出兵に使わない。これにより敵島タップは常に「その島の所有者の選択操作」か「何もしない」であり、ドラッグ開始者の攻撃と衝突しない。

中立島や敵島への攻撃は、自軍島からその島へポインターを運んでアップしたときだけ成立する。

### 通常CPU戦との対比

| 操作 | 通常CPU戦 | 2人対戦 |
| --- | --- | --- |
| 自軍島をタップ | 出兵元を選択 / 再タップで解除 | 同じ |
| 別島をタップ | 1Pが出兵 | その島が自軍ならそのプレイヤーの選択。敵・中立なら出兵しない |
| 自軍島から別島へドラッグ | 未定義（タップ扱い） | 開始島の所有者が出兵 |
| CPU | 2Pを操作 | 動作しない |

## 同時入力と競合

FlutterのポインターイベントはUIスレッドで直列化される。人間入力はCPU同時判断のようなスナップショット一括処理をせず、到着順で`GameController`へ逐次適用する。

### 適用規則

- 異なる出兵元からの出兵は、両方がその時点で合法なら両方成立する。
- 同一島を両軍が所有することはないため、同一出兵元の奪い合いは起きない。
- 同じ移動先へ両軍が出兵した場合は、既存の同時到着ルールで処理する。移動中は別部隊として共存する。
- 一方が出兵元を選択している島へ、他方がドラッグ出兵した場合、選択は維持する。その島が占領されるか兵力1以下になった時点で、既存どおり選択を無効化する。
- 同一ポインターIDは1つのジェスチャーにだけ属する。2本の指は独立したジェスチャーである。
- 一時停止ボタン、設定復帰、結果確定が先に状態を変えた場合、未完了ジェスチャーは出兵せず破棄する。
- 移動部隊IDは既存どおり、各出兵の適用直前に「現在の最大ID + 1」を採番する。

### 競合の解釈

| 状況 | 結果 |
| --- | --- |
| 両者が別の自軍島から同時にドラッグ | 到着順で2部隊を作る |
| 両者が同じ中立島へ同時にドラッグ | 2部隊を作り、到着時に既存の同時到着処理 |
| 1Pが2P島を攻撃中に2Pがその島から出兵 | 両方合法なら両方成立。2P出兵後に兵力1以下なら2P選択は解除 |
| 選択中の自軍島が敵に占領される | その陣営の選択だけ解除し、短い無効化フィードバックを出す |
| 兵力1の自軍島でダウン | 選択せず、既存の`unavailableSource`フィードバック |
| 観戦モードや非playingでのジェスチャー | 状態を変えない |

## データモデル

### GameMode

```dart
enum GameMode { playerVsCpu, playerVsPlayer, cpuVsCpu }
```

- `playerVsCpu`: 既存の1P人間対2P CPU。
- `playerVsPlayer`: 同一端末で1P・2Pとも人間。
- `cpuVsCpu`: 既存の観戦モード。

宣言順を設定UIの優先順と一致させる。既存の`cpuVsCpu`のインデックスは変わるが、試合設定は永続化していない。

`GameMode`に人間操作陣営とCPU操作陣営の導出を置き、switchを網羅的にする。

| モード | 人間 | CPU |
| --- | --- | --- |
| `playerVsCpu` | `Faction.player` | `Faction.cpu` |
| `playerVsPlayer` | `Faction.player`, `Faction.cpu` | なし |
| `cpuVsCpu` | なし | `Faction.player`, `Faction.cpu` |

### GameConfiguration

新しい難易度フィールドは追加しない。`gameMode`だけを拡張する。2人対戦へ切り替えても非表示のCPU難易度は破棄せず、通常CPU戦や観戦へ戻したときに復元する。既存の`selectGameMode`と同じく、モード変更では表示中マップを再生成しない。

### 選択状態

`GameState`の`selectedIslandId`は1P（`Faction.player`）の出兵元として維持する。2P人間用に`opponentSelectedIslandId`を追加する。

- 通常CPU戦と観戦では`opponentSelectedIslandId`は常にnullである。
- `copyWith`ではnullを設定できないため、既存の`clearSelection()`に加え、`clearOpponentSelection()`と`clearAllSelections()`を用意する。
- 等価比較と`hashCode`に`opponentSelectedIslandId`を含める。
- `selectedIslandIdFor(Faction)`のような読み取りヘルパーをdomain側に置き、UIとRulesが陣営分岐を散らさない。

`IslandState.canDispatch`は既存どおり1P用の別名として残し、陣営付き判定`canDispatchAs(Faction)`を追加する。`Faction.neutral`は常にfalseである。

### フィードバック

`InteractionFeedbackType`の種類は維持する。文言は「自軍」をプレイヤー名に固定せず、2人対戦でも使える表現にする。フィードバック枠は1つで足り、最後に失敗した操作を表示する。陣営別スロットは追加しない。

ポインター座標、ドラッグ中の仮目標、ポインターIDは`GameState`へ入れない。ルール状態と入力セッションを分離する。

## GameController

### コマンド

`tapBase`を陣営付きへ拡張する。

```dart
void tapBase(int baseId, {Faction actor = Faction.player})
```

- `cpuVsCpu`、非`playing`、破棄済みControllerではno-op。
- `playerVsCpu`で`actor != Faction.player`ならno-op。
- `playerVsPlayer`で`actor`が`player`または`cpu`以外ならno-op。
- 選択・解除・出兵の状態機械は既存1Pと同じで、参照する選択欄と作成する`MovingForce.faction`だけを`actor`にする。
- 出兵元がその`actor`所有でない、または兵力1以下なら、その`actor`の選択を消し`invalidatedSource`または`unavailableSource`を出す。

ウィジェットはジェスチャーを解決してからこのコマンドを呼ぶ。テストはジェスチャーを経由せず、`tapBase(id, actor: Faction.cpu)`で2P出兵を再現する。

既存の`tapBase(id)`は1P操作のまま通る。

### CPU

`_activeCpuFactions`は`playerVsPlayer`で空にする。開始カウントダウン完了時もCPU期限を作らない。通常CPU戦と観戦の期限処理は変更しない。

### ライフサイクル

- 開始カウントダウン: 人間操作もCPUも行わず、選択は空。
- playing: 2人対戦では両人間のみ操作可能。
- 一時停止 / 再開カウントダウン: 両選択を保持し、未完了ドラッグは破棄する。再開後に指を置き直す。
- 結果: ループ停止、CPU期限なし、未完了ドラッグ破棄。
- 途中終了: 同じ島数・モードで設定画面へ戻る。難易度値は保持するが2人対戦UIでは出さない。
- 再戦: 同じ島数・モードで新しいマップと開始カウントダウン。両選択は空。
- viewport再構築: `GameState`と設定を保持する。ポインターセッションはウィジェット再構築で破棄し、選択は残す。

## 入力ウィジェット

2人対戦のplaying中だけ、盤面全体に`Listener`を置く。各島の`onPressed`はnullにし、`InkWell`がポインターを奪わないようにする。通常CPU戦は既存の`InkWell.onTap`を維持する。

`Listener`はポインターIDごとのセッションを持つ。

```text
pointerId -> { actor, sourceIslandId, startedOnSelectedSource }
```

ヒット判定は描画と同じ島中心とウィジェットサイズを使う。島の矩形に含まれるならその島、どの島にも入らなければnullである。

通常CPU戦へモードを戻したとき、このListenerは乗せず、既存の1Pタップ経路だけを使う。

## UI

### 設定パネル

表示順は次のとおりとする。

1. 島数
2. ゲームモード
3. CPU難易度（2人対戦では非表示）
4. 開始ボタン

ゲームモードは次の3択とする。1行3列にはしない。

```text
[ PLAY VS CPU ] [ 2P LOCAL ]
[ WATCH CPU VS CPU         ]
```

ラベル:

| モード | 英語 | 日本語 | key |
| --- | --- | --- | --- |
| `playerVsCpu` | `PLAY VS CPU` | `CPU対戦` | `player-vs-cpu` |
| `playerVsPlayer` | `2P LOCAL` | `2人対戦` | `player-vs-player` |
| `cpuVsCpu` | `WATCH CPU VS CPU` | `CPU同士を観戦` | `cpu-vs-cpu` |

2人対戦ではCPU難易度行を出さない。開始ボタンSemanticsは島数と`2P LOCAL` / `2人対戦`を含み、難易度は含めない。選択中サマリーも島数とモード名だけにする。設定説明文は2人対戦時にCPU判断速度へ触れない。

設定パネルは必要時に縦スクロールし、280 x 500のSafe Area内で全設定と開始ボタンへ到達可能にする。3モード追加後も観戦時の2段難易度より行数は少ない。

### 陣営表示

`FactionPresentation.forMode`を、観戦と2人対戦の両方で1P / 2P表記にする。通常CPU戦の`P / Player`、`C / CPU`は維持する。色、輪郭、島形状、移動部隊形状は変更しない。

| モード | `Faction.player` | `Faction.cpu` | `Faction.neutral` |
| --- | --- | --- | --- |
| 通常CPU戦 | `P` / `Player` | `C` / `CPU` | `N` / `Neutral` |
| 2人対戦 | `1P` / `1P` | `2P` / `2P` | `N` / `Neutral` |
| 観戦 | `1P` / `1P` | `2P` / `2P` | `N` / `Neutral` |

### 選択と出兵先の表示

- 出兵元は既存の選択枠・発光を、その島の陣営色で出す。
- `SOURCE`バッジも1Pは緑系、2Pは赤系にする。通常CPU戦の1Pバッジ色は既存を維持する。
- 選択中はその陣営色の破線ルートを既存`_RoutePainter`と同様に出す。両者が選択しているときは両ルートを重ねる。
- 出兵先候補は「そのプレイヤーの出兵元以外の全島」とする。両者が選択中なら、両方の出兵元以外を候補表示する。
- ドラッグ中の指位置から出兵元への一時ラインと、指の下にある島の強調はウィジェットローカル状態とし、`GameState`に入れない。
- 盤面下部ステータスは1Pを左、2Pを右に並べる。未選択時はドラッグ操作を案内する。

### 操作可能性

島を人間が操作できる条件は次のとおり導出する。

```text
state.phase == GamePhase.playing &&
state.configuration.gameMode.humanFactions.isNotEmpty
```

観戦では既存どおりtap actionを公開しない。2人対戦では1P島も2P島も操作対象になり、中立島はドラッグのドロップ先としてのみ意味を持つ。Semanticsは所有・兵力・選択状態を読み上げるが、2人同時のVoiceOverプレイは対象外である。

移動部隊は既存どおり操作不能とする。

### 結果

`GameResult`の型と勝敗判定は変更しない。全滅と同時全滅の定義は既存のままである。

2人対戦の結果タイトルは観戦と同じく`winner`を正本にする。

- winnerが`Faction.player`: `1P WIN`
- winnerが`Faction.cpu`: `2P WIN`
- draw: `DRAW`

通常CPU戦だけ既存の`Victory / Defeat / Draw`を使う。結果色は`winner`の陣営色、引き分けは中立色とする。再戦と設定復帰のボタンは既存のままである。

## GameRules

戦闘・増加・移動・勝敗は変更しない。選択の無効化だけを両人間選択へ拡張する。

- tick開始時とtick後に、1P選択は`Faction.player`かつ兵力2以上、2P選択は`Faction.cpu`かつ兵力2以上でなければその選択だけを消す。
- 初期状態、カウントダウン開始、マップ生成失敗時は両選択をnullにする。
- 片方の選択無効化が他方の選択や移動部隊を消さない。

## エラー処理と不変条件

- マップ生成に失敗した場合は設定フェーズに留まり、カウントダウンも入力も開始しない。
- phaseまたはモードが不正な設定操作、島操作、CPU判断は状態を変更しない。
- 2人対戦でCPU strategyを実行しない。
- 通常CPU戦で2P人間入力を受け付けない。
- 観戦で人間の出兵を受け付けない。
- 兵力1以下、非所有、同一島への出兵は既存どおり作らない。
- 未完了ドラッグは結果・一時停止・破棄で出兵しない。
- `GameMode`と`Faction`のswitchにdefaultを置かず、値追加漏れを静的に検出する。

## 影響範囲

| ファイル | 変更内容 |
| --- | --- |
| `lib/game/game_state.dart` | `GameMode.playerVsPlayer`、人間/CPU導出、`opponentSelectedIslandId`、選択クリア、`canDispatchAs` |
| `lib/game/game_rules.dart` | 両選択の維持・無効化。戦闘ロジックは触らない |
| `lib/game/game_controller.dart` | 陣営付き`tapBase`、2人対戦でCPU空、操作防御 |
| `lib/faction_presentation.dart` | 2人対戦を1P / 2P表示へ |
| `lib/home.dart` | 3モードUI、Listener入力、両選択表示、ステータス、結果、Semantics |
| `lib/base.dart` | 陣営色の選択バッジ、2人対戦時の`onPressed`抑制 |
| `lib/l10n/app_en.arb` / `app_ja.arb` | モード名、サマリー、開始Semantics、盤面案内 |
| `docs/game-rules.md` | 2人対戦の操作、表示、対象外からの繰り上げ |
| `docs/integration-qa.md` | 自動・端末QA項目 |
| `test/game_rules_test.dart` | 設定値、両選択の無効化 |
| `test/game_controller_test.dart` | 陣営付き出兵、CPU停止、ライフサイクル |
| `test/widget_test.dart` | 設定UI、280 x 500、表示、結果 |
| `test/integration_qa_test.dart` | 全島数開始、2人出兵、結果停止 |

`CpuStrategy`、map生成、移動速度、戦闘式は原則として変更しない。

## テスト設計

テストは既存の`ManualGameLoop`とController state差し替えを使い、実時間待機を行わない。ドラッグは`TestPointer`で再現し、ルール検証は`tapBase(..., actor:)`を正本とする。

### データモデル

- 初期モードは`playerVsCpu`のままである。
- `copyWith`、等価比較、`hashCode`に`opponentSelectedIslandId`と3モードが含まれる。
- 2人対戦へ切り替えてもCPU難易度を保持する。
- `humanFactions` / CPU陣営の導出が3モードで正しい。

### ControllerとRules

- 2人対戦の`tapBase(actor: player)`と`tapBase(actor: cpu)`がそれぞれの島からだけ出兵する。
- 連続した両陣営出兵が2部隊になり、IDが重複しない。
- 2人対戦でCPU期限が作られず、判断も走らない。
- 通常CPU戦の既存`tapBase`とCPU判断が回帰しない。
- 観戦の`tapBase`がno-opのままである。
- 2P選択中の島が占領または兵力1になると、2P選択だけ消える。
- 一時停止、再開、結果、途中終了、再戦、viewport再構築でモードと選択を仕様どおり扱う。

### Widgetとアクセシビリティ

- 3モードChoiceChipの初期値、選択、key、Semanticsを確認する。
- 2人対戦で難易度行が消え、開始Semanticsに難易度が入らない。
- 280 x 500でオーバーフローせず、3モードと開始へ到達できる。
- 1P / 2P表示、両選択枠、陣営色SOURCE、結果`1P WIN` / `2P WIN` / `DRAW`。
- 通常CPU戦のP / C、Victory / Defeat、既存島タップが残る。
- 2人対戦のドラッグ出兵と、敵島単独タップでは出兵しないこと。
- 2本の`TestPointer`で同時ドラッグし、両部隊が生成されること。

### 統合

- 6・8・10・12島すべてで2人対戦を開始できる。
- 固定マップで1Pと2Pが手動出兵し、結果まで進められる。
- 結果確定後に兵力、部隊、CPU判断が進行しない。
- 再戦と設定復帰がモードを保持する。
- 通常CPU戦と観戦の既存統合を維持する。

## 検証ゲート

- 変更対象のfocused tests
- Dart format
- `fvm flutter analyze`
- `fvm flutter test`
- `git diff --check`
- l10n生成物へ影響がある場合のみ該当コマンドを実行し、生成差分を確認する

## 完了条件

- Issue #4の選択開始、両陣営操作、同時入力、勝敗と再戦、既存ルール維持をコードまたは自動テストへ対応付けられる。
- 通常CPU戦と観戦の設定、操作、CPU判断、結果表示が回帰していない。
- 2人対戦でCPUが動かず、1Pと2Pが独立に選択・出兵できる。
- 敵島の単独タップが出兵にならず、自軍からのドラッグだけが攻撃になる。
- 同時ドラッグが両方の部隊を生成することを自動テストで証明できる。
- 280 x 500で3モードと開始に到達できる。
- 文書、format、analyze、全テスト、diff checkが成功する。

## 実装時の文書更新

`docs/game-rules.md`から「同一端末での2人対戦」を初期版対象外の本文扱いに移す。追加する本文は次を満たす。

- 開始前に`2P LOCAL` / `2人対戦`を選べる。
- 1Pは右下緑、2Pは左上赤を操作する。
- 出兵は自軍島から目標島へのドラッグで、送り出す兵力は半分のままである。
- 2人対戦ではCPU判断を行わない。
- 結果は`1P WIN` / `2P WIN` / `DRAW`である。
- オンライン対戦は引き続き対象外とする。
