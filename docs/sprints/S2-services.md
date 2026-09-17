# S2-SERVICES — validated publications and document-local timestamp reuse

## Handoff

- Assignment: `docs/assignments/S2.md`, TEAM-4 / TEAM-019 / TEAM-021.
- Baseline: `a30b22893f736b72186739f1dd834de680c96fbf`.
- Branch: `codex/joe-tv-services-s2`, created only after clean-worktree and branch-absence checks.
- Exact implementation/test source commit: `a9dd5d7bf29ff78cfaca7b35da7034447643c10b`.
- R2 remains preserved on `codex/joe-tv-services-r2` at `73f722a2e2202c4f749c32ce46a4af94c9e5da1b`.
- This report is a subsequent documentation-only commit; its final SHA and clean status accompany the task handoff. PM integrates sequentially; independent QA/SecOps acceptance remains pending.

## Implemented behavior

`XMLTVGuideProvider.loadGuide` and `loadSportsSchedule` now validate a complete disk candidate before using it for throttled/offline fallback or a conditional request. An eligible 200 is parsed/decoded before its atomic write; ETag and success metadata change only after the write succeeds. Missing, empty, or whitespace-only response validators remove the prior ETag. Invalid 200 bodies retain the existing typed error, previous bytes, validator, and successful-refresh time; no new automatic retry or silent malformed-response fallback was added.

A 304 succeeds only with a validated cached representation. Missing/corrupt cache cannot supply `If-None-Match`, and an unexpected 304 leaves accepted state unchanged. The next eligible request is unconditional. Transport/write fallback returns only a validated prior result. Existing 401/404/503/other HTTP errors remain errors even when a valid old body exists.

The five-minute attempt floor is unchanged, with injected time replacing direct clock reads only for guide/sports publication methods. Attempts advance immediately before dispatch. Success advances only after accepted 200/304, not on throttle, offline reads, malformed data, or failed writes. Guide caches without known successful-refresh metadata return `.distantPast`; reading one does not create persisted freshness. Sports `generatedAt` remains the publisher's value. Validated parsed/decoded results are returned directly, avoiding a second parse of the selected representation.

The minimal internal initializer supplies synthetic configuration, URLSession, a defaults factory, cache directory, clock, and optional atomic-write closure. Its fully supplied path does not evaluate bundled configuration, `.standard`, or the normal cache location. The existing production initializer retains its previous dependencies and namespace behavior. Event-detail request/cache logic was left unchanged.

`XMLTVParser` now requires the document root to be `tv`, while preserving `<tv/>`, no matching stations/programs, and the existing row filtering. It does not add XMLTV schema validation. Each delegate owns its timestamp dictionary and four formatters. Identical normalized timestamp strings, including failed conversions, are reused only within that document. No global/cross-request mutable formatter or timestamp state was introduced.

## Owned changes

| File | Change |
| --- | --- |
| `SeasonsTV/Networking/XMLTVGuideProvider.swift` | Guide/sports validated cache selection and commit ordering, injected lifecycle dependencies, conservative unknown freshness, XMLTV root check and timestamp memoization. |
| `Tests/GuideCacheSmoke.swift` | Public-method asynchronous lifecycle tests with real isolated disk/defaults persistence and an intercept-all URLProtocol. |
| `scripts/test-guide-cache.sh` | Host-only Swift 5-mode runner, per-worktree `.build/ModuleCache`, no application target change. |
| `Tests/ParserSmoke.swift` | XMLTV-only acceptance additions; other existing tests unchanged. |
| `docs/sprints/S2-services.md` | This evidence and limitation report. |

No AppModel, Models, UI, project, backend, production endpoint, credential, or PM benchmark helper edits were made. S1's independently developed future correction commits were not imported. Competitive UI parity does not apply to these internal cache/parser contracts; the selected performance work follows the measured repository investigation.

## Correctness evidence

On implementation commit `a9dd5d7bf29ff78cfaca7b35da7034447643c10b`:

- `scripts/test-guide-cache.sh`: fresh compilation passed; guide and sports lifecycle matrices passed. The resulting executable was rerun after committing the unchanged source and passed again.
- `scripts/team-check.sh smoke`: fresh compilation and full existing smoke suite with new XMLTV cases passed. The resulting executable was rerun after committing the unchanged source and passed again.
- `sh -n scripts/test-guide-cache.sh` and `git diff --check`: passed.
- Both compilations emitted only the existing macOS FairPlay API deprecation warning at `FairPlayResourceLoader.swift:59`. No new diagnostic was observed.

The lifecycle suite runs 49 isolated scenarios across both publication types. Each harness creates a UUID defaults suite and temporary directory, uses a synthetic `.invalid` host/token and an ephemeral session, and disables URL cache, cookies, and credential storage. The protocol intercepts every request; unexpected hosts or extra requests fail locally and are asserted at cleanup. No request can fall through to the network. Cleanup removes only that harness's temporary directory and defaults domain. Provider recreation uses fresh instances of the dedicated defaults suite; this verifies persisted-store behavior within the test process, not crash/reboot durability.

The matrix asserts decoded content and exact body bytes, validator, successful-refresh time, attempt time, request count, route/method/auth/Accept/conditional headers, and guide fetchedAt/sports generatedAt. Cases include tagged/untagged/empty-tag replacement, valid 304, valid empty and unmatched XMLTV publications, every malformed body after good cache, missing/corrupt cache with invalid 200 or unexpected 304, unconditional recovery at the exact five-minute boundary, transport fallback/failure, throttled valid/missing/corrupt reads, seeded-cache and cold write failure, 401/404/503/500, and legacy unknown freshness followed by accepted 200/304. The write-failure seam throws before replacement; it does not manipulate real permissions or claim to emulate every filesystem failure mode.

Parser additions compare complete program fields and chronological order against independently constructed expected values. They cover all four accepted timestamp formats, positive/negative offsets, whitespace normalization, repeated valid/invalid timestamps, station declaration/filtering, start/end boundary exclusion, malformed start/stop values, empty documents, wrong roots, truncated/multiple-root XML, repeated independent parses, six concurrent parses, and a unique-timestamp document with 40 programs/80 different timestamps. Equal-start ordering is intentionally not given a new tie-breaker contract.

## Performance evidence

One fresh optimized compilation/run of the unchanged `scripts/benchmark-guide-parser.sh` completed on exact source `a9dd5d7bf29ff78cfaca7b35da7034447643c10b`. PM explicitly held QA's corrected app build for this window; Services reported completion and released the window immediately. No repeated benchmark run was needed.

Configuration: Apple Swift 6.3.3, Swift 5 language mode, `-O`, arm64 macOS 26.6.2 (25G83). The unchanged deterministic helper generates 588,650 bytes, 70 stations and 3,360 half-hour programs outside timing. Each complete parse selects 2,520 programs in an 18-hour window. One warm-up precedes five `ContinuousClock` samples:

| Sample | Milliseconds |
| --- | ---: |
| 1 | 28.01 |
| 2 | 27.37 |
| 3 | 27.82 |
| 4 | 27.88 |
| 5 | 27.76 |
| Median | **27.82** |

The range was 27.37–28.01 ms. The executable's count check passed on all six parses; the separate acceptance suite provides the complete-field correctness evidence. The only compilation diagnostic was the same pre-existing FairPlay macOS deprecation warning. Raw local output is in ignored `.build/s2-guide-benchmark.log`; parser smoke compilation output is in ignored `.build/s2-parser-smoke.log`.

These samples are consistent with the material repeated-timestamp benefit identified by PM's earlier [investigation](../research/guide-parser-performance.md). They are not a controlled simultaneous before/after comparison: PM's earlier baseline medians varied roughly 2–13 seconds under different host load. Do not infer a specific production speedup ratio or UI responsiveness budget from them. No new baseline compilation, unique-timestamp timing claim, profiler run, simulator measurement, or hardware measurement is included.

## Limits and remaining acceptance

- Source and host fixtures establish the bounded provider/parser behavior only. No simulator, real service, account, application cache, media, or credential operation ran. No backend deployment or device change is required.
- `AppModel.refreshEPG` still constructs its merged guide window with `fetchedAt: Date()`. This separate presentation-layer limitation is unchanged; S2 does not establish end-to-end UI freshness correctness.
- Body writes are atomic, but file and defaults changes are separate operations, not a crash-atomic transaction. Event-detail cache semantics remain outside this slice.
- A unique-timestamp document receives little memoization benefit and holds one entry per unique normalized timestamp for that document. The state is released when parsing completes. Host benchmark timings are workload/load-dependent and do not measure Apple TV navigation, input latency, network startup, or playback.
- QA must independently run the lifecycle/smoke/build checks against PM's assembled S1+S2 source and exercise affected fixture guide/focus/empty states. SecOps must independently review cache ordering, byte retention, conditional recovery, and test isolation before acceptance.
