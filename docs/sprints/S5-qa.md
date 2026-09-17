# S5 QA — Sports filter repair

Status: **final configured build/preflight and fresh smoke PASS; bounded filter layout/interaction checks PASS; both reported studio exclusions observed in normal data.** Final candidate `98844e3` is installed and open for Joe with original preferences restored. PM confirmed Design acceptance of sampled filter visuals. Intermediate evidence below is preserved; the final follow-up supersedes its pending studio gaps.

Assignment S5 / TEAM-4, `docs/assignments/S5.md`, September 17, 2026, approximately 12:02–12:08 EDT runtime. Exact integrated source **`228fb4eedc13dc28b6410115dd9f41283a2c0399`** on clean new `codex/joe-tv-qa-s5`, created after clean-status/branch-absence checks. Prior branches/artifacts preserved. Only this report changes.

## Source, configured build and install

Read assignment/App report and complete App delta `4a83b0f898043e83e2aeea9be8e2d2a2e7b81426`. Integrated JoeTVExperience is byte-identical to that commit. Against S4, the only source change is JoeTVSportsFilterView and its new private local button style; helper, Models, parser and tests are unchanged. Source diff whitespace passed. No unchanged test-suite reruns, per assignment.

Fresh `python3 scripts/build-configured-simulator.py --config /Users/joecoakley/SeasonsTV/Config/Private.xcconfig` exited 0 and returned PASS, metadata configuration present, bundle `com.jrcoak.joetv`, version 1.0/build 7. Used the accepted helper only; no raw configuration/plist/settings output. Redacted log preserved as `.build/S5-configured-build.log` (the helper's generic log path is reused between builds).

Preserved full configured bundle at `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S5-configured-artifact/Joe-TV.app`, exact source `228fb4e`; debug-dylib SHA-256 **`eb14574383f2ec301f5c7804f8c67f76221cf3e648cd86fd9176898e01559302`**. S4 bundle retained unchanged, debug-dylib `88202c59bd3f509e4b36ff745a39c9bcead004887973a80a71298193ff2aa151`. Configured bundles remain ignored local sensitive build material; no embedded token was printed/shared/committed.

Announced installation and notified PM before taking the conditional exclusive runtime grant. Reconciled dedicated Joe-TV Team QA `C95B257D-0111-40A1-9D02-2AD70D850FF8` Booted; six other devices Shutdown. Terminate/install/normal relaunch all succeeded, PID `79191`, fixture flags removed, no reset/deletion/retry. Existing login and favorites remained. No credentials, playback, direct provider probe or unrelated settings changes.

## Observed filter results

| Check | Result |
| --- | --- |
| Top rows and header | Equal-height NFL/NCAAF/CFL/XFL/MLB/College Baseball tiles; concise description fits. College Football / NCAAF is complete. Included check and excluded circle remain distinct on focused white and resting dark surfaces. |
| Long names / columns | NCAA Women’s Ice Hockey and Women’s College Basketball are fully visible, including focused right/left-column examples. No truncation, title/count overlap or focus-outline cropping observed. At this actual size these labels fit on one line; no forced two-line stress case was introduced. |
| Scrolling / last row | Traversed all 13 category rows; focused rows are revealed within the viewport, with header/footer fixed. Lacrosse/Other final tiles remain above the footer with visible outlines. Partially clipped nonfocused rows at viewport edges are ordinary scroll clipping, not clipped focused content. |
| Counts | Observed 0 events, 1 event (e.g. Golf/Soccer), and multiple events (NFL/MLB). Focused secondary counts are gray on white and readable in the captured simulator view; no numerical contrast/hardware-legibility claim. |
| Toggle and persistence | Original NCAAF was excluded. Included it once, Back dismissed to focused Sports filter button; reopening retained the filled check. Toggled NCAAF back off, leaving every other category untouched. Done returned to focused **5 sports**; final reopen still shows NCAAF excluded. Original five selections (NFL, MLB, NHL, NBA, Tennis) restored. No Select All activation. |
| Dismissal/footer | Both Back and Done restored filter-button focus. Select All reached and visibly focused from the final row; no activation because it would change the whole set. Source confirms its existing restore-default action remains unchanged. Done reached by upward traversal. |

No full VoiceOver or Reduce Motion runtime check, localization/dynamic-type stress, physical Siri Remote or couch-distance testing. Internal app AX controls are not exposed through the Simulator host tree; focus/action conclusions use native UI captures and keyboard input. Tool duration is not input latency.

## Screens and remaining studio gaps

Four sanitized PNGs reopened and visually checked, all under `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S5-qa-evidence/`:

- `filter-top.png`: full sheet, NFL focus, readable header/first rows and separated footer.
- `filter-middle.png`: complete NCAA Women’s Ice Hockey focused tile and surrounding uniform rows.
- `filter-bottom.png`: Lacrosse focus, complete final row and singular counts.
- `studio-gap.png`: normal Live grid with NFL Total Access, ACC Network Football Podcast and Towson vs. South Carolina after temporary NCAAF inclusion.

**Capture limitation:** middle/bottom simctl PNGs black out the surrounding header/footer/background, while native CUA captures at those same states show the complete fixed sheet. These two files establish grid text/focus only, not full-sheet composition. PM/Design were explicitly told; native task screenshots retain the full-sheet evidence. No missing-header runtime defect was observed. Top capture includes the complete sheet.

S4 quick look: configured schedule still populated without missing-config banner, initially Live 0 / Upcoming 25 / 5 sports with future Brewers/Pirates and pregame text. After normal data arrival Live became 1 with **NFL Total Access (ESPN+)**. Temporary NCAAF inclusion revealed Live 3 including **ACC Network Football Podcast** and Towson vs. South Carolina; restoring NCAAF returned Live 1 / Upcoming 25 / 5 sports. The two studio/podcast title gaps were reported immediately to PM and assigned separately to Services. Counts are observations, not external verification of live games or current scores. No attempt to play a row.

## Intermediate handoff

Corrected filter left **OPEN for Joe** after final restoration/reopen; runtime ownership returned to him. No further input/build/install until a new grant. Pending studio exclusions require their own exact source and affected check; filter evidence remains tied to `228fb4e`. Earlier S1/S2/S3 and hardware/real-media limits remain unchanged. Final report-only whitespace check and clean commit accompany handoff; no deployment or release.

## Final S5 follow-up and delivery

PM assigned exact candidate **`98844e3ebdf82396011be1365da630a9addd1ddd`**, preserving the S5 filter source and adding Services `acaec47ac1f3cd4b99d21b1c018c2f54a00a40ba`. Reviewed delta: shared studio classifier adds NFL Total Access and ACC Network Football Podcast exclusions; 22 lines of parser regressions cover those exclusions and retention of genuine NFL/NCAAF games. Models/tests match the Services commit. Created clean `codex/joe-tv-qa-s5-final` from the final candidate; intermediate report was cherry-picked as `50a2b5a0b8777eb806367a456f4ad9b6c4de805a`. Application, configuration, scripts and tests remain unchanged from the candidate; only this report is QA-owned.

Fresh `scripts/team-check.sh smoke` **PASS**, exit 0, including the new regressions; existing macOS FairPlay API deprecation warning remains. Fresh configured build using the same accepted helper **PASS**, exit 0, metadata configuration present, bundle identity/version unchanged. Logs: `.build/S5-final-smoke.log` and redacted `.build/S5-final-configured-build.log`. No unchanged helper/guide/layout matrix reruns, per PM scope.

Preserved final bundle: `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S5-final-configured-artifact/Joe-TV.app`; debug-dylib SHA-256 **`8c1a34ea73de18155a45ab5fc9d9e1b3ddf03d71d4a4c01755fc71edd379e4e1`**. Earlier S4 and S5 intermediate bundle hashes were rechecked unchanged. The final configured bundle is sensitive local build material and is not committed or shared.

Under PM's renewed exclusive grant on the same dedicated QA simulator, terminate/install/normal launch succeeded without retry or reset, PID `80233`. Fixture flags were absent, existing login/preferences retained. Normal metadata populated without a missing-configuration banner. Before temporary filter inclusion, Sports showed **Live 0 / Upcoming 25 / 5 sports**. Including NCAAF briefly produced **Live 1**, showing only **Towson vs. South Carolina (ESPN+)**, with team logos loaded. Both previously observed studio rows were absent, and filter counts changed from NFL 2/NCAAF 2 to **NFL 1/NCAAF 1**, with MLB 24. This is a normal-data exclusion sample, not independent verification of the remaining match's actual live status, schedule or score.

Restored NCAAF OFF; every other category remained untouched, preserving original NFL/MLB/NHL/NBA/Tennis selections. Final native view shows the NCAAF outline circle, Live 0 / Upcoming 25 behind the repaired filter, and corrected event counts. Saved and reopened both final PNGs for visual verification:

- `.build/S5-qa-evidence/final-studio-exclusions.png`: complete normal grid with the single remaining college matchup during temporary inclusion.
- `.build/S5-qa-evidence/final-filter-restored.png`: complete repaired sheet, NCAAF focused and excluded, readable title/counts, fixed header/footer. This final screenshot has no blacked-out surrounding regions.

**Final runtime released to Joe with the final configured app and Filter Sports left OPEN.** No further input/checks after release. No playback, direct provider probe, credential change, release or deployment. Earlier physical-device, FairPlay, remote, accessibility and real-match-truth limitations remain. PM will integrate the two report commits and record Design acceptance; no separate Design report is required. Report-only diff/whitespace and clean-commit verification accompany the handoff.
