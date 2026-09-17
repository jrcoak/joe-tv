# SECURITY-S1-S2 — fixture review and cache correctness contract

## Assignment and outcome

Governing revision: **TEAM-4**, with TEAM-019 continued bounded cycles. Reviewed candidate/start HEAD: `f394d4d356851092ae579051cff5a5a667d53cdb`. Task: `01a0ad34-c2ad-7e22-ae18-3468ca71fa88`; worktree: `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV`; branch: `codex/joe-tv-secops-s1-s2`. Clean status and branch absence were confirmed before creating the branch. Completed `codex/joe-tv-secops` remains preserved at `013b8868ee63f6b30a24828a99cef010fc5e95ed`.

**No S1 security blocker identified in the inspected source.** The documented navigation fixture's reachable UI paths avoid provider requests and normal preference writes. One nonblocking qualification concerns eager construction of default services; this is not proof that the fixture reads no normal configuration. QA still owns runtime/build acceptance.

**S2 recommendation:** fix validation and metadata ordering within `XMLTVGuideProvider`, with isolated lifecycle tests. Preserve existing route/auth boundaries, namespaces, normal provider behavior, and valid empty listings. Competitor parity is not applicable: fixture isolation and cache/ETag/freshness consistency are internal correctness contracts, not competitive product features.

Only this report is changed. Source inspection and repository Git checks are the evidence; no application execution, build, probe, network operation, real account/configuration/cache read, or other worktree edit was performed.

## S1: navigation fixture isolation

Reviewed the `f394d4d` changes to `SeasonsTV/App/AppModel.swift`, `SeasonsTV/Views/RootView.swift`, and `SeasonsTV/Views/JoeTVExperience.swift`; traced their dependencies through `JoeTVApp.swift`, `PlayerScreen.swift`, `Models.swift`, and client/provider initializers. Compared the claims in `docs/sprints/S1-app.md` with these entrypoints.

| Entry/boundary | Source evidence and conclusion |
| --- | --- |
| Launch and normal settings | `AppModel.init` (`AppModel.swift:154–254`) computes the navigation flag only under `#if DEBUG`. It redirects all initializer preference reads/writes to `appDefaults`, assigns that object to `self.defaults`, and resets only `com.jrcoak.joetv.debug.navigation`. The preference mutation methods, `persistFavoriteChannels`, and `adoptNewDefaultFavoritesIfNeeded` use that stored property. No introduced `.standard` write or reset of the normal domain was found. The nonfixture alias is the supplied defaults object, preserving prior behavior. |
| Session/Keychain operations | Navigation initialization skips `LegacyScheduleCredentialCleanup.run`, configures the fixture, and returns before `Task { await restoreSession() }` and before older fixture setup. `JoeTVApp` creates the model and pauses on backgrounding; it adds no independent restore request. `RootView.CatalogView.destinationBar` disables refresh, metadata refresh, Fantasy settings, and sign-out menu actions in navigation mode. No new reachable sign-in, cookie-clear, or account operation was identified. |
| Guide/channel settings | `AppModel.refreshEPG(for:around:)` returns before reaching either Very Local or XMLTV when the fixture is active. Channel enable/disable/favorite actions therefore mutate fixture preferences and retain static fixture guide data. `reload` and `loadSportsSchedule` likewise return before normal network work. |
| Playback and previews | `configureNavigationDebugFixture` builds every channel and both baseball feed options with `PlaybackRequest(endpoint: "debug", ...)`, and no artwork URLs. `makePreviewSession(for:)` and `makePlaybackSession(for:option:)` return `PlaybackSession(debugTitle:)` before `SeasonsClient.resolveStream`. That initializer creates an empty `AVPlayer`, not a media asset. Home, direct guide tune, details Watch channel now, Sports feed choice, and Quick Switch use these identities. The guide's muted focus preview follows the same local path. |
| Metadata and Fantasy | Fixture guide/schedule/detail providers are nil; `prefetchSportsEventDetails` and `focusSportsEvent` guard provider availability before requests. Fixture state sets Fantasy disabled. `JoeTVSportsView` clears the older Fantasy display flag on appearance, its Fantasy control requires `fantasyZoneEnabled`, and `refreshFantasyZone` independently requires enabled/configured Fantasy state. `PlayerScreen` refreshes Fantasy only for Fantasy playback presentation. No fixture data supplies that presentation. |
| Release behavior | The navigation flag is false outside Debug, fixture construction is Debug-only, and the new early returns are Debug-only. This is source evidence, not a successful Release build claim. |

### Qualification: default services are created before the fixture branch

**Confidence: high; source-observed; nonblocking.** `JoeTVApp` calls `AppModel()` with default arguments. `AppModel.init` still defaults `epgProvider` to `XMLTVGuideProvider()`. That provider's initializer (`SeasonsTV/Networking/XMLTVGuideProvider.swift:64–94`) reads bundled Media API configuration and four refresh/attempt values from `UserDefaults.standard`, and computes normal cache paths, before AppModel discards it in fixture mode. It does not read cache contents, issue a request, or write these values in the inspected initializer. Other default clients also construct their ordinary sessions; constructing `SeasonsClient` is not a sign-in or a cookie deletion.

Thus S1-app's claims about isolated **fixture preference mutations**, skipped credential cleanup/restoration, and nil retained metadata providers are supported. A broader claim of “no normal configuration is ever read” would be incorrect. No such stronger guarantee should be attached to runtime screenshots. If that guarantee becomes necessary, App can select the fixture before constructing real default providers, or provide lazy dependencies; it is unnecessary to redesign all clients for this S1 review.

The fixture is also not a universal network-denying model: direct calls to `restoreSession`, `signIn`, `loadESPNPlus`, or `signOut` retain their normal behavior. No new fixture UI route to those methods was found. QA should use the documented navigation entrypoint and unset older flags as instructed, rather than infer that arbitrary method invocation is safe. This limitation does not introduce a production vulnerability or justify blocking ordinary S1 navigation work.

## S2: confirmed cache defects and exact paths

All paths below are in `SeasonsTV/Networking/XMLTVGuideProvider.swift` unless specified otherwise. These defects predate S1 and are confirmed by control-flow inspection, not a new runtime reproduction.

| Path | Current result | Small correction needed |
| --- | --- | --- |
| Guide 200 | `currentGuideData` checks only nonempty data, atomically writes it, stores ETag, and calls `recordRefresh`; `loadGuide` parses afterward. Nonempty malformed XML can replace good disk data and advance freshness before rejection. | Validate the complete document before body or accepted metadata changes. |
| Sports 200 | `currentSportsScheduleData` writes body/ETag before `loadSportsSchedule` decodes. A later decode failure leaves an invalid body and new ETag, although successful-refresh time does not advance in this particular case. | Decode the complete snapshot before replacement. |
| Guide 304 | Any readable cached bytes qualify; `recordRefresh` runs before the later XML parse. Corrupt bytes can be declared freshly validated. | A 304 can revalidate only a successfully validated cached representation. |
| Sports throttle/offline/304 | `loadSportsSchedule` calls `recordSportsRefresh` after every successful decode, including throttle hits and transport-error fallback. Reusing old data moves its successful-refresh time forward. | Move recording to accepted 200/304 branches only. |
| Conditional GET | Guide/sports send a stored ETag even if body is missing or corrupt. A 304 without usable bytes cannot recover the representation. Successful 200 without ETag leaves the old ETag behind. | Send a validator only with a validated cached body; replace or remove it on successful 200. |
| Throttle/offline | Readable bytes are treated as a fallback without first establishing validity. `lastAttempt` is recorded before dispatch, appropriately separate from success, but callers decode only after the selection. | Validate cached candidates before using them. Retain attempt throttling and distinguish it from successful refresh. |

`loadSportsEventDetail` already decodes/checks identity before its 200 write and is a useful local pattern. Keep detail cache behavior out of this slice unless tests expose a necessary shared change. No backend or publisher installation change is required for these client defects.

## Minimal semantics for the implementation

Use the existing provider and public protocols; no database, cache framework, credential change, or new approval flow. A small private validated-candidate/result type or validation closure is sufficient. Validate the body on every path that can supply it, including restored disk data; avoid duplicating full parses when the decoded result can be reused.

1. **Separate attempt time, successful validation time, and publisher time.** Record an attempt only when dispatching a request. Record successful refresh only after a valid 200 has been accepted/written, or a 304 has revalidated a usable cached representation. Keep sports `generatedAt` unchanged from the decoded publication. Throttled reads, network-error fallback, malformed bodies, and failed disk writes do not advance successful-refresh time.
2. **Validate meaning without requiring nonempty listings.** Guide acceptance requires a successfully completed XML parse with the XMLTV `tv` document root; `<tv/>` and a valid guide with no programs matching the current station/time window are valid. XML syntax success alone currently accepts unrelated XML, so `<html/>` or a well-formed error document must not count as a valid empty guide. Preserve current row filtering; do not add a full XMLTV schema or require every programme row to be valid. Sports acceptance uses `SportsScheduleDecoder` and its existing required fields/types; a valid envelope with `events: []` is valid. Zero-byte, truncated, wrong-root, or undecodable data is invalid. Do not reject empty lists on count alone.
3. **Commit accepted 200 data in order.** Validate first, perform the existing atomic body write, then update ETag and successful-refresh metadata. If the new 200 has no nonempty ETag, remove the old ETag rather than retaining a validator for a different representation. A validation/write failure leaves the previous good body/ETag/refresh values unchanged; the new attempt timestamp may advance. Separate file/defaults writes are not a crash-atomic transaction, and this narrow fix should not claim they are.
4. **Retain the existing malformed-response error contract.** Recommend throwing the typed `invalidGuide`/`invalidSportsSchedule` error for an invalid 200 while preserving the old disk cache, rather than silently inventing new stale-result UI semantics. AppModel's existing `refreshEPG` retains its in-memory window on failure and `refreshSportsSchedule` retains its previous snapshot. A later throttled read can return the preserved, validated disk copy. A cold launch may still show a failure for the initial malformed fetch; immediate stale fallback for malformed 200 would be a separate deliberate behavior change, not necessary to repair corruption.
5. **Conditional requests require usable bytes.** Read/validate the old candidate before constructing the request. Attach `If-None-Match` only when that candidate is usable and its stored ETag exists. A 304 returns only that validated candidate and may advance successful-refresh time; keep the associated ETag. A 304 with no usable candidate yields the typed invalid-response error and leaves accepted state unchanged. Do not add an automatic retry loop. The next eligible request is unconditional when no valid cache exists.
6. **Preserve bounded retries and honest fallback.** Keep the existing five-minute attempt throttle. During it, return only a valid cached candidate; if none exists, return `refreshThrottled` without dispatch or a success timestamp. After it expires, missing/corrupt cache must not prevent an unconditional fetch. On transport/filesystem failure, retain existing fallback behavior only when the old candidate validates; otherwise surface failure. Preserve existing explicit 401, 404, 503 and other HTTP error behavior; do not reinterpret authorization rejection as a successful read.
7. **Do not fabricate a refresh time for legacy cache.** `loadGuide` currently uses `lastRefresh ?? Date()`. If a valid cached body lacks successful-refresh metadata, do not present the current clock as a fetch/revalidation. A conservative `.distantPast` fallback fits the current nonoptional `Date` without a model migration; successful 200/304 establishes the real time. Keep persisted metadata absent until such success. If Services prefers another representation, name it in its handoff and test that cache reads do not become fresh.

Freshness scope is specifically the provider's persisted refresh values and returned guide window. `AppModel.refreshEPG` currently constructs a merged guide window with `fetchedAt: Date()` (`AppModel.swift:1005–1010`). This is a separate existing presentation-layer limitation, so S2 must not claim end-to-end UI freshness is fixed by changing the provider alone. No AppModel edit is needed for the bounded cache-integrity slice.

## Meaningful isolated tests

Services should add the smallest internal initializer/test seam supplying **synthetic configuration, isolated defaults, a unique temporary cache directory, an injected clock, and a stub URLSession**. Production defaults remain unchanged. The test path must not evaluate `.bundled`, `.standard`, or the user's cache location when injected dependencies are present. Use an ephemeral session with cache/cookie storage disabled and an intercept-all URLProtocol (unexpected requests fail locally). Tests instantiate the provider, not AppModel, and never call credential cleanup. Destroy only their own temporary directory and defaults suite. No sleeps, real token, account, publisher, network, or simulator is needed.

Run the matrix for **both guide and sports**, asserting returned content/error, exact old/new body bytes, ETag presence/value, successful-refresh timestamp, attempt timestamp, and captured request count/headers. Recreate the provider against the isolated store in key cases to catch persistence defects, not only in-memory behavior.

| Case | Required observation |
| --- | --- |
| Valid 200 replaces valid old body | Decoded new content and persisted bytes agree; ETag changes; success and attempt advance to injected time. |
| Valid 200 without ETag | New body accepted; prior ETag removed; next eligible request has no stale conditional header. |
| Valid empty guide/sports | `<tv/>`, valid guide with zero matching programs, and complete sports envelope with `events: []` all succeed and replace prior data normally. |
| Invalid 200 after good cache | Truncated payload, zero bytes, wrong XML root, and sports invalid required-field/date cases throw the appropriate typed error; old body/ETag/success remain exact; attempt advances. Immediate throttled call returns old valid data without a second request or freshness change; recreated provider does the same. |
| Invalid 200 without good cache | Missing and corrupt cache variants cannot be returned as usable data, cannot store the new ETag, and do not acquire a success timestamp. Repeated call within the attempt interval is bounded; next eligible unconditional valid 200 recovers. |
| 304 with valid cache | Request carries old ETag; body stays byte-identical; successful-refresh advances; publisher `generatedAt` does not change. |
| Missing/corrupt body with stored ETag | At an eligible attempt, no `If-None-Match` is sent. A valid 200 repairs cache. An unexpected 304 fails without advancing success or replacing accepted metadata; advancing clock allows an unconditional recovery request. |
| Transport failure with valid cache | Cached decoded data is returned; body/ETag/success and sports `generatedAt` stay unchanged; attempt advances once. Include a new provider instance loading the cache. |
| Transport failure without usable cache | Failure remains a failure; no fabricated empty-success result or fresh timestamp. Corrupt bytes must not escape through fallback. |
| Throttle with valid/missing/corrupt cache | Zero requests; valid candidate only is returned; invalid/missing returns throttled error. No attempt/success mutation merely from a throttled call. Advance injected time instead of sleeping. |
| Disk replacement failure | With a seeded good body, an isolated failing write leaves body/ETag/success unchanged; any fallback uses only the validated old body. Do not chmod real cache directories to simulate failure; use a test seam or isolated failing target. |
| HTTP status regression and legacy timestamp | 401/404/503 remain their existing typed errors without success updates. A usable legacy guide cache without refresh metadata returns a conservative time on throttle/offline paths; a later valid 200/304 establishes success time. |

Do not add tests that simply mirror a helper's internal branches. Assert the public `loadGuide`/`loadSportsSchedule` outcomes plus persisted state and captured requests. New tests need a PM-assigned runner/file allocation; `Tests/ParserSmoke.swift` remains shared. Existing parser smoke coverage is regression support, not a substitute for this network/cache lifecycle matrix.

## Implementable S2 checklist and ownership

- [ ] PM assigns Services `XMLTVGuideProvider` guide/sports methods, minimal root validation, and an isolated lifecycle test entrypoint; serialize any shared test/runner edits.
- [ ] Validate network and cached bodies before selection/commit; keep structurally valid empty publications valid.
- [ ] Write body before ETag/success metadata; remove stale ETag on an accepted untagged 200.
- [ ] Move sports success recording out of unconditional `loadSportsSchedule`; require valid cache for conditional GET/304, throttle and offline fallback.
- [ ] Preserve good state on rejection, preserve five-minute attempt throttling, and recover missing/corrupt cache with the next eligible unconditional request.
- [ ] Run the isolated matrix; QA independently checks exact integrated source and existing smoke/build. SecOps reviews ordering and isolation without real-service probes.
- [ ] Handoff names tested commit, tests/results, unchanged production boundaries, and the remaining AppModel merged-window freshness limitation. No release, backend, or credential operation is part of this slice.

## Checks and limitations

Completed source/diff inspection, required team/spec/assignment reads, clean/branch-absence checks, and exact-baseline confirmation. S1 isolation conclusions are source-based, not observed traffic; S2 rows are proposed acceptance tests, not executed results. No smoke/build, Swift execution, simulator/device, service probe, or secret/cache read ran in this task. QA owns the current runtime and build. Only `docs/sprints/S1-S2-secops.md` is eligible for staging; final handoff supplies its exact commit, whitespace/scope check results, and clean status.
