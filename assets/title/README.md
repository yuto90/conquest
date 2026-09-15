# トップ画面の画像素材

- `title_reference.png`：ユーザー提供の元画像 `conquest_isles_top.png`（941 × 1672ピクセル）。トップ画面ではロゴの範囲（x=60、y=666、幅821、高さ130）を表示し、青緑色の背景を描画時に透過処理して元の字形を保ちます。
- `isles_chart.png`：元画像をImage Genで編集した背景（941 × 1672ピクセル）。文字と操作部分を取り除き、地図・島・コンパス・航路を残しています。

ボタン、操作ラベル、アイコン、読み上げ、ダイアログはFlutterの部品で実装しています。画面内の英語表記は元画像に合わせ、操作の読み上げと説明文は日本語・英語に対応します。

画面の文字は、[Google Fonts](https://github.com/google/fonts)のNoto Sans JP / Robotoをlocale別に使用します。取得元・ウェイト・ハッシュ・ライセンスは [`assets/fonts/README.md`](../fonts/README.md) に記録しています。
