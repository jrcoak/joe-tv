# SeasonsTV tvOS Redesign Plan

Status: implemented baseline; retained as the pre-implementation decision record and acceptance contract.

Implementation amendment (August 14, 2026): user testing superseded the planned full-grid Live TV Guide. Production EPG data now powers current-program metadata and a compact per-channel Up Next disclosure on the single Live TV browse surface. The historical guide-grid sections below remain as the original decision record, not the current product behavior.

Evidence base: `README.md` and `docs/TECHNICAL_HANDOFF.md` were read completely before code inspection. The full repository, project settings, assets, app state, networking, parsers, playback, views, and smoke tests were then audited. `docs/REDESIGN_WORKING_NOTES.md` preserves the documentation-first synthesis.

## 1. Executive Summary

SeasonsTV is functionally compact and technically coherent, but its interface currently mixes a branded landing-page aesthetic, a table-like unfinished EPG, a card grid, and default tvOS controls without a unified focus or navigation system. Primary actions are technically available but common paths compete with persistent chrome, status copy, and placeholder guide structure. Focus restoration is implicit, asynchronous states are globally blocked, startup failures masquerade as sign-out, and accessibility, localization, image caching, UI tests, and production playback proof remain incomplete.

The redesign will preserve the app's actual product: two authenticated destinations—Live TV first, Sports & Events second—with immediate playback and no invented streaming-library concepts. EPG is now committed near-term scope. The target is a calm, dark, content-first native tvOS experience: a restrained persistent destination bar, a real time-based guide with a fixed channel column and focusable program cells, event browsing grouped by category, unmistakable but stable focus treatment, explicit loading/error/empty states, and native AVKit playback. Until EPG data is available for a channel, a truthful channel-level “Watch channel” fallback occupies the schedule area without fabricating a current program.

Expected outcome: fewer remote movements, truthful now/next discovery, stronger hierarchy at television distance, predictable two-axis guide focus and Back behavior, consistent components/tokens, and EPG integration that cannot break channel playback or expose provider playback contracts.

## 2. Existing Application Architecture

- Platform: one native tvOS target, deployment target 17.0, Swift 5 language mode, SwiftUI with AVKit/AVFoundation.
- Entry: `SeasonsTVApp` creates one `AppModel` and injects it into `RootView`.
- State: `@MainActor ObservableObject AppModel` owns root screen, both catalogs, selected event category, global work/error state, and current `PlaybackSession`.
- Navigation: enum-switched root state; a local `CatalogView.Surface`; item-bound `fullScreenCover` for playback. There is no NavigationStack, route type, deep-link system, or restoration store.
- Networking: one `SeasonsClient` with a default URLSession and shared system cookie store; no cache, retry policy, timeout policy, reachability, or cancellation UI.
- Data: private authenticated Seasons4U HTML/JavaScript/XHR contracts parsed at runtime by narrow regular expressions. Genres are locally inferred.
- Playback: direct/resolved HLS uses AVPlayer; DRM pages produce runtime FairPlay configuration and an AVAsset resource-loader delegate. DRM is rejected in Simulator.
- Persistence: provider cookies only. Credentials, signed URLs, and DRM material remain ephemeral.
- Images: AsyncImage with SF Symbol fallbacks; no explicit decoding/cache layer.
- Dependencies/telemetry: no external packages, backend, persistence framework, analytics, or crash SDK.
- Tests: one standalone parser/payload smoke executable; no XCTest or UI test target.
- Assets/localization/accessibility: two color assets; no app icon/top shelf imagery, string catalog, previews/sample-data infrastructure, accessibility-specific labels, or reduced-motion handling.

Baseline verification on August 12, 2026: parser smoke, static analysis, and unsigned generic tvOS Debug/Release builds passed under Xcode 26.6. The known older FairPlay SPC API warning remains. A later simulator QA pass ran on Apple TV 4K (3rd generation), 1080p, tvOS 26.5 and covered destination/rail focus, hero updates, playback failure, Back, and focus restoration.

### Documentation comparison

Documented and present: login/token handling, cookie restoration, concurrent catalog load, two catalog surfaces, local search/genre filters, three event playback paths, native AVPlayer, runtime FairPlay, simulator guard, local sign-out, global alerts/loading, parser smoke coverage, and no third-party dependencies.

Documented but incomplete: guide/EPG, hardware FairPlay proof, server logout, resilient startup/partial refresh, request policy, accessibility, localization, production branding, caching, UI tests, and release setup.

Implemented but under-documented: a large split-layout marketing login screen; category grid hero/status pill; persistent manual Back button layered over VideoPlayer; all visible copy is hard-coded; screen-local surface/search/filter state disappears if CatalogView is recreated.

Potentially stale or misleading: “Apple TV-specific grid, focus styles” overstates the implementation—cards rely on system `.card`, with no explicit default focus or restoration. “Pull-to-refresh” is technically `.refreshable` on tvOS scroll views but is not an obvious Siri Remote affordance. The UI labels all channels “US IP required,” while the documented contracts include international variants and per-stream restrictions.

## 3. Screen Inventory

| Surface/state | Purpose and entry | Actions/exits | Current state coverage and issues |
|---|---|---|---|
| Session restoration | Initial launch | Automatic success to catalog; any failure to login | Blocking spinner only; no retry, offline, provider-outage, or diagnostic state. Non-auth failures are hidden. |
| Sign in | Invalid/missing session or expiry | Edit email/password, toggle remember, submit | Validation and server errors use global alert. Default email focus exists. No password reset/help, offline state, or explicit privacy explanation. |
| App shell/top bar | Successful load | Switch Live TV/Sports, refresh, sign out | Local destination state; destructive sign-out has no confirmation. Global actions compete with destinations. No focus restoration. |
| Live TV populated | Default catalog surface | Search, genre filter, select channel, refresh | Single vertical list. Every row says Live Now and renders empty timeline columns. No partial/stale state. |
| Live TV filtered | Search or genre active | Change/clear query or genre, play result | Search and genre combine correctly; no explicit clear control or result count. |
| Live TV empty/no match | Empty source or filters | Change filter/query or refresh | One ContentUnavailableView conflates provider-empty and filter-empty. |
| Sports populated | Switch destination | Pick category, play event, refresh | Football plus explicit provider categories; a synthetic Featured category was removed because it could mix 24/7 channels into the event hierarchy. |
| Sports empty/partial | Upstream load variation | Refresh | Generally unreachable because coupled refresh throws before catalog; no explicit screen state. |
| Global working overlay | Login, refresh, stream resolution | Wait only | Blocks all input and always says Loading; no task context, cancellation, or progressive content preservation. |
| Global error alert | Orchestration/provider failure | OK | Generic title, single dismissal, loses action context; focus return unspecified. |
| Simulator FairPlay alert | Select DRM item/channel in Simulator | OK | Correctly avoids black player; global presentation lacks source context. |
| Native player, playing/buffering | Successful session creation | Native play/pause/scrub; Back button or Menu exits | Native VideoPlayer plus always-present custom top row. Buffering is not explicitly surfaced. |
| Player failure | AVPlayer item failure | Return to channels; Menu also exits | Centered overlay; wording may expose technical domain/code to users. Return label is wrong when entered from Sports. |

No implementation exists for onboarding, profile/account selection, account switching, favorites, watchlist/library, recents, continue watching, recommendations, detail/seasons/episodes, subtitle/audio selection owned by the app, next-up/autoplay, settings, destructive library actions, deep links, or navigation restoration. Native player controls may expose stream-supported audio/subtitle behavior, but the app does not model or test it.

## 4. Existing Navigation Map

```text
Launch/checking session
├─ valid cookies + both loads succeed → Catalog / Live TV
└─ auth OR network/parser/provider failure → Sign in

Sign in → both loads succeed → Catalog / Live TV

Catalog
├─ top bar: Live TV ↔ Sports & events
├─ refresh → reload both sources in place
├─ sign out → Sign in
├─ channel/event → blocking resolution → full-screen Player
└─ global alert → dismiss to current/root state

Player
├─ Menu/Back or onscreen Back → dismiss to Catalog
└─ playback failure → Return button → dismiss to Catalog
```

The app has shallow depth, which is appropriate. Problems are state ownership and focus, not excessive route count: destination, query, and genre are local; source focus is not captured before the player; alert/player dismissal has no declared return target; Back from the catalog has no app-level policy.

## 5. User-Flow Inventory

1. First launch with no session: restore attempt → login → enter credentials → load both sources → Live TV.
2. Returning launch with valid session: restore → Live TV.
3. Returning launch during outage/malformed data: restore → misleading login.
4. Invalid/blank credentials: submit → validation/global alert → login.
5. Expired session during refresh/play: operation → login + expiry alert.
6. Live browsing: initial channel → directional row traversal → Select → playback.
7. Channel search: focus search → keyboard/dictation → results update → result → player → return.
8. Genre filtering: All/genre selection → list update → channel → player → return.
9. Filter no-results: empty panel → remote traversal back to filters → revise.
10. Sports browsing: switch destination → category → grid traversal → event → resolve/play → return.
11. Direct HLS, XHR-resolved HLS, and DRM-page events: identical visible selection with different blocking/error paths.
12. Refresh: top action or `.refreshable` → global blocking → both lists replace or error.
13. FairPlay on Simulator: select DRM → alert → return.
14. Playback failure: player overlay → return.
15. Player exit: Menu or onscreen Back → pause → previous catalog surface.
16. Sign out: top action → immediate local cookie/model deletion → login.
17. EPG browsing: absent today; near-term flow requires now/next, horizontal time movement, date/time jump, program details, missing schedule, and guide refresh.
18. App background/resume: no explicit handling; AVPlayer/app state rely on framework behavior.

Absent flows are intentionally not invented for library/personalization, accounts, and episodic playback. EPG flows are part of this redesign contract even though its provider, station mapping, and payload are not yet present in the repository.

## 6. UX Audit

- Live TV's core decision is “which channel?” but roughly half each row visualizes nonexistent schedule data. This is misleading and wastes scan width.
- The Sports hero explains controls rather than surfacing useful content. “Session active” is low-value permanent status.
- Frequent playback should be one Select from a channel/event; this is true, but destination/filter/top actions create a broad focus graph without defined entry points.
- Search, filters, Refresh, and Sign out share similar visual weight. Destructive and maintenance actions distract from browsing.
- Refresh is duplicated by a low-discoverability `.refreshable` gesture.
- All work blocks the entire app, even refreshing existing content. Labels do not distinguish signing in, refreshing, or preparing playback.
- Empty/filter-empty/provider failure/offline/session expiry lack distinct recovery actions.
- Immediate sign-out is risky on a remote and has no confirmation.
- The app invents certainty (“Live Now,” global “US IP required”) not supported by current structured data.
- Player failure says “Return to channels” even when entered from an event.

Remote-efficiency target: initial focus on the first current program (or its channel fallback); direct channel playback in one Select; program details in one Select and playback in a second; destination switch within two upward moves; category-to-first-event in one downward move; contextual refresh/sign-out outside the main browsing traversal. Exact movement counts require device/simulator validation.

## 7. Visual Audit

- Three competing languages coexist: editorial serif marketing, translucent utility bar, and data-table guide.
- Typography uses many one-off sizes (36, 42, 52, 58, 68, 70), tracking values, serif/rounded/monospaced styles without tokens.
- Spacing/radii/opacities are scattered across one 598-line view file.
- Orange-to-gold gradients appear on brand mark, every live cell, and media placeholders, weakening emphasis.
- The channel list is dense horizontally but information-poor; repeated “Watch,” play icon, live dot, genre, timeline rules, and card border overstate each row.
- Sports cards use variable adaptive widths while image quality/aspect ratio is unknown; large padding can make small logos look generic.
- The login screen resembles a web landing page and consumes half the screen with promotional copy.
- Native controls have good platform familiarity, but selected destination/filter state is communicated mainly by tint and may be confused with focus.
- There are no polished skeleton, offline, artwork-failure, or branded empty/error primitives.

## 8. Focus-System Audit

Only login text fields have explicit `FocusState`; email is assigned on appear. All other focus is delegated to SwiftUI geometry and system `.card`/bordered styles. There is no `defaultFocus`, `prefersDefaultFocus`, focus scope/section, focus binding for content IDs, focus restoration after player/alert/async changes, or reduced-motion accommodation.

Risks: launch-to-catalog may choose top navigation rather than content; switching destinations may land unpredictably; filtering can remove the focused row; returning from player may lose the originating item; global overlay/alert dismissal may jump; the custom player Back button may compete with native controls; horizontal filter scrollers nested above vertical lists can create expensive traversal.

Target focus vocabulary:

- Focused content card: 1.06 scale, modest elevation/shadow, brighter artwork/surface, 2–3 pt high-contrast keyline, 160 ms ease-out. Never reflow neighbors.
- Selected filter/destination: persistent filled/contrasting state independent from focus, plus text/icon—not color alone.
- Focused button: native lift/contrast where possible; destructive styling only in context menu/confirmation.
- Initial focus: first playable item when content exists; primary recovery action in empty/error states; email on login; Return on player failure.
- Restoration: remember source item ID per destination; restore it after player/alert and after non-destructive refresh if still present; otherwise nearest surviving item, then first item.
- Async filtering: move focus to first result when the previous item disappears; return to search/filter control for zero results.
- Back: player dismisses; search keyboard dismisses before leaving destination; catalog Back follows system app behavior; confirmation Back cancels.

## 9. Proposed Information Architecture

Existing: authentication → one catalog shell → Live TV guide or Sports category grid → player.

Proposed: authentication → one browse shell → **Live TV Guide** and **Sports & Events** destinations → player. Account/refresh become a compact trailing utility menu, not peer destinations. Live TV combines the Seasons4U playback lineup with an independent EPG domain through an explicit station-mapping layer. It presents a fixed channel identity column, horizontally time-scaled programs, a current-time marker, now/next context, and date/time navigation. Selecting a program opens a lightweight information overlay when metadata is useful; Play Channel remains immediately available. Sports categories use a focused category strip plus a vertical EPG-like event list and stable detail stage, avoiding a second horizontally scrolling content system.

This preserves the documented product priority and shallow architecture while replacing false guide semantics with real schedule data. EPG models and caching remain separate from Seasons4U playback models: a stable local mapping joins `LiveChannel.id/name` to an EPG station identifier, and guide absence or failure falls back to direct channel playback.

### EPG domain and service boundary

- `EPGStation`: provider station ID, display metadata, time zone, and aliases.
- `EPGProgram`: stable ID, station ID, title, start/end instants, synopsis, category, rating, episode metadata, image, and live/new flags only when supplied.
- `ChannelStationMapping`: explicit Seasons4U channel ID/name → EPG station ID, match provenance, and unmapped state. Heuristic matches must never silently become permanent truth.
- `EPGWindow`: absolute start/end range and programs grouped by station. Store time as `Date`; format in the user's locale/time zone while honoring source offsets.
- `EPGClient`/repository: independently fetches, normalizes, validates, caches, and refreshes guide windows. It must not receive playback URLs, Seasons4U cookies, or DRM headers.
- Cache: persist normalized, non-sensitive schedule windows with fetched/expiry timestamps; show stale data with an indicator when refresh fails; prune old windows and prefetch the next bounded window.

## 10. Proposed Navigation Model

- Persistent top destination bar inside the authenticated shell: brand, Live TV, Sports & Events, then a trailing More/account menu.
- Destination state moves into AppModel (or a dedicated lightweight navigation state) so recreation does not reset context.
- Each destination owns restorable focus, filters, and scroll position for the session.
- The guide owns one coordinated two-dimensional focus model: vertical moves preserve clock time across channels; horizontal moves select adjacent programs; moving left from the first visible program reaches the channel Play target.
- Date/time controls support Today/next day and Jump to Now. Returning from program information or playback restores station, program ID, and visible time anchor when still valid.
- Select on playable content resolves and presents the native player full-screen.
- More menu contains Refresh and Sign Out; Sign Out requires confirmation.
- Errors tied to visible content render inline when possible; session-wide/auth errors use an alert or root transition.
- Do not add sidebar, deep navigation, or detail pages until the content model warrants them.

## 11. Design Direction

“Editorial broadcast, native television”: near-black neutral backgrounds; warm gold used sparingly for selected/accent states; white/gray typography; channel logos and event artwork carry identity. Use SF system typography for maximum tvOS legibility, with an optional restrained serif only for a single marketing/empty-state accent—not as a competing application hierarchy. Generous safe-area margins, stable geometry, limited translucent material, and no decorative backdrop unsupported by artwork quality.

## 12. Component System

| Component | Role and states |
|---|---|
| AppDestinationBar | Brand, two destinations, utility menu; focused, selected, disabled/loading. |
| ScreenHeader | Eyebrow, title, concise supporting/result text; fixed hierarchy. |
| FilterChip | All/genre/category; focused vs selected are distinct; disabled if unavailable. |
| GuideChannelCell | Fixed-width channel identity/direct Play target; mapped, unmapped, focused, and image-failure states. |
| ProgramCell | Duration-scaled title/time/badges; focused, current, past, future, missing, and loading states. |
| GuideTimeline | Synchronized time header/program content, current-time marker, and edge prefetch. |
| ProgramInfoOverlay | Progressive metadata plus Play Channel; dismissal restores the program. |
| EventCard | Stable landscape card; artwork/fallback, two-line title, concise availability metadata. |
| ContentRail | Section header + horizontal cards; preserves row focus and scroll. |
| Primary/Secondary/IconButton | Shared control hierarchy and sizing. |
| StatePanel | Empty, error, offline, no-results with one primary recovery action. |
| LoadingSkeleton | Nonblocking content-shaped placeholders for initial/refresh loads. |
| BusyHUD | Only for short blocking sign-in/playback preparation; task-specific label. |
| ConfirmationDialog | Sign-out confirmation with safe default. |
| ArtworkView | Aspect-safe remote image, neutral placeholder, failure symbol, accessibility policy. |
| PlayerFailureOverlay | Context-neutral Return to Browse action and explicit default focus. |

## 13. Design Tokens

- Typography: hero/screen 56 semibold; section 32 semibold; card title 26 semibold; body 24 regular; metadata 20 medium; caption 17 semibold. Use Dynamic Type-compatible semantic styles where tvOS behavior permits and cap line counts intentionally.
- Spacing: 8, 12, 16, 24, 32, 48, 64, 80. Safe content inset: 72 horizontal, 44 vertical minimum.
- Radius: 12 artwork, 18 cards, 24 modal/state panel; capsules only for filters/status with semantic purpose.
- Surfaces: background near-black; raised 6% white; focused 12% white; subtle keyline 10% white; primary text 100%; secondary 68%; tertiary 48%.
- Accent: gold for selected/primary, not every decoration; red only for destructive/error/live data that is actually known.
- Motion: focus 160 ms ease-out; metadata/background 220 ms ease-in-out; modal/navigation 260 ms system-like; reduced motion removes scale and crossfades only.
- Scale: content 1.06; compact controls 1.04; never mix arbitrary focus factors.
- Shadows: focused only, low radius/opacity; no persistent glow.

## 14. Screen-by-Screen Redesign

### Session restoration

Purpose: establish session without ambiguity. Centered compact brand and “Checking your membership…” status. On authentication failure, transition to login. On network/provider/parser failure, retain a dedicated retry state with Sign In as secondary only when useful. Default focus Retry. No indefinite spinner; surface timeout/recovery. VoiceOver announces state changes.

### Sign in

Purpose: authenticate. Reduce promotional half-screen; use a centered, readable panel with brand, concise membership explanation, email, password, remember toggle, and primary Sign In. Add short privacy copy that password is not stored. Default focus email; submit from password; errors attach to the form while preserving entered email and returning focus to the relevant control. Offline/server error offers Retry. Back dismisses keyboard before normal system behavior.

### Live TV

Purpose: understand what is on and play a channel quickly. Header: “Live TV,” local date/time, search, genre filters, Today/date navigation, and Jump to Now. A fixed channel column aligns with a horizontally scrollable, time-scaled program grid and synchronized timeline. Initial focus is the current program for the first/restored channel; when unmapped or missing, it is the channel's direct Watch target. Select on a program opens a compact information overlay with Play Channel; selecting the channel cell plays immediately. Horizontal focus advances by programs, vertical focus preserves the same time coordinate, and edge navigation prefetches bounded windows without losing focus. Search/filter state persists through playback.

Initial lineup and EPG loads use aligned skeletons. An unmapped channel shows “Schedule unavailable” plus Watch Channel. An isolated EPG error leaves the lineup playable and may show cached schedule marked “Updated earlier.” No-results offers Clear filters; lineup failure offers Refresh; a schedule gap never claims “Live Now.” Long programs cap visual width while exact time/details remain accessible in the overlay.

### Sports & Events

Purpose: find and play a current event/source. Remove instructional hero and session badge. Header plus category strip; selected category and count. Use a vertically scrolling EPG-style event list on the left and a spatially stable event stage on the right. Select on a row plays the recommended compatible feed; Right exposes Play Best Feed and a collapsed, bounded Other Feeds list. Home/Away and other published variants remain available without multiplying event rows. First playable event is default focus. Missing images use category-specific neutral artwork. Empty category is explicit; partial catalog remains usable.

### Working and errors

Sign-in and stream preparation may use blocking BusyHUD with “Signing in…” or “Preparing [title]…”. Refresh becomes nonblocking with toolbar progress and preserves content. Inline StatePanel owns destination errors. Global alerts are reserved for session expiry and Simulator FairPlay explanation. Focus returns to origin after dismissal.

### Player

Purpose: uninterrupted native playback. Retain VideoPlayer/native controls. Remove persistent custom top Back row; Menu is the primary exit convention. If a visible title/back overlay is required, it should auto-hide with native controls and never compete for initial focus. Explicit initial buffering indicator is allowed only until AVPlayer reports readiness. Failure overlay uses “Return to Browse,” pauses, and restores the originating card. Supported native audio/subtitle controls remain AVKit-owned. No autoplay/next-up UI without episodic data.

## 15. Flow-by-Flow Redesign

| Flow | Existing problem | Proposed flow, focus, Back, edge behavior |
|---|---|---|
| Restore | All failures become login | Check → catalog on success; auth → login/email focus; connectivity/provider/parser → recovery/Retry focus. Back follows system. |
| Sign in | Global generic errors | Form → task-specific HUD → catalog/first channel; invalid fields return focus to field; server/offline inline Retry. |
| Live play | Undefined initial/return focus | First/restored channel target → Select → preparing HUD → player → Menu → same target. Failure before player returns to the source with inline/toast feedback. |
| Guide browse | Placeholder only | Current/restored program → Left/Right adjacent program; Up/Down same clock time on adjacent channel → Select details → Play Channel → player → return to program. Timeline scrolls only enough to reveal focus. |
| Guide date/time | Not implemented | Jump to Now restores current-time anchor; date control loads a bounded window; Back cancels; crossing window edges prefetches without blocking visible guide. |
| Missing/stale EPG | Claims Live Now | Unmapped/gap/error state says schedule unavailable; direct Watch remains. Cached schedules show freshness; Retry affects only EPG. |
| Search | Zero-result focus unspecified | Search → dictate/type → live stable results → first result when prior focus disappears; zero results focuses Clear Search. Player return preserves query and card. |
| Genre | Horizontal chips + vertical list | Chip → result grid; Down enters first/restored card; Up returns selected chip; zero result offers Clear Filters. |
| Sports play | Hero adds traversal | Destination → selected category → first/restored event → player → same event. Three playback mechanisms stay visually identical. |
| Refresh | Blocks and couples all UI | Utility Refresh → per-destination progress; update successful sources independently in future state refactor; retain stale source plus inline error for failed source. Focus stays on item ID. |
| Session expiry | Root changes plus alert | Pause/clear playback → login with expiry message; email focus after message dismissal. Do not label provider outage as expiry. |
| Simulator DRM | Generic alert | Source selection → explanatory alert → OK → exact source focus. No DRM request. |
| Playback error | Wrong return label | Failure overlay/Return to Browse focus → pause/dismiss → exact source card. Menu has same result. |
| Sign out | Immediate destructive action | More → Sign Out → confirmation with Cancel default → local clear → login. Remote Back cancels. Document remote logout limitation. |
| Background/resume | Undefined | Pause/continue according to native AVPlayer lifecycle policy; preserve browse and player route; revalidate only when a new authenticated request fails. Hardware QA required. |

## 16. State Coverage

- Loading: separate restoration, sign-in, lineup, EPG window, guide-edge prefetch, events, refresh, artwork, stream-preparation, buffering, and DRM-key states.
- Empty: no channels/account catalog, no events/category, no search results, no genre results.
- Error: validation, credentials, session expiry, offline/network, provider HTTP, malformed parser response, entitlement, blackout, unavailable stream, incompatible FairPlay, Simulator-only, player failure, image failure.
- Success: loaded/stale-loaded content, signed in, filter results, player presented.
- Partial: channels loaded/events failed and inverse; lineup loaded/EPG failed; mapped/unmapped channels; complete/gapped schedule windows. These require independent load states.
- Missing data: no logo/image, empty subtitle, long/malformed title, unknown genre fallback; never invent schedule or restriction facts.

## 17. Accessibility Strategy

- Use semantic combined labels for cards: channel/event name, genre/availability, and “Play.” Decorative images are hidden; meaningful artwork has concise labels.
- Distinguish focus, selection, live/error, and destructive states with shape/text/icon as well as color.
- Ensure focus order follows visual order and state changes are announced.
- Honor Reduce Motion by removing scale/parallax and using short opacity changes.
- Maintain high contrast and minimum readable sizes at ten feet; test long strings and VoiceOver rotor/navigation.
- Add accessibility identifiers for UI automation and localized string infrastructure before broad localization.

## 18. Performance Strategy

- Keep Lazy grids/stacks and stable IDs; avoid rebuilding all content from focus changes.
- Virtualize guide rows and render only a bounded visible/prefetched time window. Derive geometry once per window and synchronize one timeline offset rather than nesting independent horizontal scroll positions.
- Cache normalized EPG windows separately with expiry, coalesce overlapping requests, prefetch at edges, prune history, and refresh on foreground only when stale.
- Introduce image request caching/downsampling only after measuring; define bounded memory/disk budgets and never cache signed media URLs.
- Size remote logos to rendered dimensions; avoid using low-resolution images as heroes.
- Limit blur/material to navigation and modal surfaces; avoid animated full-screen backgrounds.
- Decouple refresh and publish state changes once per source to reduce churn.
- Cancel superseded search/play/refresh work where safe; prevent duplicate playback preparation.
- Profile scrolling and memory on physical Apple TV, especially 87+ logos and long sessions.

## 19. Technical Refactoring Requirements

Required: split the monolithic RootView file into design tokens, shared components, authenticated shell, Live TV Guide, Sports, login, and state views; model destination, lineup, EPG, and event load states independently; introduce EPG domain/repository protocols and explicit station mapping; add program/channel focus IDs plus time-anchor context; centralize task labels and styling; make refresh results independent; add sign-out confirmation; generalize player return semantics.

Recommended but staged: protocol-backed client for previews/tests; sample fixtures and SwiftUI previews; XCTest/UI targets; image pipeline; localization catalog; modern AVContentKeySession investigation. Do not rewrite parser/network/FairPlay contracts merely for architectural symmetry.

## 20. Implementation Phases

A. Foundations: tokens, shared buttons/chips/artwork/cards/state panels, sample data/previews.

B. State and navigation: destination state, explicit source load states, task context, restoration IDs, utility menu, sign-out confirmation.

C. Live TV guide foundation: EPG models/service protocol, station mapping, cache/window policy, synchronized timeline geometry, guide/program components, missing-data fallback.

D. Live TV guide integration: provider adapter when its contract is available, now/date navigation, program overlay, search/filter recovery, and two-axis focus tuning.

E. Sports & Events: remove instructional hero, consistent category/card layout, focus/empty states.

F. Authentication and resilience: compact login, privacy copy, restoration recovery, partial refresh and inline errors.

G. Playback: native-control cleanup, return context, buffering/failure focus, lifecycle verification. FairPlay contract changes remain separate and hardware-gated.

H. Quality: accessibility/localization identifiers, image performance, XCTest/UI coverage, simulator and hardware remote QA.

I. Release polish: app icon/top shelf/privacy/distribution only after authorization and hardware playback proof.

## 21. Dependency Order

```text
Documented invariants
→ design tokens → base controls/artwork/state panels → channel/event cards
→ EPG models/protocol → station mapping → window geometry/cache
→ app navigation state → authenticated shell → destination/time focus restoration
→ Live TV Guide → Sports & Events
→ explicit source load states → resilient restore/refresh/error UI
→ playback return context → player polish
→ accessibility/performance instrumentation → full flow QA → release assets
```

## 22. Risk Register

| Risk | Level | Mitigation |
|---|---|---|
| FairPlay hardware regression/unproven baseline | High | Do not alter key contract during visual work; signed-device matrix before release. |
| Focus loss after filter/refresh/player | High | Stable IDs, explicit focus bindings/scopes, automated identifiers, remote QA each phase. |
| Provider parser/contract changes | High | Preserve security guards; add sanitized fixtures/XCTest before parser changes. |
| Incorrect channel-to-station mapping | High | Reviewed explicit mapping with provenance and unmapped fallback; never fuzzy-play a different channel. |
| Time-zone/DST/program-boundary errors | High | Absolute dates, injected clock, source-offset and DST fixtures, locale formatting tests. |
| Guide focus/scroll desynchronization | High | One time coordinate and synchronized offset; bounded virtualization; remote QA. |
| EPG outage/stale data | Medium | Independent repository/cache state, freshness label, and channel playback fallback. |
| Startup/partial-state refactor changes auth semantics | High | Separate auth from source errors; unit-test transitions and cookie behavior. |
| Image memory/scrolling | Medium | Fixed render sizes, lazy containers, measured caching/downsampling, device profiling. |
| Native player chrome conflict | Medium | Prefer AVKit; minimize custom overlays and test Menu/control interactions. |
| Long/localized strings | Medium | Tokenized layouts, line limits, pseudolocalization/manual fixtures. |
| Sign-out confirmation focus | Low | Native confirmation and Cancel default; UI test. |

## 23. Regression Risks and Invariants

Must not change unintentionally: anti-forgery login; passwords never persisted; cookie restoration/local deletion; JavaScript parsed only as data; UUID/path validation; catalog mappings/deduplication; direct/resolved/DRM playback selection; signed URLs and DRM secrets remain memory-only/redacted; simulator blocks FairPlay; native HLS/FPS behavior; session-expiry handling; provider entitlement/geo/blackout enforcement; EPG/playback separation.

Visual changes are layout, hierarchy, styling, and focus. Intentional behavioral changes are sign-out confirmation, real EPG integration with truthful missing-data fallbacks, program-information disclosure, explicit restoration/failure states, and independent source refresh. Anything else is a regression unless separately approved and tested.

## 24. Redesign Matrix

| Existing surface | Problem | Proposed surface | UX/visual change | Engineering impact | Risk |
|---|---|---|---|---|---|
| Launch spinner | Failures look signed-out | Session recovery | Truthful retry/error | Load-state model | High |
| Split login | Web-marketing density | Centered native form | Less copy, clearer privacy/errors | View extraction | Low |
| Top bar | Equal-weight utilities | Destination bar + More | Content-first traversal | Navigation state/menu | Medium |
| Guide table | Fake EPG/wasted space | Real time-based guide | Now/next discovery plus direct play | EPG domain, mapping, cache, 2-D focus | High |
| Search/filter | No clear/recovery | Persistent filters + results | Explicit Clear/result count | Focus logic | High |
| Sports hero/grid | Instructional chrome | Header/category/content | Earlier content, shared cards | View/component refactor | Medium |
| MediaCard | One-off styling | EventCard | Stable aspect/focus/fallback | Shared component | Low |
| LiveChannelRow | Repeated decorative chrome | GuideChannelCell + ProgramCell | Channel identity, real schedule, direct play | Shared components and focus mapping | High |
| Working overlay | Generic/global | Task HUD + inline refresh | Context and preserved content | Task/source states | Medium |
| Global alert | Context loss | Inline state/session alert | Better recovery/focus | Error routing | High |
| Player header | Competes with AVKit | Native player-first | Auto-hidden/minimal overlay | Player cleanup | Medium |
| Player error | Wrong destination wording | PlayerFailureOverlay | Return to Browse/restoration | Playback context | Medium |
| Scattered constants | Inconsistency | Design tokens | Coherent system | Foundation files | Low |

## 25. Acceptance Criteria

- Both documented destinations and all three event playback paths remain available.
- Initial and restored focus are deterministic on every state; no traps/disappearance after filtering, refresh, alerts, or player dismissal.
- Live playback is one Select from a focused content item; Back/Menu behavior is consistent.
- The UI makes no unsupported EPG, live-status, or geographic assertion.
- EPG programs align to correct channels and absolute times across time zones/DST; unmapped channels and gaps remain directly playable.
- Guide Left/Right, Up/Down, Jump to Now, date/window edges, program overlay, playback return, cached/stale, and EPG-outage flows preserve predictable focus.
- Search/filter state and source focus survive playback; empty and error states have direct recovery.
- Sign-out is confirmed and still clears only local provider session state unless a remote endpoint is intentionally added.
- Typography, spacing, radii, focus scale, controls, cards, artwork, loading, empty, and errors use shared tokens/components.
- VoiceOver labels/order, contrast, non-color state cues, and Reduce Motion are validated.
- 1080p/4K safe areas, long titles, missing images/metadata, and localization expansion are verified.
- Parser smoke and unsigned device build pass after each phase; UI flows pass in Simulator; ordinary HLS and domestic/international FPS pass on signed hardware.
- Scrolling remains smooth and memory stable across the full live lineup and long playback.

## 26. Open Questions and Assumptions

- Physical Apple TV and authorized live account access are required to validate focus with real data and all playback paths; current interaction findings are code-derived.
- EPG is committed near-term scope. The provider, authentication, schema, cadence, rate limits, attribution/licensing, and sample payload remain open; begin behind a provider-agnostic protocol/fixtures and add the adapter when supplied.
- Confirm who owns the authoritative channel-station mapping and how lineup changes will be reviewed.
- Confirm whether “Remember me” changes provider cookie lifetime reliably; the UI should not promise more than the server provides.
- Confirm whether the provider has a supported logout endpoint before adding remote revocation.
- Confirm whether any channels genuinely require US IP globally; current blanket UI claim should be removed pending structured truth.
- Confirm preferred production brand assets and legal naming before app icon/top-shelf work.
- Assume no detail pages, favorites, profiles, or recommendations should be invented without new data/product scope.

## 27. Pre-Implementation Review

All discovered screens, meaningful states, routes, playback mechanisms, authentication paths, missing features, accessibility/performance concerns, destructive action, long/missing data, and documentation discrepancies are covered. The proposal keeps navigation shallow, does not create redundant detail/home/library concepts, and separates visual work from state resilience and DRM risk. The largest unresolved validation gaps—real-device focus and FairPlay—are explicit release gates, not assumptions.

Implementation may now begin with Phase A foundations, followed by the authenticated shell and Live TV. Each phase must remain buildable and re-run parser/build verification. Final QA must replay every flow in Section 5 and compare every reusable pattern in the redesign matrix before completion.
