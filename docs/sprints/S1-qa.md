# S1 QA — baseline checkpoint

Status: **baseline complete; ready for PM's exact integrated candidate. Final acceptance pending.**
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
