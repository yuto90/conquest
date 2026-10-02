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
| 当初の選定候補 | Track 3（ループバージョン、21秒） |
| ビルド入力 | ユーザー提供MP3（約179秒。候補の21秒版とは異なり、トラック番号・ループ版かは未確認） |
| 採用ファイル名 | `assets/audio/metropolis_destruction.mp3` |
| 出典確認日 | 2026-09-15 |
| 提供ファイル確認日 | 2026-10-02 |
| 形式・サイズ・長さ | MP3 / 44.1kHz / stereo / 7,149,285 bytes / 178.667 seconds |
| SHA-256 | `aa82af825cf87023006bd9e22023261c7ae0e87a2a9c350015a0faf9b99a09ee` |

タイトル画面と対戦設定だけで再生し、戦闘画面へ移ると停止・リセットする。クレジット表記は `Metropolis Destruction — MFP【Marron Fields Production】 / OpenTracks` とする。

## 提供音源と保管方針

2026-10-02にユーザーから2曲のMP3が提供された。対戦用は上記の選定済みSHA-256と一致する。メニュー用は上記の提供ファイルを使用する。どちらも編集・形式変換せず、原本のハッシュをビルド入力と出力で照合する。

ユーザーは「webでの利用は問題ない」と確認し、GitHubで音源を公開しない方針を指定した。音源の非公開保管先はCloudflareとし、保管先の設定はユーザーが行う。これはユーザーの利用確認の記録であり、新たなライセンス条項の解釈や許諾取得を行ったという意味ではない。

Cloudflareの非公開原本をCIで取得し、アプリにはアセットとして同梱、正式Webには再生用のアセットとして配信する。公開Webではブラウザへ音源が送信されるため、原本の保管先を非公開にしても配信された音源の保存を完全には防げない。暗号化・ZIP化・拡張子変更をコピー防止や利用許諾の代替とは扱わない。Git、Git LFS、GitHub Release添付、音源配布用のGitHub artifactにはMP3を追加しない。PRプレビューにも原本を取り込まない。

## 未確定事項

- 対象iOS・Android・Chrome・Safariで2周以上を通過させた可聴ループ、音量、消音、割り込み、開始遅延、終了後の停止は未確認である。先頭・末尾の無音を含むため、シームレス性は未承認である。
- メニュー用の提供MP3は当初の21秒版と長さが異なり、シームレスなループとしては未確認である。
- Cloudflareの取得URLはまだ設定されておらず、外部ストレージからの実取得は未確認である。

同梱検証と可聴再生・ループ検証は区別して記録する。実音源を公開リポジトリ、Release添付、原本配布用の公開ストレージ、Git LFSへ追加しない。

## リポジトリとビルド入力

- `assets/audio/.gitkeep` は音源ディレクトリのマーカーだけであり、音声ではない。
- `assets/audio/*` は `.gitignore` で除外している。配布形態とライセンス上の根拠が承認された後に限り、承認済みの音源を使う担当者は、権限のあるローカルまたはCIの保護された作業領域へ、採用名 `assets/audio/tense_tactics.mp3` または `assets/audio/metropolis_destruction.mp3` として一時的に配置する。新しい外部保存先や権限は作らない。
- `lib/audio/bgm_player.dart` はアプリ内アセット `audio/tense_tactics.mp3` と `audio/metropolis_destruction.mp3` を参照する。音源が存在しない開発・CI環境では再生を失敗として扱い、タイトル操作やゲームを無音で継続できる。
- PRプレビューへ実音源を混ぜない。正式Webへの取り込みは上記のユーザー確認に基づく。対象端末での再生・ループ・音量・割り込み・消音動作の検証結果は別途記録する。
- 取り込み後は採用トラック番号、採用ファイルのSHA-256、編集内容、確認日、iOS・Android・Web（Chrome／Safari）の検証結果、公開配布方法のライセンス根拠を必ず記録する。音源ダウンロード機能やサウンドトラック配布機能は追加しない。

提供された2曲のSHA-256、形式、長さを確認した。実機／ブラウザ音響確認・シームレス性の合格判定は保留であり、ビルドの成功だけを可聴再生の合格とは扱わない。

## 正式iOSビルドへの取り込み

音源のないcheckoutをそのままビルドすると、`pubspec.yaml`のディレクトリ指定だけではMP3は生成されず、再生時にアセット読み込みが失敗する。正式ビルドは、既存の保護された音源の取得URLと承認済みSHA-256を`testflight` Environmentから受け取り、Flutterビルド前に2曲を配置する。

| 設定 | 種別 | 内容 |
| --- | --- | --- |
| `BGM_MENU_URL` | Secret | メニュー用MP3を取得する保護されたHTTPS URL |
| `BGM_BATTLE_URL` | Secret | 対戦用MP3を取得する保護されたHTTPS URL |
| `BGM_MENU_SHA256` | Variable | 承認済みメニュー用MP3のSHA-256 |
| `BGM_BATTLE_SHA256` | Variable | 承認済み対戦用MP3のSHA-256 |

URLは署名付き等、curlで追加の認証ヘッダーなしに直接取得できる保護されたHTTPS URLを用い、期限内であることを確認する。[Cloudflare R2の署名付きURL](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)は最大7日で失効するため、ビルド前に有効なGET URLへ更新する。APIトークンやCloudflareの管理画面URLはこの設定の代用にはならない。新しい公開ストレージや音源公開用artifactは作成しない。URLをログ・Issue・PRに書かない。

`script/prepare-bgm-assets.sh`は2曲の取得と検証が完了してから配置する。設定不足、ダウンロード失敗、空ファイル、ハッシュ不一致は正式ビルドを失敗にする。ArchiveのFlutterアセットにも同じハッシュ検証を行い、音源の欠落や取り違えをIPA export・uploadの前に検出する。音源入力はworkflowの終了時に削除する。通常のPRビルドとWebプレビューには音源を取り込まない。

権限のあるローカル環境では、外部通信を使わず提供された2曲を配置できる。

```bash
export BGM_MENU_SHA256='<承認済みメニュー音源のSHA-256>'
export BGM_BATTLE_SHA256='<承認済み対戦音源のSHA-256>'
bash script/prepare-bgm-assets.sh assets/audio /path/to/approved-audio
fvm flutter build ios --simulator --debug --no-codesign
bash script/prepare-bgm-assets.sh --verify \
  build/ios/iphonesimulator/Runner.app/Frameworks/App.framework/flutter_assets/assets/audio
```

提供元ディレクトリのファイル名は`metropolis_destruction.mp3`と`tense_tactics.mp3`にする。ハッシュの一致は可聴再生やライセンス確認の代わりにはならない。実音源での再生確認が終わるまでBGM修正完了とは扱わない。

## 正式Webビルドへの取り込み

`Production` EnvironmentへiOSと同じ4つの設定を登録する。`Preview`へは音源URLを登録しない。`Deploy Web`は`main`へのpush時だけ2曲を取得し、`fvm flutter build web --release`の後に`build/web/assets/assets/audio`のSHA-256を検証してから、既存のVercelデプロイへ渡す。設定不足・期限切れ・ハッシュ不一致は公開前に停止する。成功・失敗にかかわらずCIの入力音源とWeb出力の一時コピーを終了時に削除する。

ローカルではiOSと同じ取り込みの後にWebをビルドする。Androidも同じアセット宣言を使用するので、取り込み後に`fvm flutter build apk --release`で同梱できる。MP3やビルド出力をGitへ追加しない。

```bash
bash script/prepare-bgm-assets.sh assets/audio /path/to/approved-audio
fvm flutter build web --release --base-href /
bash script/prepare-bgm-assets.sh --verify build/web/assets/assets/audio
```

ローカルで検証を終えたら`assets/audio/`の2曲を削除する。提供元の原本はリポジトリ外の権限のある保管先で管理する。

## 提供ファイルでのビルド検証

2026-10-02、提供された2曲をローカルの保護された入力から取り込み、MP3の全体デコード、iOS Simulator debugビルド、Web releaseビルドに成功した。iOSのFlutterアセットとWebの`assets/assets/audio`内の両ファイルについて、提供された原本とのSHA-256一致を確認した。Gitの管理対象は引き続き`.gitkeep`のみで、MP3はGit除外のままである。

iOSはこのmacOS環境用にXcode 27.0 RCと`FLUTTER_XCODE_IPHONEOS_DEPLOYMENT_TARGET=15.0`を使用した。Cloudflareからの取得、署名付きIPA、Androidへの実音源同梱、可聴再生・ループはこの検証には含めていない。ストア投稿やWeb公開も行っていない。
