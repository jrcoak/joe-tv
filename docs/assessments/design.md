# M0-DESIGN — Product Design assessment

## 1. Assignment and evidence boundary

Joe-TV already has a coherent television experience. Preserve its favorites-led Home, full-width Sports board, explicit tuning, and unobtrusive Fantasy presentation. Under TEAM-2, the first implementation recommendation is UI polish, shorter watching paths, predictable focus, and measured responsiveness. Section 7 supersedes the original proposal ranking; the source findings remain valid.

| Field | Accepted value |
| --- | --- |
| Assignment / spec | M0-DESIGN / TEAM-2 accepted; original source assessment under TEAM-1 |
| Specialist task | `01a0ad34-9969-7ce1-9a82-a53fe7b979e9` on `local` |
| PM task | `01a0ad24-56de-73e1-b5de-5a0fdc8c49ff` |
| App baseline | `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8` |
| Assessment starting HEAD | `314968dc10f0bd73451ed6b0876a7fc7ed5c5233` — shared instructions atop the app baseline |
| Branch | `codex/joe-tv-design` |
| Worktree | `/Users/joecoakley/.codex/worktrees/3770/SeasonsTV` |
| Allowed change | This report only; no app or shared-document edits |

The managed worktree was clean before branch creation. Its initial detached HEAD was `138c2714805ce47d26f0da5c3d9d8cf48bd488b8`; the requested branch was then created explicitly at `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`. Findings below concern that assigned baseline, not the release task's later work. Git needed permission to update shared worktree metadata; no files in the original checkout or PM worktree were edited.

Evidence labels used below:

- **Source observation:** directly inspected control flow, view composition, or declarations at the assessment HEAD. This does not establish runtime behavior.
- **Historical/reference:** RALLY concept materials or earlier reports; neither is a fresh Joe-TV screen capture or test result.
- **Hypothesis/proposal:** expected viewer effect or future behavior requiring validation and scope approval.

Read all eight assignment/bootstrap documents: `AGENTS.md`, `spec.md`, `docs/agent-team.md`, `docs/tvos-specialists.md`, `docs/team.md`, `docs/decisions.md`, `docs/product-context.md`, and `docs/assignments/M0.md`. Inspected the RALLY design writeup, `flows/REMOTE-NAVIGATION.md`, and its guide/player reference PNGs. Inspected active screen paths in `SeasonsTV/Views/RootView.swift`, `JoeTVExperience.swift`, `DesignSystem.swift`, and `PlayerScreen.swift`; relevant state, playback, availability, history, and Fantasy symbols in `SeasonsTV/App/AppModel.swift` and `SeasonsTV/Models/Models.swift`; and the freshness boundary in `SeasonsTV/Networking/ESPNScoreboardClient.swift`. Consulted earlier design/implementation/handoff documents only to identify stale claims. No simulator, device, provider stream, private configuration, or SHELF inspection was performed.

## 2. Strengths and annotated journey

### Preserve these decisions

| Existing strength | Exact source evidence | Verification |
| --- | --- | --- |
| A small, stable navigation hierarchy: Home, Live TV, Sports, with settings in More. Focused navigation and selected destination have separate treatments. | `SeasonsTV/Views/RootView.swift`: `CatalogView.destinationBar`, `destinationButton`, `requestContentFocus`; `SeasonsTV/Views/DesignSystem.swift`: `TopNavigationButtonStyle`. | Source; high confidence. Remote reachability pending. |
| Home's hero follows the focused enabled favorite. A channel remains playable when guide artwork or program metadata is missing. | `SeasonsTV/Views/JoeTVExperience.swift`: `JoeTVHomeView.featuredChannel`, `heroCopy`, `nowAndNext`; `SeasonsTV/App/AppModel.swift`: `favoriteLiveChannels`. | Source; high confidence. Hero transition and first/last card clipping pending. |
| Guide duration is spatial, NOW is aligned with time, and metadata failure does not remove channel actions. Focus requests a debounced muted preview; Select explicitly starts primary playback or opens program actions. | `SeasonsTV/Views/JoeTVExperience.swift`: `JoeTVGuideGrid`, `JoeTVGuideView.schedulePreview`, `epgStatus`, `JoeTVProgramActionsView`, `EPGLoadState.usableWindow`. | Source; high confidence. Preview/primary-player handoff pending Playback/QA validation. |
| Sports consolidates sources into Live/Upcoming and persistent granular filtering, with selected-event copy above a full-width board and compact artwork preview. | `SeasonsTV/Views/JoeTVExperience.swift`: `JoeTVSportsView.body`, `sportsSelectionHeader`, `guideContent`, `sportsPreview`, `JoeTVSportsFilterView`; `SeasonsTV/App/AppModel.swift`: `consolidatedSportsItems`. | Source; high confidence. The Sports preview is artwork, not a running video preview. |
| Broadcast groups use human names, including Home/Away/National. Explicit start-over remains a separate option when supplied; normal live entry retains the live-edge policy. | `SeasonsTV/Views/JoeTVExperience.swift`: `JoeTVBroadcastSelector`, `MediaItem.sportsBroadcastGroups`, `broadcastGroupTitle`; `SeasonsTV/Models/Models.swift`: `PlaybackSession.positionAtLiveEdgeIfNeeded`. | Source; high confidence in the UI/policy. Actual feed/date/live-edge correctness is pending. |
| Quick Switch separates browsing from tuning and returns to the prior session on preparation failure. History uses stable targets; the rail omits the current stream and deduplicates recents/favorites. | `SeasonsTV/Views/PlayerScreen.swift`: `quickSwitchGroup`, `handleBack`; `SeasonsTV/App/AppModel.swift`: `quickSwitchEntries`, `switchPlayback`, `installPlaybackSession`; `SeasonsTV/Models/Models.swift`: `PlaybackHistoryPolicy` (`recentLimit = 4`). | Source; high confidence. No real or fixture switch was exercised here. |
| Fantasy keeps video full-width, offers only Matchup/League in its temporary drawer, and formats missing score values as a dash rather than an invented probability. | `SeasonsTV/Views/PlayerScreen.swift`: `playbackSurface`, `FantasyScorebugContent`, `FantasyDrawerTab`, `FantasyPlaybackDrawer`, `FantasyPlaybackState.score`. | Source; high confidence. Overlay readability/opacity pending. |
| Warm black/paper/coral/volt, editorial titles, 4-point focus outlines, and short focus animations carry the adopted RALLY language into native views. | `SeasonsTV/Views/DesignSystem.swift`: `SeasonTheme`; `SeasonsTV/Views/JoeTVExperience.swift`: `JoeTVFocusBody`, `JoeTVCardButtonStyle`. | Source plus reference images. This is not a rendered parity assessment. |

The concept's Multiview, recording, reminders, profiles, spoiler mode, and catch-up video are historical ideas, not M0 scope. Later Joe decisions govern the current Sports board, optional blind surfing, and Fantasy scorebug/drawer.

### Storyboard A — find a favorite, glance at another channel, return

This is a source-derived journey, with runtime checkpoints explicitly marked. Assume a signed-in viewer, two enabled favorites, and blind surfing disabled (the default).

```text
HOME                    PRIMARY PLAYBACK           QUICK SWITCH
[Hero: favorite A]      [Full-width video A]        [Video A behind rail]
[Watch live]            [Chrome fades]             [Recent … | Favorite B]
[A] [B] [C]             Down opens rail             Focus B previews its card
Focus B changes hero    Select reveals controls     Select commits switch
       | Select                  |                         |
       +------------------------>+-------------------------+

Successful B → controls fade → B plays
Failed B     → A restored + switch message → choose another card
Back in rail → controls → hidden chrome → originating browse surface
```

| Frame | Annotation and exact source | What QA should establish |
| --- | --- | --- |
| 1. Home | `JoeTVHomeView.onChange(of: focusedID)` records the favorite; `featuredChannel` updates the hero. `nowAndNext` only calls `model.play` inside the button action. | Focus alone never starts primary playback; hero/channel labels agree; long titles remain readable. |
| 2. Watching | `PlayerSessionView.onAppear` shows passive identity; `scheduleChromeHide` starts at four seconds. `handleDown` opens Quick Switch when entries exist. | Default Down opens browsing without tuning; Select starts at Play/Pause; hiding controls preserves picture. |
| 3. Choose B | `quickSwitchGroup` starts switching only in its button action. `AppModel.installPlaybackSession` holds the previous session for rollback. | One audible/active playback session; focus does not resolve a new primary stream; a forced failure leaves a usable previous session and reachable recovery. |
| 4. Back | `handleBack` unwinds rail → controls → hidden → dismissal. `beginPlaybackBackDismissal` suppresses browse Back briefly. | One physical Back press unwinds one layer and does not exit the app. Verify the actual originating card after dismissal; source alone does not prove focus restoration. |

### Storyboard B — optional Fantasy glance

`More → Fantasy Zone settings → username/league → Sports → Fantasy Zone → RedZone or NFL game → full-width video + scorebug → Select → Matchup → drawer → Back → controls focused on scorebug.` This follows `FantasyZoneSettingsView`, `JoeTVSportsView.fantasyStreamingOptions`, `PlayerSessionView.showFantasyDrawer`, and `closeFantasyDrawer`. Selecting the League tab commits a tab change; merely focusing it does not. RedZone/NFL Network remain useful watch choices when no game cards are live. The scorebug's no-data/failure distinction needs the change proposed in D-I2.

## 3. Findings, impact, and confidence

### D-F1 — Sports availability is only partly explained

**Source observation, high confidence:** `SeasonsTV/Views/JoeTVExperience.swift:1440`, `JoeTVSportsView.activate`, returns immediately when `sportsPlaybackAvailable` is false. Cards remain ordinary buttons with the same focus style. `JoeTVSportsGuideCard.cardDetail` at line 2882 announces a coverage time for an upcoming schedule entry whenever `sportsCoverageStartsAt` exists; that date is calculated independently of `isPlayable` in `SeasonsTV/Models/Models.swift:254`–`262`. Thus a schedule-only event can advertise “Coverage begins at…” even though no playable source is attached.

**Viewer impact hypothesis:** a responsive-looking card whose Select does nothing can seem broken; coverage copy may overpromise availability. **Status:** source-confirmed paths, no observed user failure. **Owner/dependency:** App with Services on availability semantics; D-I1 below. Preserve the 15-minute gate, stable identity/date matching, and explicit broadcast selection.

### D-F2 — No-track captions have no normal entry point

**Source observation, high confidence:** `SeasonsTV/Views/PlayerScreen.swift:533`, `PlayerSessionView.playerControls`, creates the Captions button only when `subtitleOptions` is nonempty; `controlFocusTargets` repeats that condition. The dialog contains “No captions available,” but an ordinary no-track session cannot reach it through this control. `PlaybackSession.refreshSubtitleOptions` in `SeasonsTV/Models/Models.swift:1313` is asynchronous, so empty also represents discovery before completion.

**Viewer impact hypothesis:** absence is ambiguous between unsupported stream, still loading, and missing app functionality. **Status:** source-confirmed visibility gap against TEAM-1's understandable unavailable state; media discovery and assistive-technology behavior untested. **Small maintenance acceptance:** retain a named Captions entry; distinguish checking, available/off, and unavailable; preserve focus if options change; no fake track and no disabled-only explanation that cannot be read. Playback owns player and track state, with App/Design review and QA using clear media with/without tracks. A track-discovery state may require a specifically assigned `Models.swift` symbol.

### D-F3 — Fantasy can present retained data or failure as if still current/loading

**Source observation, high confidence:** `SeasonsTV/App/AppModel.swift:714`, `refreshFantasyMatchup`, and `:743`, `refreshFantasyNFLScoreboard`, retain prior data on failure and publish failure state separately. `FantasyScorebugContent` in `SeasonsTV/Views/PlayerScreen.swift:1025` renders a retained matchup without consulting those states; with no matchup it always shows a loading spinner. `FantasyPlaybackDrawer.lineupView` similarly uses “Lineup details are loading…” for absent data. `JoeTVSportsView.fantasySelectionHeader` can suggest adding a username when a configured initial load failed. `FantasyMatchupSnapshot.fetchedAt` exists in `SeasonsTV/Models/Models.swift:713` but is not displayed in these views.

**Viewer impact hypothesis:** delayed points may look live, and a failed initial load may look endless or invite unnecessary setup. **Status:** source-confirmed state omission; no outage simulated. **Owner/dependency:** Playback/App with Services; D-I2. Retaining useful data and keeping video uninterrupted are strengths to preserve. The historical choice to suppress transport errors should remain: show plain viewing context, not decoder or networking details.

### D-F4 — Back and return focus need a targeted audit

**Source observation:** `JoeTVBroadcastSelector` (`SeasonsTV/Views/JoeTVExperience.swift:2098`) models broadcast and live/start-over choices as two stages. Its on-screen Back clears `selectedGroupID` and focuses the first group, not the group just exited. It has no local `.onExitCommand` implementing this two-stage unwind. `JoeTVGuideView.restoreFocus` (`:494`) preserves the selected program but focuses the current filter; `JoeTVSportsView.restoreFocus` (`:1461`) focuses scope. `PlayerSessionView.closeFantasyDrawer` always focuses the scorebug, even if the drawer was opened from the Matchup control.

**Impact hypothesis:** the visual context can be retained while the actionable focus jumps elsewhere; remote Back may dismiss the whole feed sheet instead of one internal stage. **Confidence:** high in the explicit assignments; medium in resulting native focus/dismissal behavior. **Status:** runtime hypothesis, not a reproduced navigation defect. **Acceptance:** QA records focus before/after Cancel, physical Back, player dismissal, failed switch, and sheet closure; a nested selector returns to its originating feed; removing the original item uses a documented nearby fallback. App owns browse/sheets; Playback owns player; PM must allocate any shared browse-origin state.

### D-F5 — Some labels and fixed layouts warrant couch-scale validation

**Source observation, high confidence:** `JoeTVSportsGuideCard` (`SeasonsTV/Views/JoeTVExperience.swift:2759`) uses 8–12-point source/status/date/detail text and single-line team names. `JoeTVGuideFilterBody` (`:3047`) is 42 points high. `FantasyScorebugContent` uses 10–12-point supporting text. `FantasyPlaybackDrawer.lineupView`/`leagueView` (`SeasonsTV/Views/PlayerScreen.swift:1248`, `:1275`) use unscrolled `ForEach` content in the available vertical space. `JoeTVGuideGrid.programRow` (`JoeTVExperience.swift:701`) uses a 94-point minimum program width at eight points per minute, which can exceed the actual slot width for a short program. RALLY's reference calls for 64-pixel interactive targets, but prototype pixels and native points are not a measured equivalence.

**Impact hypotheses:** essential availability text may be hard to read; large fantasy rosters/leagues may overflow; short guide programs may overlap; scaled focus at clipped board edges may lose part of its outline. **Status:** no actual clipping, contrast ratio, or television readability measured. **Acceptance:** QA supplies native screenshots at the supported layout sizes with long team/program names, a large lineup/league, short adjacent programs, missing artwork, and focus at each edge; Joe verifies essential status at normal seating distance. Adjust density based on that evidence while retaining the full-width board and compact scorebug. App owns browse layout; Playback owns drawer; shared tokens need PM assignment.

### D-F6 — Small resilience and semantic inconsistencies

**Source observations:** Home's empty-favorites copy says “Settings → Channels,” but the actual navigation control is named More (`JoeTVHomeView.nowAndNext`; `CatalogView.destinationBar`). Guide and broadcast row styles animate without consulting Reduce Motion, unlike the primary/card styles (`JoeTVGuideButtonStyle`, `JoeTVRowButtonStyle` in `JoeTVExperience.swift:3116`, `:3132`). In player identity without a guide program, “LIVE EDGE” depends only on `session.isLivePlayback`, not distance from the edge; pause and supported seeking can change playback position (`PlayerSessionView.playerIdentity`; `PlaybackSession.seek` in `Models.swift:1421`).

**Impact hypotheses:** a dead-end instruction, inconsistent motion, and a misleading position label. **Confidence/status:** high for source conditions; actual reduced-motion behavior and visible stale label need runtime checks. **Small maintenance acceptance:** use the visible navigation name or a direct Channels action; honor Reduce Motion in all relevant styles; label stream type as “LIVE” unless edge position is known. Do not turn program-schedule progress into a claim about playback position. These are bounded fixes, not additional product concepts.

## 4. Three grounded innovations for PM ranking

All three are proposals, not accepted implementation. Effort is relative and provisional: **small** means one contained surface/policy change; **medium** spans UI and state/provider contracts. No numerical performance gain or delivery date is asserted.

### D-I1 — Make every sports selection answer “Can I watch this?”

**Viewer situation:** Joe sees tomorrow's game, a game inside the pregame window, or a score-only listing and presses Select.

**Proposed behavior:** retain focus-driven editorial details and the current board. Add a concise availability line to selected-event details. Select on unavailable entries opens a compact informational sheet with the scheduled time, availability reason, and Close; Back restores the event. Playable entries retain their current direct-watch or broadcast-selector path. Suggested states:

| Known state | Viewer copy/action |
| --- | --- |
| Playable source, before the pregame gate | “Scheduled 7:00 PM · Check back from 6:45 PM.” No promise that a provider will be healthy then. |
| Playable source, inside gate | “Pregame coverage available” and the existing Watch/broadcast action. |
| Schedule metadata, no matched source | “Schedule only · No stream available in Joe-TV yet.” No coverage promise. |
| Live but no matched source | “Live scores · No stream available in Joe-TV.” Keep useful metadata. |

**Benefit hypothesis:** fewer repeated Select presses and clearer distinction between event time and stream availability. **What already exists:** `sportsPlaybackAvailable`, `sportsCoverageStartsAt`, selected-event header, broadcast sheet, and schedule-only `.unavailable` items; no new provider is required. **Effort/confidence:** small-to-medium; high confidence in the problem, medium in the preferred copy/interaction.

**Dependencies/risks:** App owns `JoeTVSportsView` and card/sheet design; Services validates reason derivation and date matching. Avoid new network work on focus and don't bypass source/playback gates. PM assigns a model symbol only if a shared availability enum is needed. Playback verifies existing playable entry behavior; QA owns fixture validation.

**Smallest experiment:** a fixture storyboard/prototype with four states above, including one event crossing the 15-minute boundary while focused. **Acceptance:** each focused item tells whether Select will watch or explain; schedule-only entries never promise coverage; Select always gives useful feedback; no focus-triggered tune; the boundary update preserves the card's identity/focus; Joe correctly predicts the outcome for every fixture. Compare wrong/repeated Select attempts with baseline before claiming improvement.

### D-I2 — A Fantasy glance that earns trust when updates lag

**Viewer situation:** the game keeps playing but Sleeper or the live NFL scoreboard stops refreshing, or Fantasy starts without any successful data.

**Proposed behavior:** preserve scorebug dimensions and full-width video. Keep last-known points, replacing a secondary line with “Matchup updates delayed · checked 8:42 PM” when warranted. With no successful matchup, show a quiet “Matchup unavailable” state instead of an endless spinner. Put separate Matchup/NFL update context and a reachable Retry action inside the existing drawer; a successful refresh clears the notice without moving focus. Initial loading remains distinct. No probability bar, new tab, full-height persistent rail, or technical errors.

**Benefit hypothesis:** Joe can tell the difference between no points, no active players, and stale information without leaving the game. **What already exists:** retained matchup/scoreboard data; separate `fantasyState` and `fantasyNFLScoreState`; `FantasyMatchupSnapshot.fetchedAt`; 30-second refresh loops; `ESPNScoreboardClient`'s private `lastRefresh`. **Effort/confidence:** medium; high confidence in the source gap, medium in the best unobtrusive treatment.

**Dependencies/risks:** Playback owns scorebug/drawer; App owns Fantasy browse states; Services defines update-age semantics separately for the two feeds. Sleeper fetch time is a last-check time, not proof that upstream points changed then. NFL freshness is not exposed alongside its event array today; do not use the current render time or a cached response's read time as fresh data. Preserve the direct-live-data exception and existing request throttling. PM assigns any changes to `AppModel.refreshFantasy*`, `Models.swift`, or `LiveNFLScoreProviding`; SecOps reviews only relevant provider/error handling changes.

**Smallest experiment:** frozen fresh/delayed/failed/recovered fixtures inside the existing scorebug and drawer. Establish a candidate delay threshold with Services and test it rather than inventing an SLA. **Acceptance:** an injected failure retains values with a plain delayed indicator; first-load failure terminates loading; a stale scoreboard cannot by itself justify a fresh LIVE badge; no unknown score becomes zero; Retry is reachable and respects throttling; playback/audio continue; Back restores the invoking context; Joe recognizes all four states at seating distance without needing larger permanent chrome.

### D-I3 — Optional broadcast memory, with the viewer still in control

**Viewer situation:** Joe repeatedly chooses a team's home commentary, including when that team is away, but must navigate Home/Away/National each game.

**Proposed behavior:** after an explicit opt-in, remember a team/broadcast preference on this Apple TV and focus the matching current feed in the existing selector, labeled “Your usual broadcast.” Select still commits. Keep Home/Away/National available. When the remembered feed is absent, say so and present the ordinary alternatives; never silently tune a substitute or persist a media URL. Remember the team's identity, not merely the home/away position. Preserve normal live entry and the explicit start-over choice.

**Benefit hypothesis:** fewer directional presses on repeat viewing while preserving the accepted selector and avoiding surprise tuning. **What already exists:** RALLY's historical “Broadcast memory” idea; `MediaItem.PlaybackOption.broadcastKey`; `sportsBroadcastGroups` and `broadcastGroupTitle`; `SportsScheduleEvent.homeTeamID`/`awayTeamID`; URL-free playback target history. The inspected selector currently focuses the first ordered group and has no saved team-broadcast preference. **Effort/confidence:** medium; medium confidence in desirability; team identity consistency is a feasibility dependency.

**Dependencies/risks:** Design/App own preference wording and initial focus; Services validates league/team/source identity and matching across provider records; Playback ensures fresh stream resolution and correct live mode; PM assigns additive persistence/model symbols. Keep namespaces stable and opt-in off by default. Missing or ambiguous team IDs disable the recommendation rather than guessing. No new account/profile or backend deployment is proposed.

**Smallest experiment:** static selector states for the same team at home, away, unavailable, and ambiguously matched; first trial uses no persistence. Compare presses and wrong-feed selections against the existing first-group default. **Acceptance:** only a uniquely matched team feed receives preferred focus; away games don't invert the preference; absent/ambiguous matches do not auto-substitute; all choices remain reachable; Select is the sole tuning action; nested Back returns to the selected group; Joe completes repeat selection with fewer directional presses and no increase in wrong-feed choices. Persistence follows only if this trial is useful.

## 5. Ownership, documentation discrepancies, and decisions still needed

This assignment changes no app symbols. The original TEAM-1 suggestion was D-I1 first, D-I2 second, and D-I3 as a small exploration. TEAM-2 replaces that ordering with the friction/performance-first roadmap in section 7. The three proposals remain available for subsequent prioritization.

| Topic | Ownership / next dependency |
| --- | --- |
| Availability, Home empty state, guide/Sports focus/layout | App; Services reviews availability identity/date facts. |
| Captions, player labels, switch recovery, Fantasy overlays | Playback; Design reviews behavior; QA exercises fixtures/device as appropriate. |
| Freshness and broadcast identity | Services; PM serializes shared `AppModel.swift`, `Models.swift`, protocols, persistence, and smoke-test changes. |
| Tokens, project/build/release | Shared tokens require PM assignment; project/release configuration stays with PM/release owner. No need for these changes in this assessment. |
| Visual verification | Design reviews QA's captures; QA operates the assigned simulator. Joe provides physical remote/couch/DRM evidence. |

Documentation discrepancies to route to PM, without editing their sources:

- `JOE-TV-DESIGN-IMPLEMENTATION.md` describes native-player-owned captions and a free Very Local login entry. Current `PlayerSessionView` implements custom captions, while the active `LoginView` presents sign-in without that free-entry button. Very Local support remains in the app; absence of an entry button is not absence of the integration.
- `docs/REDESIGN_IMPLEMENTATION_REPORT.md` and the UI section of `docs/TECHNICAL_HANDOFF.md` describe a left/right Sports master/detail split. `CatalogView` routes to `JoeTVSportsView`'s current full-width board. Old `SportsView`, `LiveTVBrowseView`, and `LiveTVGuideView` definitions remaining in `RootView.swift` are not the active destination routes inspected here.
- `docs/TECHNICAL_HANDOFF.md` describes a persistent left Fantasy rail, hold-Select opening Quick Switch, and default Up/Down surfing. Current source uses scorebug/drawer; hold Select recalls the last stream; Down opens Quick Switch with blind surfing disabled by default. Its blanket statement that Joe-TV never contacts ESPN needs the already-documented Fantasy exception. Its warm-gold description also predates `SeasonTheme`'s coral/volt palette.
- RALLY's reference PNGs include concept-only controls. They establish visual intent, not a requirement to add Multiview/recording or restore a superseded layout. Earlier reported remote walkthroughs and live-edge timings are historical evidence only.

Outstanding questions are validation dependencies, not reasons to block this report: which configured simulator/device will QA use for focus evidence; how often Joe selects alternate commentary; the longest real league/lineup to support; and what plain delay indication he finds readable without distracting from video. No feature is assumed approved by listing these questions.

## 6. Checks performed and pending acceptance

| Check | Actual result |
| --- | --- |
| Managed worktree `git status --short` before setup and after branch creation | Clean. |
| `git branch --show-current` / `git rev-parse HEAD` | Requested branch and exact bootstrap HEAD confirmed. |
| `git diff c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8 HEAD -- SeasonsTV Tests Joe-TV.xcodeproj` | Empty: inspected app/test/project tree matches the assigned app baseline. |
| Active-view/state inspection and exact-symbol searches | Completed; findings above are source observations or explicitly labeled hypotheses. |
| RALLY guide/player PNG inspection | Completed as reference review only; no current app screenshot produced. |
| Report whitespace/scope review | `git diff --cached --check` passed; staged-name/stat inspection showed only `docs/assessments/design.md`. No application symbols changed. |
| Offline smoke and simulator build | Not run by Design. QA owns fresh `scripts/team-check.sh smoke` / `build` evidence; earlier pass reports are not reused. |
| Simulator, physical remote, captions media, live service, FairPlay | Not exercised. No success or failure claim is made for these. |

Requested QA coverage is bounded: baseline navigation/return-focus journey, nested broadcast Back, empty/no-track captions, forced switch failure, no-data/failed Fantasy states, long text/large rosters, short guide slots, and outline visibility at scroll edges. Use the existing debug fixture hooks where suitable (`AppModel`'s `JOE_TV_DEBUG_QUICK_SWITCH`, `JOE_TV_DEBUG_FANTASY_ZONE`, `JOE_TV_DEBUG_FANTASY_UPCOMING`, and suitable clear caption media via `JOE_TV_DEBUG_CAPTIONS_URL`); those hooks were inspected, not executed. Missing failure/size fixtures are a proposed QA dependency, not permission for Design to add code.

M0-DESIGN acceptance is satisfied by this baseline-specific report, two annotated journeys, six evidence-backed finding groups, and three bounded proposals with ownership, experiments, and success criteria. Runtime product acceptance remains pending the independently owned evidence above. Commit only this report, hand its exact commit to PM for sequential integration, then stop this assignment.

## 7. TEAM-2 addendum — make ordinary watching feel effortless

**Direction accepted:** read `spec.md`, `docs/decisions.md`, and `docs/assignments/M0.md` directly from commit `25f0b74db3b0fae8cc29be49cb95d3a179f7b934` using `git show`. TEAM-013 places UI polish, performance, fewer heavy click paths, and exceptionally simple navigation first. Joe likes the current visual direction; a new shell or more features are not prerequisites for improvement. This addendum starts from report commit `7cd3200dd96b0eb12c598a3caa108d3f3d68f24f`; it changes only this report and does not advance the assessed app baseline. No additional runtime tests were run.

### First milestone proposal: remove friction from the existing surfaces

| Friction map, source evidence | Proposed change | Acceptance / dependency |
| --- | --- | --- |
| Select on a guide program opens `JoeTVProgramActionsView`, then Watch channel starts playback. Channel-name buttons already tune directly. (`JoeTVGuideView.body`, `JoeTVGuideGrid.programRow` in `SeasonsTV/Views/JoeTVExperience.swift`.) | For a program airing now, Select tunes directly; its title/synopsis remain above the grid. Future programs retain the information sheet, with any channel action clearly labeled as watching the channel now. | One Select from a focused current-program cell to playback; no tuning on focus; future programs never imply future playback. App + Playback; QA checks missing/expired EPG and the time boundary. |
| Broadcast stage Back focuses the first group; browse return and drawer close have fixed focus destinations (D-F4). | Restore the exact invoking item/control and unwind one layer consistently; define a nearby fallback when that item no longer exists. | Zero corrective refocus presses after a layer closes while its origin remains present. App/Playback; PM allocates shared origin state only if needed. |
| Dense supporting text, focus-edge risk, inconsistent motion, and indirect empty-state instructions (D-F5/F6). | Polish existing typography/spacing, focus gutters, motion, and action wording from QA evidence. Make empty states lead directly to the relevant action. | Readable essential status, complete focus outline, no clipped roster content, and no instructions naming absent controls. Design reviews QA captures; no wholesale palette/layout change. |
| Unavailable sports Select can appear unresponsive (D-F1); slow-feeling navigation has not been timed. | Explain availability primarily in the existing selected-event header; reserve a sheet for useful details after Select. Profile the normal navigation path before changing timing or data work. | Every Select has an understandable outcome; focus stays responsive during loading. D-I1 is supporting polish, not a mandate to add a modal to every sports interaction. App/Services/QA. |

**Before/after example, source-derived counts rather than observed timings:** start with focus on a currently airing guide program. Today: **Select → program sheet → Select “Watch channel” → player**: two Select presses, an intervening sheet, then playback. Proposed: **Select → player**: one Select and no intervening sheet. On return, restore the same program cell and scroll position if still valid. This shortens this specific path by one Select and one surface; it does not claim to improve the already-direct channel-name path or eliminate stream preparation time. A future program still opens details. Validate this pair with fixtures before applying it broadly.

**Responsiveness validation plan, not results:** QA/App should record a baseline and candidate on the same named simulator/device, fixed catalog, cache state, and media/network conditions. Measure input-to-visible-focus response, destination-to-usable-content, Select-to-preparing feedback, and Select-to-first-frame separately; record median/tail latency, press count, focus transitions, and corrective presses. Include navigation while metadata refreshes and a long guide/Sports list. Inspect main-thread work only where measurements identify a stall; preserve cached sports consolidation and nonblocking metadata. The guide's explicit 1.1-second preview dwell (`JoeTVGuideView.schedulePreview`) is intentional source timing, not a measured UI stall or permission to increase provider requests. Set numerical budgets after baseline evidence. Acceptance is the demonstrated shorter path, correct restoration, and no responsiveness regression under matched conditions; this report asserts no measured speed gain.

### Future roadmap explorations, after the polish milestone

| Direction | Smallest useful design experiment | Dependencies and acceptance |
| --- | --- | --- |
| **Left-side primary navigation**, informed by the Plex library pattern Joe likes. | Static remote-flow storyboard for a compact rail that expands when entered, with Home/Live TV/Sports and access to settings. Model entering from each content surface and returning to its last focused item before changing layout code. | App/Design define focus boundaries so Left still traverses guide time and horizontal cards; reaching the navigation boundary must be explicit and predictable. Preserve selected/focused distinction and Back layering. Compare end-to-end presses and wrong destinations against the current top bar, including a return from playback. Advance only if Joe finds it simpler without shrinking key content or adding navigation steps. Medium effort; source feasibility and desirability still unverified. |
| **Curated Home across favorite channels and teams**, including Patriots/Bruins. | Home storyboard with a relevant team game, overlapping games, unavailable coverage, and offseason/no-game states. Keep the current channel-favorites rail; trial a small “Your teams” area or eligible featured game rather than replacing Home wholesale. | Add optional stable league/team preferences; never hard-code Joe's examples as universal defaults. Services validates event/date/source matching through the existing Mac mini → Personal Media API path. Preserve channel visibility/favorites and their saved ordering/choices with additive migration; use D-I1's availability states and 15-minute policy. Offseason falls back to useful channel content without a large empty panel. Acceptance: a matched favorite-team game is discoverable from Home, duplicates are consolidated, ambiguous matches do not claim watchability, and no existing channel choice is lost. Medium effort with identity dependencies; no new live-score architecture implied. |

D-I2's trustworthy Fantasy states and D-I3's optional broadcast memory remain later candidates. Security/reliability review accompanies this roadmap; a confirmed urgent issue can require separate action, but speculative risk or feature expansion should not displace Joe's stated first priority. All stages here remain planning proposals until Joe/PM selects bounded implementation work.
