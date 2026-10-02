# Player profile and match storage contracts

This document is the shared boundary for issues #127–#133 of
[#126](https://github.com/yuto90/conquest/issues/126). The integration branch
`feature/mypage` was created once from `main` at
`7961d67aefd31c09164f287c7a3751b996e6f758`. Subissue PRs target that branch;
only the parent owns the final integration PR to `main`.

## Ownership and identity

- `GameConfiguration`, `GameResult` and `MatchSummary` remain the game truth.
  `lib/profile/` contains immutable snapshots and interfaces, not a second
  game engine. No DB, migration activation or controller wiring occurs in #127.
- `profile_id`: UUID identifying a durable local storage scope. Generate with
  an injected `UuidGenerator` only when creating a new profile; persist it and
  reuse it after restart. Display name, avatar and rank are not identity.
- `match_id`: UUID identifying one actual playable match. REMATCH and NEW MAP
  both create new IDs, even with identical settings/board. Never persist the
  controller's existing process-local `match-N` as a key.
- `execution_id`: UUID generated once by the root-owned `MatchContextFactory`
  per application execution, not per controller, screen or match. It identifies
  a writer for recovery and Web ownership. It is not a profile or auth account.
- `user_id`: future authentication subject, distinct from all three IDs. A
  future account can bind multiple profiles. No auth/cloud SDK, service
  credentials, cloud synchronization or login UI is introduced in this work.
- UUIDs are canonical lowercase text, never array indexes, localized names or
  timestamps. `SecureUuidGenerator` emits UUID v4 using `Random.secure`.
  UUID/UTC clock interfaces can be replaced by deterministic test values.

## Eligible sessions

Eligibility requires **explicit** `SessionOrigin.gameplay`, `SessionKind.normal`
and `GameMode.playerVsCpu`, with a supported normal island count. Difficulty or
island count alone cannot establish origin. `newMatch` returns null for excluded
sessions; `MatchRecord` rejects excluded contexts as a second boundary.

| Source / final state | History | Completed metrics / win rate | XP |
| --- | --- | --- | --- |
| Normal victory | completed / win | Included | Existing victory reward, once |
| Normal defeat | completed / loss | Included | 0 |
| Normal draw | completed / draw | Included | 0 |
| REMATCH / NEW MAP | New UUID, same rules | Included upon completion | Once per new match |
| Explicit quit after playing starts | abandoned, outcome null | Excluded; separate count | 0 |
| Previous dead execution's unfinished match | interrupted, outcome null | Excluded; separate count | 0 |
| Countdown cancellation before first playing | No row / no match context | Excluded | 0 |
| Spectator, including normal island counts | No row | Excluded | 0 |
| Practice, including a future normal-sized lesson | No row | Excluded | 0 |
| Preview, CPU forecast, synthetic test sessions | No row | Excluded | 0 |
| Future daily session | Reserved `daily`, currently excluded | Separate policy in #113 | Separate policy |

Tests of normal persistence explicitly use gameplay origin; synthetic engine
simulations use test/preview/forecast origin and cannot accidentally write.

## Start, terminal state and retry boundary

```text
first playing boundary -> retain one MatchStartContext -> in_progress
  -> completed (known result, end time and all metrics)
  -> abandoned (known quit time and current summary; no outcome)
  -> interrupted (recovery time only; end time/metrics/outcome unknown)
```

#129 calls `newMatch` once at the first playing boundary (after countdown),
retains its context and sends `recordStart`. Pause/resume, provider rebuild,
rotation and notification reuse that object. Never create another UUID in
`Widget.build`, a result listener or a retry. Each new rematch/new map calls the
factory again. Controller lifetime must not determine the persistent identity.

Freeze `MatchCompletion.fromGame` once at result determination, using the same
context and original end time. It copies the existing summary, requires exact
agreement with `GameResult.elapsedMs`, and validates player win/loss/draw.
It deliberately ignores result-screen XP/rank enrichment: receipt rendering
must not create a different completion or trigger another award.

`MatchCompletionService` is the root write boundary. #128/#129 implement:

1. Serialize profile initialization/migration and subsequent mutations.
2. In a DB transaction, locate the start by `match_id` and require identical
   immutable start fields (including profile, execution, origin and versions).
   Same start is idempotent; different contents conflict. A delayed identical
   start cannot revert a terminal record.
3. Only `in_progress` can enter a terminal state. An already finalized identical
   DTO returns the **original** `MatchCommitReceipt`, including original XP
   before/after, even if other matches have changed current XP. Use
   `requireSameFinalization` inside the transaction; different content throws
   `MatchCommitConflict`. Completed vs abandoned/interrupted also conflicts.
4. Final record plus eligible XP entry commit atomically. Return a receipt only
   after durable commit; throw on failure, never report an in-memory success.
   Zero-XP terminal receipts still preserve their original XP snapshots.
5. Keep failed frozen DTOs in a root queue during this application execution;
   retry the same DTO/end timestamp. Screen disposal does not cancel valid old
   saves. Apply a delayed receipt to UI only if its match ID is still current.
   Unsaved data can be lost on forced process termination.

Recovery requires exclusive writer ownership and proof that the **specified old**
execution is dead. Do not recover on ordinary backgrounding or recover another
live Web tab. #128 implements persistent Web owner locking; #129 wires cold
start recovery. No interrupted board is resumed. `recovered_at_utc` describes
discovery, not the unknown match end.

## Metrics and NULL semantics (metrics version 1)

| Persistent value | Existing source / meaning |
| --- | --- |
| `elapsed_ms` | `GameResult.elapsedMs` = frozen `MatchSummary.elapsedMs`; game time only |
| `dispatch_count` | `playerDispatchCount`: established positive player dispatches, including allied reinforcements |
| `forces_sent` | `playerDispatchedForces`: sum of forces on those established dispatches |
| `captures` | `playerCaptureCount`: neutral/CPU -> player ownership transitions, including recaptures |

Selections, refused commands, same-owner attacks, equal-force attacks without
ownership change, CPU actions and forecasts are not additional counters.
Concurrent arrivals already counted by the engine are copied once. Persistence
and UI never independently recount events.

All known counts, elapsed milliseconds and XP values must be non-negative.
Validation is runtime validation, including release builds; asserts alone are
insufficient. Known zero is distinct from unknown null. In-progress and recovered
interrupted rows have null metrics. Abandoned rows retain the known summary but
are excluded from completed aggregates. Completed rows require every metric.

UTC timestamps normalize to UTC at millisecond precision and persist as integer
epoch milliseconds; reconstruction cannot change idempotency equality.
They are display/order data; **never subtract them to obtain match duration**.
A clock adjustment may make end time earlier than start; that is allowed and
does not modify game elapsed time. Missing end times are not replaced by recovery
time or zero. `stats_started_at_utc` is recording activation, not an invented
installation date.

## Read contracts and UI boundary

`PlayerProfileRepository` exposes profile/XP/statistics subscriptions, editing,
difficulty aggregates, fastest conditioned victory, bounded history and detail.
Riverpod adapters in #130 inject this interface; Widgets cannot use SQL or
SharedPreferences. Failures throw or emit stream errors, not empty data.

- Completed = wins + losses + draws. Win rate = wins/completed, undefined/null
  for zero completed matches (render `—`). Abandoned/interrupted are separate.
  Actions and total time sum **completed only**; label time as completed-match
  time, not total application play time.
- Fastest victory is MIN(elapsed_ms) for exact difficulty **and** island count;
  no qualifying win returns null, including legacy-XP-only profiles.
- Current XP comes from the ledger; rank and progress use existing `RankCatalog`.
  Do not persist another authoritative total, win rate or rank in `profiles`.
  Do not join XP rows in a way that multiplies match counts.
- History order is `(started_at_utc DESC, match_id DESC)`. Use strict keyset
  `(time < cursor.time OR time = cursor.time AND id < cursor.id)`. Fetch at most
  limit+1 to determine continuation, never load all history in UI. Default page
  20, recent 5, valid requested limits 1–100. Cursor stores profile/filter scope;
  `requireScope` rejects cross-query reuse. Changing filters resets cursor.
- Detail always scopes both profile and match IDs. It returns the stored
  configuration/metrics/XP, not the current controller state. Unknown metrics
  remain null and render `—`. History entries/pages are immutable.
- Profile edits contain only display name/avatar, never XP/history/identity.
  Repositories validate trimmed 1–20 graphemes, no control characters, and
  bundled avatar keys before saving. Null name is the unset default, localized
  by UI; unknown stored avatar keys render a generic icon. UI preserves pending
  edits on failure. Full edit validation/UI belongs to #130/#131.

#131 owns the common profile header and two tabs (STATS/HISTORY); #132 supplies
the history tab and detail route using the same repository/filter/cursor contract.
Opening/returning preserves configuration and the generated board. Loading,
empty, filtered-empty, additional-page failure and storage failure are distinct.

## Storage and versions for downstream implementation

#128 creates `profiles`, `match_records`, `xp_entries`, `storage_meta` with foreign
keys on every connection, profile-consistent XP, runtime/SQL constraints matching
these DTOs and indexes for history and aggregation. Preserve stable enum storage
keys supplied here, never `.index` or translated labels. `origin` is eligibility
provenance retained in the start context; only approved normal gameplay is
persisted in this initial schema.

- `schemaVersion`: Drift schema compatibility, owned by #128 migrations.
- `app_version`: actual application build/version for diagnostics.
- `rules_version`: explicit engine rules revision, initial `1`; update when
  gameplay semantics change, independently of the app or DB schema version.
- `metrics_version`: initial `1` above. Historical meanings are not silently
  reinterpreted; future changes need an explicit compatibility policy.
- `reward_version`: initial `1`, representing existing victory rewards
  Very Easy=500, Easy=1000, Normal=1500, Hard=3000. #129 reuses `victoryXpFor`
  and `RankCatalog`; it removes the independent `recordVictory` path when
  enabling DB writes. Result XP is receipt output, not completion input.
- Future award `catalog_version`: separate from all the above.

XP ledger uses unique `(match_id, reason)` for victory rewards. Legacy import has
an independently stable unique entry ID (do not rely on nullable UNIQUE match
IDs), and the imported value is not a past match. Profile creation, import and
marker commit together. Keep the old SharedPreferences key read-only after
cutover; never invent wins from it or discard above-max-rank XP. Invalid values
and read errors cannot become successful zero imports. #128 provides migration
parts only; activation is atomic with #129's XP write switch. Unknown/corrupt DB
must not be deleted or silently replaced by memory storage.

## Shared boundaries with #124 / #125

#124 is rank badge presentation only. My Page works with existing localized rank
text plus a generic icon until a shared badge exists; badge artwork is not a
storage key, metric, XP source or prerequisite for this feature.

#125 consumes the **same stable ID, frozen start and completion** for awards.
It must reuse these counters, capture eligible assignments at start when its
catalog is introduced, and join the same durable finalization boundary. The
earlier separate SharedPreferences award-profile proposal must not become a
second authoritative match/XP write path. Award evaluation/catalog migrations
are separate work; no ribbons, medals, extra XP or award tables are added here.
Any future award persistence needs atomic consistency with finalization, stable
IDs and an explicit catalog version, including repeat-notification handling.

## Verification

### Durable storage foundation (#128)

`ProfileStorage.open(executionId: ...)` owns a platform executor and exclusive
writer lease. It opens and checks schema version 1, table/column identities,
SQLite integrity and foreign keys; it does **not** initialize a profile or read
legacy XP. Close the root-owned storage only after its queued saves finish.

`storage.store.initialize(SharedPreferencesLegacyXpSource())` is the explicit
cutover component for #129. It creates the profile, `legacy:<profileId>` ledger
entry and migration marker in one transaction. `null` and zero import zero;
invalid values/read failures roll back and stay retryable. Repeated initialization
never reads/reimports the source. The old key is never written or removed.
Read `storage_meta.execution_id` before initialization if needed for recovery:
initialization records the current owner. An exclusive lease is required before
recovering a specified old execution; the current execution cannot be recovered.

Native uses an isolated SQLite executor in Application Support and an exclusive
lock file. Web uses the non-stealing `conquest_profile_writer_v1` Web Lock before
opening `conquest_profile`; in-memory and unsafe IndexedDB implementations throw.
Asset preflight rejects missing files, SPA HTML fallbacks and wrong MIME. The
WASM/worker URLs resolve relative to the document base URI. Serve the headers in
`vercel.json` (or their equivalent on another host); never remove the writer lock
to make an unsupported browser work. Database errors preserve the original file.

Reproduce assets/schema sources from the repository root:

```bash
bash script/fetch_drift_web_assets.sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart run drift_dev make-migrations
fvm dart run drift_dev schema generate drift_schemas/profile test/drift/profile/generated
fvm flutter test test/profile_storage_test.dart --reporter expanded
fvm flutter test --platform chrome test/profile_storage.browser.dart --reporter expanded
```

The checked-in worker and WASM come from the official Drift 2.35.0 release and
are checked against `web/drift-assets.sha256`. Never edit generated Dart/schema
fixtures or those assets by hand. Future schema changes must bump `schemaVersion`
and provide a tested upgrade; unknown versions/tables/columns are refused without
reset. `StorageFaultPoint` hooks inject failures inside the migration/finalization
transactions for rollback/retry fixtures. Receipt snapshots, including zero XP,
are persisted on every terminal match. Reward version is the contract value `1`.

Chrome unit tests cover writer exclusion, release/reacquisition, wrong MIME and
missing assets. #133 additionally verifies durable browser reload, actual
OPFS/IndexedDB selection, two-tab crash/restart behavior and device/UI workflows
after #129 activates the production path.

`Verify My Page` runs on every push to `feature/mypage` and PRs targeting
`feature/mypage` or `main`, without path-based skips. It records the tested SHA,
uses FVM 3.2.1/Flutter 3.44.8, runs build_runner (Riverpod now, Drift later), l10n,
format, generated-source diff, analyze, full tests and release Web build. It has
read-only permissions and no deployment, audio downloads or secrets. Existing
production workflows/security are unchanged. Push validation checks actual
integration HEAD; final main PR checks the proposed merge. #133 additionally
owns integrated iPhone/iPad/Web UI and storage failure/restart validation.
