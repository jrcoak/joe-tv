# Joe-TV quality cycles

Status: five bounded implementation cycles are assembled on local `codex/joe-tv-team`. Latest application source `98844e3ebdf82396011be1365da630a9addd1ddd`, version 1.0 / build 7, is installed in the configured simulator. S4/S5 timing/studio corrections and Filter Sports layout have fresh test/build and sampled normal-session evidence. Filter Sports is open for Joe with login and original selections preserved. Earlier S1–S3 full UI/async acceptance remains pending. The work was subsequently merged/pushed to main and uploaded as TestFlight1.0(8); Apple processing began. No production service deployment was performed. See `../releases/1.0-8.md`.

## Implemented

| Cycle | Viewer-facing result | Evidence |
| --- | --- | --- |
| S1 watching and returning | Restore Home/guide/Sports origins, direct Select-to-watch for current guide programs, truthful future/expired channel actions, direct Choose Favorites from empty Home, consistent Fantasy scorebug Back. | Original candidate passed Home, Quick Switch origin, removed-favorite fallback, empty settings, sampled baseball return and staged Fantasy Back. Guide-origin player controls failed; the native preview was replaced with a passive video layer. That correction passes smoke/build but has not been observed after the Mac locked. See `S1-qa.md`. |
| S2 readability and data | Channels sheet has explicit text/row sizes, wider footer controls and visible enabled/favorite states. Guide/sports caches validate before replacement; validators and successful-refresh metadata stay paired with accepted content. Repeated XMLTV timestamps parse once per document. | Services' 49 isolated cache scenarios and expanded XMLTV equivalence tests passed; SecOps accepted the source. QA independently passed lifecycle/smoke/build on the combined candidate. Channels layout/focus and final guide regression still need unlocked simulator checks. See `S2-services.md`, `S2-secops.md`, and `S2-qa.md`. |
| S3 guide continuity | Keep applicable listings/mappings for failed sources; successful updates, including empty, replace old data. Preserve original program times and source age, including long-running programs across guide windows. | Services source `88061c7`, independent App/SecOps source reviews, and QA merge/smoke/build PASS at combined `9d3cd8a`. Async provider lifecycle and on-screen behavior remain unobserved; the navigation fixture skips refreshEPG. See `S3-services.md`, `S3-app-review.md`, `S3-secops.md`, and `S3-qa.md`. |

| S4 truthful Sports status | Unknown timing no longer becomes Live; future starts and end bounds govern generic statuses; studio examples excluded; proper Debug metadata configuration restored. | Independent four-check PASS and configured normal launch; observed Live 0 / Upcoming 25, dated upcoming/pregame labels and no configuration banner. Partial normal-session sample only; full grid/unknown state not observed. See `S4-qa.md`. |

| S5 Sports filter layout | Explicit typography, equal tiles, complete long names, separated fixed header/footer, focus gutters and singular count grammar. | Configured build, all26-category traversal, both-column focus, toggle/reopen persistence with restoration, Done/Back focus return and Design screenshot review passed. Final studio follow-up smoke/build and normal exclusion sample passed at `98844e3`. See `S5-qa.md`. |

Provider benchmark on a fixed synthetic 70-station / 3,360-program guide: five final host parse samples had a 27.82 ms median. Prior baseline medians varied roughly 2–13 seconds under different host load. This supports a workload-specific parsing improvement; it does not establish a production ratio, Apple TV input latency or hardware performance. See `../research/guide-parser-performance.md` and `S2-services.md`. S3 replaces AppModel's merged-window `Date()` stamp with conservative source age. The single aggregate timestamp can remain older than individual retained contributions; it is not per-source freshness tracking.

## Stream discovery

Joe has dropped new-channel work entirely (TEAM-025), including WBZ. The [earlier research](../research/public-stream-shortlist.md) is historical only. Existing app quality and verification remain the focus.

## Remaining acceptance after Joe’s simulator session

QA preserved source-specific unsigned artifacts in its worktree:

1. `S1-corrected-artifact/Joe-TV.app`, source `d010f395bcae7b66e46a6b50168005005f0ba9b2`: test current-program, channel-name and future-details Watch after active preview; controls after badge timeout, Back and two guide-origin returns; a filter/scroll and time-boundary case if practical.
2. `S2-combined-artifact/Joe-TV.app`, source `bbb60d6effc7536e27b931899c8915d38e6449c2` (full evidence in `S2-qa.md`): compare Channels with the saved clipping screenshot, verify state text, long names, footer/focus bounds and empty-Home cancel/add/disabled-favorite return; repeat a guide regression sample. Design reviews the final screenshot.
3. `S3-combined-artifact/Joe-TV.app`, source `9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d`: repeat affected browsing/selection/metadata regressions after the source-specific S1/S2 comparison. Actual provider failure/recovery and async ordering require isolated controllable-provider evidence; the existing navigation fixture cannot establish those paths. See `S3-qa.md` for exact artifact hash and limits.

All live under `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/`. The dedicated Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8` is now open under Joe’s control. PM must coordinate a new runtime handoff before QA resumes this sequence. Do not infer unlock or permission from elapsed time, bypass the host lock, or operate other devices. No further compilation is needed unless source or artifacts change. Any runtime defect goes to its code owner, receives a new candidate, and gets affected verification before acceptance.

Rapid duplicate Back, physical Siri Remote, real media/captions/FairPlay and couch readability retain their explicit evidence limits. The original main checkout remains at `138c271` with only unrelated SHELF untracked. Repository decisions/reports and the existing seven tasks retain the team context; no recurring automation was installed.

## S3 checkpoint and next phase

S3 source and App/SecOps reviews are integrated; independent QA report `5ba967367f25a938c42aef061f23f270c3c8819f` records all three fresh checks passing at `9d3cd8a`. S1/S2 artifact hashes were reverified unchanged. All specialist runs and compilation are complete; no active runtime session or unattended work is installed.

Next: after Joe’s simulator session and a coordinated runtime handoff, finish the pending guide-controls correction and Channels visual acceptance, route any observed defect to its owner, then verify the final combined app. The latest normal-mode app is open at sign-in and responded to one focus movement; this is launch evidence, not acceptance of those remaining journeys. Further layout changes should follow that checkpoint. New-channel work is closed; sidebar/team-curated Home remain later product directions.

## S4/S5 delivered

The live-status repair and configured build are installed, preserving Joe's login and preferences. PM inspected the saved normal Sports screenshot. QA stopped on detected user input and handed the app back to Joe. His subsequent Filter Sports screenshot demonstrates oversized semantic fonts/uneven tile heights; S5 repairs that sheet only, with App implementation, Design guidance and fresh configured-build/visual QA. See `../assignments/S5.md`. The earlier plan to retest retained S1/S2 artifacts remains separate; do not replace Joe's configured app with those offline artifacts without a named session.

Final follow-up `98844e3` also removes observed NFL Total Access and ACC Network Football Podcast from game listings; meaningful fixed-clock regressions preserve legitimate NFL/college games. QA observed both exclusions after normal metadata arrival, restored Joe's five sports, and left the corrected filter open. Design accepted sampled source/screen evidence; physical couch readability and VoiceOver were not certified. The current next phase is the previously pending guide-controls/Channels acceptance after a coordinated runtime handoff, not additional speculative layout work during Joe's simulator session.
