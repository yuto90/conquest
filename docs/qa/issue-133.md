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
| Restart recovery / initialization delay / ownership / unavailable storage | Controller cold-root recovery and initial-load gate; store ownership and recovery tests; opener failure stays retryable without fake zero/empty data |
| Unknown schema / corruption preservation | Store suite: version 0/999, version 1 with unknown tables, corrupt bytes preserved, schema snapshot validation; no reset or destructive recovery |
| Counts and game-time agreement | Controller production-loop arrival persists engine summary unchanged; repository `W2/L1/D1/A1/I1` fixture checks ledger/statistics/groups/recent/detail, completed-only metrics, nullable interruption and fastest exact conditions; rules/controller counter regressions remain in full suite |
| Native durable storage → controller → repository → providers → UI | `my_page_test.dart`: native opener restart retains stable profile, edited name/avatar, receipt/XP, 65s/4 dispatches/77 forces/3 captures; My Page values/recent row/detail agree with persisted data |
| Quit copy matches actual behavior in EN/JA | `quit_storage_qa_test.dart`: phone dialog says save is conditional and spectator/practice excluded; cancel retains in-progress match; normal quit persists abandoned/zero XP; write failure is unsaved, same DTO retry persists abandoned; spectator creates no match |
| Profile edit validation, cancel/discard, write/read failure, live providers, keyboard and scaled layout | `my_page_test.dart`, `profile_repository_test.dart` and history/detail widget tests; full suite covers shared screen navigation and active match preservation |
| Filter/profile isolation, ties/clock rollback, pagination/retry/stale responses | Repository exact 0/20/21 boundaries, combined filters, reversed-clock insertion, history generation/disposal tests and SQL read error tests; no zero/empty substitution |
| Web single writer, lease release, asset errors | `profile_storage.browser.dart` in headless Chrome: second writer/open rejected before DB writes; release/reacquire; HTML/wrong MIME/missing assets rejected and lock released |
| Bounded 10,000-row reads | Repository benchmark: 21 SQL rows/page, recent 5, scoped detail; full keyset traversal finds every ID once; measured queries/plans below |

Widget tests use `tester.runAsync` for real SQLite/isolate I/O. The new I/O
helper advances widget timers while waiting for stream cancellation/queued
writes, with a bounded timeout. This models test-harness scheduling, not a
production storage workaround.

## Executed commands and environment

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
| `fvm flutter test --reporter expanded` | Final run pending |
| `fvm flutter test --platform chrome test/profile_storage.browser.dart --reporter expanded` | Final run pending |
| `shasum -a 256 -c web/drift-assets.sha256` | Final run pending |
| `fvm flutter build web --release --base-href /` | Final run pending |
| `fvm flutter build ios --simulator --debug --no-codesign` | Final run pending |

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
Earlier committed measurements remain in `docs/player-profile-storage.md`.

| Read | Median µs | p95 µs | SQL rows | Plan |
| --- | ---: | ---: | ---: | --- |
| First page | 483 | 728 | 21 | match_history(profile_id) |
| Next page | 349 | 489 | 21 | match_history(profile_id, tuple cursor) |
| Deep page | 473 | 850 | 21 | match_history(profile_id, tuple cursor) |
| Combined filter | 395 | 983 | 21 | match_history(profile_id) |
| Statistics | 4410 | 4994 | 1 | match_execution(profile_id) |
| Difficulty groups | 6178 | 7950 | 2 | match_execution + temporary GROUP BY B-tree |
| Recent five | 431 | 1196 | 5 | match_history(profile_id) |
| Detail | 126 | 378 | 1 | unique match_id/profile_id index |
| Fastest (no wins) | 789 | 1062 | 1 | match_statistics(profile/status/session/difficulty/islands) |

History/detail correlate XP through the match index without multiplying rows.
Aggregates scan the scoped DB rows in SQL, not all records in Dart. RSS bytes:
224,755,712 before seeding; 251,756,544 after; 253,640,704 after reads. RSS includes
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

## Pending parent acceptance — do not mark passed from shell tests

Record exact integrated SHA, device/OS/browser, actions and artifacts for each:

| Area | Status / required evidence |
| --- | --- |
| Final iPhone and iPad UI | Pending: EN/JA, profile edit/restart, natural win/loss/draw vs stored totals, rematch/new map, abandoned vs interrupted, filters/20+ rows/detail, difficulty/island combinations |
| Layout/input/accessibility | Pending: portrait/landscape where supported, large text, keyboard focus/save/cancel, screen reader labels, touch targets; actual hardware and VoiceOver remain unknown until available |
| Final release Web | Pending: actual asset/header responses and storage choice, reload/page leave, profile retention, completed/abandoned records, two live tabs, closed/crashed owner recovery, unsupported/quota/read/write failure UI and retry |
| 10,000 rows in actual UI | Pending: scrolling/filtering/pagination and retained UI memory; native SQL benchmark does not prove browser/phone rendering performance |
| Final branch CI / main PR | Pending: integration HEAD `Verify My Page` and parent final PR gates; no deployment or main merge in this child |

The parent's earlier iPhone SE evidence was on a pre-133 revision and revealed
the obsolete quit text. It is not final-SHA acceptance. Final corrected-copy
device/browser testing resumes only after this branch is integrated.
