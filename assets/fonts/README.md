# Bundled UI fonts

The app bundles fixed-weight TrueType files so Web, Android, and iOS use the
same font assets without a network request or an installed system font.

## Noto Sans JP

- Source: [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;600;700;800)
- Upstream: [google/fonts `ofl/notosansjp`](https://github.com/google/fonts/tree/main/ofl/notosansjp)
- Google Fonts webfont release: `v56`
- Weights: 400 Regular, 600 SemiBold, 700 Bold, 800 ExtraBold
- License: [NotoSansJP-OFL.txt](NotoSansJP-OFL.txt)

## Roboto

- Source: [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=Roboto:wght@400;600;700;800)
- Upstream: [google/fonts `ofl/roboto`](https://github.com/google/fonts/tree/main/ofl/roboto)
- Google Fonts webfont release: `v51`
- Weights: 400 Regular, 600 SemiBold, 700 Bold, 800 ExtraBold
- License: [Roboto-OFL.txt](Roboto-OFL.txt)

The files were retrieved on 2026-09-15. SHA-256 values are recorded below to
make replacement or auditing reproducible.

| Family | Weight | File | SHA-256 |
| --- | ---: | --- | --- |
| Noto Sans JP | 400 | `NotoSansJP-Regular.ttf` | `4593dfcdc70ee68852606c90d75dfc6e022feda12780a55615239c53c54ef086` |
| Noto Sans JP | 600 | `NotoSansJP-SemiBold.ttf` | `2c7c3e9c133e288e4c46573f139ac49eb93de013c3bfa70bd44873c69ec22685` |
| Noto Sans JP | 700 | `NotoSansJP-Bold.ttf` | `a3910e15eea0451ffbea62e894e951ea9f7c812c8b4b5e947593b6ecc2d4b057` |
| Noto Sans JP | 800 | `NotoSansJP-ExtraBold.ttf` | `1d9b643eed6250e7e62541844b9637bfc55168a471014684024c417f61289653` |
| Roboto | 400 | `Roboto-Regular.ttf` | `dece7c71bbe61710787f0839c722c65e87355dd2eb4a823e6b5488121ff81e4b` |
| Roboto | 600 | `Roboto-SemiBold.ttf` | `f478ba88b0292e685e487901dfbb1401457d32d6ebee4030cdfd5698235bffa8` |
| Roboto | 700 | `Roboto-Bold.ttf` | `35757eaa996b3359022f47f164a67ee9eac04971af24c5b8fbd4b89e844ff190` |
| Roboto | 800 | `Roboto-ExtraBold.ttf` | `8e2e0999f2abc8a2b1c761dd8bf3b88bd0d742191099b55c09775bc6713931ff` |

Only the four weights used by the tactical typography styles are registered.
