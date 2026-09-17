# M0-PLAYBACK assessment

## 1. Assignment and evidence boundary

- Assignment: **M0-PLAYBACK**, spec **TEAM-1**.
- Playback task: `01a0ad34-ab28-7012-94c5-ed6e82ea8f8e`; PM: `01a0ad24-56de-73e1-b5de-5a0fdc8c49ff`, host `local`.
- Worktree: `/Users/joecoakley/.codex/worktrees/52e6/SeasonsTV`.
- Branch: `codex/joe-tv-playback`.
- Assessed HEAD / team-bootstrap commit: `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`.
- App baseline: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`. A source-path Git comparison confirmed no changes between these two commits in `SeasonsTV/`, `Tests/`, or `Joe-TV.xcodeproj/`.
- Setup: managed worktree was clean and detached at `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`; the requested branch did not exist. Created it at the specified bootstrap commit. No edits to the original checkout or release-owned build number.
- Only deliverable: this report. Its commit is identified in the completion handoff.

Read all required shared instructions and the M0 assignment. Inspected `SeasonsTV/Views/PlayerScreen.swift`, playback types/policies in `SeasonsTV/Models/Models.swift`, playback orchestration in `SeasonsTV/App/AppModel.swift`, `SeasonsTV/Playback/FairPlayResourceLoader.swift`, relevant resolution/DRM functions in `SeasonsTV/Networking/{SeasonsClient,HTMLCatalogParser,PBSLiveClient}.swift`, presentation/preview paths in `SeasonsTV/Views/{RootView,JoeTVExperience}.swift`, `SeasonsTV/App/JoeTVApp.swift`, relevant `Tests/ParserSmoke.swift` cases, and `scripts/team-check.sh`. Compared playback claims in `README.md`, `JOE-TV-DESIGN-IMPLEMENTATION.md`, and `docs/TECHNICAL_HANDOFF.md` with source.

**Evidence terminology:** “Observed” below means inspected source/control flow, not observed device behavior. “Inferred” identifies an unexecuted consequence or timing risk. “Historical” means a prior report, not fresh verification. No provider requests, streams, builds, smoke execution, simulator/device operations, private configuration inspection, or external research were performed.

## 2. Existing strengths and lifecycle worth preserving

| Stage | Observed implementation and exact source |
| --- | --- |
| Resolve a selection | `AppModel.playMediaItem` / `playLiveChannel` (`SeasonsTV/App/AppModel.swift:1048`, `:1078`) resolve before installation. `makePlaybackSession(for:option:)` (`:1185`) supports direct HLS, runtime request resolution, and DRM pages. Live/upcoming sports request live-edge entry. `makePreviewSession` (`:1604`) handles Seasons4U, Very Local, and PBS separately. |
| Prepare the player | `PlaybackSession` (`SeasonsTV/Models/Models.swift:1194`) owns AVPlayer, item-status observation, subtitle discovery, and a 20-second **item-preparation** timeout. DRM construction retains its loader and assigns a serial delegate queue (`:1237`). This timeout starts after service resolution, so it is not an end-to-end start budget. |
| Present | `RootView.body` (`SeasonsTV/Views/RootView.swift:23`) overlays `PlayerScreen` in a ZStack. Full-screen video uses custom `PlayerSurface` / `PlayerSurfaceView` (`SeasonsTV/Views/PlayerScreen.swift:1634`), backed by AVPlayerLayer. Appearance and session changes call `play()` (`:171`, `:181`). Preserve this intentional custom experience. |
| Switch and recover | `AppModel.switchPlayback` (`SeasonsTV/App/AppModel.swift:1102`) guards concurrent switch selection and resolves a stable target. `installPlaybackSession` (`:1220`) pauses and retains the previous session, installs the candidate, and changes history/active identity only when it reports ready. Preparation failure restores the previous session/presentation and a readable switch message. Transition UUID and session-identity guards protect the installed callbacks. |
| Recent/favorite identity | `PlaybackTarget` and `PlaybackHistoryPolicy` (`SeasonsTV/Models/Models.swift:923`, `:966`) keep source IDs and option IDs rather than resolved media URLs; cap recents at four; deduplicate favorites and exclude the active target. `AppModel.quickSwitchEntries` / `lastPlaybackTarget` (`SeasonsTV/App/AppModel.swift:400`, `:410`) filter unavailable entries. Cards tune only in Button actions (`SeasonsTV/Views/PlayerScreen.swift:651`). |
| Live and seeking | `PlaybackSession.positionAtLiveEdgeIfNeeded` / `seek(by:)` (`SeasonsTV/Models/Models.swift:1302`, `:1421`) join via a positive-infinity seek and clamp subsequent skips to available bounds; finite duration is a fallback only for non-live playback. Live items set `automaticallyPreservesTimeOffsetFromLive`. `MediaItem.sportsPlaybackAvailable` (`:254`) retains the 15-minute coverage rule. |
| Captions | `refreshSubtitleOptions`, `installSubtitleOptions`, and `selectSubtitle` (`SeasonsTV/Models/Models.swift:1313`, `:1350`, `:1336`) asynchronously load legible tracks, label accessibility captions, read current selection, and select supported options. The custom dialog and accessible control exist (`SeasonsTV/Views/PlayerScreen.swift:238`, `:532`). |
| Remote and exit | `PlayerChromeLayer` and `handleBack` (`SeasonsTV/Views/PlayerScreen.swift:5`, `:896`) encode rail → controls → video → browse. Back has a 0.45-second debounce, delayed dismissal, and 0.75-second browse suppression (`PlayerScreen.swift:29`, `:911`; `AppModel.swift:1726`). Down normally opens Quick Switch, Up opens controls; blind surfing is optional and defaults off (`PlayerScreen.swift:714`, `:805`; `AppModel.swift:206`). |
| Cleanup | `dismissPlayback` (`SeasonsTV/App/AppModel.swift:1734`) invalidates installed transition callbacks, clears preparation handlers, pauses playback, and drops the session. `PlayerSurface.dismantleUIView` detaches its player (`SeasonsTV/Views/PlayerScreen.swift:1649`); view disappearance cancels chrome/message tasks (`:177`); `PlaybackSession.deinit` cancels timeout/subtitle tasks (`SeasonsTV/Models/Models.swift:1466`). Status observation is retained by the session rather than an untracked global observer. |

The full-width Fantasy video, compact scorebug, and two-tab translucent drawer are implemented in `PlayerScreen.swift:101`, `:309`, and `:1141`. They do not require a second player and should remain intact.

## 3. Findings

### PB-01 — Resolution can outlive dismissal (recommended first reliability experiment)

**Observed:** `AppModel.switchPlayback` awaits `makePlaybackSession` then unconditionally installs it (`SeasonsTV/App/AppModel.swift:1110–1111`). Its transition UUID is created inside installation (`:1225`), after that await. Dismissal/sign-out changes the UUID (`:1735`, `:1661`) but does not cancel or invalidate the outstanding resolver. Quick Switch launches an unstructured Task (`SeasonsTV/Views/PlayerScreen.swift:653`); disappearance cancels only chrome/message tasks. Initial play paths (`AppModel.swift:1060`, `:1088`) have the same post-await installation shape.

**Inferred impact:** start switching, back out before resolution returns, then receive the late result: the source permits a new session to reopen playback. Overlapping selection/dismissal/sign-out could similarly allow stale results to win. Existing callback guards protect preparation after installation, not the earlier resolution phase.

**Confidence/status:** high confidence in the missing guard; conditional runtime outcome, not reproduced. **Dependency:** Playback plus PM-assigned `AppModel` symbols; Services cancellation contract; App navigation; QA deterministic delayed resolver. Acceptance should include late success **and** late error after cancellation, with no new player, stale alert, or history change.

### PB-02 — Ready status ends rollback before playback health is established

**Observed:** `PlaybackSession.handlePlayerStatus` marks ready, cancels the timeout, invokes the ready handler, and clears both preparation handlers on `.readyToPlay` (`SeasonsTV/Models/Models.swift:1274–1289`). Live positioning issues a seek without awaiting completion (`:1302`). No player time-control/waiting-state, media-progress, or stall observer was found in the inspected playback paths. A later item failure gets the failure overlay but no longer has the previous-session rollback handler. `failureView` offers Return to Browse (`SeasonsTV/Views/PlayerScreen.swift:680`).

**Inferred impact:** “switch completed” currently means item ready, not confirmed first frame, advancing time, or audible playback. A candidate that becomes ready and then stalls can lose the early rollback opportunity. An indefinite stall that leaves item status ready has no dedicated waiting/recovery UI in this code. This does not prove streams presently stall.

**Related observed state gap:** Play/Pause uses view-local `isPaused` (`PlayerScreen.swift:70`, `:702`), while scene inactivity pauses through `JoeTVApp.swift:13` / `AppModel.pausePlayback` (`AppModel.swift:1722`). Those external pauses do not update that Boolean. Rollback always calls `previousSession.player.play()` (`AppModel.swift:1268`), including when the previous stream had been paused. **Inferred:** stale labels/first Play-Pause behavior after inactivity, or undesired resume after a failed switch.

**Confidence/status:** high for control flow, medium for user-visible timing; source only. **Dependency:** Playback owns transport state and cleanup; App owns scene coordination. Define intended pause/resume behavior before changing it. A small health-state adapter and deterministic ready-then-stall/fail fixture are preferable to replacing the player.

### PB-03 — Caption availability and Off do not always match the control surface

**Observed:** the Captions button exists only when `subtitleOptions` is nonempty (`SeasonsTV/Views/PlayerScreen.swift:532`). The dialog contains a no-captions state (`:243`), but normal entry is unavailable when discovery returns no tracks or fails. The only discovery triggers are item readiness and pressing that existing button. The dialog always offers Off when tracks exist (`:247`); `PlaybackSession.selectSubtitle(nil)` changes selection only if `group.allowsEmptySelection` (`SeasonsTV/Models/Models.swift:1344`). Discovery errors clear options; there is no exposed distinction between loading, unsupported, and failed (`:1313–1333`).

**Impact/inference:** viewers receive no explanation for an absent captions control. For a group requiring a selection, Off is visible but can do nothing. No explicit audio-track selection (`.audible`) or saved caption-language intent was found; language identifiers and track indexes are session-local, so persisting these IDs would be inappropriate. System defaults may still influence selection; this was not tested.

**Confidence/status:** high source confidence; media/device behavior pending. **Dependency:** Playback, Design for accessible states, QA clear-media fixtures. This directly supports TEAM-1's understandable unavailable state, without claiming audio selection is already a requirement.

### PB-04 — Live indication describes the source, not distance from live

**Observed:** the LIVE badge reads the immutable `session.isLivePlayback` flag (`SeasonsTV/Views/PlayerScreen.swift:351–356`). `PlaybackSession.seek(by:)` allows DVR rewind when seekable ranges exist (`SeasonsTV/Models/Models.swift:1421`). There is no distance-from-edge state or explicit Go Live action. Live hints omit seeking even though the handler supports it (`PlayerScreen.swift:89`, `:830`). Initial live-edge seeking sets its one-shot flag before confirming success (`Models.swift:1302`).

**Impact/inference:** a viewer paused or rewound behind a game still sees LIVE and has no direct action to rejoin the edge. A late-populating seekable window needs validation; source alone does not establish whether the initial seek succeeds or what the actual latency is.

**Confidence/status:** high for display/control gap; live-entry success unverified. **Dependency:** Playback/Design and a bounded local DVR fixture. The historical “about four seconds behind live” in `docs/product-context.md` is neither a measured result here nor an acceptance budget.

### PB-05 — Back protections exist, but some focused routes bypass them

**Observed:** standard controls and rail cards call `handleBack`, while the parent `handlePlayerBack` requires hidden chrome and player focus (`SeasonsTV/Views/PlayerScreen.swift:926`). The focusable Fantasy scorebug under controls has no local exit handler (`:328–342`). The failure button also has none (`:693`), while errors request focus for that action (`:196`). The drawer calls its close closure directly (`:1186`), outside `acquireBack`; captions rely on native confirmation-dialog dismissal.

**Inferred impact:** Back while the Fantasy scorebug or failure action is focused may not unwind through the intended handler; rapid drawer/caption Back dispatch could differ from normal controls. These are specific pending focus/event tests, not a claim that tvOS propagation is broken. Returning to the originating browse focus also needs App/QA evidence because RootView keeps browsing underneath the player.

**Confidence/status:** medium; source routing gap, simulator/physical remote pending. **Dependency:** Playback owns handlers; App owns originating context; QA tests each focused state, single and repeated presses. Preserve the existing anti-fallthrough protection until hardware evidence supports changes.

### PB-06 — Preview and full-screen lifetime are coordinated locally, not centrally

**Observed:** the guide starts a muted preview after 1.1 seconds (`SeasonsTV/Views/JoeTVExperience.swift:535`), cancels and checks its task around resolution, and stops previews before its explicit Watch actions (`:375`, `:388`). This is good cancellation precedent. Preview ownership is view-local; `AppModel.pausePlayback` addresses only the full-screen session, and the guide has no inspected scene-inactivity or global-playback guard. `.playing` is set immediately after `player.play()` (`:553–555`); `JoeTVProgramPreview` does not observe `PlaybackSession.isReady`/`playbackError` (`:2385`, `:2410`).

**Inferred impact:** preview can label itself live before readiness and may not represent later failure. Cross-entry or background transitions merit a one-player audit. Normal guide selection explicitly stops preview, so this is **not evidence of confirmed concurrent streams**. Pausing a retained session also does not demonstrate that provider requests have ceased.

**Confidence/status:** high source confidence, medium lifecycle risk; no stream or resource counts measured. **Dependency:** App owns the guide, Playback defines ownership/stop hooks, Services and QA help distinguish player activity from outstanding network work. Validate with local media and counters before any serialized provider session.

### PB-07 — Preserve the specific FairPlay contracts; cancellation remains unverified

**Observed contracts:** `HTMLCatalogParser.parseDRMConfiguration` (`SeasonsTV/Networking/HTMLCatalogParser.swift:466`) scopes certificate/header lookup to text beginning at `fairplay`, recognizes domestic as well as international proxy prefixes, accepts active explicit license lines, and ignores the known commented-out content-ID transformation. `DRMContentIdentifierStrategy` (`SeasonsTV/Models/Models.swift:1146`) supports full SKD and scheme-stripped identifiers with an optional prefix drop. `PBSLiveClient.drmConfiguration` (`SeasonsTV/Networking/PBSLiveClient.swift:42`) supplies a fixed explicit license route and no provider headers. `AppModel.makeDRMPlaybackSession` and PBS construction reject simulator DRM before playback (`AppModel.swift:1640`, `:1624`).

`FairPlayResourceLoader.fulfill` (`SeasonsTV/Playback/FairPlayResourceLoader.swift:47`) obtains the certificate through `SeasonsClient.authenticatedData`, makes SPC from the configured identifier, chooses explicit license URL or proxy + transformed SKD route, POSTs raw SPC, and returns raw CKC. It tracks tasks per loading request and cancels them on `didCancel` (`:39`). Debug logging emits domain/code only (`:27`); player errors follow the same redaction pattern (`Models.swift:1292`). Keep URLs, headers, cookies, SPC/CKC, and tokens out of diagnostics.

**Inferred risks:** there are no explicit cancellation checks between certificate load, SPC creation, license load, and response completion, or a loader-wide shutdown method. A task promotes the weak loader to a strong reference for the exchange. Cancellation may propagate through URLSession, but suppression of late completion and bounded teardown are unverified. The parser uses an 8,000-character suffix, not a balanced FairPlay object; future provider layout/comments can still change which fields are selected. These are maintenance/test seams, not a demonstrated license failure or credential exposure.

**Confidence/status:** high for current contract and code gaps; medium for consequences. **Dependencies:** Services owns transport/parser changes; Playback owns key lifecycle; SecOps reviews destination/header trust and redaction. Smallest checks are sanitized parser variants and a stubbed certificate/license cancellation sequence. Actual license interoperability remains physical-device work; no wholesale DRM API migration is proposed without evidence and scope.

### PB-08 — Recent selection can fall back to a different feed; pregame recall is filtered

**Observed:** `AppModel.playbackOption(withID:in:)` falls back to the first playable option when the saved option is missing (`SeasonsTV/App/AppModel.swift:1553`). Installation still uses the incoming target/detail, so a fallback feed need not update its label. `PlaybackTarget.id` intentionally deduplicates the event independently of feed (`SeasonsTV/Models/Models.swift:937`). Quick Switch resolution/availability require `.live` (`AppModel.swift:1161`, `:1578`), even though `.upcoming` can be playable within the accepted coverage window (`Models.swift:254`).

**Inferred impact:** a disappearing Home/Away/National option can silently return a different feed with stale detail text. A viewer who leaves playable pregame coverage may not see it in recent recall until its phase becomes live. Confirm product intent before widening eligibility; completed/replay filtering must remain intact.

**Confidence/status:** high source confidence, provider catalog transitions unverified. **Dependency:** Services owns stable option identity, Playback selection behavior, Design fallback wording; PM assigns shared symbols. Use a changed-options fixture and a fixed-clock pregame fixture before implementation.

## 4. Three bounded improvement proposals

### P1 — Make switching cancelable and preserve the viewer's prior state

- **Viewer situation:** a channel takes time to resolve, the viewer presses Back, or the replacement fails while the prior stream was paused.
- **Proposed behavior:** one generation owns resolution through preparation; dismissal invalidates it immediately; late results cannot reopen playback. Retain previous target and pause intent until a defined successful handoff. Keep recovery in the player and use fresh resolution for an explicit retry. Derive control state from session transport rather than a separate view toggle.
- **Already present:** stable targets, one-at-a-time switch guard, preparation timeout, previous-session retention, rollback, and sanitized errors. Build on these mechanisms; avoid an architecture rewrite.
- **Expected benefit:** fewer unwanted reopen/resume actions and a clearer recovery path. No unmeasured startup-speed claim.
- **Effort/confidence:** medium, spanning model orchestration and player state; high confidence in the cancellation value, medium in the right readiness threshold until measured.
- **Dependencies/risks:** PM grants `AppModel` playback symbols and `Models.swift` session edits; Services defines cancellation; App handles scene/dismissal; QA owns delayed/failing fixtures; SecOps reviews any new diagnostics. Do not add automatic provider retry bursts. A stricter readiness condition must not unnecessarily delay good switches.
- **Smallest experiment:** an injected local resolver/session adapter with delayed success, delayed error, ready-then-fail, and paused prior-session scenarios. This can establish the race independently of a provider. Include preview/full-screen active-player counters in the later integration check.
- **Acceptance:** after Back/dismiss/sign-out, completing any older operation creates no session and publishes no stale error/history update; the latest valid selection alone wins; failed preparation restores the correct target and prior pause intent; no two players are instructed to play concurrently; repeated local switches/dismissals leave no growing set of observers/tasks. Record resolve, ready, and first-progress timestamps separately without URLs. Hardware still validates actual stream teardown and FairPlay.

### P2 — Add truthful live position and one-action Go Live

- **Viewer situation:** a viewer pauses or rewinds sports, then wants to catch up without repeated ten-second skips.
- **Proposed behavior:** distinguish live-source content from being at its edge. When measurable and behind the current seekable end, show a concise Behind Live state and a focused Go Live action. Show no invented delay when the window is unknown. Keep automatic live entry and existing ten-second seeking.
- **Already present:** live classification, positive-infinity seek, and bounded seek policy. Missing pieces are observed position/window state, an action, and feedback on completion.
- **Expected benefit:** makes DVR behavior understandable and return-to-live direct.
- **Effort/confidence:** small-to-medium; high confidence in viewer value, medium in stream-specific window behavior.
- **Dependencies/risks:** Playback adds bounded observers and deterministic cleanup; Design chooses wording/focus placement; QA covers DVR, nonseekable live, and finite media. Agree an edge tolerance from named local/device conditions; do not reuse the historical four-second anecdote as a budget. Moving/discontinuous ranges must not cause invalid seeks or oscillating labels.
- **Smallest experiment:** one local clear HLS DVR fixture with a moving window plus controlled time/window inputs; expose only live/behind/unknown and Go Live before designing a timeline.
- **Acceptance:** rewind/pause moves to the appropriate state; Go Live seeks to the currently available edge and confirms completion; label does not remain At Live after a substantial rewind; absent/invalid ranges produce neither fabricated latency nor unsafe seeks; Back/focus remains predictable; finite media never receives a Go Live action. Observe protected-media behavior later on hardware.

### P3 — Make captions dependable across streams, then assess audio choice

- **Viewer situation:** a viewer needs captions but cannot tell whether a stream lacks them, discovery is loading, or their preferred language was lost when switching.
- **Proposed behavior:** keep a reachable captions entry with loading, available, unavailable, and retryable discovery states. Offer Off only when supported. If Joe selects persistence, remember semantic intent (system/default, off, preferred language/accessibility), not a session track index; fall back visibly when unavailable. Treat alternate audio as an optional follow-on after proving actual audible options in a fixture.
- **Already present:** asynchronous legible-group loading, language/CC labels, native dialog, accessible control label/value, and `JOE_TV_DEBUG_CAPTIONS_URL` fixture entry (`SeasonsTV/App/AppModel.swift:215`, `:1274`).
- **Expected benefit:** caption users understand capability and need fewer repeated adjustments.
- **Effort/confidence:** small for truthful availability/Off; medium for saved preference semantics and audio. High confidence in the current availability gap; audio demand/capability needs validation.
- **Dependencies/risks:** Playback owns discovery/state; Design defines unavailable/loading behavior; PM allocates shared model/preference symbols; App preserves existing preference namespaces and system choices; QA supplies licensed/local clear media with known tracks. Do not silently override system accessibility preferences or persist media URLs.
- **Smallest experiment:** use the existing caption fixture hook with known CC/language tracks, no tracks, delayed discovery, and a required-selection group; prototype an always-reachable entry first. No new provider integration.
- **Acceptance:** each availability state is understandable and reachable; selecting a real track changes the checked selection and rendered captions; Off appears only when actionable; switch/failure/return restores valid focus; any saved intent survives reordered track lists and has a defined fallback. Simulator clear-media checks do not substitute for protected captions and Siri Remote checks on Apple TV.

## 5. Ownership, documentation discrepancies, and decisions needed

Playback's default code ownership remains `PlayerScreen.swift` and `FairPlayResourceLoader.swift`; this assignment changes neither. Future work needs explicit PM allocation of `AppModel` orchestration, `PlaybackSession`/DRM models, preferences, and any shared smoke-test additions. App owns RootView, guide previews, and browse-focus restoration. Services owns stream resolution, provider parser contracts, and available-feed identity. Design owns player wording/focus intent. QA independently verifies; SecOps reviews network/DRM/diagnostic changes. No project, bundle, signing, release, infrastructure, or publisher change is needed for the proposed local experiments.

Documentation corrections should be assigned separately:

| Existing claim | Baseline source disagreement |
| --- | --- |
| `docs/TECHNICAL_HANDOFF.md:201`: player uses `fullScreenCover(item:)`. | `RootView.swift:23` uses a ZStack overlay. Back/focus evaluation must use this lifetime. |
| `JOE-TV-DESIGN-IMPLEMENTATION.md:30–31`: guide moving preview and custom captions remain deferred/native-owned. | `JoeTVGuideView.schedulePreview` is implemented; full-screen custom captions are in `PlayerSessionView.playerControls` and `PlaybackSession`. Native AVPlayerViewController remains in the muted preview only (`JoeTVExperience.swift:2475`). |
| `docs/TECHNICAL_HANDOFF.md:446`: long Select opens the rail and hidden Up/Down always surf. | `PlayerScreen.swift:287` long Select recalls the previous stream; hidden Down opens the rail by default, with optional surfing. Even the earlier summary at handoff line 32 differs from current Down behavior. |
| `docs/TECHNICAL_HANDOFF.md:423`: Fantasy uses a persistent left rail. | Current full-width video, upper-right scorebug, and Matchup/League drawer replace that layout. |
| `docs/TECHNICAL_HANDOFF.md:472`: user-facing playback failure contains AVFoundation domain/code. | `Models.swift:1291` publishes a generic recovery message; domain/code prints only in Debug. Preserve redaction. |

Historical device FairPlay success in `docs/TECHNICAL_HANDOFF.md:34`, later FairPlay regressions/fixes in `docs/product-context.md`, and previously reported live-edge timing remain historical evidence. This report neither revalidates nor contradicts those runtime observations.

PM decisions for a next assignment: select P1/P2/P3; define pause intent on failed switches/background return; decide whether ready status or confirmed media progress completes the handoff; confirm pregame recall and missing-feed fallback behavior; choose system-default versus explicit remembered caption intent. These questions do not block this source assessment.

## 6. Checks and remaining verification

**Actually performed:** clean-status and branch-existence inspection before setup; requested branch creation; exact HEAD/branch verification; source comparison against the app baseline; line-numbered source reads and targeted symbol searches; required-document review; smoke/fixture **source** coverage review. `Tests/ParserSmoke.swift:53–123` has history/surf/seek-policy assertions; `:140–167` covers PBS configuration; `:1478–1574` covers international/domestic/ESPN FairPlay parsing, including the commented content-ID regression. No inspected test exercises asynchronous session switching, stalls, transport intent, caption rendering, or native Back propagation. Debug Quick Switch sessions report ready without media (`Models.swift:1226`), so they cannot establish playback success.

Pre-commit report validation: `git diff --check` and `git diff --cached --check` passed; explicit-path staged review confirmed only `docs/assessments/playback.md`. Completion handoff records the final repeat check and report commit.

| Check | Status / next owner |
| --- | --- |
| Fresh smoke suite and unsigned build | **Not run here**, as required by source-only assignment; QA owns fresh baseline/integrated evidence. Existing assertions are coverage observations, not passes. |
| Late resolution after dismissal, timeout, ready-then-stall, pause-preserving rollback | **Pending** deterministic local harness under a selected follow-up; Playback implementation and independent QA. |
| Back from controls, rail, caption dialog, Fantasy scorebug/drawer, preparing/error views; originating focus | **Pending** QA's assigned simulator session; then physical Siri Remote, including rapid presses. |
| Caption selection, absent tracks, required-selection Off, preferred-language fallback | **Pending** known clear-media fixture; physical protected-stream check separately. |
| Live entry, pause/DVR window, Go Live prototype, switching latency, player/task lifetime | **Pending** named local fixture/device measurements. No performance or memory result asserted. |
| Domestic/international Seasons4U, ESPN FairPlay, PBS FairPlay and renewal/cancellation | **Pending** signed physical Apple TV and a PM-assigned serialized session. Parser tests/mocks cannot prove keys or playback. |
| Provider request termination / one real stream | **Pending** coordinated account/device/browser ownership. No live session was requested or opened in M0-PLAYBACK. |

No app code, other documentation, SHELF content, private settings, or release artifacts were changed. Proposed experiments remain unimplemented pending a bounded PM assignment.
