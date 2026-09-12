# タイトル画面の検証記録

検証日: 2026-09-05 / Flutter 3.44.8

## 自動検証

- `fvm flutter test --no-pub`: 193テスト成功。
- `fvm flutter analyze --no-pub`: 指摘なし。
- `fvm flutter build web --release --no-pub`: 成功。
- `fvm flutter build ios --simulator --debug --no-pub`: 成功。
- 起動時のタイトル、設定への遷移、戻るボタン・Android相当のシステム戻る操作、島数・モード・両CPU難易度の保持、タイトル待機中のゲーム停止を検証。
- バックグラウンド復帰と再起動、日英表示、280×320・文字倍率2・SafeArea、横長Web配置、デスクトップでの両ボタンの48px最小高を検証。
- 既存の設定・対戦・再戦・結果・一時停止・リサイズ・Web非表示時の停止テストも成功。既存の端末QAテストにはタイトルから進む操作を追加。

## 表示・操作確認

- ChromeでWeb releaseビルドを起動。390×844と1440×900でタイトルと海図背景の中央配置、設定への遷移を確認。
- Webの実際のアクセシビリティ要素を測定し、「はじめる」と「タイトルへ戻る」がともに幅330px・高さ48pxであることを確認。デスクトップのcompact densityによる40pxへの縮小を修正済み。
- iPhone 17 / iOS 26.5シミュレータでタイトルと対戦設定を確認。ノッチ・ホームインジケータと重ならず、各ボタンを操作できる。
- シミュレータで8島・Hardに変更してタイトルへ戻り、再入場後も選択が保持されることを確認。ゲーム開始、カウントダウン、対戦結果から設定へ戻る動作も確認。
- Androidの戻る操作と大きな文字の検証はwidgetテストで実施。10分間の端末QAテストは今回実行していない。
- 読み取り専用コードレビューを実施し、修正を要する指摘なし。

## スクリーンショット

- [Webタイトル・390×844](../design-qa-assets/title-screen/web-title.png)
- [Webタイトル・1440×900](../design-qa-assets/title-screen/web-title-wide.png)
- [iOSタイトル](../design-qa-assets/title-screen/ios-title.png)
- [iOS対戦設定](../design-qa-assets/title-screen/ios-settings.png)
