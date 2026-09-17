# S2-SECOPS — independent provider and test review

## Verdict and provenance

**Accept the reviewed source for sequential integration and independent QA. No concrete blocker or required source correction identified within the S2 contract.** This is a source-review verdict, not a build, runtime, performance, or release acceptance.

- Specification: TEAM-4; decisions TEAM-019/TEAM-021; `docs/assignments/S2.md` and the prior `docs/sprints/S1-S2-secops.md` contract.
- Reviewed Services source: `a9dd5d7bf29ff78cfaca7b35da7034447643c10b`.
- Implementation baseline: `a30b22893f736b72186739f1dd834de680c96fbf`.
- Review task: `01a0ad34-c2ad-7e22-ae18-3468ca71fa88`, local.
- Review branch/worktree: `codex/joe-tv-secops-s2-review`, `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV`.
- Clean status and branch absence were checked before creating the review branch at the Services source commit. Prior assessment/review branches were preserved. Only this report is edited; its exact commit is supplied in the completion handoff.

Read the assignment, prior contract, applicable instruction/decision changes, and parser performance investigation. Inspected the complete four-file implementation delta and surrounding provider code. Competitor parity does not apply to these internal cache and parser correctness contracts.

## Cache contract review

References below are to `SeasonsTV/Networking/XMLTVGuideProvider.swift` at the reviewed source commit. Confidence in the control-flow findings is high; execution evidence remains separately attributed below.

| Contract | Evidence and assessment |
| --- | --- |
| Validate before writing | `currentGuidePrograms` at lines 223–281 and `currentSportsSchedule` at 284–340 validate incoming 200 bodies before `writeCache`, then update/remove ETag and record success. The guide uses a complete XML parse; sports maps decode failures to `invalidSportsSchedule`. Malformed responses cannot reach the body/metadata writes. |
| Preserve good state on rejection | Guide parse failures are typed `invalidGuide`; sports validation is explicitly wrapped. Both catches rethrow `EPGServiceError`, so malformed responses and explicit HTTP errors cannot silently become successful stale fallback. Atomic write failures occur before ETag/success updates; ordinary filesystem/transport failures may return only the already validated old candidate. Dispatched attempts still advance. |
| ETag correctness | Lines 242–244 and 301–303 attach `If-None-Match` only with a validated cached candidate and a nonempty stored validator. Accepted 200 removes the old validator when the new ETag is absent or whitespace-only. The new validator is installed after the body write, not before. |
| 304 and missing/corrupt recovery | Lines 264–267 and 323–326 require a validated candidate for 304 and only then record success. Missing/corrupt bytes cannot qualify. They suppress conditional headers on the next eligible request, allowing unconditional repair. There is no automatic retry loop. |
| Five-minute throttle | Cached bytes are parsed before the throttle decision. A valid candidate, including an empty result, can be returned locally; missing/invalid bytes produce `refreshThrottled`. These branches neither dispatch nor modify attempt/success values. `recordAttempt`/`recordSportsAttempt` run immediately before actual session dispatch. |
| Freshness | The unconditional sports success write was removed from `loadSportsSchedule`. Both routes record successful refresh only on accepted 200 or usable-cache 304. Transport/write fallback and throttled reads retain previous success time. `loadGuide` uses `.distantPast` for a legacy cache without success metadata; sports returns publisher `generatedAt` unchanged. |
| Valid empty documents | `XMLTVParser.parse` requires parse completion plus `hasTVRoot` (line 450); the first element must be `tv` (507–510). `<tv/>` and zero matching stations/programs remain valid empty dictionaries. Sports still uses the existing envelope decoder, accepting `events: []`. No result-count requirement or broad schema validation was added. |
| Scope | Production initialization retains existing defaults, configuration loading, cache paths and session defaults, adding the production clock and atomic writer closures. The separate supplied-dependency initializer is narrow. Event-detail request/cache behavior is unchanged. No route, token, publisher, playback, UI, or project change is in the delta. |

Retaining the old ETag on an invalid response with missing/corrupt cache is consistent with the contract: it is not sent while that body is unusable, and a successful repair replaces/removes it. Preserving the last attempt after failure keeps retries bounded. There is no need to clear account state or rotate credentials to fix these paths.

As previously scoped, the body file and UserDefaults metadata are separate writes, not a crash-atomic transaction. The report does not infer stronger crash consistency. `AppModel.refreshEPG` still stamps the merged window with `Date()`; provider correctness does not repair that known, out-of-scope UI freshness limitation.

## Test isolation and assertion quality

`Tests/GuideCacheSmoke.swift` exercises public `loadGuide` and `loadSportsSchedule` methods for both publication kinds, rather than only testing private helpers.

- **Isolation:** `Harness` (lines 93–137) creates a UUID-named temporary directory and defaults suite. Its provider call supplies synthetic configuration, cache directory, defaults factory, clock, session, and writer. The supplied-dependency provider initializer (lines 102–126) does not evaluate bundled configuration, standard defaults, or the normal cache location. No AppModel, credential cleanup, or real account is instantiated by this test path.
- **Network boundary:** `StubProtocol.canInit` accepts every request; all replies/errors are local. The harness session is ephemeral with URL cache, cookie storage, cookie setting, and credential storage disabled. `Wire` fails verification for unexpected hosts or unused/unexpected replies. Captured requests are checked for route, GET, Accept, synthetic Authorization, and exact conditional validator. No unexpected request is allowed to fall through to a socket in the inspected setup.
- **Owned cleanup:** `close` invalidates that session and removes only the generated directory/suite. The injected failing writer throws before writing and does not change permissions on any cache directory. The suite runs cases sequentially; its shared stub wire is reset per harness and protected by a lock. The injected clock is also locked and advanced without sleeps.
- **State assertions:** `state` (185–190) checks exact disk bytes, ETag, success time, attempt time, and request count. `expect` checks decoded titles and guide freshness or unchanged sports publisher time. `headers` (192–199) verifies actual requests. Provider recreation reuses only the isolated store, testing persistence as well as in-memory results.

The matrix at lines 218–342 meaningfully covers accepted replacement, persisted 304, absent/empty ETag replacement, empty publications/zero matches, invalid-after-valid, malformed bodies/required dates, missing/corrupt cache, unexpected 304, unconditional repair, zero-request throttle, offline fallback, write failure with/without good cache, HTTP 401/404/503/500, and unknown legacy freshness followed by successful revalidation. Rejected bodies retain good bytes and metadata; recovered requests have asserted validator behavior. This is adequate evidence design for the assigned contract, not merely implementation-shaped branch checks.

`scripts/test-guide-cache.sh` compiles the explicit source/test list into the worktree's ignored `.build`, with a local module cache, then runs that binary. It has no configuration-copy, network, simulator, permission-change, or production step. I inspected it but did not invoke it.

## Parser memoization and equivalence

`XMLTVParser.parse` creates a new delegate for each document. `XMLTVParserDelegate.timestamps` and lazy formatters (lines 474–488) are instance state, not static or global. The normalized-string key matches the former whitespace trimming; the valid/invalid enum also memoizes malformed timestamps. The four format strings, format order, POSIX locale, and Gregorian calendar match the old implementation. No shared mutable formatter or cross-document cache was introduced. `parseDate` (585–600) returns stored dates only within that delegate.

Outside the requested document-root check, the delta preserves station filtering, declared-station pruning, chronological ordering, field extraction, and strict window-overlap comparisons. Independent parses with different station filters cannot inherit a previous document's program state or timestamp cache. Memory remains proportional to unique timestamps within one document; this does not establish a universal performance gain.

`Tests/ParserSmoke.swift.xmltvAcceptance` (from line 1581) supplies independently computed full `EPGProgram` expectations, covering all four forms, positive/negative offsets, whitespace, malformed/repeated-invalid values, repeated timestamps, chronological output, both exact window edges, declared/allowed stations, valid empty documents, and unrelated/malformed XML. Equal-start rows are compared without inventing a tie-breaker requirement. A 40-row unique-timestamp document uses arithmetic expected times. Repeated parses and six concurrent independent parses check different documents/filters. These assertions are substantially stronger than matching program counts and suit the optimization's stated equivalence requirement.

## Evidence, limitations, and integration handoff

Performed: read-only Git baseline/diff/scope inspection, source and test tracing, and report whitespace/staging scope checks before commit. No source was edited. No build, Swift execution, benchmark, network request, simulator, live provider, or real configuration/cache/credential read was performed.

PM's assignment reports that Services passed the new lifecycle suite and expanded ParserSmoke at this source commit. Those are **Services-reported results**, not independent execution by SecOps. The final benchmark was still compiling at assignment time; no new measurement or Apple TV latency claim is made here. The earlier performance investigation is historical motivation only.

Proceed with the already planned sequence: integrate the reviewed provider/tests with PM's separate S1 preview/Channels corrections, then have QA run fresh lifecycle, smoke, unsigned build, and affected guide/empty-state verification on the exact combined commit. This review does not evaluate those later UI changes, approve release/deployment, or impose a new approval step. No additional requirement outside the agreed cache/parser contract is proposed.
