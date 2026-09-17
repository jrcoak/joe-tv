# S4 QA — configured repair delivered

Status: **offline checks/configured bundle preflight PASS; normal Sports schedule visibly populated, missing-configuration banner gone. Configured app left open for Joe.** Runtime sampling ended when Joe resumed input; complete grid/unknown/studio traversal remains limited as below.

Assignment: S4 repair QA/delivery, TEAM-4, `docs/assignments/S4.md`, Joe's explicit fix request and PM's exclusive dedicated-device handoff. September 17, 2026, approximately 11:53–11:56 EDT for runtime observations. Exact candidate **`7fe97fcddd32630f27de2e74ea2f70e53bb017d5`**. Clean `codex/joe-tv-qa-s4` created after clean-status/branch-absence checks; prior branches, app data and artifacts preserved. Only this report changes.

## Source and offline evidence

Read assignment, live-status diagnosis, Services/App/SecOps reports and approved helper source. Empty Git diffs confirm Models/parser/ParserSmoke match Services final `8b41a49753f93089e38f43c4b473260c857080e4` (base implementation `ef8945acaddd6d1d67e5b3da03b60853857622f5`); both UI files and AppModel match App `1ed871bd59cb360eb3917116f62da14409b199fb`; configured helper/tests match SecOps-reviewed `2e926079d935dfbf3649f39f3c34fe9afafd7b48`.

All requested commands freshly ran **sequentially**, exit 0:

| Check | Actual result / evidence |
| --- | --- |
| `python3 Tests/ConfiguredBuildTests.py` | 4 tests, OK; synthetic configuration/redaction/preflight checks, no real configuration read by this test. |
| `scripts/team-check.sh smoke` | `Parser smoke test passed`; `.build/S4-qa-smoke.log`. |
| `scripts/test-guide-merge.sh` | `Guide merge smoke passed: loss reproduction, partial retention, authoritative empty, remapping, filtering, provenance, recovery and absence`; `.build/S4-qa-guide-merge.log`. |
| `python3 scripts/build-configured-simulator.py --config /Users/joecoakley/SeasonsTV/Config/Private.xcconfig` | Helper returned `result: PASS`, bundle `com.jrcoak.joetv`, version 1.0/build 7, `metadata_configuration_present: true`. Redacted build log `.build/configured-simulator-build.log`. |

Used the approved helper exclusively for configured build/preflight; no raw xcodebuild/showBuildSettings or configuration/plist dump. Host smoke compilations retained the existing FairPlay macOS API deprecation warning; no warning/error lines were found in the helper's redacted configured-build log. Build uses two jobs, Debug generic tvOS Simulator SDK and worktree `.build/ConfiguredDerivedData`. Configuration shape/token selection PASS is distinct from server authorization and runtime loading evidence.

Fixed-clock smoke assertions include no-time/unknown exclusion, future+Live and ended+Live, stale statuses and five-hour no-end boundary, disrupted/final/replay distinctions, tournament labels, fractional/invalid dates, parser-time boundary advancement, studio exclusions (Good Morning Football and SEC In 60/In60), and start−901/start−900/start pregame boundaries. These passed; they do not independently validate the current live status of real teams.

## Artifact and replacement

Preserved complete configured bundle at **`/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S4-configured-artifact/Joe-TV.app`**, source `7fe97fc`, version 1.0/build 7. Copied debug-dylib SHA-256 matches helper build product: `88202c59bd3f509e4b36ff745a39c9bcead004887973a80a71298193ff2aa151`. This ignored local bundle embeds the authorized Debug read token and must remain local; no token/config values were printed, committed or shared. No standalone private config copy was made.

Retained S1/S2/S3 debug-dylib hashes rechecked unchanged: respectively `47082a5872b5302a6aeba49144253b50500c9d411c4849dcdd0dbb5bdb6c6008`, `9052881cc59d77235fdb5501e51e2048216c2ff4a8cae58eacc3d648c09bedc4`, `745bdeba6efacc6254bb9b4a5a99543743f4866d0ebb46b5bb71e2fe927b719d`. Earlier unconfigured bundles remain separately identified offline artifacts.

Reconciled devices: only assigned **Joe-TV Team QA `C95B257D-0111-40A1-9D02-2AD70D850FF8`** was Booted; other six Shutdown. Announced replacement, terminated old Joe-TV, installed over it successfully without deletion/reset, then launched normal mode with all known fixture environment flags removed. Launch succeeded, PID `77695`. No restart/retry was needed. Normal Home appeared already signed in with existing favorites; QA entered no credentials or settings changes. No real playback or direct provider probe was performed.

## Actual Sports observations

- At approximately **11:54 EDT**, Sports showed **Live 0 / Upcoming 25 / 5 sports**, with Upcoming selected and a populated dated schedule. The previous missing-configuration/error banner was absent. Home/guide also displayed normal program metadata. This is visible metadata-enrichment evidence rather than merely a successful bundle check; response transport/status and disk-versus-network provenance were not inspected.
- **Brewers @ Pirates** showed **UP NEXT**, September 17 at **12:35 PM**, and its card said **Coverage begins at 12:20 PM**. Dodgers @ Reds showed 12:40 PM / coverage 12:25 PM; Athletics @ Rays 1:10 PM / coverage 12:55 PM. Visible later rows were marked TODAY or TOMORROW. Future entries therefore remained Upcoming, with the expected 15-minute pregame text, instead of the prior erroneous Live label.
- No Good Morning Football or SEC In 60 appeared in the captured visible rows. The Live count was zero; QA did **not** independently enter/traverse the empty Live grid or all 25 Upcoming entries. Unknown notice/unknown-entry presentation was not observed in this enriched sample. Exact real-game truth is not inferred from counts, dates or the provider publication alone. Actual pregame availability at its clock boundary was tested in policy, not awaited in the normal session.
- Immediately after capturing Sports, CUA rejected the next input because the **user changed Simulator**. QA re-read state as instructed and saw Joe's Filter Sports sheet, then stopped all input and released runtime ownership to Joe. No blind continuation or extra preference mutation. The existing Filter Sports sheet visibly clips some rows/oversized labels; it is outside S4's source changes and is a separate polish observation, not a proved S4 regression.

Verified sanitized 1920×1080 PNG, reopened from disk after capture: **`/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S4-qa-evidence/sports-upcoming-loaded.png`**. It shows populated Upcoming 25, Live 0, no missing-config banner, the future Brewers/Pirates hero and multiple pregame labels. No credentials, tokens or private URLs are visible. Source/time/count attribution above applies; the image does not prove every hidden row or real-time game status.

## Handoff and limits

Configured repair was installed and normal metadata-rich browsing was observed; **Simulator and Joe-TV remain OPEN for Joe**, with runtime ownership returned to him. No shutdown, source changes, account reset, playback test, backend change, release or upload. Final report-only staged whitespace check/clean commit accompany handoff.

Remaining S4 runtime coverage: full grid/studio exclusion, an observed unknown-listing state, and actual pregame transition. S1/S2 focus/layout matrices and S3 controlled async lifecycle remain separately pending. Physical remote, rapid duplicate Back, VoiceOver/Reduce Motion, FairPlay, real media/captions/audio, exact live scores/status and TV performance are not established by this repair sample. No unobserved condition is labeled passed.
