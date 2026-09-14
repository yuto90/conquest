# Issue #63 browser verification

Code HEAD: `7f55e8c327d498e420ff93e334419e44f2fdccec`.
Baseline: `4108aaaa59b94b6455b0dab85039eadfa193a1cc`.
Environment: local Flutter release web build, headless Google Chrome, Japanese locale.

- Settings: all 36 island asset requests observed before match start.
- Normal match: 10 islands, 390x844. Dynamic troop count, capacity, faction and headquarters badge visible.
- Compact status acceptance: the large unified three-line dark panel is removed; each island now shows a faction-colored pill, a dark troop chip with white text, and capacity text outside the chip. The smaller composition exposes clearly more island artwork while keeping `100` and `/200` readable.
- Select player headquarters, wait >1 tick (120ms), then tap a neutral small island: dispatched force and observed capture from N durability10 to P with capacity50 (troops continue increasing after capture). Same outline and location visually retained.
- Selected source badge/frame and destination brackets visible; Semantics reports selected source/valid target.
- Pause and resume countdown verified. Images and values remain visible behind overlays.
- Additional verified configurations: 6 islands at390x844; 8 at280x500; 12 spectator at390x844 with1P/2P labels; 10 at1200x700 with portrait stage.
- Final full matrix run: no page errors or console errors. Result in browser-qa-result.json.
- No iOS/Android device run in this browser check.

## Compact status acceptance

- Status comparison at390x844: `before-status-390x844.png` / `after-board-390x844.png`.
- Status comparison at280x500: `before-status-280x500.png` / `after-selected-8islands-280x500.png`.
- The old before captures and new after captures use separately generated random maps and are not identical layouts. Deterministic headquarters anchors support the status comparison; the original `before-board-390x844.png` and `before-board-8islands-280x500.png` remain as baseline board-context evidence.
- In the selected280x500 layout, the capacity text remains separated from the bottom operation hint. Island positions and the100px headquarters frame are unchanged.

## Valid final screenshots

- before-board-390x844.png
- before-selected-390x844.png
- before-board-8islands-280x500.png
- before-status-390x844.png
- before-status-280x500.png
- after-board-390x844.png
- after-selected-390x844.png
- before-capture-390x844.png
- after-capture-390x844.png
- after-paused-390x844.png
- after-resume-countdown-390x844.png
- after-board-6islands-390x844.png
- after-board-8islands-280x500.png
- after-selected-8islands-280x500.png
- after-spectator-12islands-390x844.png
- after-board-10islands-1200x700.png

Exclude current.png and after-countdown-390x844.png: intermediate captures.

The initial existing browser session and fixed-delay scripting caused timing/locator failures, not app assertions. Final run used a fresh browser, explicit state waits and verified selected settings. Some Japanese glyphs initially failed to render; a fresh context with ignoreHTTPSErrors enabled produced complete glyphs and zero console errors. A local font-fetch TLS issue is inferred from this, not independently proven.
