# Joe-TV team assessment — integrated findings

Status: **M0/R1 complete for team setup, assessment and research.** Independent integrated-document QA accepted the assembled package; product implementation remains deferred.
Spec: TEAM-3. App source: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`. PM also includes release commit `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`, whose only app/project delta is build number 6 → 7.
Integration branch/worktree: `codex/joe-tv-team`, `/Users/joecoakley/.codex/worktrees/joe-tv-team-pm`.

The team is established. The strongest next candidate is polishing everyday watching and returning, followed by measured responsiveness. The sidebar and favorite-team Home are recorded as future experiments. No application code or services were changed by this setup/research milestone. See [the ranked roadmap](../roadmap.md).

## Team evidence

| Role | Integrated deliverable / source commits | Main contribution |
| --- | --- | --- |
| Product Design | [Assessment](design.md), `7cd3200` + `49b8912`; [research](../research/streaming-discovery.md), `1336952` | Current journeys, fewer redundant actions, layout/focus hypotheses, Netflix/Disney+/Plex patterns |
| tvOS App | [Assessment](app.md), `bd4b790` + `e85a7b1` | Active navigation/state paths, bookmark and guide-window issues, performance measurement plan |
| Playback | [Assessment](playback.md), `c54738d`; [research](../research/live-tv-patterns.md), `23d6cfc` | Switching/lifecycle, live position, captions, YouTube TV/Hulu/Fubo patterns |
| Services | [Assessment](services.md), `a6dcdac` | Provider/API/publisher boundaries, cache/freshness, event identity and partial failure |
| SecOps | [Assessment](secops.md), `013b886` | Credential/destination/session boundaries, conditional risks, synthetic release-validator result |
| QA | [Baseline and integrated QA](qa.md), `cd9fc84` + `82e8ea5` | Fresh smoke/build and dedicated simulator evidence; independent device/fixture matrix |

PM integrated each report sequentially. Original technical reports retain TEAM-1 provenance; Design/App added TEAM-2 priorities; TEAM-3 governs deferred improvements and competitive research. No retesting claim is created by a spec-label change.

## Findings to act on, and their limits

| Finding | Evidence strength | Consolidated action |
| --- | --- | --- |
| Fantasy scorebug ignores Back while focused | Repeated keyboard Escape result in dedicated tvOS 26.5 simulator; source explains missing local handler. Physical remote pending. | One Playback-owned Back/focus slice, with App/QA, in roadmap package 1. |
| Guide return can focus Home navigation instead of original row | One complete simulator sequence, not a demonstrated universal failure. Source restoration paths need reproduction. | App/Playback jointly reproduce across origins; preserve row/filter/scroll. |
| Some common actions add avoidable decisions or appear inert | Source: current-program sheet then Watch; indirect empty-Home settings path; unavailable Sports Select returns. Exact end-to-end remote counts are unmeasured. | Prototype direct useful actions; preserve genuinely necessary details/feed choices. |
| Captions disappear while no tracks are loaded | Source plus empty-player fixture observation. Real caption tracks/selection untested. | Explicit understandable caption states, then known-media validation. |
| Data/cache and async lifecycle can invalidate otherwise useful state | Independent Services/SecOps source traces; Playback/App identify late resolution. Conditional runtime outcomes mostly unreproduced. | Merge duplicate cache findings into one Services slice and stale resolution into one Playback/Services boundary. Use delayed/malformed synthetic fixtures. |
| Responsiveness needs measurement | User feedback plus source hypotheses; no Instruments/timing/memory results. Prior optimizations are historical/code evidence. | Collect named baseline journeys and separate focus/rendering from service/media waits. |
| Event matching and preference handling need protection | Source predicates permit ambiguous doubleheaders; bookmark reconciliation mixes identity types. No sampled live misrouting proved. | Bound correctness work before personalized team Home; retain migrations and feed/date rules. |

## Fresh verification versus pending coverage

| Check | Actual status |
| --- | --- |
| Offline parser/policy smoke | **PASS**, executed at bootstrap `314968d` / app build 6. Host Swift 5 language mode; no app-view/UI orchestration in this executable. |
| Unsigned Debug tvOS simulator build | **PASS** at `314968d`, Xcode 26.6 (17F113), Simulator SDK 26.5 (23L470). Initial sandbox CoreSimulator error resolved with normal permission escalation. |
| Dedicated simulator interaction | Sampled navigation, Quick Switch identity, guide without EPG, Fantasy drawer/no-live and Sports Live/Upcoming tested. Scorebug Back failed; guide return concern recorded. Empty players do not prove media behavior. |
| Test environment cleanup | Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8` shut down; original simulator states preserved. No authenticated provider streams opened. |
| SecOps synthetic release guard | Seven cases executed; whitespace-only value passed shell validation but would fail runtime normalization. No real tokens read/exposed. |
| Integrated scope | PM compared `138c271` with assembled branch: no delta in app source, tests, project or Config. Changes are docs plus an offline check wrapper. Independent QA also confirmed exact tree equivalence at reviewed commit28e3406; acceptance is recorded below. |
| Not verified | Physical Siri Remote; FairPlay/renewal/protected captions; real media failure/cleanup/live-edge; login/session persistence; backend authorization/deployment; performance, full VoiceOver/couch/4K acceptance. |
| Existing release | Another task owns TestFlight. Its build-7 source commit is reconciled; this work does not assert App Store processing or release acceptance. |

## Security and service scope

SecOps found no confirmed critical/high finding in its scoped review. Medium candidates concern distributed read-token scope, provider-derived destinations, and sign-out lifecycle; missing backend evidence remains unknown rather than a pass. Logging/identity practices worth preserving include Debug domain/code diagnostics, transient playback resolution, and stable history IDs.

Services owns coordinated future work across the app, Personal Media API and Mac mini publishers, but could not identify authoritative local source/deployment baselines in the bounded discovery. The publisher architecture is accepted history, not fresh remote verification. Obtain exact source/version/install evidence when a backend change is assigned. No Notion/Northstar integration is needed.

## Internal coordination and next step

A fresh read-only coordinator completed the first [internal standup](../standups/2026-09-16.md), identifying stale status labels, overlapping cache/focus findings, and QA's evidence limits. Specialist contexts remain available; no recurring schedule is installed. PM chooses models per assignment under Joe's authorization.

All six specialists have completed their assigned work and may idle. All product improvements stay deferred; [roadmap package 1](../roadmap.md) is the recommended next implementation choice.

## Integrated acceptance

QA **accepted** exact assembled commit `28e3406c7aa67787537faa53d17bbbfb0b01b8da`, with no blocking documentation fixes. Evidence is committed in `82e8ea5a9dd1e68158a96fa12c294d9f106d3b75` and integrated into PM. QA checked report provenance, 32 relative file targets across 26 documents, twenty official research URLs, scope/claim consistency and three direct official-page anchors. This is documentation acceptance, not media/device/release certification.

After review, PM corrected two nonblocking facts against source: the Last Stream hint already exists, and sports detail prefetch selects up to 12 identities in two-item batches. PM also closed checkpoint status labels, recorded the QA model and cleaned decision-table formatting. Application/test/project/configuration trees remain unchanged. No new runtime pass is claimed for those document edits. Remaining hardware, media, accessibility, performance and backend checks above are future implementation/delivery dependencies.
