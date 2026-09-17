# Joe-TV quality cycles

Status: two implementation cycles are assembled on local `codex/joe-tv-team`. Combined application candidate: `bbb60d6effc7536e27b931899c8915d38e6449c2`, version 1.0 / build 7. Fresh independent cache-lifecycle, parser smoke and unsigned tvOS Debug build checks passed. Final UI acceptance is **blocked by the locked Mac**, not established by the successful build. No release or production deployment has been performed.

## Implemented

| Cycle | Viewer-facing result | Evidence |
| --- | --- | --- |
| S1 watching and returning | Restore Home/guide/Sports origins, direct Select-to-watch for current guide programs, truthful future/expired channel actions, direct Choose Favorites from empty Home, consistent Fantasy scorebug Back. | Original candidate passed Home, Quick Switch origin, removed-favorite fallback, empty settings, sampled baseball return and staged Fantasy Back. Guide-origin player controls failed; the native preview was replaced with a passive video layer. That correction passes smoke/build but has not been observed after the Mac locked. See `S1-qa.md`. |
| S2 readability and data | Channels sheet has explicit text/row sizes, wider footer controls and visible enabled/favorite states. Guide/sports caches validate before replacement; validators and successful-refresh metadata stay paired with accepted content. Repeated XMLTV timestamps parse once per document. | Services' 49 isolated cache scenarios and expanded XMLTV equivalence tests passed; SecOps accepted the source. QA independently passed lifecycle/smoke/build on the combined candidate. Channels layout/focus and final guide regression still need unlocked simulator checks. See `S2-services.md`, `S2-secops.md`, and `S2-qa.md`. |

Provider benchmark on a fixed synthetic 70-station / 3,360-program guide: five final host parse samples had a 27.82 ms median. Prior baseline medians varied roughly 2–13 seconds under different host load. This supports a workload-specific parsing improvement; it does not establish a production ratio, Apple TV input latency or hardware performance. See `../research/guide-parser-performance.md` and `S2-services.md`. AppModel's merged-window `Date()` freshness remains a separate known limitation.

## Stream discovery

The [eight-channel shortlist](../research/public-stream-shortlist.md) is complete. Classic Arts Showcase, NHK WORLD-JAPAN and DW English are the strongest initial playback leads; CBS News Boston is locally relevant but its direct integration path is unresolved. Playlist resolution and availability labels remain untested. No channels were added or media endpoints probed. QA sampling and integration are later bounded steps.

## Resume after unlock

QA preserved source-specific unsigned artifacts in its worktree:

1. `S1-corrected-artifact/Joe-TV.app`, source `d010f395bcae7b66e46a6b50168005005f0ba9b2`: test current-program, channel-name and future-details Watch after active preview; controls after badge timeout, Back and two guide-origin returns; a filter/scroll and time-boundary case if practical.
2. `S2-combined-artifact/Joe-TV.app`, source `bbb60d6effc7536e27b931899c8915d38e6449c2` (full evidence in `S2-qa.md`): compare Channels with the saved clipping screenshot, verify state text, long names, footer/focus bounds and empty-Home cancel/add/disabled-favorite return; repeat a guide regression sample. Design reviews the final screenshot.

Both live under `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/`. PM grants the dedicated Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8` for this resumption. Do not infer unlock or permission from elapsed time, bypass the host lock, or operate other devices. No further compilation is needed unless source or artifacts change. Any runtime defect goes to its code owner, receives a new candidate, and gets affected verification before acceptance.

Rapid duplicate Back, physical Siri Remote, real media/captions/FairPlay and couch readability retain their explicit evidence limits. The original main checkout remains at `138c271` with only unrelated SHELF untracked. Repository decisions/reports and the existing seven tasks retain the team context; no recurring automation was installed.
