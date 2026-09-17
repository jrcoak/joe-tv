# M0-APP — tvOS application assessment

## 1. Assignment and inspected baseline

- Assignment: M0-APP; accepted specification: **TEAM-1**.
- App baseline: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`.
- Assessed HEAD / team bootstrap: `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`.
- Specialist task: `01a0ad34-a194-7232-bde5-886ee0c7fb35`, host `local`.
- Worktree: `/Users/joecoakley/.codex/worktrees/0b9c/SeasonsTV`.
- Branch: `codex/joe-tv-app`, created from the assigned bootstrap after confirming a clean worktree and that the branch did not exist.
- Deliverable: this report only. No app, project, shared-document, provider, or release changes.

Read the eight assigned instruction/context files. Inspected `SeasonsTV/Views/RootView.swift`, `SeasonsTV/Views/JoeTVExperience.swift`, `SeasonsTV/Views/DesignSystem.swift`, relevant navigation/state/persistence orchestration in `SeasonsTV/App/AppModel.swift`, `SportsEventGuidePolicy` in `SeasonsTV/Models/Models.swift`, and the entry/exit/controls boundary in `SeasonsTV/Views/PlayerScreen.swift`. Compared current routing with `README.md`, `JOE-TV-DESIGN-IMPLEMENTATION.md`, and `docs/TECHNICAL_HANDOFF.md`.

**Evidence terminology:** “Observed” below means observed in source at the assessed HEAD, not exercised behavior. A predicted viewer effect is an inference. Historical reports are explicitly identified. There is no fresh build, simulator, hardware, live-service, VoiceOver, or performance evidence in this assessment.

### Navigation and state map

| Boundary | Active source and state | Implication |
| --- | --- | --- |
| Launch / authentication | `RootView.body` switches `AppModel.Screen` between checking, signed out, and catalog; `LoginView` submits credentials | One app-level working overlay and error alert surround these screens. |
| Main destinations | `RootView.swift` → `CatalogView.body` routes `.home`, `.liveTV`, `.sports` to `JoeTVHomeView`, `JoeTVGuideView`, `JoeTVSportsView` | These are the screens to assess and implement. `LiveTVBrowseView`, `LiveTVGuideView`, `SportsView`, and `JoeTVESPNPlusView` remain defined but are not routed here. |
| Navigation focus | `CatalogView.destinationButton`, `requestContentFocus`, per-screen `entryFocusRequest` | Horizontal focus does not change destination; Select changes destination. Down requests focus in the currently selected destination. Keyboard and remote paths need separate runtime checks. |
| Home | `JoeTVHomeView.lastFocusedFavoriteID`, `focusedID`, `featuredChannel(at:)` | Hero follows focused favorite. Local view state controls the rail/hero relationship. Initial entry defaults to the hero, consistent with existing design. |
| Live TV | `JoeTVGuideView` owns filter, selection, program sheet, and preview task/session; `AppModel.lastFocusedLiveID` stores a string bookmark | Grid Back → filters → navigation is explicit. Program Select opens a sheet; channel Select tunes. |
| Sports / Fantasy | `JoeTVSportsView` owns scope, selected item, filters/feed/settings sheets and Fantasy mode; categories persist in `AppModel` | Event focus selects metadata; activation checks availability and may open the broadcast selector. Fantasy has an independent 30-second refresh task. |
| Playback | `RootView.body` overlays `PlayerScreen` at z-index 100; `AppModel` owns session/target, Playback owns chrome | Catalog remains in the hierarchy. Player Back has layer handling, a delayed removal, and a browse-Back suppression deadline; actual focus restoration is not established by this source pattern alone. |

## 2. Strengths and accepted behavior to preserve

- **Clear visual hierarchy and distinct focus treatment.** `DesignSystem.swift` → `SeasonTheme`, `TopNavigationButtonStyle` and `JoeTVExperience.swift` → `JoeTVGuideFilterBody` distinguish selected state from the volt focus outline. Several styles honor Reduce Motion. Bundled artwork and `ArtworkView` fallbacks avoid blank channel cards when remote artwork fails.
- **Focus and activation are substantially separated.** Home focus changes hero context; Sports focus invokes `handleFocusedEvent` and debounced metadata lookup, while `activate` commits playback. Live guide focus may start a debounced **muted preview**, which is different from committing full-screen playback. Preserve that distinction in acceptance language.
- **Existing performance work has useful boundaries.** `AppModel.rebuildConsolidatedSportsItems` caches consolidation; `prefetchSportsEventDetails` limits detail work to two-item batches and publishes batches; `focusSportsEvent` debounces 350 ms. Sports uses `LazyVGrid`. These are source observations, not a measured latency guarantee.
- **Data and playback can remain useful independently.** `EPGLoadState.usableWindow` retains cached guide data through loading/failure, and channel actions do not require a program. Persistent favorites and enabled channels are separate (`favoriteLiveChannels`, `setChannel`, favorite migrations). Do not reset namespaces or user choices to simplify new UI state.
- **Retain the accepted player and sports features.** Source includes full-width Fantasy playback, a compact scorebug and Matchup/League drawer, captions with an unavailable state, and layered Back handling. The proposed work does not replace the player, change baseball feed choices, alter coverage policy, or reintroduce the old Sports split layout.

## 3. Findings and evidence

### APP-01 — the active guide can keep an old time window

**Observed:** `JoeTVExperience.swift` → `JoeTVGuideGrid.windowStart` derives from `max(anchor, guideWindow.start)`, and `windowEnd` is three hours later. The active `JoeTVGuideView.body` supplies `model.guideTimeAnchor`; its minute `TimelineView` updates labels but does not advance that anchor. `AppModel.guideTimeAnchor` is initialized/reset to `Date()`. The other time-navigation assignments found in `RootView.swift` belong to the unrouted `LiveTVGuideView`. `AppModel.loadEPG`/`refreshEPG` do not update the anchor.

**Inferred effect:** with no intervening state reset, the guide eventually shows an earlier three-hour window while its status says “Now”; `nowLine` disappears after the window ends. Returning after extended playback can expose the same stale window. Manual metadata refresh is not an explicit “jump to now” action.

**Confidence / verification:** high for the source dependency; viewer outcome pending a fixture clock or controlled long-session check. **Priority:** high-value correctness candidate, not a measured release incident. **Owners:** App; PM must allocate any `guideTimeAnchor` edits; Services supplies current/cached schedule fixtures.

### APP-02 — focus bookmarks and layered return are inconsistent

**Observed:** `JoeTVGuideView.updateSelection` writes either `program:<id>` or `channel:<id>`. `AppModel.applyChannelPreferences` strips only `channel:` and compares the remainder with channel IDs. A valid program bookmark therefore fails that comparison and is replaced when preferences/catalog reconciliation runs. `JoeTVGuideView.restoreFocus` restores selection but deliberately focuses the filter, not the cell. `JoeTVSportsView.selectedItemID` is local state; it does not use `AppModel.lastFocusedEventID`, which the legacy `SportsView` uses. The current sheets have no explicit originating-focus restoration on dismissal.

`JoeTVBroadcastSelector` additionally has an inner feed-mode layer. Its visible Back button clears `selectedGroupID` and focuses the **first** group; there is no selector-level `onExitCommand` for remote Back to unwind that inner layer.

**Inferred effect:** refresh/settings may lose the guide bookmark; returning from playback or sheets relies partly on framework restoration. At the feed-mode layer, remote Back may dismiss the entire sheet, and the visible Back action cannot restore a non-first originating feed. Do not treat intentional initial Home hero focus or guide-filter entry focus as a defect without Design agreement.

**Confidence / verification:** high for bookmark parsing and missing explicit inner-layer handling; medium for actual remote/sheet behavior. All runtime outcomes pending. **Owners:** App/Design, with Playback for player dismissal and PM allocation of `lastFocusedLiveID`/`applyChannelPreferences` or a replacement typed bookmark.

### APP-03 — empty states do not always distinguish absence from failure

**Observed:** `JoeTVSportsView.body` shows an ESPN+ error banner only when `espnPlusItems` is nonempty. `AppModel.loadESPNPlusSportsWindow` can set an error with an empty result. `guideContent` then chooses ordinary empty copy once loading ends; it does not inspect the ESPN+ failure or `eventState`. Thus a successful metadata path plus a failed empty catalog can yield “Nothing is live”/“No upcoming events” without explaining that events could not be loaded.

`JoeTVGuideView.epgStatus` places failure detail in `.help(message)` without an inline retry control. The no-channel action always sets filter to All: if every channel is disabled, Show all changes no enabled-channel preference and cannot recover the screen. `JoeTVHomeView.nowAndNext` describes how to add favorites but has no direct action and says “Settings → Channels” while the actual entry is the More menu.

**Inferred effect:** viewers can mistake unavailable data for no events or encounter a recovery button that leaves the screen unchanged. **Confidence / verification:** high for branch logic; wording/reachability pending fixtures and remote checks. **Owners:** App/Design; Services agrees failure and stale-data distinctions, SecOps reviews any changed error mapping for disclosure.

### APP-04 — active screens have gaps in explicit accessibility semantics

**Observed:** current Home cards, `JoeTVGuideGrid` channel/program buttons, Sports event cards, and scope/filter buttons lack the explicit contextual labels/hints/identifiers present in several legacy `RootView.swift` screens. `JoeTVGuideFilterBody` draws selected state but supplies no selected accessibility trait; the scope/filter call sites also do not add it. Guide program buttons visibly supply title/start time without a combined channel/end-time/action label. `JoeTVSportsView.activate` silently returns for an unavailable event, while its card remains a Button without an availability hint.

`JoeTVGuideButtonStyle`, `JoeTVRowButtonStyle`, and `JoeTVGuideGrid.speedScroll` animate without checking Reduce Motion, unlike `JoeTVCardButtonStyle` and `TopNavigationButtonStyle`. Active guide/sports metadata includes fixed 8–14 point text; its couch readability is unmeasured.

**Inferred effect:** VoiceOver may omit channel context, selected scope, and what Select will do; behavior and speech must be inspected before asserting that controls are inaccessible. Animation preference and TV-distance readability need a focused pass. **Confidence / verification:** high for modifier differences, medium for experience impact; no VoiceOver or visual verification. **Owners:** App/Design/QA; shared token changes require PM allocation.

### APP-05 — remaining rendering work needs profiling before optimization

**Observed:** `JoeTVGuideGrid.body` creates both channel and program columns with eager `VStack`/`ForEach`. Every channel attaches a listener to the common `focusedID`; the guide root also resolves that identifier, scanning channel programs for program focus. `JoeTVSportsView.body` derives Live, Upcoming and Fantasy lists even in normal Sports mode; `SportsEventGuidePolicy.filteredItems` filters and sorts. `JoeTVSportsFilterView.counts` derives filtered/grouped counts from a computed property read inside category rendering.

**Inference only:** large guide windows/catalogs and broad `AppModel` updates may increase focus-time work. Source alone cannot establish slow frames, memory pressure, redundant network downloads, or a benefit from changing to lazy guide columns; virtualization could itself harm pinned-row alignment/focus.

**Confidence / verification:** high for work locations, low-to-medium for material performance impact. No launch/navigation/memory/frame-time numbers collected. **Owners:** App profiles with QA on an assigned resource; Services/PM only if profiling justifies shared derivation changes. Preserve cached consolidation and batched metadata updates.

### APP-06 — playback entry and preview cancellation deserve a bounded race check

**Observed:** `JoeTVGuideView.schedulePreview` cancels pending work, checks cancellation/identity after resolution, and `stopPreview` runs before both current guide play actions and on disappear. These are good safeguards. However, `resetSelection` does not stop an existing preview when a chosen filter has zero channels; the old preview session can remain retained/playing while the selection is empty. There is no explicit preview suspension on opening a settings sheet or focus moving to global navigation.

Separately, Home/Guide/Sports buttons launch unstructured playback tasks. `AppModel.playMediaItem`/`playLiveChannel` set `isWorking` but do not guard a second initial request or attach a pre-resolution request identity. `RootView.WorkingOverlay` supplies no explicit catalog focus/activation gate. `installPlaybackSession` guards preparation callbacks only after resolution/installation.

**Inferred risks:** a preview may continue out of context; if repeated Select reaches underlying controls, two initial resolutions could complete out of order. Framework focus/overlay behavior may prevent that input, so this is not a confirmed duplicate-stream defect. **Confidence / verification:** high for source control flow, medium for preview consequence, conditional for initial activation race. **Owners:** App and Playback, Services for a delayed resolver fixture. Verify with offline/clear-media instrumentation, never concurrent authenticated provider probes.

## 4. Three proposed user-facing improvements

These are proposals for Joe/PM selection, not implementation authorization. Effort is relative engineering scope; it excludes unknown hardware findings.

### P1 — return to the right program in a guide that stays current

- **Viewer situation:** after a game or a program-details visit, the viewer wants the same channel/context and a useful current schedule.
- **Behavior:** preserve the originating channel/program through details and playback; reconcile missing programs to the current program on that channel, then to a visible channel. Give the guide an explicit Now action and advance an expired window at an agreed safe boundary, without moving focus while the viewer is inspecting a future program. Remote Back inside broadcast mode selection returns to the originating feed before closing the sheet.
- **Benefit / prior work:** builds on existing string bookmarks, filter Back chain, and playback suppression; fixes APP-01/02 rather than redesigning navigation. Keep Home's accepted first-entry hero behavior.
- **Effort / confidence:** medium; high confidence in the need for clock/bookmark fixes, medium in the minimal cross-screen focus design.
- **Dependencies:** Design chooses automatic-window timing and fallback rules; App owns view changes; Playback owns dismissal coordination; PM assigns `AppModel.guideTimeAnchor`, `lastFocusedLiveID`, `applyChannelPreferences` and any new shared state. QA owns simulator session; hardware validates physical Back repetition.
- **Smallest experiment:** one guide fixture with a controllable clock, two channels, current/future programs, and a removable originating program. Prototype explicit bookmark restoration and Now on this screen; separately exercise Home/Away/National → mode → remote Back with local feed fixtures.
- **Acceptance:** after advancing beyond the original three-hour window, Now exposes the actual current program; future browsing is not interrupted. Detail/player return focuses the same extant item, with deterministic channel fallback if removed. A catalog refresh or unrelated channel toggle preserves a valid program bookmark. One Back unwinds one layer and restores the chosen feed; focus alone never commits full-screen playback. Validate keyboard, simulator remote, and physical remote separately.

### P2 — make every empty or unavailable screen lead somewhere useful

- **Viewer situation:** no favorite is configured, all channels are disabled, or a catalog fails during a quiet sports window.
- **Behavior:** add direct Choose Favorites/Manage Channels entry actions; distinguish “nothing scheduled,” filtered-out content, loading and load failure; keep existing usable cards visible with a concise Retry action. State event availability in ordinary language when Select cannot play it. Keep technical transport text out of the main browsing experience.
- **Benefit / prior work:** builds on `StatePanel`, `InlineStatusBanner`, More-menu settings sheets and independent load states; avoids extra menu hunting and misleading empty results (APP-03/04).
- **Effort / confidence:** small-to-medium; high source-backed value. No new provider or preference schema is required for the first prototype.
- **Dependencies:** App owns settings-route callbacks through `CatalogView` and screen state presentation; Design owns copy; Services agrees existing failure/partial-success semantics. SecOps reviews any new surfaced error detail. Do not persist different favorites or channel enablement merely to populate an empty screen.
- **Smallest experiment:** fixture matrix for zero favorites, all channels disabled, no scheduled events, no selected sports, cold ESPN+ failure, and failure with cached events. Wire one inline recovery action per actionable case using existing methods.
- **Acceptance:** each action changes the relevant state or opens the relevant settings sheet; Done/Back restores its originating action. Failed loading is not reported as proven absence of events. Retry preserves filter/favorite choices and usable content; no focus movement issues a playback request. Confirm every action is reachable using the remote and VoiceOver.

### P3 — make the active guide understandable by speech and from the couch

- **Viewer situation:** a viewer uses VoiceOver or Reduce Motion, or cannot read small schedule/status labels at normal viewing distance.
- **Behavior:** announce channel, title, time range and action for program cells; announce selected scope/filter and event playback availability; provide concise, nonduplicated card speech. Honor Reduce Motion consistently and review small metadata sizes without changing the adopted layout.
- **Benefit / prior work:** reuses the stronger accessibility patterns in settings/player and legacy screens; improves the actual routed screens (APP-04), with stable identifiers that also help QA.
- **Effort / confidence:** small for semantics/motion; medium if readability requires layout adjustment. High confidence in source gaps, user benefit to be verified.
- **Dependencies:** App and Design; QA for VoiceOver/remote matrix; Playback for any agreed player-boundary change. PM allocates shared token edits only if needed.
- **Smallest experiment:** one Home favorite, guide channel/program, Live/Upcoming control, playable event and unavailable event. Add semantic labels/state to those prototypes and compare spoken output and long-title layouts, with Reduce Motion on/off.
- **Acceptance:** speech identifies context, selected state and Select behavior without decorative duplicates; unavailable events explain why playback cannot begin. Focus remains visible and reachable. Reduce Motion removes optional animated scrolling/scaling transitions. Long titles and selected outlines do not clip; Joe/Design checks TV-distance readability on identified hardware rather than accepting a simulator screenshot alone.

## 5. Ownership, documentation discrepancies, and open questions

App owns the routed view changes in `RootView.swift`/`JoeTVExperience.swift`; shared visual tokens in `DesignSystem.swift` require coordination with Design and PM. `AppModel.swift`, `Models.swift`, `Tests/ParserSmoke.swift`, and project configuration are not available for unassigned edits. Playback is default owner of `PlayerScreen.swift`; App should propose an entry/exit contract, not independently change player internals. Services owns data/failure/resolution contracts. PM integrates and updates shared documents. This report does not request deletion of legacy views as prerequisite work.

| Historical documentation | Source reconciliation at the assessed HEAD |
| --- | --- |
| `README.md` implemented features / Run: free Very Local login button, search/Up Next browse, master/detail Sports | `LoginView` has no free-entry action. `CatalogView` routes the new guide and full-width Sports board; old browse/search/disclosure implementations are not current routes. Do not restore them solely to match prose. |
| `docs/TECHNICAL_HANDOFF.md` §6: two destinations, Live TV default, `fullScreenCover` player | `AppModel.Destination` has three cases and defaults to Home; `RootView` uses a ZStack player overlay. |
| `JOE-TV-DESIGN-IMPLEMENTATION.md`: native player owns captions; focus never starts playback | Custom captions exist in `PlayerScreen`; guide focus starts a muted preview. Describe the accepted distinction between preview and committed playback. |
| `docs/TECHNICAL_HANDOFF.md` Fantasy/player/design passages: left rail, old long-Select/Up–Down behavior, split Sports | Current source/spec use scorebug + two-tab drawer, optional blind surfing, and the full-width board. Historical prose is not current interaction acceptance. |

Open decisions for a future scoped assignment: when should an expired guide recenter automatically versus require Now; should guide preview pause while a sheet/global navigation owns focus; what exact restoration target is intended after player exit; and should unavailable event selection present brief information or remain a clearly announced non-playable card? None blocks this source assessment. Historical four-second live-edge and performance success reports in `docs/product-context.md` were not reproduced and are not new budgets.

## 6. Checks and remaining validation

- Confirmed clean initial worktree; verified assigned branch did not exist; created it at the exact bootstrap HEAD. The managed checkout initially pointed to a later release commit, then was switched to the requested assessment baseline. No release-owned app files were edited.
- Read and searched active routes, focus handlers, state branches, accessibility modifiers, clock/bookmark writes, preview/playback boundaries and historical documentation. This establishes source facts only.
- Ran `git diff --check` and checked the staged file list before commit; report-only scope. No application checks were run: no smoke suite, build, simulator, UI automation, profiling, live stream, or external-service request. QA owns fresh execution evidence.
- Pending QA fixtures: program/channel bookmark refresh, expired guide window, empty/failed states, sheet and playback return, feed-mode Back, long labels, VoiceOver/Reduce Motion, delayed repeated-Select resolution, and preview cleanup after an empty filter. Use known clear media or local fixtures first.
- Pending hardware: physical Siri Remote Back/press repetition, TV-distance readability, representative performance/memory. FairPlay, real stream preparation, captions on actual supplied tracks, and provider connection limits need separately authorized Playback/QA/device evidence. Simulator or source inspection cannot prove them.
- Coordination limitation: both onboarding message attempts to the assigned PM task were rejected by automatic approval review because it did not accept the destination authorization evidence. No PM message was delivered. The report and local commit remain available for review; sending the handoff requires that approval issue to be resolved.

All proposed runtime work needs PM resource allocation. Current release ownership, credentials, private configuration, the original checkout's source, and SHELF were left untouched.
