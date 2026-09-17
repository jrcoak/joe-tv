# S1-DESIGN — watching and returning

## Scope and evidence

TEAM-4 accepted. Source reviewed at **22f0fdf51b9b105bfb5b34cf5ecc2bb6e72a1340**, on new branch `codex/joe-tv-design-s1` in the existing Design worktree. Clean status and branch absence were verified before creation; completed `codex/joe-tv-design` is preserved. This assignment changes only this report. App and Playback implement; QA exclusively owns runtime verification.

The criteria below implement [S1](../assignments/S1.md), using [R1 conclusions 1, 2 and 6](../research/streaming-discovery.md) and the [evaluation method](../research/evaluation-method.md). Source locations refer to this baseline, not later integrated code. No simulator, build, provider session, new competitor survey or timing measurement was performed by Design. Historical [QA-1/QA-2](../assessments/qa.md) remain QA observations, not newly reproduced results.

## Current program versus details

Evaluate the program against the clock **when Select is handled**. Existing `EPGProgram.contains` (`Models/Models.swift:1052`) already defines `start <= now && now < end`; no model change is needed for that contract.

| Selected target | Required result | Copy/focus acceptance |
| --- | --- | --- |
| Current program | Tune its channel directly, without the program sheet. | One Select from the focused cell commits playback. Preserve that cell as the browse origin. |
| Future program | Open existing program details; do not tune automatically. | Show the selected title and scheduled date/time. Primary action: **Watch channel now**. Supporting text: **Plays what is on this channel now.** Secondary action: **Close**. |
| Expired program | Retain details, without implying replay/start-over availability. | Use the same channel-now action and explanation. Keep the selected program's actual date/time; do not relabel it as current. |
| Channel name / channel action | Preserve existing direct tune. | Restore the channel target after playback. |

At exactly the start, direct tune applies; at exactly the end, details apply. A cell left focused across a boundary must use the new time, irrespective of cached highlights. The details action always tunes the channel's present output, even if the selected program's status changes while the sheet is open. Do not add recording, reminder or replay branches.

Retain existing initial focus on the sheet's watch action. Close/Back restores the selected guide cell and viewport without starting playback. Capture its browse origin before dismissing the sheet for Watch; the sheet button itself is not the browse return target. Focus alone may update metadata and the existing muted preview; it must not start full-screen playback. Preserve preview cancellation on activation and its intentional dwell.

Update the guide hint at `JoeTVExperience.swift:440`, which currently says Select opens the program. Suggested replacement: **Select a current program or channel to watch live. Other programs open details.** Any missing-synopsis fallback must avoid describing a future/expired selection as live. Keep baseball Home/Away/National and other explicit sports feed choices unchanged.

**Comparison decision — adapt:** R1's Disney Live Guide evidence documents program options/availability; Plex documents contextual details versus direct resumption. Neither establishes a universal one-Select live-guide rule. Joe-TV's known-channel watching task justifies this conditional direct action. The source-derived reduction is two activations to one from an already focused current cell; full journey improvement remains unmeasured.

## Empty Home → Choose Favorites → Home

Replace the passive empty rail (`JoeTVExperience.swift:165–168`) with neutral copy that also works when saved favorites are disabled:

- Title: **Your favorites appear here**
- Supporting text: **Choose channels for quick access on Home.**
- Action: **Choose Favorites**

Use the existing Channels sheet opened by `CatalogView.showsChannelSettings` (`RootView.swift`), retaining separate enabled/favorite controls and immediate preference behavior. Opening or closing it must not enable channels, clear saved favorites or change unrelated settings. Do not create a second favorites editor.

Down from the hero must reach Choose Favorites when the rail is empty; Up returns to the hero. Give the CTA a stable focus identity and the existing action-button treatment (18-point label, 64-point minimum height) rather than a small text link. Preserve current hero actions.

The sheet must receive visible, usable focus, and its channel/favorite controls must be reachable. Reuse existing sheet entry behavior for S1; QA should record the initial target and complete input count. An optimized favorite-control entry target can be a later refinement if evidence shows unnecessary travel.

On Done or Back: if no enabled favorite is visible, restore Choose Favorites; otherwise focus the first visible favorite in the existing displayed order and reveal it in the rail. Never target the removed CTA. A disabled favorite remains saved but does not become visible merely because this route was used. An empty catalog must still allow Done/Back and return to the CTA without a trap. Reopening Channels through More retains the ordinary settings route and behavior.

**Comparison decision — preserve/adapt:** R1's Disney Watchlist/Plex Watchlist comparisons support keeping a saved preference distinct from availability; they do not prove this settings route. The direct action addresses Joe-TV's own passive empty state without adding a destination or changing preference semantics.

## Playback origin and Back

App should distinguish ordinary destination entry from return after playback. Baseline Home `restoreFocus` goes to the hero (`JoeTVExperience.swift:258`), guide to a filter (`:494`), and Sports to scope (`:1461`); those defaults must not overwrite a valid playback origin.

Capture stable destination, initiating item/control, filter/scope, and enough row/time/scroll context to reveal it **before playback or a transient sheet dismissal loses it**. Restore once after the browse content is available, without later asynchronous entry requests pulling focus elsewhere.

| Origin | After playback is dismissed with Back |
| --- | --- |
| Home favorite / hero Watch live | Restore that favorite / hero control, preserving rail position. |
| Guide current program / channel | Restore the selected program / channel in the same filtered guide and visible viewport. |
| Guide details → Watch channel now | Restore the program that opened details, not the sheet or filter. |
| Sports card → explicit feed → playback | Restore the initiating event in the same scope/filter and position. Feed cancellation returns to the event without playback. |

A still-present originating program remains the target even if it has since expired. If absent, prefer the same visible channel row in the guide; otherwise choose the nearest surviving visible item by prior displayed position, then the first visible item. If the filtered result is empty, use that screen's existing empty-state action. Preserve filters rather than broadening the result to manufacture a target. Home/Sports use the same nearest-visible-item principle; Home's empty fallback is Choose Favorites. Focus must be on screen and valid after catalog/preference changes.

Quick Switch changes the playing stream, not the saved browse origin. Conversely, the player's explicit **Guide** command is an intentional destination change and must retain its existing behavior instead of being overridden by Back restoration. Avoid consuming a bookmark in a way that breaks repeated watch/return journeys.

Playback's focused Fantasy scorebug must call the existing `handleBack` path (`PlayerScreen.swift:895`): drawer → controls, controls → hidden chrome, hidden chrome → browse. Quick Switch → controls remains one layer. Preserve repeated-input protection and browse-event suppression; do not compensate with new Design-specified timers. Deliberately spaced Back presses should progress through layers; repeated delivery of one press must not skip them or escape the app.

**Comparison decision — preserve:** Plex's documented remembered tab supports continuity, but does not prove exact item restoration. This is Joe-TV's accepted Back contract and a response to historical QA evidence; competitor internal focus implementation is unavailable.

## Small next-cycle polish candidates

These are source-backed review candidates, **not additional S1 implementation requirements or reproduced visual failures**. App owns the listed surfaces; PM should choose a bounded follow-up after QA captures. R1 conclusion 6 supports readability/accessibility review, but no competitor source supplies universal tvOS font or spacing values.

| Candidate and baseline evidence | Small possible change | Required QA evidence |
| --- | --- | --- |
| Favorite star uses `focusVolt` whenever saved (`RootView.swift:504`), conflating persistent state with the adopted focus color. | Keep filled-star/name/value semantics; use an existing non-focus color for saved state. No shared-token edits. | Channels sheet with saved and unsaved stars, each focused and unfocused; verify state remains understandable without color. |
| Guide preview is 218 points high inside a 190-point selection header (`JoeTVExperience.swift:326,454`). | Reconcile local header/preview geometry if captures show collision or cramped spacing. | Full guide with long title, synopsis, preview and focused first-row/filter edges. Source mismatch alone does not prove overlap. |
| Details title is 46-point serif without a line limit in a fixed 960×530 sheet (`JoeTVProgramActionsView`, `:2046`). Added channel-now explanation increases content pressure. | Adjust local wrapping/spacing or sheet sizing only if needed to keep title, time and both actions visible. | Long title, four-line synopsis, missing synopsis, future and expired dates; focused action outline visible. Any clipping introduced by S1 copy is an S1 regression to fix. |
| Guide/row button styles animate focus unconditionally (`:3116,3132`), while neighboring action/card styles honor Reduce Motion. | Apply the existing local Reduce Motion convention to those styles in a scoped follow-up. | Paired traversal with Reduce Motion off/on; focus remains obvious and stable. No claim of device accessibility certification. |

## QA handoff and checks

Use the exact integrated candidate and controlled fixtures. Capture before/after focused targets and count directional, Select and Back inputs separately for: Home favorite; two distinct guide origins; current/future/expired and boundary-crossing selection; details cancellation; empty Home with no change, a new favorite and only disabled favorites; Sports feed selection/cancellation; removed-origin fallback; Quick Switch then return; explicit player Guide; Fantasy drawer/scorebug with repeated and spaced Back. Include two consecutive watch/return cycles and preference persistence.

For touched surfaces, verify unclipped focus outlines, long text, meaningful accessibility names/states and Reduce Motion. Do not substitute screenshot-tool duration for input latency. Empty-player fixtures can establish navigation and identity, not media startup, FairPlay or physical Siri Remote behavior. Those remain pending appropriate hardware/media evidence.

Design checks: baseline/branch/status verified; governing TEAM-4/S1 and existing research reviewed; active source symbols and program time predicate inspected; report whitespace and changed-path checks performed before handoff. No application files, shared tokens, tests or runtime resources changed. PM receives the full Git-verified report commit separately for integration.
