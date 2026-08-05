# Issue #15 統合QA記録

この記録は、`docs/game-rules.md` の初期版CPU戦について、統合自動テストと
端末・画面QAで実際に確認した範囲を記録する。新しいゲームルールは追加していない。

## 実施環境

- 実施日時: 2026-08-05 14:29–14:35 JST（05:29–05:35 UTC）
- checkout: `codex/issue-15-integration-qa`, 実施開始時のHEAD `62521a1`
- host: macOS 26.5.2 / Darwin arm64（`uname -a`: Darwin 25.5.0）
- Flutter: 3.44.8、Dart 3.12.2（FVM 2.2.6）
- Xcode: 26.6 (17F113)
- 端末: iPhone 17 Simulator、iOS 26.5 (23F77)、モデル `iPhone18,3`、UDID
  `2EBD3334-E7B5-42DC-BFBE-EEF75C95AEF7`
- スクリーンショット: `xcrun simctl io ... screenshot` が成功し、設定画面の
  10島マップを1206×2622 pixelで取得。SHA-256
  `da4017d0b3b0ed62fa45df3beee2e438c5caaf3de6544a6afae393693d0f9040`
  （`/tmp/conquest-issue-15-board.png`）。一時的なSimulator画面であり、個別の
  画像ファイルを成果物に含める必要はないためcommitしていない。

## 統合自動テスト

`test/integration_qa_test.dart` は `ProviderContainer`、固定乱数、手動
`GameLoop` を接続し、実際の `GameController` → `GameRules` → `CpuStrategy` の経路を
走らせる。

| 確認項目 | 自動テスト | 結果 |
| --- | --- | --- |
| 6・8・10・12島の生成、点対称ペア、開始前マップ、3秒カウントダウン | `starts every supported map deterministically through the countdown` | PASS |
| 固定乱数で同じ試合結果を再現 | `replays the same CPU result with a fixed seed and manual loop` | PASS |
| プレイヤー勝利（CPU本陣占領） | `completes a scripted player victory on every map size` | PASS |
| CPU勝利（プレイヤー最後の島を占領） | `replays the same CPU result with a fixed seed and manual loop` | PASS |
| 同時到着による引き分け、結果後の停止 | `resolves a draw from simultaneous equal arrivals and freezes the loop` | PASS |
| 自軍増援の上限、中立の同数攻撃、敵島の超過攻撃 | `keeps friendly, neutral, and enemy boundary arrivals independent` | PASS |
| 一時停止、再開カウントダウン、結果、再戦、provider破棄 | `pauses, resumes, rematches, and disposes without advancing state` | PASS |
| 多数部隊の同時存在、取りこぼし・上書きなし | `handles many simultaneous troops without dropping or overwriting them` | PASS |

個別ルールの境界値は既存テストでも確認している。`test/game_rules_test.dart` の
成長境界・容量上限・移動時間・中立/敵の不足/同数/超過・同時到着・最後の島喪失後の
移動中部隊・引き分け凍結、`test/game_controller_test.dart` の選択/出兵/複数部隊/
provider破棄、`test/cpu_strategy_test.dart` の防衛・攻撃優先順位、`test/widget_test.dart`
のSafe Area・縦長制約・意味論・pause/resume/resultを合わせて対象ルールを網羅する。

## 端末・画面QA（実観測）

Flutter debugアプリを `fvm flutter run -d 2EBD3334-E7B5-42DC-BFBE-EEF75C95AEF7`
で起動し、Simulatorのアクセシビリティツリーと画面を確認した。

| QA項目 | 実施結果 | 証拠・制約 |
| --- | --- | --- |
| スマートフォン縦向き | PASS | iPhone 17のportrait画面で起動。Safe Area内に本陣と設定パネルを表示。 |
| 6・8・10・12島の盤面 | PASS | 設定チップを順に選択し、AXで`Island map, N islands`を6/8/10/12すべて確認。 |
| Safe Areaとタップ領域 | PASS | countdown画面の本陣・中立島がノッチ/下端内側に配置。playing中にプレイヤー本陣をタップできた。 |
| 島のサイズ・所属・現在値・上限値 | PASS | AXでheadquarters `forces N of 200`、small/medium/largeの所属、耐久値、上限値を確認。 |
| 選択・解除・無効フィードバック | PARTIAL | playing中に`selected dispatch source`と有効な移動先表示を確認。解除/無効メッセージの自動テストはPASS。 |
| 両軍の複数移動部隊 | PASS | playing中にAXでCPU moving troopを複数確認。200部隊の統合自動テストもPASS。 |
| カウントダウン | PASS | AX/画面で`Game start 3`を確認し、完了後にPAUSEと操作可能な島を確認。 |
| 一時停止 | PASS | PAUSEをタップし、`Game Paused`、`RESUME`、`QUIT MATCH`を確認。 |
| 再開 | PASS | RESUME後に`Game start 3`を確認し、playingへ復帰。 |
| 結果画面 | PASS | CPU進行後に`Defeat`、`PLAY AGAIN`、`RETURN TO SETTINGS`を確認。 |
| 再戦 | PASS | `PLAY AGAIN`後に同じ10島数の新マップとカウントダウンを確認。 |
| 色以外の陣営識別 | PASS | AXでPlayer/CPU/Neutralのラベル、`P`/`C`/`N`マーク、数値を確認。 |
| 長時間試合の操作性・描画安定性 | 未手動 | 長時間の実時間試合は実施せず、固定時間の成長境界・CPU進行・多数部隊を自動テストで代替。 |
| バックグラウンド自動一時停止 | 未手動 | Simulatorでのホーム遷移は今回実施せず。`test/widget_test.dart` の`backgrounding a playing board pauses it automatically`でライフサイクル通知を検証。 |
| 移動先タップによる実端末出兵 | 未手動 | CPUの再描画でAX element IDが短時間に更新され、今回のComputer Use操作ではdestination dispatchの安定した証跡を取得できなかった。`test/widget_test.dart` と `test/game_controller_test.dart` のタップ自動テストで補完。 |

## `game-rules.md` 対応表

| ルール文書の節 | 対応する自動テスト/端末QA |
| --- | --- |
| ゲームの目的、陣営色以外の識別、本陣喪失と全滅、勝利/敗北/引き分け | `game_rules_test.dart` の結果判定・本陣単独喪失・同時全滅、`integration_qa_test.dart` の3結果、端末AXのP/C/Nラベル |
| ゲーム開始、6/8/10/12島、初期10島、3/2/1/START | `game_rules_test.dart` の構成/マップ、`integration_qa_test.dart` の全島数開始、`widget_test.dart` の設定/カウントダウン、端末QA |
| 点対称マップ、島サイズ、耐久力、容量、Safe Area、重なりなし | `game_rules_test.dart` の生成/矩形検査、`widget_test.dart` の縦長/resize検査、端末QA |
| 兵力増加、1秒境界、上限、中立非成長、到着前成長 | `game_rules_test.dart` のgrowth/境界/容量テスト |
| 島選択、半分切り捨て、選択解除、繰り返し出兵、複数部隊 | `game_controller_test.dart` のselection/dispatch/multiple troops、`widget_test.dart` のsemantics、統合多数部隊 |
| 移動速度、距離比例、到着時のみ処理 | `game_rules_test.dart` のmovement duration/arrival tests、統合境界到着 |
| 自軍増援、中立/敵の不足・同数・超過、残存兵力上限、同時到着 | `game_rules_test.dart` のcombat tests、`integration_qa_test.dart` のboundary/simultaneous tests |
| CPU間隔、1判断1部隊、防衛、攻撃/出兵元優先、到着予測 | `cpu_strategy_test.dart` 全体、`cpu_controller_integration_test.dart`、固定乱数CPU統合 |
| 表示値、選択枠、移動部隊値、無効フィードバック | `widget_test.dart` のsemantics/feedback/moving-force tests、端末AX観測 |
| 一時停止、バックグラウンド、再開、途中終了、未保存 | `game_controller_test.dart`、`widget_test.dart` のpause/quit/lifecycle、統合pause/resume/dispose |
| 結果停止、もう一度、設定へ戻る | `game_controller_test.dart`、`widget_test.dart`、統合result/rematch |

### 対象外

難易度選択、同一端末2人対戦、オンライン対戦、初期版に不要な演出、試合の保存・復元は
Issue #15および初期ルール文書の対象外であり、実装・QAしていない。
