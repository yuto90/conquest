# Very Hard / Hard ローカル比較

PRのPreview Deploymentが作成された直後に、ローカルCodexから実Jevを使った比較を実行するための固定ハーネスです。通常のFlutterテスト・CIからは呼び出しません。

## 実行前の条件

- Previewがデプロイ済みで、Flutter Webと`/api/v1/cpu/very-hard`が同じPreview URLから応答すること。
- ローカルの`HEAD`が、比較対象PRのHEAD SHAと一致していること。
- `--pr-head`はPR画面から取得した40桁の小文字SHAをそのまま指定すること。
- Preview URLへquery、fragment、ユーザー名、パスワードを付けないこと。
- Jevのtokenはコマンド、環境変数、レポートへ渡さないこと。PreviewがDeployment Protectionで保護されている場合だけ、VercelのAutomation Bypass secretを`VERCEL_AUTOMATION_BYPASS_SECRET`環境変数へ設定する。secretをコマンド引数・レポート・リポジトリへ記録しない。
- Automation Bypass secretはHTTPSの`conquest-*-yuto90s-projects.vercel.app`だけへ送信し、HTTP・別ホスト・redirectでは安全側へ停止する。

## 外部設定ゲート

次の設定はリポジトリや通常CIへ持ち込まず、PreviewとProductionのVercelプロジェクトで別途確認・適用します。

- Functionは`@vercel/firewall`の`conquest-very-hard-v1`ルールIDを使います。PreviewとProductionの両方で、同じIDの`@vercel/firewall`条件を持つWAF rate-limit ruleを作成し、対象APIを制限する設定を公開してください。ルール未作成・Firewallエラー時はFunctionが安全側へ停止します。
- AI Gateway側で、`typesafe-ai/jev`を使うプロジェクトの利用予算・アラート・Provider利用可否をPreviewとProductionそれぞれ確認してください。予算超過はFunctionの分類済みエラーになり、ベンチマークではフォールバックとして記録されます。
- これらの設定変更、secret投入、deployはこのハーネスや通常CIから実行しません。

## Codexからの正確な実行コマンド

PR番号、PR HEAD SHA、Preview URLを埋めて、リポジトリのルートから実行します。

```sh
IFS= read -rsp 'Automation Bypass secret: ' VERCEL_AUTOMATION_BYPASS_SECRET
printf '\n'
export VERCEL_AUTOMATION_BYPASS_SECRET
fvm dart run tool/very_hard/run.dart \
  --pr-number <PR番号> \
  --pr-head <PRの40桁HEAD SHA> \
  --preview-url https://<Previewのホスト>
```

保護されていないPreviewでは`export`行は不要です。実行後に同じshellでsecretが不要なら`unset VERCEL_AUTOMATION_BYPASS_SECRET`で破棄します。

記録用ファイルへ保存する場合は、出力だけを保存します。

```sh
fvm dart run tool/very_hard/run.dart \
  --pr-number 99 \
  --pr-head <PRの40桁HEAD SHA> \
  --preview-url https://<Previewのホスト> \
  | tee /tmp/conquest-very-hard-80.md
```

Codexへ渡す固定プロンプトは次のとおりです。

> PR `<PR番号>` のPreview URL `<Preview URL>`、PR HEAD `<40桁HEAD SHA>`を使い、上記コマンドを実行してください。出力された日本語MarkdownをPRの検証資料として確認してください。ローカルHEADがPR HEADと一致しない場合は実行せず、token・secret・盤面本文を表示しないでください。勝点率60%未満でも結果・観察事項・残存リスクを隠さず記録してください。

ハーネスは実行前に`git rev-parse HEAD`と`--pr-head`を比較し、一致しなければpreflightを含む外部通信を行わず終了します。

## 比較条件

- CPU対CPU、対戦相手はHard。
- 島数6・8・10・12それぞれ固定seed 10件。
- 同じseedでVery Hardを`player`/`cpu`へ入れ替え、合計80試合。
- マップ、候補生成、移動時間、戦闘、増加は既存の`GameRules`と`VeryHardCandidateGenerator`を使用。
- Jev待機中はルールtickだけを進め、同じtickで期限を迎えたHard/Very Hardは製品と同じ共有snapshot・`player`→`cpu`順のbatchで適用する。
- 判断間隔は製品と同じ1,500〜2,750ms、判断期限は1,200ms。
- ゲームは50ms固定stepで進め、実際のJev応答待ち時間もゲーム内時刻へ加算。
- 1試合の観測上限はゲーム内10分。
- 勝利1点、引分0.5点、敗北0点、未完了0点。未完了は引分と別表示。

レポートにはPR番号、HEAD、実行日時、固定/解決済みモデル、prompt/schema version、島数別と全体のW/D/L/未完了、勝点率、フォールバック数/率、レイテンシ中央値/p95、分類済みProvider/APIエラー、観察事項、残存リスクを出力します。HTTP本文、候補説明、認証情報は出力しません。

60%は観測上の目標であり、未達だけでPRを失敗扱いにしません。モデル更新、Previewリージョン、ネットワーク、未認証APIの利用制限による変動を残存リスクとして併記してください。
