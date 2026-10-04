# Original Conquest rank crest

- `chart-crest.png`: 192×192透明PNG。承認済みC案から引き継いだ自作のコンパス・曲線の葉モチーフ。Conquest向けにこの変更で作成したCanvasパスが原本で、外部画像の取得、BF4素材の転載・抽出・トレースはしていない。
- 元データ: `tool/rank_badges/crest_source.dart` の `paintRankCrestSource`。正規化100×100座標を1.92倍でラスタライズする。
- 再生成: リポジトリルートで `fvm flutter test tool/rank_badges/generate_test.dart --no-pub`。比較PoCの画像は変更しない。形/色を変更した場合は生成物と製品Painterの配色・縮小表示を同時に確認する。
- 配布: Flutterのローカルassetとして1点だけ同梱。全141階級へ共有し、ランタイムに外部ダウンロードしない。共有するのは中央紋章のみで、枠・系列差・段階マークは `lib/ui/rank_badge.dart` で描画する。
- ライセンス方針: 第三者の素材ライセンスは導入していない。Conquestプロジェクト向けオリジナル素材として既存プロジェクトの著作権管理に従い、本変更で別のOSS/CCライセンスや第三者への再配布許諾は新設しない。リポジトリ直下に包括LICENSEがないため、公開リポジトリであることだけを自由再利用の許諾とみなさない。独立したライセンス公開・法的確認が必要なら所有者が別途判断する。

検証・比較時点との差分・性能の測定範囲: `docs/qa/issue-124-product.md`。
