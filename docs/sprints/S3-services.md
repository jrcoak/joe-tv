# S3-SERVICES — preserve guide data on partial refresh

## Source and scope

Assignment `docs/assignments/S3.md`, TEAM-4 / TEAM-019 / TEAM-024. Baseline: `a8301bcaa22f965ad4b4d5cf37ad2d583f36fb6b`. Branch: `codex/joe-tv-services-s3`, created after clean/absence checks. Previous S2 branch remains at `74f3b62f17cc07b8f49582df8832d44543a1b724`.

Implementation/test commit: `88061c7fbf8a4e41e90ed4e3d10b1dbd7b25272e`. This report follows in a documentation-only commit; final SHA/clean status accompany the handoff. PM integrates after independent App/SecOps review; QA acceptance is pending.

Changed only `AppModel.refreshEPG`, additive guide-only `EPGGuideMergePolicy` beside `EPGGuideWindow` in `Models.swift`, `Tests/GuideMergeSmoke.swift`, `scripts/test-guide-merge.sh`, and this report. Existing model/provider interfaces remain source-compatible. No provider/networking, UI/player, preferences, Sports, ParserSmoke, project, backend or channel work. Competitor documentation cannot establish this internal merge contract; no parity or performance claim applies.

## Merge contract

Production `refreshEPG` invokes the same pure policy exercised by the new tests, supplying each source's explicit requested channel IDs and loaded/failed/unavailable outcome.

- Successful sources replace their prior contribution authoritatively, including empty programs and omitted mappings. Failed sources retain only relevant last-known data for requested mapped channels. Unrequested mappings, unrelated station buckets and invalid/out-of-window program ranges are excluded.
- Retained program times must overlap both the prior source viewport and the requested viewport. PM selected a small exception to viewport-overlap gating: a long-running program can prove its own applicability even when those viewports are disjoint. Outside viewport overlap, only mappings with actually retained overlapping programs survive; empty/mapping-only/expired data cannot imply new coverage. Original program times/fields/identities are preserved. Merged bounds describe the requested display viewport, not continuous provider coverage.
- Successful station claims include both prior requested mappings and new mappings. They override ambiguous failed-source shared-station rows, including successful-empty/remapped results. Within overlapping viewports a failed requested channel may retain a mapping to that authoritative station, even if empty. Outside viewport overlap, suppressed old rows cannot justify a mapping. PM confirmed successful-claim precedence. Production source namespaces are currently disjoint (`verylocal:` versus explicit XMLTV station IDs).
- Current rows from two successful sources sharing a station are deduplicated by program ID, then sorted by start and ID. Conflicting equal IDs keep the first source's value in the existing request order. Mappings remain a dictionary of stable associations, with no presentation-order contract.
- Missing XMLTV provider is explicitly unavailable/failed, using the existing generic error and retention rules. Empty channel groups are ignored; no requested channels yields unavailable with no mappings. Failures stay failed states with applicable cached content; existing localized messages and first-source-error precedence remain.
- Successful windows (including empty publications) contribute their fetchedAt; retained mappings/content contribute the prior aggregate fetchedAt. The minimum becomes merged age, preserving `.distantPast` rather than substituting `Date()`. Repeated partial results may remain older than any one source warrants because the existing single timestamp cannot reconstruct per-source provenance. All-success recovery can replace that conservative age. No per-source persistence architecture was added.

## Evidence

- Final `scripts/test-guide-merge.sh`: fresh isolated host compilation and all production-policy assertions passed.
- `scripts/team-check.sh smoke`: fresh pass before the final program-proven viewport exception. Per PM, it was not repeated after that change; QA will rerun against the integrated source.
- `xcrun swiftc -frontend -parse SeasonsTV/App/AppModel.swift`: passed on the unchanged final AppModel edit; syntax only, not an app typecheck/build.
- Runner shell syntax and staged/full-diff whitespace checks passed. Host compilations emitted only the existing macOS FairPlay deprecation warning at `FairPlayResourceLoader.swift:59`.

Tests build a known-good two-source snapshot and reproduce the old loaded-results-only loss before verifying the production policy. Complete windows/program values, associations, timestamps and error/load states are checked for either source failing, both succeeding/remapping, authoritative empty with/without mappings, repeated partials/recovery, cold/no-cache results, removed channels, requested/prior-window filtering, long-running cross-viewport programs, disjoint expired/empty mappings, original unclipped times, unknown freshness, provider absence, no channels/sources, shared-station authority, deduplication/order and reordered nonconflicting source outcomes.

The runner uses explicit repository dependencies and the worktree's `.build/ModuleCache`. Test execution constructs only pure guide data/policy: no AppModel/provider/session/defaults/credentials/normal cache access. Ignored logs: `.build/s3-guide-merge.log` and `.build/s3-parser-smoke.log`.

## Async lifecycle source audit and limitations

The navigation-fixture early return, new request ID before no-channel handling, and loading(cached:) state are unchanged. Cached window/mappings are captured on the main actor before suspension. Provider request order remains Very Local then XMLTV, with no timeout or retry change. The existing request-ID guard remains after awaits and before both result writes, with no intervening await. `signOut` still clears guide/mapping state and rotates the request ID; no new retained state needs logout cleanup. `usableGuideWindow` continues exposing cached content for failed/loading states.

This is direct source evidence, not a runtime stale-completion/sign-out test. Pure policy tests and AppModel syntax parsing do not prove async lifecycle, tvOS typechecking, focus/selection or on-screen behavior. No simulator, app build, benchmark, live network/account/media, backend or hardware operation ran. Independent QA must compile/build and verify the assembled candidate; S1/S2 UI acceptance is unaffected.

Very Local still suppresses individual station failures inside an otherwise successful provider result. AppModel cannot distinguish these from authoritative empty content; station-level failure handling remains outside S3.
