# Conquest Isles: App Store search and conversion

2026-10-02に実施。対象語は **conquest**、対象市場は日本と米国。App Store IDは `6800177702`。

検索上位は設定だけでは保証できない。Appleは名前・サブタイトル・キーワード・カテゴリの関連性に加え、ダウンロード・評価・レビューなどを使う。タイトル先頭の `Conquest` は維持する。

## 保存済みの掲載情報

App Store Connectの審査待ち **1.0.2** に日英のサブタイトル・説明・プロモーション文・キーワードを保存した。主カテゴリはゲーム、ゲームのサブカテゴリはストラテジーとカジュアル。公開版は確認時点では **1.0.1**。保存と公開は別であり、新しい情報の公開確認が必要。

- 正本: [`metadata/app-store/listing.json`](../../metadata/app-store/listing.json)。各言語のテキストも同じディレクトリに保存。
- 変更前/保存後: `before-*.json` / `after-*.json`。公開用フィールドのみ。開発者の連絡先・認証情報・内部アナリティクスを含めない。
- 名前は現在の `Conquest Isles` を維持。`proposed_name` は確認待ちの提案で、自動アップロード用の値ではない。
- 名前の説明語追加を採用した場合、英語は `Conquest Isles: Island RTS`、日本語は `Conquest Isles - 島取りRTS`。この場合、名前と重なる `island,RTS` / `RTS,島取り` をキーワードから削除し、英語は空き枠へ `reinforcement` を戻す。
- `conquest` をキーワードにも重複させず、関連する戦術・島取り・オフライン・観戦などの語に枠を使う。無関係な語、競合名、商標は入れない。
- 説明の古い島数を8〜16島へ修正。操作練習、同じ初期盤面での再戦、XP、観戦、iPad対応を実装に合わせて説明。
- プロモーション文は体験を伝えるための文。これ自体に検索順位を上げる効果はない。
- ビルド `36976409588`、手動リリース、既存評価を維持する設定は変更しない。

## スクリーンショット

日英 × iPhone/iPad × 5枚。既存の海図スタイルを保ち、先頭3枚を「島の占領」「タップで出兵」「ランダムマップ」の順に変更した。4枚目は難易度、5枚目はCPU観戦。素材は1.0.2の実UIを決定的なマップで描画したもので、未実装機能や架空の戦績を含めない。

```bash
fvm flutter test tool/aso_capture.dart
cd tool/app-store-screenshots
pnpm dev
```

ブラウザで **Export bundle** をiPhoneとiPadそれぞれ実行する。書き出し後は次を確認する。

- iPhone: 1320×2868、1284×2778、1206×2622、1125×2436（6.9/6.5/6.3/6.1インチ用）。
- iPad: 2064×2752、2048×2732。
- 合計60 RGB PNG、各サイズ・言語に5枚。Appleはαチャンネルも受け付けないため、エディタの生ZIPをそのままアップロードせず、次の処理でRGBへ変換する。画像が欠けたり真っ黒になっていないこと、文字が重ならないこと。
- 160px幅の縮小画像で見出しが読めること。今回の確認画像は [`screenshots-thumbnail-160.png`](screenshots-thumbnail-160.png)、サイズ検証は [`export-manifest.json`](export-manifest.json)。

ローカルの完成ZIPと展開済みPNGは `tool/app-store-screenshots/exports/aso-2026-10-02/final/` にある（Git対象外）。App Store Connectへの画像反映は、審査の取り下げ・再提出の判断待ち。素材ができたことを提出済みと扱わない。

```bash
# ffmpegが必要。出力は入力と別のディレクトリにする。
python3 tool/aso_package_screenshots.py \
  --input /path/to/iphone-export.zip \
  --input /path/to/ipad-export.zip \
  --output tool/app-store-screenshots/exports/aso-2026-10-02/final
```

入力のZIPは保存し、RGB変換後のZIPだけをアップロードする。今回の変換は60枚の全RGBピクセルが元画像と同一であることも確認した。対象サイズの詳細は[Appleの仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)を参照。

## 評価とダウンロードへの導線

新しいビルド向けに `lib/reviews/store_review.dart` と画面連携を追加した。現時点の審査中ビルドには含まれない。

- iOSだけでApple標準の評価シートを要求。独自の評価フォームや星の事前質問は使わない。
- この機能の初回起動から7日以上、通常のCPU対戦3回以上の完了後が対象。勝ち・負けで対象を分けない。観戦・操作練習は対象外。
- 結果画面で2秒待ち、画面移動・バックグラウンド・破棄時には要求しない。
- 120日以上間隔を空け、過去365日で最大3回のAPI呼び出し。OS側が表示するかはOSが決めるため、表示やレビュー投稿をアプリ側で確認できない。
- ローカル保存は初回日・完了数・要求日だけ。評価内容の収集、報酬、外部追跡は追加しない。
- 開発用Simulatorでは標準シートの動作を確認できるが、TestFlightでは表示されない。実際の評価は公開版でのみ行える。

READMEにApp Storeリンク、Web版にSafariのSmart App Bannerを追加。公開はPRをマージした後のWebデプロイに依存する。

## 公開後の測定

今回の [`search-baseline-2026-10-02.json`](search-baseline-2026-10-02.json) は公開iTunes Search APIの並びで、端末のApp Store順位とは一致を保証しない。`conquest isles` は日米ともAPI先頭。`conquest` は日本で108番目、米国は返却結果に見当たらなかった。広告枠、国、言語、OS、端末・個人差は別に扱う。

```bash
python3 tool/aso_search_baseline.py --output /tmp/conquest-aso-after.json
```

公開直前、公開7日後・14日後・28日後に同条件で記録する。自動定期実行は設定していない。

1. 公開版の名前・サブタイトル・最初の3枚・言語を日本/米国のストアで確認する。
2. 実機のApp Storeで日本/米国、同じ端末・言語・検索語 `conquest` の自然検索位置を記録する。広告枠を順位に含めない。
3. App Store Connectで同じ期間・国・App Store検索ソースを指定し、インプレッション、プロダクトページ閲覧、初回ダウンロード、コンバージョンを比較する。
4. クラッシュ・継続率・評価の推移も確認する。公開直後の短期変動を効果と断定しない。

確認時のソース分析（7月3日〜9月30日）では検索流入の内訳は「-」で、十分な効果判定データがない。アナリティクスの生データは公開リポジトリに保存しない。

## 現時点で開始しない施策

- **PPOのA/Bテスト**: 新しい標準画像をまず公開し、検索流入が測定できる状態で、先頭1枚の見出しを変える1案から試す。データ不足のまま多案を始めても判断できない。
- **カスタムプロダクトページ**: `conquest` は標準ページの島取り訴求と合う。観戦向けなど異なる意図や実際の配信キャンペーンがある時に別ページを作る。
- **App Preview**: 画面キャプチャだけを動画化したスライドショーではなく、実際の操作を見せる15〜30秒の映像を用意し、画像と比較できる流入ができてから検証する。今回は未制作。
- **アプリ内イベント/課金の検索表示**: 実際のイベントや課金商品がないため、ASO目的で架空のイベントや商品を作らない。
- **アイコン変更**: ゲーム内容を示す既存アイコンを維持。比較データや新しいブランド判断なしに置き換えない。
- **Apple Ads**: 有料広告は自然検索順位の設定ではない。予算と獲得目標の判断が必要なので開始しない。
- **追加言語**: アプリ本体が対応する日英を先に整える。未対応言語を対応済みと誤認させる掲載はしない。

## 参照

- [Apple: App Store search](https://developer.apple.com/app-store/search/)
- [Apple: Product page](https://developer.apple.com/app-store/product-page/)
- [Apple: Ratings and reviews](https://developer.apple.com/app-store/ratings-and-reviews/)
- [Apple: Product page optimization](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization)
- [Apple: Custom product pages](https://developer.apple.com/app-store/custom-product-pages/)
- [Apple: Smart App Banners](https://developer.apple.com/documentation/webkit/promoting-apps-with-smart-app-banners)
- [in_app_review: behavior and testing](https://github.com/britannio/in_app_review)
