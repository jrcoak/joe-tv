# M0-QA — baseline verification and acceptance plan

## 1. Assignment and evidence boundary

- Assignment/spec: **M0-QA / TEAM-1**, accepted September 16, 2026 (America/New_York).
- QA task: `01a0ad34-d1be-78d0-b050-35a67462b35d`, host `local`.
- Worktree: `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV`.
- Branch and tested HEAD: `codex/joe-tv-qa` at `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`.
- App baseline: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`. A scoped diff confirmed no changes between that commit and tested HEAD in `SeasonsTV/`, `Tests/`, `Joe-TV.xcodeproj/`, or `Config/`.
- Initial managed checkout was clean at `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`; the requested QA branch did not exist. Created it at the assigned bootstrap commit without resetting another branch or editing another checkout. The tested app is version 1.0, build **6**. PM later reported separately integrating release build 7; that integration was not tested here.
- Owned change: this report only. No app, project, shared documentation, signing, credential, production-service, or release changes.
- Inspected: all required team documents; `scripts/team-check.sh`; `Tests/ParserSmoke.swift`; relevant `Models.swift`, `ChannelDirectory.swift`, `AppModel.swift`, `RootView.swift`, `JoeTVExperience.swift`, `PlayerScreen.swift`; project target configuration; README and technical-handoff testing claims. Parser/client behavior is assessed through the smoke fixtures, not a fresh exhaustive services/security audit.

**Result:** offline smoke and unsigned Debug build pass. Actual keyboard-driven simulator fixture interaction established several navigation paths and identified two focus/Back concerns below. This is bounded baseline evidence, not release acceptance. Integrated-assessment QA remains a later PM assignment at an exact assembled commit.

Evidence labels used below: **observed** means this task ran the check; **source** means inspected implementation; **historical** means a prior document/task claim; **inferred** means a risk or proposed benefit not measured here.

## 2. Existing strengths to preserve

- **Observed offline:** the suite protects real product decisions: all 26 sports categories and legacy-filter expansion; repeated baseball series/date separation; the 15-minute coverage boundary; replay/studio exclusions; merged S4U/ESPN+ sources; Quick Switch recency, four-item limit, deduplication, and omission of the active target. Evidence: `Tests/ParserSmoke.swift:35–123`, `:414–513`, `:567–776`.
- **Observed fixture UI:** moving focus between Quick Switch cards leaves the active identity unchanged; Select changes it; the previous channel becomes a recent entry and the new active channel is absent from the rail. Home/Live TV navigation distinguishes focused and selected destinations. A guide with unavailable schedule data remains navigable and can open a fixture channel.
- **Observed fixture UI:** Fantasy has the compact scorebug, two drawer tabs, lineup totals, and League pairings. The no-live-games fixture retains NFL RedZone/NFL Network and the extended NFL schedule. Ordinary Sports can move from an empty Live view to Upcoming without leaving the screen.
- **Source:** `AppModel.installPlaybackSession(_:target:presentation:)` retains the previous session for preparation-failure recovery; `PlaybackSession` has preparation timeout and subtitle-load cancellation. These are useful foundations, but their real-media failure paths were not exercised.
- **Source:** explicit synthetic `debug` playback references avoid provider stream resolution in the tested Quick Switch/Fantasy paths. Fixtures are Debug-only. Keep this separation and the current stable content identities.

## 3. Findings, impact, and confidence

### QA-1 — Back is ignored while the Fantasy scorebug is focused

**Priority:** P2 interaction defect candidate. **Status/confidence:** observed repeatedly with Simulator keyboard Escape; high confidence for this environment, physical Siri Remote result pending.

Reproduction on the dedicated tvOS 26.5 simulator:

1. Launch with `JOE_TV_DEBUG_FANTASY_ZONE=1`; select NFL RedZone.
2. Up opens player controls; Up focuses the scorebug.
3. Press Escape before chrome auto-hide. Scorebug focus and controls remain visible.
4. Opening the drawer with Select and closing it with Escape restores scorebug focus; another Escape is again ignored.

Evidence: `SeasonsTV/Views/PlayerScreen.swift:322`, `PlayerSessionView.playerChrome`, gives the scorebug Down handling but no local `.onExitCommand`/Escape handler. Other controls, e.g. Play/Pause at `:465–478`, explicitly call `handleBack()`. The parent `handlePlayerBack()` at `:926` only handles hidden chrome with `playerFocused == true`, so it does not cover this controls-layer focus target. This supports the observed result; it does not prove hardware event delivery.

Impact: Back appears unresponsive immediately after closing Fantasy details. Owner: Playback; App coordinates focus semantics. Smallest experiment: a separately assigned local scorebug Back handler using the existing `handleBack()` path. Acceptance: one Back from focused scorebug hides controls, the next exits playback into the originating context; drawer Back still closes only the drawer. Repeat with keyboard and physical remote, including rapid and deliberately spaced presses.

### QA-2 — exiting guide playback did not restore the originating row

**Priority:** P2 focus-restoration concern. **Status/confidence:** one complete observed keyboard sequence; medium confidence pending a dedicated reproduction and hardware comparison.

Using Quick Switch fixtures, navigate Home → Live TV, focus ESPN in the guide, Select to open playback, Down for Quick Switch, then three individually observed Escapes: rail → controls → hidden controls → browse. The Live TV guide and ESPN details remained visible, but the **Home navigation button** had focus, not the originating ESPN row or the selected Live TV navigation item. The app stayed open.

Relevant source: `SeasonsTV/Views/RootView.swift`, `RootView.body` player overlay and `CatalogView` destination focus; `SeasonsTV/Views/JoeTVExperience.swift:494`, `JoeTVGuideView.restoreFocus()`; `SeasonsTV/Views/PlayerScreen.swift:911`, `dismissPlaybackAfterBackPress()`; `SeasonsTV/App/AppModel.swift:1730–1750`, `beginPlaybackBackDismissal()`/`dismissPlayback()`. Source locations identify the handoff, not a proven root cause.

Impact: additional navigation is needed after watching, and focus differs from the selected destination. Owner: App with Playback. Smallest experiment: reproduce starting from two different guide rows and a Home favorite, then compare explicit focus restoration when the overlay disappears. Acceptance: Back preserves destination, filter, scroll position, and original focused content; a single Back never also exits the app. Record fresh results at the eventual fix commit.

### QA-3 — current fixtures cannot establish switching recovery or media behavior

**Priority:** P1 coverage gap before playback changes, not an observed playback failure. **Status/confidence:** source, high.

`SeasonsTV/Models/Models.swift:1227`, `PlaybackSession.init(debugTitle:isLivePlayback:)`, creates `AVPlayer()` with no item and immediately sets `isReady = true`. `AppModel.configureQuickSwitchDebugFixture()` (`:1485`) and `makePlaybackSession(for:)` (`:1148`) use that path. It bypasses media preparation, timeout, buffering, license requests, audio overlap, live-edge position, subtitle discovery, and recovery callbacks.

`scripts/team-check.sh` smoke compiles policy/parser/service-model files against the host SDK; it does **not** compile `AppModel` or views into the smoke executable. `Tests/ParserSmoke.swift` is one fail-fast executable, not an XCTest/UI target. Successful rail-policy assertions therefore do not verify `AppModel.installPlaybackSession` rollback, cancellation, or observer/session cleanup.

Impact: a polished passing fixture run could still conceal a failed real stream switch. Owners: Playback + Services, with PM assignment for `AppModel.swift`, `Models.swift`, tests, and project changes. Acceptance for closing this gap is in proposal QI-1; hardware DRM remains separate.

### QA-4 — captions unavailable explanation is not reachable through current controls

**Priority:** P2 source discrepancy with TEAM-1. **Status/confidence:** source plus empty-player fixture observation, high for control visibility; suitable-media behavior pending.

`SeasonsTV/Views/PlayerScreen.swift:533` only renders the Captions button when `session.subtitleOptions` is nonempty; `controlFocusTargets` at `:779` uses the same condition. The confirmation dialog at `:238–258` contains a disabled “No captions available” item, but the normal button cannot open it when there are no options. The tested empty-player controls showed no captions entry, as this condition predicts. This is not evidence about a real stream's caption tracks.

Impact: a viewer cannot readily distinguish unavailable captions from a missing control or a track still loading. Owners: Design + Playback. Smallest experiment: agree one consistent discoverable unavailable/loading state; check one captioned clear stream and one stream without captions. Acceptance: viewer can identify availability, select a supplied track, turn it off where supported, and return focus to the captions control without interrupting playback.

### QA-5 — deterministic fixture coverage is useful but incomplete and not wholly isolated by a flag

**Priority:** P2 testability gap. **Status/confidence:** source, high; future failure frequency unknown.

`AppModel.init(...)` (`:146–233`) accepts injected guide/Fantasy providers and UserDefaults, but default construction reads/migrates ordinary preferences before checking fixture environment variables. `configureFantasyZoneDebugFixture()` uses `Date()` and remote logo URLs; `refreshFantasyZone()` explicitly skips refresh in that fixture. The Sports destination/baseball-selector flags change navigation/selection without supplying a catalog. They must not be treated as offline dataset fixtures.

No deterministic UI fixture was found for stale/error guide data, failed media preparation, delayed responses, expired login, preference upgrade, or a full baseball selector dataset. The built-in captions flag accepts a supplied URL; no bundled captioned media asset was identified. The new dedicated simulator contained preference writes from normal initialization, but no existing user simulator or account was changed.

Impact: empty/loading/error and upgrade behavior are harder to reproduce safely; different dates/preferences can change screenshots. Owners: Services + App, with PM allocation of shared initialization/tests. Acceptance: named scenarios select fixed time, isolated preferences, and synthetic providers before side effects; fixtures require no production credentials and remain clearly identified in evidence.

## 4. Three practical improvement proposals

These are proposals, not implementation authorization. Effort is relative: small = focused change; medium = coordinated changes across the named owners. No performance gain or delivery date has been measured.

| ID | Viewer situation and proposed behavior | Existing foundation / evidence | Benefit and confidence | Effort / dependencies | Smallest experiment and success criterion |
| --- | --- | --- | --- | --- | --- |
| QI-1 | A viewer switches during a game and the next stream fails. Preserve the previous stream, show a recoverable message, and let another selection succeed. Add deterministic ready/delayed/fail/timeout scenarios to verify this behavior. | Existing `installPlaybackSession` rollback and 20-second `PlaybackSession.startPreparationTimeout()`; current fixture bypasses both (QA-3). | Protects continuity; high confidence that the coverage gap exists, benefit size unmeasured. | Medium; Playback leads, Services supplies fake resolver, QA writes scenarios; PM assigns shared model/AppModel/test symbols. | Start with A ready → B preparation failure → C ready. Assert active ID/recents only commit on readiness, A resumes after B fails, B is paused, retry is reachable, late callbacks cannot replace C, and at most one session is playing. Add a controlled local clear-media run; FairPlay still requires hardware. |
| QI-2 | A viewer returns from playback or closes Fantasy details and should continue exactly where they left off. Establish a short, repeatable focus/Back journey suite while addressing QA-1/QA-2. | Existing focus state, accessibility identifiers on player controls, Back suppression, and passing rail/drawer interactions. | Removes dead-end-feeling remote actions; high confidence in scorebug reproduction, medium in guide restoration scope. | Small-to-medium; App + Playback + Design; dedicated simulator and later Joe/device session. | Use two guide origins, a Home favorite, and Fantasy scorebug/drawer. Replay Select/Back at each layer, including before auto-hide; record focused target after each action. Pass only when one action unwinds one layer and restores the named origin without tuning on focus or escaping the app. |
| QI-3 | A viewer upgrades the app or encounters an empty/stale schedule. Preserve their favorites/filters and keep working streams available. Add fixed-clock, isolated-preferences scenario coverage. | Sports boundary/migration policies already pass smoke; AppModel migration and failure orchestration are outside that suite. Guide fixture with unavailable schedule remained navigable. | Safer updates and clearer failure handling; high confidence in missing orchestration coverage, UX benefit inferred. | Medium; App + Services, Design for state wording, QA; PM allocates AppModel/tests, SecOps reviews any transport diagnostics. | Seed a temporary defaults suite with an explicit removed NHPBS favorite and legacy sports filters; construct twice and verify idempotence/user choices. Advance fixed time across coverage −1 second/at boundary and midnight; inject stale guide then failure. Pass if preferences survive, no wrong-day feed becomes playable, cached data is distinguishable, and valid channel selection still works. |

## 5. Ownership, documentation, and dependencies

- QA owns this report and independent acceptance; code fixes must be assigned to the owners above. No silent repairs were made. PM retains `AppModel.swift`, `Models.swift`, `Tests/ParserSmoke.swift`, and project-file allocation.
- **Observed documentation discrepancies:** README's statement that Joe-TV never contacts ESPN (`README.md:15`) conflicts with the intentionally direct Fantasy scoreboard provider in `AppModel` and `ESPNScoreboardClient`. README's “Watch Very Local free” login instruction (`:31`) is absent from current `RootView.LoginView`. `docs/TECHNICAL_HANDOFF.md:487` describes 66 curated channels while the smoke guard at `Tests/ParserSmoke.swift:1388–1392` verifies 70. PM/docs owners should reconcile these without removing accepted features.
- **Historical only:** prior claims of live-edge lag near four seconds, successful FairPlay playback/TestFlight delivery, and earlier smoke/build passes were not reused as fresh evidence. This report neither confirms nor contradicts those sessions.
- Runtime ownership was initially withheld. PM then explicitly released the release task's session and assigned this QA task a dedicated simulator after smoke/build. Only the newly created device below was booted, installed, launched, terminated, or shut down by QA.
- Remaining dependencies: exact assembled assessment commit from PM; suitable controlled clear media with/without captions; deterministic failure/upgrade datasets; Apple TV with known tvOS version and physical Siri Remote; separately authorized, serialized real-provider session. No production secrets were copied or needed.
- Before accepting a numerical speed/memory budget, name the hardware, OS, stream, network, cold/warm state, and measurement method. This run did not collect performance or memory measurements.

## 6. Checks performed and remaining acceptance matrix

### Build and smoke evidence

Run September 16, 2026 EDT / September 17 UTC at tested HEAD `314968d…`:

| Check | Actual result / scope |
| --- | --- |
| Initial `git status --short`; branch check | Clean; QA branch absent. Branch creation needed ordinary Git worktree-metadata permission escalation. Clean again before report creation. |
| `scripts/team-check.sh smoke` | **PASS**, exit 0, final output `Parser smoke test passed`. Compiled Swift 5 language mode against host SDK. One warning: `FairPlayResourceLoader.swift:59`, older SPC resource-loader API deprecated in macOS 15.0. No live network test or license exchange. |
| `scripts/team-check.sh build`, sandboxed attempt | Exit 65. Asset compilation could not reach CoreSimulatorService; `Assets.xcassets: error: No available simulator runtimes for platform appletvsimulator`. Environment access failure, not classified as app regression. No device reset/restart performed. |
| Same build with normal permission escalation | **PASS**, exit 0, `** BUILD SUCCEEDED **`. Unsigned Debug, scheme/project Joe-TV, SDK `appletvsimulator`, destination `generic/platform=tvOS Simulator`, deployment target tvOS 17.0, arm64 + x86_64. |
| Toolchain | Xcode **26.6 (17F113)**; Apple TV Simulator SDK **26.5 (23L470)**; Swift **6.3.3**, `swiftlang-6.3.3.1.3`, host arm64 macOS target. Xcode and SDK versions differ; both were read directly. |
| Successful build diagnostics | Warning: AppIntents metadata extraction skipped because no AppIntents.framework dependency. Note: configuration-validation script runs every build because dependency analysis is disabled. No Swift source errors reported. |
| Cache/evidence isolation | Smoke `.build/ModuleCache`; build `.build/TeamDerivedData` and its module caches, entirely in this worktree. Untracked/ignored local logs: `.build/m0-qa-build.log` (sandbox failure), `.build/m0-qa-build-approved.log` (pass). Concise evidence is preserved here; logs are not part of the commit. |

### Offline fixture coverage inspected

All following groups are exercised within the single freshly passing `ParserSmoke.main()`; these are not separate XCTest results:

| Source in `Tests/ParserSmoke.swift` | Covered behavior | Important unproved behavior |
| --- | --- | --- |
| `:7–123` | EPG end-exclusive boundary/geometry, sports taxonomy/migration, recents rail policy, channel wrap, bounded seek calculation | Persistent migration orchestration, actual focus, actual seeking or session lifecycle |
| `:126–213`, `:1332–1470` | Very Local/NHPBS identities, mappings/ordering, Media API request construction/placeholder rejection, curated directory, numeric XMLTV matching | Live catalogs, authorization, cache 200/304/error transitions |
| `:216–411`, `:515–564` | Published schedule/detail decoding; ESPN scores and week-through-Tuesday; Sleeper identity, roster, scoring and lineup parsing | Live refresh, malformed/partial response recovery, onboarding UI |
| `:414–513`, `:567–776` | Repeated-series date separation, pregame boundary, Live/Upcoming/final behavior, taxonomy samples, merged provider sources | UI boundary timing, timezone/DST sweep, all production variants |
| `:779–1330` | HTML/controller requests, football variants, extensive baseball Home/Away/DVR/backup/null/partial cases, comment/template exclusion | Upstream contract changes outside these synthetic samples; full selector UI |
| `:1473–1575` | HLS parsing, international/domestic/ESPN+ FairPlay configuration, active content-ID rule despite commented code, correct FairPlay certificate choice | Any actual certificate/SPC/CKC exchange, license renewal, protected playback |

### Simulator session and direct interaction evidence

- Device created: **Joe-TV Team QA**, Apple TV 4K (3rd generation) **at 1080p**, **tvOS 26.5 (23L470)**, UDID **`C95B257D-0111-40A1-9D02-2AD70D850FF8`**.
- Installed the successful local unsigned Debug build using its explicit UDID. Launched three times: `JOE_TV_DEBUG_QUICK_SWITCH=1`; `JOE_TV_DEBUG_FANTASY_ZONE=1`; and Fantasy plus `JOE_TV_DEBUG_FANTASY_UPCOMING=1`. `SIMCTL_CHILD_` was used for per-launch environment forwarding; no global fixture setting or user login was installed.
- Interactions used native CUA against the window titled **Joe-TV Team QA**, with Up/Down/Left/Right, Return, and Escape. Screenshots were inspected after actions; the macOS accessibility tree exposed the Simulator shell, not app content, so this is visual interaction evidence rather than accessibility-tree assertions or VoiceOver coverage. Screenshots remain in the QA task transcript, not committed image artifacts.
- Earlier separated actions sometimes crossed the player's auto-hide timer; Back-layer verification was repeated with consecutive input/screenshot steps. Only the controlled sequences below are counted as layer checks.
- **Cleanup observed:** terminated `com.jrcoak.joetv`, shut down the explicit QA UDID, then `simctl list devices available` showed **Shutdown**. The existing user's tvOS 17.5 device `E98B3E2D-BEA0-439C-BEF2-247A76F11019` remained **Booted**; all other existing device states matched discovery. QA device and its fixture-only app data remain for later assigned reuse; no device was erased or deleted. No authenticated provider stream was opened. Fantasy artwork can load public logos, so this UI run is not described as entirely network-free.

| Area | This run | Next acceptance check / dependency |
| --- | --- | --- |
| Navigation and guide | **PASS for sampled fixture paths:** focus on Live TV retained Home until Select; selected Live TV entered guide. Down through Live Desk/ESPN updated header, then Select opened ESPN. Unavailable EPG did not block navigation. | Full channel categories, filters, saved selection, populated EPG, and asynchronous focus changes need richer fixtures. |
| Quick Switch identity | **PASS:** focus moved WCVB → NHPBS while Live Desk stayed active. Selecting WCVB changed active title; rail then included Live Desk and omitted WCVB. No duplicate in the visible sample. | Repeat with four recents, sports feed options, expired targets, and failed fresh resolution; policy count limit already passed smoke. |
| Player Back layers | **PASS for sampled rail path:** Quick Switch → controls with Pause focused → hidden chrome → guide, staying inside app. **CONCERN:** guide-origin focus landed on Home nav (QA-2). | App/Playback reproduce and restore original row; physical remote remains pending. |
| Fantasy scorebug/drawer | **PASS:** selected NFL RedZone fixture, opened scorebug/drawer, viewed Matchup lineups and selected League to see five pairings, closed drawer back to scorebug. **FAIL for keyboard Back at focused scorebug:** controls remained (QA-1). | Fix/retest every controls focus target; verify overlay translucency over actual video and continuing playback. |
| Fantasy no-live state | **PASS for fixture display:** Live 0; RedZone/NFL Network still present; four upcoming NFL games shown without invented NFL scores. Ordinary Sports Upcoming showed two today/tomorrow events, distinct from Fantasy's extended schedule. | Clock-boundary, real refresh and missing-opponent states still pending. |
| Sports empty/recovery | **PASS:** selecting Live showed “Nothing is live right now”; selecting Upcoming restored event cards. | Loading, malformed/stale/error states, retries, multi-select persistence, and full baseball feed selector pending. |
| Captions | **SOURCE ONLY** flag `JOE_TV_DEBUG_CAPTIONS_URL`; no supplied captioned asset used. Empty-player fixture had no captions control (QA-4). | Controlled clear HLS with multiple tracks plus no-caption media; select/off, track labels, focus return, then protected-media captions on device. |
| Live-edge/seek/Play-Pause | **POLICY ONLY:** bounded seek calculations passed. Empty-player UI cannot establish transport or audio behavior. | Clear DVR and nonseekable live media, then hardware; verify join-live, seek bounds, and remote Play/Pause. Measure live lag rather than reuse historical ~4-second claim. |
| Switch failure/cleanup | **SOURCE ONLY:** previous-session rollback, timeout, cancellation inspected. | Inject delayed/failing preparation and rapid superseding switches; inspect active player count and retry. Requires QI-1 or assigned equivalent. |
| Login/persistence/service failures | **PENDING:** no credentials supplied, sign-in, session-expiry, or real API checks performed. | Isolated fixtures for restore/migration/cache failure; separately authorized live integration session if needed. |
| Accessibility/readability/performance | **PARTIAL visual only:** focus outlines, layout and text inspected at scaled 1080p simulator view. | VoiceOver, Reduce Motion, TV-distance contrast/readability, 4K, scrolling/memory, launch/navigation timing on named hardware remain pending. Design owns final visual review. |
| FairPlay/device/release | **PENDING:** parser configuration only; no device, signing, TestFlight, real media, or license validation. | Joe + Playback on signed Apple TV: one authorized stream at a time across domestic/international/ESPN+/NHPBS, preparation/failure/renewal/interruption, stop/cleanup; physical Siri Remote taps/holds/Back. Record installed version/build. |
| Integrated M0 | **PENDING PM assignment:** this report covers baseline only. | At exact assembled commit verify roster/ownership, report conflicts, ranked proposals, unchanged app scope, and honest evidence matrix. Rebuild if integration changes relevant source/configuration. |

No unresolved item above has been converted into a claimed pass. The documentation-only report can be integrated; device/release acceptance and proposed implementation remain explicitly separate.

## 7. M0-INTEGRATED / R1-VERIFY — independent assembled-document review

**Reviewed commit:** `28e3406c7aa67787537faa53d17bbbfb0b01b8da` on PM's `codex/joe-tv-team`. **Governing revision:** TEAM-3 accepted for this review, September 16, 2026 EDT / September 17 UTC. **Outcome: ACCEPT for documentation-only M0/R1; no blocking documentation fixes identified.** This accepts the assessment/research package, not product implementation, performance, backend security, or release readiness.

Review ran from the existing clean QA branch/worktree at `cd9fc8411fd9e08a197adb4766939b2dd00ce3bb`, reading the immutable PM commit through Git. No checkout/rebase of shared work and no PM-worktree edits occurred. Only this addendum is changed. Earlier sections retain their TEAM-1/build-6 provenance.

| Independent check | Result and evidence boundary |
| --- | --- |
| Scope and source equivalence | **PASS.** Git tree IDs for `SeasonsTV`, `Tests`, `Joe-TV.xcodeproj`, and `Config` are identical between reviewed SHA and release `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`. Release versus app baseline changes only the two build-number settings from 6 to 7. Assembled changes outside release are documentation and `scripts/team-check.sh`; that wrapper is byte-identical to the one tested at bootstrap `314968d`. No new build or simulator run was justified or performed. |
| Six roles and report provenance | **PASS.** Design, App, Playback, Services, SecOps, and QA are present with distinct task IDs/branches/worktrees and owned report paths. Each integrated assessment blob equals its cited final source report: `49b8912`, `e85a7b1`, `c54738d`, `a6dcdac`, `013b886`, `cd9fc84`, respectively. Cited earlier report and research commits also resolve; inspected report commits change only their assigned paths. Both research reports explicitly acknowledge TEAM-3. This verifies committed provenance, not a fresh live-task census. |
| Governance and deferred scope | **PASS.** Read assembled `AGENTS.md`, spec, roster, operating model, decisions, M0/R1 assignments and standup protocol/template/checkpoint. PM model discretion and recorded R1 overrides are explicit. Standups use a bounded fresh read-only internal coordinator, preserve specialists' contexts, leave decisions/runtime ownership with PM, and create neither a recurring schedule nor a separate user-owned standup task. The recorded standup labels its earlier snapshot rather than claiming current live status. No coordinator was spawned for this review. |
| Synthesis and recommendations | **PASS.** Summary/roadmap/evaluation method preserve UI/navigation/performance priority, rank five packages, and defer sidebar, favorite-team Home and feature expansion. Recommendations map to report findings, owners, dependencies and smallest validations. Cache and lifecycle findings remain source-based conditional risks; backend/publisher absence is unknown, not evidence of safety or a confirmed production failure. |
| Counts and benefits | **PASS.** Repeated scorebug Escape behavior remains distinct from one guide-return observation. Two-to-one Select/activation comparisons are scoped source-derived proposals, not full journey counts. No measured responsiveness, first-frame, memory or competitor usability benchmark is asserted. Ten distinct official source URLs occur in each research report, twenty across their disjoint source sets; this is a citation inventory, not twenty hands-on validations. |
| Links | **PASS.** Checked Markdown relative file targets across 26 reviewed/shared/report/reference documents: 32 relative targets, none missing at the reviewed SHA. Research reference-style citations have no undefined labels. This is a file-target check, not a guarantee of every external URL's availability or every heading anchor. |
| Evidence labeling | **PASS.** Summary keeps smoke/build at bootstrap `314968d`, build 6, and calls the PM build-7 reconciliation a source change only. Hardware/media/backend/performance gaps remain explicit. Source-only specialist statements that runtime QA is pending retain their original historical boundary; the synthesis supplies the newer QA observations. |

Official-page spot checks were deliberately limited to three recommendation anchors, read directly during this review:

- [Netflix TV redesign](https://www.netflix.com/tudum/articles/netflix-new-tv-layout) supports top-positioned shortcuts and browsing metadata, with a staged TV-device rollout. It does not establish tested Apple TV parity or a latency benefit.
- [Google's TV controls guidance](https://support.google.com/youtubetv/answer/7452153?hl=en) supports recently watched programs below the player. The interaction wording is TV-generic; the Apple TV installation section does not make every remote shortcut Apple TV-specific.
- [Fubo in-progress recordings](https://support.fubo.tv/hc/en-us/articles/8361914566029-How-can-I-watch-an-in-progress-Cloud-DVR-recording) explicitly describes Apple TV's return-to-live action after pausing/rewinding an in-progress recording. The roadmap correctly adapts the state/action rather than proposing a recording service.

The Design report labels Disney/Plex indexed-only retrieval and its Disney locale caveat; roadmap also labels some Hulu material as indexed-only. These limitations remain intact. Other sources, exact update dates and installed competitor versions were not independently revalidated here; recheck affected platform evidence when a sprint is selected. No competitor login, subscription, app test or exhaustive repeat research was performed.

**Nonblocking precision notes for later document/feature work:** `docs/research/live-tv-patterns.md` recommendation 4 proposes adding a Last Stream cue, but `SeasonsTV/Views/PlayerScreen.swift:89`, `remoteControlHint`, already includes “Hold Select · Last Stream” when applicable. Treat this as evaluating/improving the existing cue, not filling a wholly absent capability. README still says “Featured-plus-four” prefetch, while `AppModel.sportsDetailPrefetchLimit` is 12, as Services already records. Neither discrepancy changes the first-sprint recommendation or constitutes new implementation scope.

PM may close the explicitly expected “pending final QA” labels after integrating this handoff; those checkpoint labels are not a review failure. Remaining product evidence is unchanged: physical Siri Remote/FairPlay/protected captions, real-media recovery/cleanup/live-edge, backend authorization/publisher provenance, login/persistence, performance, full accessibility and couch/4K validation. No simulator/device/runtime or production operation occurred in this review. The handoff identifies the Git-verified addendum commit separately from the reviewed PM SHA.
