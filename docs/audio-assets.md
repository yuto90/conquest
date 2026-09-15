# BGM音源の出典と配布管理

この文書は、ゲーム内BGMの出典、利用条件の確認状況、正式ビルドへ取り込む音源の管理方法を記録する。リポジトリが公開されているため、音源ファイルそのものはGit管理しない。

## 選定済みトラック

| 項目 | 内容 |
| --- | --- |
| 曲名 | Tense Tactics |
| 作者 | マニーラ |
| 配布元 | OpenTracks（旧DOVA-SYNDROME） |
| 楽曲ページ | https://dova-s.jp/bgm/detail/22136 （2026-09-15にOpenTracksへリダイレクト） |
| 公式ダウンロードページ | https://dova-s.jp/bgm/detail/22136/download （2026-09-15にOpenTracksへリダイレクト） |
| 利用規約 | https://dova-s.jp/help/articles/license/ （OpenTracksへリダイレクト） |
| 用途FAQ | https://dova-s.jp/help/articles/license-usage/ （OpenTracksへリダイレクト） |
| 出典確認日 | 2026-09-15 |
| 採用トラック | Track 2（公式ダウンロードページのループ版） |
| 取得時の形式 | MP3 / 128kbps / 48kHz / stereo |
| 取得時のサイズ | 3,073,152 bytes |
| 取得時の長さ | 192.072 seconds |
| SHA-256 | `5a261f1d15e1bcec001ea21c12834fccb68adc9b8d1ddbb086a4bc0d1332811b` |

公式の利用規約・用途FAQではゲーム、アプリ、WebサービスのBGM利用が認められている。任意クレジットは `Tense Tactics — マニーラ / OpenTracks（旧DOVA-SYNDROME）` とする。

公式ダウンロードページではTrack 1が非ループ、Track 2がループとして掲載されているため、Track 2を採用候補に選定した。取得・技術確認は公開リポジトリ外の一時領域で1回だけ行い、音源ファイルは保存・公開していない。無音区間として先頭約18.1ms、末尾約31.9msを観測したため、公式の「ループ」表記だけでシームレスな可聴ループとは判定しない。

## メニューBGM

| 項目 | 内容 |
| --- | --- |
| 曲名 | Metropolis Destruction |
| 作者 | MFP【Marron Fields Production】 |
| 配布元 | OpenTracks |
| 楽曲ページ | https://opentracks.com/bgm/detail/23422 |
| 採用トラック | Track 3（ループバージョン、21秒） |
| 採用ファイル名 | `assets/audio/metropolis_destruction.mp3` |
| 出典確認日 | 2026-09-15 |
| 取得時の形式・サイズ・長さ | 未確認（MP3は実装担当者が後日提供） |
| SHA-256 | 未確認（MP3提供後に記録） |

タイトル画面と対戦設定だけで再生し、戦闘画面へ移ると停止・リセットする。OpenTracksの利用条件と、公開リポジトリやWebプレビューへ音源単体を含めない配布方法を確認するまで、受け入れ可能な実音源ビルドとして扱わない。クレジット表記は `Metropolis Destruction — MFP【Marron Fields Production】 / OpenTracks` とする。

## 未確定事項

- 対象iOS・Android・Chrome・Safariで2周以上を通過させた可聴ループ、音量、消音、割り込み、開始遅延、終了後の停止は未確認である。先頭・末尾の無音を含むため、シームレス性は未承認である。
- ゲーム利用許可とは別に、公開GitHubリポジトリ、GitHub ActionsのPRプレビュー、Vercel等の静的Web配布物、アプリ配布物から音源単体を容易に取得できる状態にしてよいかは未確認である。現行規約の禁止事項7は音源配布を、禁止事項8は変換等をせずエンドユーザーが音声ファイルとして容易にアクセス・複製できる状態を禁じている。MP3からの形式変換、拡張子変更、ZIP化、Base64化、暗号化だけでは許諾や制限を満たす根拠にならない。
- 保護された正式ビルド入力と配布形態、そのライセンス上の根拠は未承認である。

上記が確認されるまで、受け入れ可能な実音源ビルドとして扱わない。実音源を公開リポジトリ、Release添付、公開ストレージ、Git LFSへ追加しない。

## リポジトリとビルド入力

- `assets/audio/.gitkeep` は音源ディレクトリのマーカーだけであり、音声ではない。
- `assets/audio/*` は `.gitignore` で除外している。配布形態とライセンス上の根拠が承認された後に限り、承認済みの音源を使う担当者は、権限のあるローカルまたはCIの保護された作業領域へ、採用名 `assets/audio/tense_tactics.mp3` または `assets/audio/metropolis_destruction.mp3` として一時的に配置する。新しい外部保存先や権限は作らない。
- `lib/audio/bgm_player.dart` はアプリ内アセット `audio/tense_tactics.mp3` と `audio/metropolis_destruction.mp3` を参照する。音源が存在しない開発・CI環境では再生を失敗として扱い、タイトル操作やゲームを無音で継続できる。
- 承認前に通常のWebビルドやPRプレビューへ実音源を混ぜない。正式取り込み時は、まず配布物の静的ファイルから音源だけを容易に取得できないこと、対象端末での再生・ループ・音量・割り込み・消音動作を確認し、その根拠と手順をこの文書へ追記する。
- 取り込み後は採用トラック番号、採用ファイルのSHA-256、編集内容、確認日、iOS・Android・Web（Chrome／Safari）の検証結果、公開配布方法のライセンス根拠を必ず記録する。音源ダウンロード機能やサウンドトラック配布機能は追加しない。

現時点では、アプリの再生制御とFakeテスト、戦闘用Track 2の選定・ハッシュ確認、メニュー用Track 3の参照先登録までが実施済みである。メニュー用MP3の提供・ハッシュ確認、実音源の梱包・配布承認・実機／ブラウザ音響確認・シームレス性の合格判定は保留であり、実音源なしの状態を本機能の完成とは扱わない。
