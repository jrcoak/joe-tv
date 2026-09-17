# Joe-TV quality cycles

Status: three implementation cycles are assembled on local `codex/joe-tv-team`. Current combined application candidate: `9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d`, version 1.0 / build 7. Fresh independent S3 guide-merge, full parser smoke and unsigned tvOS Debug build checks passed. S2 provider lifecycle checks passed at its earlier exact candidate; provider/test source is unchanged. Final UI acceptance is **blocked by unavailable computer-control access**. The September 17 inventory succeeded but Simulator selection timed out twice; current lock state is unestablished (`S2-ui-qa.md`). No release or production deployment has been performed.

## Implemented

| Cycle | Viewer-facing result | Evidence |
| --- | --- | --- |
| S1 watching and returning | Restore Home/guide/Sports origins, direct Select-to-watch for current guide programs, truthful future/expired channel actions, direct Choose Favorites from empty Home, consistent Fantasy scorebug Back. | Original candidate passed Home, Quick Switch origin, removed-favorite fallback, empty settings, sampled baseball return and staged Fantasy Back. Guide-origin player controls failed; the native preview was replaced with a passive video layer. That correction passes smoke/build but has not been observed after the Mac locked. See `S1-qa.md`. |
| S2 readability and data | Channels sheet has explicit text/row sizes, wider footer controls and visible enabled/favorite states. Guide/sports caches validate before replacement; validators and successful-refresh metadata stay paired with accepted content. Repeated XMLTV timestamps parse once per document. | Services' 49 isolated cache scenarios and expanded XMLTV equivalence tests passed; SecOps accepted the source. QA independently passed lifecycle/smoke/build on the combined candidate. Channels layout/focus and final guide regression still need unlocked simulator checks. See `S2-services.md`, `S2-secops.md`, and `S2-qa.md`. |
| S3 guide continuity | Keep applicable listings/mappings for failed sources; successful updates, including empty, replace old data. Preserve original program times and source age, including long-running programs across guide windows. | Services source `88061c7`, independent App/SecOps source reviews, and QA merge/smoke/build PASS at combined `9d3cd8a`. Async provider lifecycle and on-screen behavior remain unobserved; the navigation fixture skips refreshEPG. See `S3-services.md`, `S3-app-review.md`, `S3-secops.md`, and `S3-qa.md`. |

Provider benchmark on a fixed synthetic 70-station / 3,360-program guide: five final host parse samples had a 27.82 ms median. Prior baseline medians varied roughly 2–13 seconds under different host load. This supports a workload-specific parsing improvement; it does not establish a production ratio, Apple TV input latency or hardware performance. See `../research/guide-parser-performance.md` and `S2-services.md`. S3 replaces AppModel's merged-window `Date()` stamp with conservative source age. The single aggregate timestamp can remain older than individual retained contributions; it is not per-source freshness tracking.

## Stream discovery

Joe retained **WBZ / CBS News Boston only** as a future candidate on September 17; the other [research candidates](../research/public-stream-shortlist.md) are dropped from active consideration. WBZ’s direct integration path is unresolved. No channel was added or media endpoint probed; UI/performance work remains active.

## Resume when UI access is available

QA preserved source-specific unsigned artifacts in its worktree:

1. `S1-corrected-artifact/Joe-TV.app`, source `d010f395bcae7b66e46a6b50168005005f0ba9b2`: test current-program, channel-name and future-details Watch after active preview; controls after badge timeout, Back and two guide-origin returns; a filter/scroll and time-boundary case if practical.
2. `S2-combined-artifact/Joe-TV.app`, source `bbb60d6effc7536e27b931899c8915d38e6449c2` (full evidence in `S2-qa.md`): compare Channels with the saved clipping screenshot, verify state text, long names, footer/focus bounds and empty-Home cancel/add/disabled-favorite return; repeat a guide regression sample. Design reviews the final screenshot.
3. `S3-combined-artifact/Joe-TV.app`, source `9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d`: repeat affected browsing/selection/metadata regressions after the source-specific S1/S2 comparison. Actual provider failure/recovery and async ordering require isolated controllable-provider evidence; the existing navigation fixture cannot establish those paths. See `S3-qa.md` for exact artifact hash and limits.

All live under `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/`. PM grants the dedicated Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8` for this resumption. Do not infer unlock or permission from elapsed time, bypass the host lock, or operate other devices. No further compilation is needed unless source or artifacts change. Any runtime defect goes to its code owner, receives a new candidate, and gets affected verification before acceptance.

Rapid duplicate Back, physical Siri Remote, real media/captions/FairPlay and couch readability retain their explicit evidence limits. The original main checkout remains at `138c271` with only unrelated SHELF untracked. Repository decisions/reports and the existing seven tasks retain the team context; no recurring automation was installed.

## S3 checkpoint and next phase

S3 source and App/SecOps reviews are integrated; independent QA report `5ba967367f25a938c42aef061f23f270c3c8819f` records all three fresh checks passing at `9d3cd8a`. S1/S2 artifact hashes were reverified unchanged. All specialist runs and compilation are complete; no active runtime session or unattended work is installed.

Next: restore supported Simulator access, finish the pending guide-controls correction and Channels visual acceptance, route any observed defect to its owner, then verify the final combined app. Joe has been asked to open Simulator and confirm it is visible; no reply has yet been received. Do not infer UI availability from elapsed time or an open browser. Further layout changes should follow this acceptance checkpoint. WBZ remains a future candidate, and sidebar/team-curated Home remain later product directions.
