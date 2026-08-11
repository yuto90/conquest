# App Storeリリース手順

このリポジトリのApp Storeリリースは、GitHub Actionsから明示的に起動した場合だけ実行されます。`main`へのpushやマージではApple側の状態を変更しません。審査提出後の公開は、Apple承認を確認してからApp Store Connectで手動操作します。

審査までの経路は次の2つです。

- **確認重視:** 内部TestFlightへ配布し、確認済みの同じbuildを審査へ提出する。
- **審査直行:** TestFlightグループへ配布せず、mainのcommitからbuildして審査へ提出する。

どちらも同じReusable iOS App Store Buildを使用します。共通buildは対象commit、App version、Build number、App Store Connectのbuild ID、workflow、配布経路をprovenance artifactに記録します。artifactは90日保持されます。

## 初回設定

### GitHub Environment

リポジトリの`testflight` Environmentへ次のVariablesを登録します。値はこのドキュメント、Issue、workflow summaryへ書きません。

- `APP_BUNDLE_ID`: App Store Connectへ登録したConquestのBundle ID
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `TESTFLIGHT_INTERNAL_GROUP`: 自動配布を無効にした内部TestFlightグループ名

同じEnvironmentへ次のSecretsを登録します。

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `IOS_APP_STORE_PROVISIONING_PROFILE_BASE64`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`

証明書、profile、API keyはログやartifactへ出力しません。workflowは、1つでも不足している場合は署名・upload・metadata更新を開始せず終了します。

### App Store Connect

workflowの初回実行前に、App Store Connect側を次の状態にします。

1. `APP_BUNDLE_ID`と一致するiOSアプリを作成する。
2. App versionを手動公開（Manual release）で扱えるようにする。
3. 日本語localizationへdescription、keywords、support URLなど審査必須metadataを登録する。
4. App Review連絡先を登録する。demo accountが必要な場合は名前とパスワードも登録する。
5. スクリーンショット、年齢区分、プライバシー、価格・配信地域など、workflowが更新しない必須項目を登録する。
6. `TESTFLIGHT_INTERNAL_GROUP`と完全一致する内部グループを作り、全build自動配布を無効にする。workflowはupload前にこの設定を検証する。

証明書はApple Distribution identityを含むもの、profileは指定Bundle ID・Team IDに一致するApp Store配布用で、期限切れでないものを用意します。Team IDやBundle IDをworkflowへ固定しないでください。

## 共通の入力ルール

Actionsのworkflowを実行するときは、実行branchに`main`を選びます。`commit_sha`は`main`の履歴に含まれる40文字の完全なSHAだけが有効です。短縮SHA、別branchのSHA、存在しないSHAはApple側を変更する前に拒否されます。

App versionは対象commitの`pubspec.yaml`から読み取られる`x.y.z`です。Build numberはworkflowの`github.run_id`で、App Store Connect画面に表示された任意の番号を手入力するものではありません。Flutter SDKは`.fvm/fvm_config.json`の3.44.8を検証し、preflightで`fvm flutter analyze`と`fvm flutter test`を実行します。

## 内部TestFlightで確認してから審査へ提出する

### 1. Deploy TestFlight

1. Actionsで`Deploy TestFlight`を開く。
2. branchに`main`を選ぶ。
3. `commit_sha`へ対象commitの完全な40文字SHAを入力して実行する。
4. SummaryからApp version、Build number、App Store Connect build ID、commit SHA、`Internal distributed: true`を控える。
5. TestFlightの内部テスターで対象buildを確認する。

Reusable buildは、署名素材を一時keychainへ導入し、profile・Team ID・Bundle ID・期限・用途を検証してからIPAを作成します。Appleのprocessing完了後、指定された内部グループへ対象buildだけを割り当てます。配布ポリシー確認が成功するまでprovenance artifactは保存されません。

配布成功後、`Prepare App Store version` jobがApp Store version枠を準備します。対象versionがすでに存在する場合はManual releaseかつ再利用可能な状態だけを再利用し、live version以下のversionはskipします。

### 2. Submit App Store Review

内部テスターの確認後、Actionsで`Submit App Store Review`を開きます。

- `app_version`: Deploy TestFlight SummaryのApp version
- `build_number`: 同じSummaryのBuild number（Deploy TestFlightのrun ID）
- `whats_new_ja`: App Storeに表示する日本語の「このバージョンの新機能」
- `review_notes`: 必要な場合だけ入力。空欄なら既存値を保持

workflowは成功した`Deploy TestFlight` run、runのbranch、workflow path、commit SHA、90日以内のprovenance artifactを照合します。さらにApp Store Connect側で、同じversion/buildが処理済み・期限内・指定内部グループへ配布済みであること、日本語metadataとReview連絡先が存在すること、別versionの審査競合がないことを確認します。

確認済みbuildを再build・再uploadせず、metadataを更新して`fastlane deliver submit_build`で提出します。`automatic_release: false`のため、Apple承認後に自動公開されることはありません。同じbuildがすでに審査待ち・審査中の場合は、再提出せず`already-submitted`として冪等成功します。

## TestFlightを経由せず審査へ提出する

Actionsで`Build and Submit App Store Review`を開き、branchに`main`を選びます。

- `commit_sha`: 審査対象commitの完全な40文字SHA
- `whats_new_ja`: App Storeに表示する日本語の「このバージョンの新機能」
- `review_notes`: 必要な場合だけ入力

共通buildがIPAをuploadした後、どのTestFlightグループにも属さないことをAPIで確認します。submit jobは同一runのprovenance artifact、App version、Build number、build ID、commit SHA、`submission_source: direct_review`、`internal_distributed: false`を照合してから、App Store version準備、metadata更新、審査提出を行います。グループ所属が検出された場合は提出せず停止します。

この経路でも`automatic_release: false`です。uploadしたbuildがApp Store ConnectのTestFlight画面に表示されることはありますが、グループ未所属のため内部テスターへ自動配布されません。

## Summaryとartifactの確認

成功したbuild Summaryには次の値が表示されます。

- App version
- Build number（run ID）
- App Store Connect build ID
- commit SHA
- submission source（`testflight`または`direct_review`）
- internal distributed（`true`または`false`）

provenance artifact名は`app-store-build-provenance-<run_id>`です。審査提出時はこのartifactをActions APIから読み取り、期限切れ・重複・内容不一致をfail-closedで拒否します。秘密鍵、証明書、profile、review metadata本文はprovenanceに含めません。

## 失敗時と再実行

| 状況 | 対応 |
| --- | --- |
| EnvironmentのVariable/Secret不足 | 値の存在だけを確認してから、同じ入力で再実行する。値をログへ貼り付けない。 |
| commit SHAが40文字でない、またはmainの祖先でない | `main`上の完全なSHAを入力し直す。Apple側は変更されない。 |
| Flutter version、pubspec version、Xcode/iOS SDKが契約外 | 対象commitとrunnerの設定を直して再実行する。署名・uploadは開始されない。 |
| 証明書identity、profileのTeam ID/Bundle ID/用途/期限が不一致 | Apple Developer側で素材を作り直し、同じworkflowを再実行する。 |
| 内部グループが外部または自動配布 | 自動配布を無効にした内部グループを作り、`TESTFLIGHT_INTERNAL_GROUP`を更新する。 |
| Buildが未処理、期限切れ、別version/build | processing完了と入力値を確認する。別buildへの差し替えや審査中versionの変更は自動で行わない。 |
| provenanceがrun/workflow/path/source/buildと一致しない | Summaryとartifactを確認し、取り違えたBuild numberを使わない。 |
| 審査直行buildがTestFlightグループに所属 | 提出せず停止する。グループ状態を直し、新しいbuildでやり直す。 |
| 同じbuildがすでに審査待ち・審査中 | `already-submitted`の冪等成功。再提出やmetadataの不要な変更をしない。 |
| 一時keychainやAPI keyのcleanup | 成否にかかわらずcleanup jobが実行される。失敗時はrunner上の一時ファイルが残っていないことを確認する。 |

進行中のbuild・審査提出はconcurrencyで直列化され、新しい実行が進行中の実行をcancelしません。判断できない状態ではActions SummaryとApp Store Connectの読み取り状態を確認し、Apple側の取り下げや別buildへの差し替えを自動で行わないでください。

## Apple承認後の公開

審査が承認され、対象version/buildが正しいことをApp Store Connectで確認した後、App Store Connectの公開操作を手動で行います。GitHub Actionsには承認後の公開workflowを追加していません。公開の判断、価格・配信地域、公開日時はApple側で確認してから確定します。

## 認証情報登録後の初回確認

1. `testflight` EnvironmentへVariables/Secretsを登録する。
2. 自動配布を無効にした内部グループを作成する。
3. `Deploy TestFlight`を`main`の対象SHAで実行する。
4. Summaryのversion/build/build ID/commit SHAと内部配布状態を確認する。
5. 実機またはTestFlightで対象buildを確認する。
6. 審査提出の意思を確認してから、同じversion/buildで`Submit App Store Review`を実行する。
7. 審査直行を使う場合は、`Build and Submit App Store Review`のSummaryで内部配布が`false`であることを確認する。
8. Apple承認後、対象version/buildを確認してApp Store Connectから手動公開する。

Issue #46の実装では、認証情報未登録のため署名IPAのupload、TestFlight配布、Apple審査提出のlive実行は行っていません。
