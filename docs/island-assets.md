# 島画像素材とアプリ統合

2026-09-13、Issue #63 の素材レビュー承認済み。ユーザーが確認した36枚を正本としてFlutterアプリへ統合した。ゲーム上の島数・配置・サイズ区分・占領条件・兵力・移動・タップ領域は変更していない。

## 出典

ユーザー提供、2026-09-13。`/Users/apple/Desktop/isles/` で今回指定された原画を `tool/island_assets/sources/` に無加工で保存した。外部フリー素材ではない。

今回受領したファイルのSHA-256はIssue本文の値と異なる。ユーザーが今回「この素材を切り取って使用して」と指定したファイルを使用し、旧ファイルとの同一性は主張しない。

| 原画 | SHA-256 |
| --- | --- |
| conquest_isles_ally.png | d9368f60b6a29ca850e40ba63f250b7d88b7e04968abadc24b44cce5bb95438f |
| conquest_isles_enemy.png | 80f7f492c36611cef1a6f666b3497ed932d37a4dce61ce4b1ca2803ad0adde42 |
| conquest_isles_neutral.png | e0c5363f8ceca3935338630aac8137bbd41efb297873b6e3cc1fadb5cc7b08ab |

3枚とも1448×1086px。原画はFlutter配布アセットに含めない。

## 出力と確認画像

- `assets/islands/ally/island_01.png` ～ `island_12.png`：自陣
- `assets/islands/enemy/island_01.png` ～ `island_12.png`：敵陣
- `assets/islands/neutral/island_01.png` ～ `island_12.png`：中立

左上から横方向に01〜04、05〜08、09〜12。同じ番号は3陣営で同型。周辺の小島・岩も同じPNG内の装飾として保持する。

確認画像は `tool/island_assets/review/` に保存する。

- `contact-sea.png`：海色背景の36枚一覧
- `contact-white.png`、`contact-dark.png`、`contact-checker.png`：白・暗色・市松背景の同じ一覧
- `alignment-overlay.png`：同一キャンバスのアルファを自陣=赤、敵陣=緑、中立=青で重ね合わせ。白は3枚の重複領域、色付きの縁は原画由来の輪郭差を含む差分。

一覧の各番号は左から自陣・敵陣・中立。上段116px、下段50pxの表示比較。これは素材確認用で、実際のゲーム画面ではない。

## 再生成

Python 3.13で検証。プロジェクトルートから実行する。

```sh
python3.13 -m venv /tmp/conquest-island-assets-venv
/tmp/conquest-island-assets-venv/bin/pip install -r tool/island_assets/requirements.txt
/tmp/conquest-island-assets-venv/bin/python tool/island_assets/extract_islands.py
```

依存は開発用のPillow・NumPy・SciPyのみ。アプリのランタイム依存は追加しない。スクリプトは原画ハッシュと解像度を検証し、36枚・確認画像・`crop_plan.json`を再生成する。

### 切り抜きと背景透過

境界はx=`[0,360,750,1105,1448]`、y=`[0,400,730,1086]`。右端・下端を含まない。等分割や成分単位の切り離しは行わない。

背景候補はRGBの0〜255値で `G > 150`、`G-R > 30`、`G-B > 50` をすべて満たす画素。そのうち切り出し外周から4近傍で連結する領域だけを背景とする。候補色と判定されても外周につながらない内部の樹木は保持する。

外周背景から6px超離れた背景画素のRGB中央値をキー色としてサンプリングする。輪郭の内外3px以内だけ、最寄りの内部画素の色を使ってキー色との混合率を推定し、半透明のアルファを復元する。境界のRGBは最寄りの内部色を延長し、低アルファで色ノイズが増幅されて緑やマゼンタの縁になることを防ぐ。アルファが2/255未満の画素は完全透明にする。輪郭から3px超内側のRGBは原画のまま保持する。小さい連結成分を一律削除する処理はない。

### 位置合わせ

自陣を基準に、アルファ128以上のシルエットの重なりが最大になる整数平行移動を±8pxから探索する。今回はx=0〜1px、y=0〜−5px。移動量、背景サンプル、共通原点、キャンバス寸法、シルエットIoUを `crop_plan.json` に記録する。IoUは約0.966〜0.991で、原画の微細な輪郭差は残す。

平行移動後の3枚共通の外接範囲に最低4pxの余白を付け、同じ正方形キャンバスへ配置する。出力は原画と1:1の画素スケールで、陣営ごとの拡縮・非等方変形・描き直しは行わない。縮小は確認シートの表示用だけ。

## 素材確認（レビュー承認済み）

36枚すべてのRGBA PNG読み込み、同型3枚の寸法一致、最低4pxの透明余白、半透明画素の存在、切り出し境界での地形の欠けをスクリプトで検証した。海色・白・暗色・市松の一覧とシルエット重ね合わせを目視確認し、ユーザーの素材レビューを完了した。

## アプリ統合

- `lib/ui/island_assets.dart` の純粋関数が、`island.id` の `0..11` を `01..12` へ決定的に対応付ける。12を超えるIDも同じ規則で循環し、`Faction.player`／`cpu`／`neutral` を `ally`／`enemy`／`neutral` へ変換する。
- `Base` は正方形の既存ウィジェット枠とタップ領域を維持し、画像を `Image.asset` と `BoxFit.contain` で表示する。選択枠・移動先候補・P/C/N（観戦時は1P/2P）・現在値・兵力上限・本陣マーカー・SemanticsはFlutter UIとして画像の上に重ねる。
- `IslandAssetPreloader` は盤面ライフサイクルで36枚を一度ずつ `precacheImage` し、画像の遅延・読み込み失敗時は最新の所属色を反映した小さなフォールバックを表示する。失敗ログはアセットごとに一度だけ出力する。
- `pubspec.yaml` には実行時に使う3陣営の出力ディレクトリだけを登録し、`tool/island_assets/sources/` の原画は配布アセットに含めない。
- `docs/game-rules.md` の「占領済みの島は現在兵力を大きく、兵力上限を小さく表示する」という正本に合わせ、従来 `Offstage` だった上限表示を小さな可視テキストへ変更した。上限値自体は変更していない。

## 実装時の検証

次の検証を実装HEADに対して実行し、すべて成功した。

```sh
fvm flutter analyze
fvm flutter test
fvm flutter build web --release
```

`test/island_assets_test.dart` は12種類×3陣営の決定的な対応と36枚の重複しないプリロード一覧を検証する。`test/island_ui_test.dart` は所属変更時の同一バリアント切り替え、実アセットのパス、容量表示、本陣マーカー、Semantics、読み込み失敗フォールバックを検証する。既存の `test/widget_test.dart` と `test/tactical_ui_test.dart` では配置・サイズ・操作・観戦モード・カウントダウン・一時停止・結果表示の回帰を確認する。
