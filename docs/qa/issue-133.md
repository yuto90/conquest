# Issue 133: local profile / match history QA

Scope: [parent 126](https://github.com/yuto90/conquest/issues/126),
[QA 133](https://github.com/yuto90/conquest/issues/133), issues 127–132 integrated
into `feature/mypage`. Authentication/cloud synchronization/guest-account
migration remain deferred to [134](https://github.com/yuto90/conquest/issues/134).
Version remains `1.0.3+4`. This is integration evidence, not a release or a main
merge. The parent owns the final integration PR and device/browser acceptance.

## Repeatable automated acceptance mapping

All DB fixtures use isolated SQLite or a test-owned temporary directory. Faults
are injected through `StorageFaultHook`; no production database is altered.

| Acceptance / risk | Executable evidence |
| --- | --- |
| Missing/zero/normal/over-cap legacy XP; invalid/read failure; retry without duplicate import | `profile_storage_test.dart`: `legacy … survives repeated/concurrent initialization unchanged`, invalid values, read failure, migration rollback at after-profile/after-ledger/precommit; SharedPreferences key remains read-only |
| Final match and XP atomicity | Same suite: finalization rollback before match update, after match update, before XP insert, after XP insert, before commit; in-progress row and original XP survive each failure; identical retry commits once |
| Commit succeeded but acknowledgment lost | Same suite: native opener test verifies committed match/XP after the error, original receipt after a later reward, repeated replay and real isolate close/reopen; migration acknowledgment failure cannot reimport after restart |
| Duplicate completion / zero-XP receipts / difficulty rewards / uncapped MAX XP | Store serialized rewards/replay test and `match_persistence_controller_test.dart`: original receipt ten times for each difficulty, MAX ledger, losses/draws retain zero XP |
| Rematch / new map / delayed old save / result disposal | Controller suite: distinct IDs across reopen, both delayed-old-receipt variants, frozen DTO survives disposal, synchronous notifications and immediate rematches; lost-ack retry cannot replace newer result or edited profile |
| Restart recovery / initialization delay / ownership / unavailable storage | Controller cold-root recovery and initial-load gate; store ownership and recovery tests; `my_page_storage_error_test.dart` uses the production ProviderScope retry policy to expose initialization errors immediately and explicitly recover |
| Unknown schema / corruption preservation | Store suite: version 0/999, version 1 with unknown tables, corrupt bytes preserved, schema snapshot validation; no reset or destructive recovery |
| Counts and game-time agreement | Controller production-loop arrival persists engine summary unchanged; repository `W2/L1/D1/A1/I1` fixture checks ledger/statistics/groups/recent/detail, completed-only metrics, nullable interruption and fastest exact conditions; rules/controller counter regressions remain in full suite |
| Native durable storage → controller → repository → providers → UI | `my_page_test.dart`: native opener restart retains stable profile, edited name/avatar, receipt/XP, 65s/4 dispatches/77 forces/3 captures; My Page values/recent row/detail agree with persisted data |
| Quit copy matches actual behavior in EN/JA | `quit_storage_qa_test.dart`: phone dialog says save is conditional and spectator/practice excluded; cancel retains in-progress match; normal quit persists abandoned/zero XP; write failure is unsaved, same DTO retry persists abandoned; spectator creates no match |
| Profile edit validation, cancel/discard, write/read failure, live providers, keyboard and scaled layout | `my_page_test.dart`, `profile_repository_test.dart` and history/detail widget tests; full suite covers shared screen navigation and active match preservation |
| Filter/profile isolation, ties/clock rollback, pagination/retry/stale responses | Repository exact 0/20/21 boundaries, combined filters, reversed-clock insertion, history generation/disposal tests and SQL read error tests; `my_page_read_error_test.dart` makes real SQLite tables temporarily unavailable after initialization and verifies immediate error/Retry on My Page/detail plus restoration of the same profile/match/XP |
| Web single writer, lease release, asset errors | `profile_storage.browser.dart` in headless Chrome: second writer/open rejected before DB writes; release/reacquire; HTML/wrong MIME/missing assets rejected and lock released |
| Bounded 10,000-row reads | Repository benchmark: 21 SQL rows/page, recent 5, scoped detail; full keyset traversal finds every ID once; measured queries/plans below |

Widget tests use `tester.runAsync` for real SQLite/isolate I/O. The new I/O
helper advances widget timers while waiting for stream cancellation/queued
writes, with a bounded timeout. This models test-harness scheduling, not a
production storage workaround.

## Automated acceptance on the integrated application revision

Application/test revision: `8d8b8e8d838686bdc37ed2cbc77547cf24363a96`,
[PR 147](https://github.com/yuto90/conquest/pull/147), fast-forwarded into
`feature/mypage`. The following commands ran on that revision using the same
toolchain and Xcode environment described below:

| Command | Result |
| --- | --- |
| `fvm dart run build_runner build --delete-conflicting-outputs` | Passed; the current build_runner ignores the removed flag; generated sources unchanged |
| `fvm flutter gen-l10n` | Passed; generated sources unchanged |
| `fvm dart format --output=none --set-exit-if-changed lib test integration_test` | Passed, 112 files unchanged |
| `fvm flutter analyze` | Passed, no issues |
| `fvm flutter test --reporter expanded` | 595 passed |
| `fvm flutter test --platform chrome test/profile_storage.browser.dart --reporter expanded` | 3 passed |
| `shasum -a 256 -c web/drift-assets.sha256` | Both official assets match |
| `fvm flutter build web --release --base-href /` | Passed, 24.6s compilation |
| `fvm flutter build ios --simulator --debug --no-codesign` | Passed, Xcode build 10.3s |

PR 147's codegen/analyze/test/release Web, Android release APK and iOS Simulator
checks passed; Devin Review returned zero findings for that SHA. The Vercel
deployment job was skipped on the integration base, and is not counted as a
passed check or release-origin UI verification. The integration-push
codegen/analyze/test/release Web job (`111059238701`) also completed successfully
on this SHA; its logs include all 595 tests and release Web build. The final
main-PR CI is a separate gate.

The SQL read-error widget regressions fail on the previous revision with five
My Page spinners and one detail spinner. All six downstream asynchronous
read providers now disable Riverpod automatic retry; errors reach the existing
explicit Retry controls instead of remaining in loading/backoff.

## Earlier automated acceptance and environment

2026-10-02, macOS Darwin 25.5.0 arm64, FVM 3.2.1,
Flutter 3.44.8/Dart 3.12.2, Drift 2.35.0, SQLite 3.53.4.
`PATH="$HOME/.pub-cache/bin:$PATH"` is required on this VM.

| Command | Result |
| --- | --- |
| `fvm flutter test test/profile_repository_test.dart --reporter expanded` | 15 passed; fresh 10,000-row table below |
| `fvm dart run build_runner build --delete-conflicting-outputs` | Passed; generated sources regenerated |
| `fvm flutter gen-l10n` | Passed; EN/JA quit copy regenerated |
| `fvm dart format --output=none --set-exit-if-changed lib test integration_test` | Passed |
| `fvm flutter test test/my_page_test.dart test/quit_storage_qa_test.dart --reporter expanded` | 17 passed; storage/controller cases also included in final full-suite gate below |
| `fvm flutter analyze` | Passed, no issues |
| `fvm flutter test --reporter expanded` | 589 passed in 17s (575 baseline + 14 added cases) |
| `fvm flutter test --platform chrome test/profile_storage.browser.dart --reporter expanded` | 3 passed in headless Chrome |
| `shasum -a 256 -c web/drift-assets.sha256` | Both official assets match (macOS equivalent of CI's `sha256sum`) |
| `fvm flutter build web --release --base-href /` | Passed, including Wasm dry run; 28.1s compilation |
| `fvm flutter build ios --simulator --debug --no-codesign` | Passed; Xcode build 28.8s |

These full-suite/browser/build results were executed on
`6681f95620233831efaefc6971ffce20ee9a4647` in
[PR 143](https://github.com/yuto90/conquest/pull/143). Subsequent QA-document
updates do not change application/test code. Devin Review completed on that
commit with zero findings. PR checks and integration HEAD results are available
on the PR and in the child handoff; parent acceptance must use the final remote
`feature/mypage` SHA, not an earlier child SHA.

Native build uses the blueprint's Xcode 27.0 RC `DEVELOPER_DIR`, its `usr/bin`
at the front of `PATH`, and `FLUTTER_XCODE_IPHONEOS_DEPLOYMENT_TARGET=15.0`.
Repository deployment targets are unchanged. Compilation is not device UI proof.

The parent reported a pre-133 baseline of 575 passing tests at
`15ade798dec120aac9837b062edee900af506825`; it does not verify this revision.
Initial new-fixture runs exposed test harness scheduling, model identity
comparison and display-format mistakes, corrected without weakening required
behavior. Final results above replace those development runs.

## Fresh 10,000-row measurements

Real native SQLite in-memory executor, 10,000 persisted normal losses split
across two difficulties; 25 samples/query include assertions and decoding.
These observations are not phone/Web latency guarantees or timing thresholds.
These values were captured in the full 595-test run on `8d8b8e8`.
Earlier committed measurements remain in `docs/player-profile-storage.md`.

| Read | Median µs | p95 µs | SQL rows | Plan |
| --- | ---: | ---: | ---: | --- |
| First page | 709 | 2705 | 21 | match_history(profile_id) |
| Next page | 552 | 1164 | 21 | match_history(profile_id, tuple cursor) |
| Deep page | 482 | 901 | 21 | match_history(profile_id, tuple cursor) |
| Combined filter | 392 | 839 | 21 | match_history(profile_id) |
| Statistics | 4618 | 8727 | 1 | match_execution(profile_id) |
| Difficulty groups | 6762 | 9954 | 2 | match_execution + temporary GROUP BY B-tree |
| Recent five | 437 | 1259 | 5 | match_history(profile_id) |
| Detail | 122 | 341 | 1 | unique match_id/profile_id index |
| Fastest (no wins) | 1083 | 1277 | 1 | match_statistics(profile/status/session/difficulty/islands) |

History/detail correlate XP through the match index without multiplying rows.
Aggregates scan the scoped DB rows in SQL, not all records in Dart. RSS bytes:
201,605,120 before seeding; 227,835,904 after; 230,359,040 after reads. RSS includes
VM/DB/allocator and is not retained UI heap or a memory budget. The test traverses
all 10,000 IDs in bounded pages; UI state grows only with requested pages and is
released on refresh/disposal.

## Release Web storage requirements

- Secure context/HTTPS (localhost for tests) and Web Locks are mandatory. The
  writer lock is non-stealing; another live tab cannot write or recover its owner.
- Serve actual `sqlite3.wasm` as `application/wasm` and `drift_worker.js` as
  `text/javascript` or `application/javascript`, relative to the base URI.
  Missing assets/HTML SPA fallbacks must remain visible errors.
- Serve `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: credentialless` as configured in `vercel.json`
  (or equivalent isolation headers). Verify actual response headers and
  `crossOriginIsolated` on the release origin, including redirects/cache.
- Preserve the checked-in official WASM/worker checksums. Production rejects
  in-memory and unsafe IndexedDB choices; record the actual supported
  implementation (OPFS or supported IndexedDB variant) during parent testing.
- Headless lock/preflight tests do not prove a durable release-browser reopen.
  The Flutter browser-unit harness does not serve these production assets;
  actual browser reload/multitab/crash/reopen belongs to parent acceptance.

## Integrated UI acceptance

All results in this section use application/test SHA
`8d8b8e8d838686bdc37ed2cbc77547cf24363a96`. The subsequent QA-document-only
commit does not change application code, tests, dependencies, native resources
or Web assets. Its final branch/PR CI must still run. Earlier PR 143–146
recordings remain historical evidence and are not substituted for these runs.

| Environment | Executed UI acceptance |
| --- | --- |
| macOS, Chrome 153, Flutter release Web, EN/JA, normal zoom | Profile edit/save/discard; statistics/history/detail/Back; durable reload and page leave/revisit; natural wins/losses; read/write/quota refusal and explicit Retry; two live tabs/owner close; renderer crash; WASM/worker503 recovery |
| iPhone SE (3rd generation) Simulator, iOS 26.5, debug, EN/JA, text size large | Profile edit/discard and repeated process restart; unknown-result detail; natural defeat/NEW MAP/QUIT; same settings, new layout and distinct match IDs. Device rotation preserves the app's declared portrait-only UI |
| iPad mini A17 Pro Simulator, iOS 26.5, debug, EN/JA, maximum accessibility text | Cold START without blank screen; portrait/landscape profile/history/detail/Back; preserved 10,000-row fixture and 40-row detail return viewport |
| macOS VoiceOver, release Web | Actual caption output and VO-key navigation through profile input/save/discard, statistics, history, detail and Back; restored original profile name and VoiceOver OFF state |

### Web persistence and real I/O errors

Actual release responses used WASM `application/wasm`, JavaScript worker MIME,
COOP `same-origin` and COEP `credentialless`; secure context, Web Locks and
`crossOriginIsolated=true` were observed. Actual Drift selection was `opfsLocks`.
Clean production controls on two preserved origins each passed two reloads,
with one writer lock held and none pending. No instrumentation/control hook
was present in those controls.

The isolated fault harness prepended an OFF-by-default wrapper to the worker
response and threw `NotAllowedError` or `QuotaExceededError` immediately before
actual `FileSystemSyncAccessHandle.read/write`. Application source, build
files, SQL, DTOs and game outcomes were unchanged. This tests post-initialization
OPFS API refusal, not HTTP asset failure or physical disk exhaustion.

- Read refusal showed error/Retry on five My Page sections and detail at the
  approximately one-second observation. No automatic I/O retry was observed
  while idle. Explicit Retry failed visibly while refusal remained; OFF/Retry
  and reload restored the same profile/match/XP500.
- Natural win under write refusal retained the same match ID and frozen
  summary through three save attempts: 1:00, 14 dispatches, 309 forces, 6
  captures. OFF/Retry saved it once.
- Natural win under quota refusal retained the same match ID and summary
  through three attempts: 1:43, 37 dispatches, 575 forces, 10 captures.
  OFF/Retry saved it once. A preceding natural loss saved with zero XP.
- Each victory produced one XP INSERT. XP progressed 500 → 1000 → 1500;
  reload and page leave/revisit retained four completed matches (3W/1L).
- Second tab displayed ownership/error/Retry; Retry failed while owner
  remained and succeeded after owner close. A playing-owner renderer crash
  produced one interrupted record; a later reload did not add another.
- WASM and worker 503 produced error/Retry; restoring both assets to 200 and
  explicitly retrying retained the profile, XP and match counts.

One initial instrumented reload showed a spinner for at least 9.132 seconds,
but the observer did not reconnect to the new document and attempted CDP
evaluation on a blocking OPFS Worker. It did not reproduce after all old
targets/hooks were removed on either pure production origin. A new document
observer using page-only BroadcastChannel/SAB control then passed read,
recovery and reload. This is a harness limitation, not a demonstrated product
failure. Final cleanup acknowledged faults OFF, removed asset markers and
closed the dedicated tabs/workers/servers; existing native/browser data remained.

### Final observed fixture state

| Target | Profile / durable state |
| --- | --- |
| Web | `IO QA`, Icon4, profile `02a06088-ebf2-4d08-8052-d2c1420c628c`, XP1500, completed4 (3W/1L), abandoned0, interrupted1, history5 |
| iPhone | `PR146 EN`, Icon4, XP1500, completed9 (3W/6L), abandoned5, interrupted2, history16; native values also checked by read-only SQLite queries |
| iPad | Default localized name, Icon4, XP0, completed10,000 (all losses); test fixture was preserved |

### Evidence and remaining limits

The final integration PR carries screenshots and this acceptance record.
Full recordings and the testing report are delivered through the
[parent session](https://app.devin.ai/sessions/3df0731068b247e694441cc9aa4559e5):
`conquest-pr147-clean-reload`, `conquest-pr147-read-v2`,
`conquest-pr147-write-quota`, `conquest-pr147-two-tab`,
`conquest-pr147-native`, `conquest-pr147-voiceover` and
`conquest-pr147-final-supplement`. Raw auxiliary artifacts are named
`clean-state.json`, `io-v2.jsonl`, `write-evidence.json` and `report.md` in
the testing handoff.

Still unverified: physical iPhone/iPad and iOS VoiceOver, natural gameplay
draw, actual disk exhaustion, Android/Safari/Firefox UI, and strict 10,000-row
UI latency/RSS/p95. Private audio files are intentionally absent locally;
audible BGM acceptance was not performed, while automated audio controller
regressions passed. The iOS 26.5 Simulator Accessibility settings and search
did not expose VoiceOver; macOS VoiceOver acceptance does not establish iOS
hardware acceptance. Automated draw/transaction cases and SQL benchmarks
remain valid separate evidence, not substitutes for these unperformed checks.

No known product failure remained in the executed matrix. Main merge,
production deployment and store release are not performed. The final PR
requires review and explicit user approval; any additional mandatory hardware
acceptance must be completed or explicitly decided by the user before merge.
