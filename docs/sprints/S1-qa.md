# S1 QA — original candidate checkpoint

Status: **original candidate `f394d4d` not accepted; correction `d010f39` builds and passes smoke, but UI verification is blocked by the locked Mac. Guide acceptance pending.**
Latest checkpoint: September 16, 2026 EDT (September 17 UTC), S1-QA / TEAM-4. Candidate results are appended below; baseline provenance and findings remain historical.

## Historical baseline

Assignment: S1-QA baseline phase, TEAM-4. Checked September 16, 2026 EDT (September 17 UTC).
Starting commit: `22f0fdf51b9b105bfb5b34cf5ecc2bb6e72a1340`.
Branch: `codex/joe-tv-qa-s1`, created from that SHA after clean-status and branch-absence checks. Completed `codex/joe-tv-qa` preserved at `82e8ea5a9dd1e68158a96fa12c294d9f106d3b75`.
Owned change: this report only; no application, test-target, shared-document or project edits.

## Environment and provenance

- Exclusive resource: **Joe-TV Team QA**, `C95B257D-0111-40A1-9D02-2AD70D850FF8`, Apple TV 4K (3rd generation) at 1080p, tvOS 26.5 / 23L470. Host: arm64 MacBook Air, macOS 26.6.2 / 25G83; Xcode 26.6 / 17F113.
- All seven simulators were Shutdown at entry. Only the assigned QA device was booted/operated. Its app was terminated and device shut down at checkpoint; all seven again Shutdown. No erase, app deletion, user-device operation, authenticated provider request or private configuration copy. QA remains the assigned S1 runtime owner pending PM's candidate.
- Reused M0's unsigned Debug simulator artifact at `.build/TeamDerivedData/Build/Products/Debug-appletvsimulator/Joe-TV.app`, version 1.0, **build 6**, built at `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`. Fresh Git comparison against the S1 starting SHA found no differences in `SeasonsTV/`, `Tests/`, `Config/` or `scripts/team-check.sh`; the project delta is solely the two build-number settings 6 → 7. Thus UI source is equivalent, but this is explicitly not a fresh build-7 or S1 candidate result.
- Quick Switch fixture: six channels, five Home favorites, two seeded recents, no populated EPG, no artwork URLs. Fantasy fixture: four live NFL games, two watch channels, sample matchup/league data. Both use ready **empty AVPlayer sessions**, not media. Fantasy can load public ESPN artwork; its dates derive from launch time. Existing dedicated-app data/cache retained, no cold-cache claim or production catalog load.
- Input: Simulator keyboard arrows / Return / Escape via native UI automation, visually checked between steps. Internal app controls are not exposed in Simulator's host accessibility tree. Physical Siri Remote remains pending. Tool/screenshot roundtrip duration is not input latency; hurried batched destination inputs can precede focus settlement, so only stable focused-origin actions below are counted.

## Short fresh interaction baseline

This extends, rather than repeats, [M0 QA](../assessments/qa.md). Each journey below is a single fresh sample unless noted.

| Journey | Observed baseline | Comparison boundary |
| --- | --- | --- |
| Home favorite → watch → return | From focused ESPN favorite, Right focused NBC · Boston and changed the hero without full-screen tuning. One Select on NBC opened its fixture player. One Back with controls hidden returned to Home with NBC's hero retained, **focus on the top Home button**, not the NBC card. | One Select + one Back from the focused favorite; setup/corrective movement excluded. Candidate must restore the card or documented valid fallback. |
| Guide traversal → channel → return | All filter → Down Live Desk → Down ESPN changed selected metadata/preview without full-screen tuning. One Select on ESPN's channel name opened ESPN. One Back with controls hidden retained the Live TV destination and ESPN details, but **focused Home in top navigation**. | Fresh reproduction strengthens M0 QA-2, which previously had only one observed guide-return case. This is a channel-name path, not a program-cell test. |
| Sports / Fantasy → watch → return | Fantasy scope → Down focused NFL RedZone without tuning; Select opened its fixture player. After the drawer/scorebug checks and controls auto-hide, Back returned to the same Fantasy board, **focus on top Home**, not RedZone. | Four live games and two watch channels, not baseball/feed coverage or a full Sports journey press-count benchmark. |
| Focused scorebug / drawer Back | Up from hidden controls focused Pause; another Up focused scorebug. Escape left scorebug focus and visible controls unchanged. Selecting the scorebug opened Matchup; Escape closed the drawer and restored scorebug focus; a further Escape again did nothing. | Two fresh ignored-Back observations, captured before the 10-second auto-hide. Confirms M0 QA-1. Auto-hide later allows Back to dismiss; it must not be mistaken for a successful scorebug Back. |

Existing M0 evidence remains the baseline for Quick Switch deduplication/current-stream exclusion, rail → controls → hidden → browse layers, and Fantasy Live/Upcoming scope behavior. Those were not rerun in full. Current/future/expired program cells, a second guide origin, empty Home/settings/return, baseball feeds, removed-origin fallback, preferences, repeated/spaced Back and delayed-data behavior await the populated S1 candidate fixture and exact source.

Local, sanitized **baseline fixture UI** artifacts (not committed):

- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-baseline-evidence/fixture-guide-return.png` — verified screenshot: Live TV/ESPN retained, Home button focused.
- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-baseline-evidence/fixture-scorebug-after-autohide.png` — verified screenshot captured after controls auto-hid; demonstrates the empty-player scorebug layout only, **not** the ignored-Back focus state. The before/after focused scorebug evidence is in this task's UI captures. Final candidate captures must be verified for the intended state before handoff.

## Profiling feasibility and checks

`xcrun xctrace list templates` succeeded with normal tool-cache escalation and lists SwiftUI, Time Profiler and Animation Hitches. `xctrace list devices` recognizes the dedicated tvOS simulator. Bounded Time Profiler attempts against the live Quick Switch fixture process PID `37880` both failed before recording:

1. `xcrun xctrace record --template 'Time Profiler' --device C95B257D-0111-40A1-9D02-2AD70D850FF8 --attach 37880 --time-limit 30s --output .build/S1-baseline-time-profiler.trace`
2. Same app-specific attachment through the default Mac host, omitting `--device`, with 20s limit and `.build/S1-baseline-host-time-profiler.trace` output.

Both exited **21**, `Cannot find process for provided pid: 37880`. Between attempts, `ps` confirmed that PID alive and its executable inside the assigned simulator's Joe-TV app container. No all-process recording, permissions/settings changes or other-device operation was attempted. SwiftUI template availability is verified; SwiftUI recording is **not** verified. This establishes an attach limitation in this session, not universal tvOS Instruments incompatibility. No usable trace, app CPU/latency/memory statistic, performance gain or numerical budget is claimed. Source's intentional guide-preview dwell is not a measured stall. Bounded visible state/activation comparisons are currently the reliable method; a future profiling attempt needs a concrete attachment fix, not repeated setup retries.

Fresh `scripts/team-check.sh smoke` at the exact S1 starting SHA: **PASS**, exit 0, `Parser smoke test passed`; existing FairPlay SPC API deprecation warning remains. Log: `.build/S1-baseline-smoke.log`. No new build was run in this baseline checkpoint under PM's explicit source-equivalent artifact reuse authorization. Prior M0 build evidence is historical; final integrated acceptance requires fresh smoke **and** unsigned Debug build at PM's exact SHA.

## Ready state / next acceptance

PM may supply the integrated candidate and fixture instructions. QA will verify its exact source, fresh build/smoke, then exercise the S1 matrix: Home favorite and empty Home/settings return; two guide origins with current/future/expired selection; no full-screen tune on focus; Sports/baseball/feed return; Fantasy/Quick Switch/control Back layers with spaced/repeated input; valid and removed-origin restoration; retained filters/preferences. Record unsupported fixture cases explicitly rather than asserting coverage. Preserve a few sanitized candidate screenshots with absolute paths for PM/Design and compare supported steps only.

Real playback startup/first-frame, audio, captions on actual media, FairPlay, physical remote, couch readability and device performance remain pending appropriate media/hardware. This checkpoint does not accept the unfinished S1 candidate or authorize a release.

## Original integrated candidate — bounded acceptance checkpoint

Tested exact PM candidate **`f394d4d356851092ae579051cff5a5a667d53cdb`**, branch `codex/joe-tv-qa-s1-candidate`, created after clean-status and branch-absence checks. Earlier QA branches preserved. Scope: TEAM-4 S1 interaction acceptance against the candidate's checked-in S1 App/Playback/Design fixture and behavior notes. Only `docs/sprints/S1-qa.md` changed; no application or test code changed.

Fresh `scripts/team-check.sh smoke`: **PASS**, exit 0, parser smoke passed; existing FairPlay SPC API deprecation warning. Fresh `scripts/team-check.sh build`: **PASS**, exit 0, `BUILD SUCCEEDED`, unsigned Debug generic tvOS Simulator, arm64/x86_64, deployment target 17, SDK 26.5, same Xcode/host as baseline. Existing AppIntents no-dependency and always-run media-validation script warnings remain. Logs: `.build/S1-candidate-smoke.log` and `.build/S1-candidate-build.log`. Installed fresh version 1.0 **build 7** over the existing dedicated QA app without deletion/reset. No further build ran during Services' compiler window.

Only Joe-TV Team QA (`C95B257D-0111-40A1-9D02-2AD70D850FF8`) was operated. All seven simulators were Shutdown before this candidate session; Joe-TV was terminated and QA shut down at completion, with all seven again confirmed Shutdown. Retained dedicated app data; no cold-cache claim. No authenticated media or provider probes.

### Fixture and evidence boundaries

- Navigation fixture: `JOE_TV_DEBUG_NAVIGATION=1`; destination `guide` / `sports` when needed and `JOE_TV_DEBUG_EMPTY_FAVORITES=1` for empty Home, passed through `SIMCTL_CHILD_` launch variables. Twelve enabled channels, first eight favorites, four EPG programs per channel (expired/current/future/later), eight live baseball games with Home/Away choices. Channel 01 lacks synopsis; channel 12 has long text. Dates use actual launch time; the clock is not frozen. Default current-program duration was used; boundary crossing was not tested.
- Navigation fixture uses a reset-on-launch separate defaults suite, ready empty AVPlayer sessions and no artwork URLs. Source inspection supports provider isolation; this was not a packet-capture/network audit. A hash-only comparison of the ordinary dedicated-app preference plist before and after navigation scenarios was byte-identical (`cmp` exit 0; `.build/S1-normal-preferences-before.sha256` and `after.sha256`). This comparison ended **before** the older Fantasy fixture, which uses ordinary dedicated-app preferences; it makes no isolation claim for that later fixture.
- Fantasy used only `JOE_TV_DEBUG_FANTASY_ZONE=1`: four NFL games, RedZone/NFL Network, sample matchup, empty player, possible public ESPN artwork. These fixtures prove UI state transitions, not decoding, streaming or real feed selection.
- Keyboard input and visual verification as in baseline. Immediate post-key screenshots sometimes precede settled UI; subsequent captures resolved state. Tool execution duration is not input latency. Reported narrow activation counts begin at a verified focused origin; no whole-journey speedup or remote gesture equivalence is claimed.

### Observed candidate matrix

| Case | Result and observed behavior | Limits |
| --- | --- | --- |
| Home focus, watch, return | **PASS.** Right from favorite 01 focused 02 and updated its hero without full-screen tuning. One Select entered player; one Back from hidden controls restored **favorite 02 card focus**, fixing the baseline top-navigation return. Repeated watch/return also restored 02. | No media-startup measurement. |
| Quick Switch preserves original browse origin | **PASS.** From Home 02 playback, Down opened rail with 01 first and active 02 omitted. Selecting 01 visibly changed badge/title to channel 01 / Current Program 1. Back through controls and hidden layer returned to **original Home 02**, despite the replacement stream. | One earlier rail attempt auto-hid before Select and is excluded. No exhaustive deduplication rerun. |
| Removed Home origin | **PASS.** Unfavoriting playing 02 through the player removed its card. Back focused **03**, the valid next card at the former index. | Fixture has no asynchronous removal of guide programs or sports events. |
| Explicit player Guide | **PASS.** From Home 03 player, selecting Guide opened **Live TV**, with All filter focus, instead of restoring Home. | Initial guide selection was channel 01; playing-channel alignment is not claimed. |
| Empty Home and Channels return | **PASS.** Choose Favorites opened existing Channels. Cancel with no change restored CTA focus. Adding 01 and leaving focused the new first Home card. Opening Channels through More and disabling 01 retained its favorite star (11 enabled / 1 favorite); leaving ordinary settings restored More focus. Reopening from empty Home retained the disabled favorite; Done restored CTA without silently enabling it. | In-launch setting persistence verified; fixture deliberately resets its separate suite each launch. Existing sheet clipping recorded below. |
| Current program / channel-name / details-watch guide playback | **FAIL — S1-QA-C1.** Three entry paths reached full-screen fixture playback but then controls could not be recovered with Up and a reliable return was unavailable. Current-program path reproduced from an existing session and fresh guide launch; fresh channel-name and future-details Watch paths showed channel 02's initial badge/current title before later input failed. | Do not interpret black empty-player video as a media failure or absence of initial player rendering. See reproduction below. |
| Future / expired program details | **PASS for details.** Future 01 showed scheduled date/time and Watch channel now explanation, with no invented synopsis. Close returned focus to Future Program 1 in the same viewport. Scrolling to future 12 and opening showed long title and synopsis truncated inside the sheet, with both actions and explanatory copy visible. Expired 12 showed its past date/time and the same truthful live-channel CTA, without implying replay. | Future Watch activation is covered by the blocker; expired Watch was not repeated. Two successful guide playback origins and clock-boundary behavior remain pending. |
| Baseball selector and return | **PASS.** From Sports Live (8), Game 2 Select opened Home 2 / Away 2 choices. Cancel restored Game 2 focus/metadata. Reopen and select Home 2 entered a player titled Fixture Game 2; Up exposed controls. Back through controls then hidden returned to **Game 2** in the same Live grid. | One game and one chosen feed; no actual video, National feed, filter-persistence or event-mutation coverage. |
| Focused Fantasy scorebug Back | **PASS.** Hidden player → Up Pause → Up scorebug → Back hid controls and retained player/scorebug, observed before the 10-second auto-hide. This addresses the baseline ignored-Back case. | Sanitized screenshot captures resulting hidden state; preceding focus/action is documented by UI observations. |
| Fantasy drawer and spaced Back layers | **PASS, staged fresh sequence.** RedZone → player → focused scorebug → Matchup. One Back closed drawer and visibly restored focused scorebug with controls. Next Back hid controls. Next Back returned to Fantasy board with **NFL RedZone card focused**, fixing baseline top-Home focus. | Earlier batched exploration ended at system Home unexpectedly; timing/transition ambiguity prevents attributing it to a guard defect. Fresh separated sequence passed. Sub-450 ms duplicate delivery and rapid-repeat guard remain **unverified**, not passed. |

### S1-QA-C1 — guide-origin player loses usable input (acceptance blocker)

Reproduce on original candidate with navigation fixture destination `guide`: focus Current Program 2, Select, allow initial player badge to clear, then press Up. Expected: player controls become usable; Back unwinds to the captured guide origin. Observed: full-screen empty-player surface persists, Up does not reveal controls, and spaced Back does not reliably restore the guide. Reproduced after an earlier Home → explicit Guide sequence and in a fresh guide launch. In one attempt Back eventually reached system Home while the Joe-TV process remained alive; this is not evidence of an app crash.

PM requested comparisons, completed using fresh launches: (1) focus channel 02's channel-name cell with `LIVE PREVIEW · MUTED` visible, Select; (2) open Future Program 2 details, then select Watch channel now. **Both initially showed channel 02's badge and Current Program 2 title**, then Up failed to recover controls after the badge cleared. Thus the failure is shared across tested guide handoffs, not isolated to the direct current-program shortcut. Home and baseball entry controls were usable in independent tests.

Runtime log inspection found repeated SwiftUI “Publishing changes from within view updates” faults and render-pipeline compilation messages while the process was alive. Causality is unestablished; these logs are not a measured latency result. PM/App's suspected native muted-preview focus ownership is a **hypothesis**. App correction commit `9132f930897fd162df9e7572b3118953e9934821` was reported by PM but **was not built or tested in this checkpoint**. Wait for PM's exact corrected integrated SHA and explicit compiler release before targeted A/B verification; do not treat that correction as accepted from source description alone.

### Layout observation and verified artifacts

The existing Channels sheet clips its surfing row text/subtitle, truncates channel names to indistinguishable “Fixture Channel…” labels, and wraps Clear Favorites across three lines at this simulator size. Controls used above remained reachable. Sent to PM for subsequent polish; this is **not established as an S1 regression** because the same sheet was not compared on baseline. Program details, in contrast, retained readable actions/support text with long fixture content.

All five local PNGs below were reopened and visually verified after capture. They are sanitized fixture UI, uncommitted; screenshot state alone does not prove the input sequence.

- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-candidate-evidence/fixture-guide-select-black.png` — empty black player after guide activation/badge timeout. Supports state only; the failed Up/Back observations above establish the blocker.
- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-candidate-evidence/fixture-empty-home-return.png` — empty Favorites and focused Choose Favorites after cancel.
- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-candidate-evidence/fixture-settings-disabled-favorite.png` — disabled first channel retains favorite; 11 enabled / 1 favorite, plus sheet clipping.
- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-candidate-evidence/fixture-long-future-details.png` — future channel 12, two-line truncated title/three-line synopsis, visible CTA/Close/explanation.
- `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-candidate-evidence/fixture-scorebug-after-back.png` — controls hidden after observed focused-scorebug Back, scorebug/player retained.

### Remaining acceptance and handoff

Original candidate is **not accepted**, despite fresh build/smoke and independent passes above. Next bounded check: exact corrected candidate fresh build/smoke, then the three failed guide entry paths, successful restoration from two guide origins, and remaining guide timing/filter cases supported by the fixture. Preserve independent passing evidence rather than broadly rerunning it without a change-related reason. Rapid duplicate Back, removed guide/Sports origins, delayed-data behavior and broad filter persistence are not established by this checkpoint. Baseline Instruments attachment limitation remains; no retry or performance gain claimed.

Physical Siri Remote, VoiceOver/Reduce Motion, real media startup/audio/captions, FairPlay, couch readability and device performance remain pending suitable hardware/media. No deployment or release was performed or authorized. QA has stopped the app and shut down its simulator; PM retains coordination of the next exclusive runtime/compiler window.

## Correction candidate — build checkpoint, UI blocked

Exact PM candidate: **`d010f395bcae7b66e46a6b50168005005f0ba9b2`**. Created clean `codex/joe-tv-qa-s1-correction` from this SHA after clean-status and branch-absence checks, preserving prior branches. Same S1-QA / TEAM-4 assignment and report-only ownership. Source comparison against `f394d4d` confirms the sole application-source change is `JoeTVExperience.swift`: passive, nonfocusable/noninteractive `AVPlayerLayer` preview surface replaces `AVPlayerViewController`, with player detachment on dismantle. Candidate also contains Services' host benchmark scripts and reports; no S2 application changes. Source inspection alone does not verify the focus correction.

- Fresh `scripts/team-check.sh smoke`: **PASS**, exit 0, parser smoke passed; existing FairPlay SPC deprecation warning. Log `.build/S1-correction-smoke.log`.
- Fresh `scripts/team-check.sh build`: **PASS**, exit 0, `BUILD SUCCEEDED`; unsigned Debug generic tvOS Simulator, SDK 26.5, same host/Xcode/DerivedData path as original candidate. Existing AppIntents no-dependency and always-run validation-script messages remain. Log `.build/S1-correction-build.log`. Verified artifact build number **7**. Compiler released to PM after completion.
- Preserved full build-7 bundle from exact `d010f395bcae7b66e46a6b50168005005f0ba9b2` at `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-corrected-artifact/Joe-TV.app` before any subsequent build. Copied executable and debug dylib SHA-256 values match their original build products (`b2ee0d6a5090e30e1483ec86ec72ab5a139d7d7a6c0167ffd4e94666cc983b11` and `47082a5872b5302a6aeba49144253b50500c9d411c4849dcdd0dbb5bdb6c6008`, respectively). This uncommitted local artifact preserves the preview-only comparison independently of future S2 builds.
- All seven simulators were Shutdown at entry. Booted only assigned QA `C95B257D-0111-40A1-9D02-2AD70D850FF8`, installed over existing app without deletion/reset, launched navigation fixture directly to guide (PID `46633`). No real-media probe.
- First native UI access returned **“The Mac is locked and automatic unlock could not unlock it.”** No corrected guide screen, controls, input, return focus, boundary behavior or screenshots were observed. Manual unlock was requested; no lock bypass or substitute input mechanism attempted. Thus **S1-QA-C1 remains unverified on the correction**, not passed or reproduced.
- App terminated and assigned simulator shut down after the blocked attempt. All seven again confirmed Shutdown. No profiling retries or unrelated retests. Only this report changed.

Resume after manual Mac unlock under PM's runtime coordination: use this exact built artifact if source remains identical, check the three guide entry paths after active preview/badge timeout, usable controls and Back to two distinct origins, focus-only preview, retained filter/horizontal scroll, and selection-time boundary if practical. Keep original unrelated passes attributed to `f394d4d`. This build checkpoint does not accept the correction or release S1.
