# R1-DESIGN — Streaming discovery patterns for Joe-TV

**Recommendation:** improve the current watching path and context restoration first. Explore left navigation and favorite-team Home afterward, using the same measurable journeys. Netflix, Disney+, and Plex document useful patterns; their size or visual finish does not establish that copying their layouts would make Joe-TV faster or easier.

## Scope and evidence

- Assignment: R1-DESIGN, research only; **TEAM-3 accepted** after reading `spec.md` and `docs/assignments/R1.md` via `git show 1404c9d`. This records the existing research scope and preserves TEAM-2 / TEAM-013 product priorities previously read at `25f0b74db3b0fae8cc29be49cb95d3a179f7b934`. All improvements remain future-sprint proposals; existing M0 reports remain unchanged evidence.
- Task: `01a0ad34-9969-7ce1-9a82-a53fe7b979e9`; branch: `codex/joe-tv-design`; worktree: `/Users/joecoakley/.codex/worktrees/3770/SeasonsTV`.
- Starting HEAD: `49b8912f4ef3d9fce58bbaa08b9dffa801ade6a7`. Earlier M0 report commits are preserved. Joe-TV source baseline remains `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8` plus bootstrap `314968dc10f0bd73451ed6b0876a7fc7ed5c5233`; no claim about later integrated app changes.
- Research accessed **2026-09-17 UTC** (2026-09-16 evening in America/New_York). Dates below are publisher-displayed dates where available, not search-engine crawl dates.
- **J — source observation:** Joe-TV code inspected, including the active routes rather than dormant legacy views. **C — documented competitor behavior:** official descriptions, with platform limits. **H — hypothesis:** likely viewer effect, requiring QA/user validation. **P — proposal:** future-sprint adaptation, not accepted implementation.

No hands-on competitor tests, logins, installs, streams, simulator sessions, latency measurements, or accessibility certification were performed. Marketing claims such as “simpler” or “responsive” are not measured usability or performance evidence. TV-wide documentation does not prove Apple TV parity, an exact remote sequence, or universal rollout. Netflix's responsive recommendations concern recommendation changes, not input latency.

## Ten official sources retained

All links below were researched on the access date above. Netflix pages were readable directly. Plex direct opens returned 403; substantive official text was available in search-index results. Disney direct opens returned empty text or errors; official indexed article text supplied the evidence. This reduces confidence in freshness compared with an observed installed version. The Disney live-guide URL has an `es-UY` path while the indexed page presents English text and a US Help Center title; treat it as that retrieved document, not proof of Uruguay availability.

| ID / direct source | Visible publication/update date | Platform/device scope and limitation |
| --- | --- | --- |
| [N1 — Netflix TV redesign][N1] | May 7, 2025 | TV/TV-streaming-device announcement; rollout beginning May 19, with device eligibility expanding. Documents top navigation, a personal hub and browsing metadata. Does not identify a tested Apple TV version. |
| [N2 — Netflix preview autoplay][N2] | No publication/update date visible | Profile control through mobile/web; some TVs/streaming devices lack previews. No TV-side settings route or exact Apple TV support promise supplied. |
| [N3 — Netflix accessibility][N3] | No publication/update date visible | Cross-platform help: screen readers and captions; app-font-size control is specifically mobile. Do not transfer that font setting to tvOS. |
| [D1 — Navigating Disney+, UK help][D1] | December 4, 2025 | Explicit TV-connected-device sidebar instructions; Home hubs and discovery. UK version avoids treating US subscription hubs as globally identical; no installed Apple TV version given. |
| [D2 — Disney+ Watchlist][D2] | April 28, 2026 | UK help distinguishes TV, web and mobile entry points. Saved titles are distinct from unfinished viewing; reordering/grouping is documented as unavailable. |
| [D3 — Disney+ caption formatting][D3] | August 5, 2024 | Explicit Apple TV section points to device caption styling. Older menu wording may differ on newer tvOS. Does not establish browse-text scaling or screen-reader quality. |
| [D4 — Disney+ Live Guide][D4] | August 26, 2026 | Documents Live hub → Browse/Guide, program options and availability indicators; claims supported-device access. Recent indexed help, not independent rollout or Apple TV verification; locale caveat above applies. |
| [P1 — Plex big-screen navigation][P1] | Last modified September 17, 2025 | Explicitly includes Apple TV. Sidebar/source navigation and Home rows; guide mini-player is qualified as available on supported platforms, not specifically guaranteed on Apple TV. |
| [P2 — Plex Apple TV settings][P2] | Last modified September 13, 2024 | Explicit Apple TV settings: remembered source tab, optional theme music, appearance and subtitle sizes. Some player features require Plex Pass; version parity not tested. |
| [P3 — Plex Universal Watchlist][P3] | Last modified July 9, 2025 | Explicitly includes Apple TV. Saved movies/shows lead to availability details; personal-library matching requires supported metadata agents. Not a live-event/team-following feature. |

## Compare journeys, not feature totals

**J baseline map:** `SeasonsTV/Views/RootView.swift` → `CatalogView.destinationBar`, `destinationButton`, `requestContentFocus`; `SeasonsTV/Views/JoeTVExperience.swift` → `JoeTVHomeView.heroCopy`, `nowAndNext`, `featuredChannel`; `JoeTVGuideView.body`, `restoreFocus`, `schedulePreview`; `JoeTVSportsView.sportsSelectionHeader`, `sportsPreview`, `activate`, `restoreFocus`. Player references: `SeasonsTV/Views/PlayerScreen.swift` → `PlayerSessionView.playerControls`, `handleBack`, `quickSwitchGroup`. Persistence/history: `SeasonsTV/App/AppModel.swift` → `favoriteLiveChannels`, `quickSwitchEntries`; `SeasonsTV/Models/Models.swift` → `PlaybackHistoryPolicy`, `MediaItem.sportsPlaybackAvailable`. Detailed source findings remain in `docs/assessments/design.md`.

| Viewer journey | Joe-TV — J | Netflix — C | Disney+ — C | Plex — C |
| --- | --- | --- | --- | --- |
| Leave browsing for another destination, then return | Three top destinations; content entry requests often focus hero/filter/scope. Exact runtime return focus is unverified. | Redesign puts destination shortcuts at the top. No documented item-level return-focus guarantee here. [N1][N1] | On TV, Left or remote Back opens the sidebar. Home additionally has hubs. Do not collapse these into one navigation level. [D1][D1] | Left-edge sidebar selects a source; its view can remember the prior tab. Item-level restoration is not established. [P1][P1], [P2][P2] |
| Arrive unsure what to watch | Favorite-channel hero and rail; Sports owns event discovery. | Browsing surfaces title context and changing recommendations; personal hub gathers saved/unfinished interests. [N1][N1] | Home offers personalized discovery and routes to familiar content. [D1][D1] | Home mixes resumption, recent additions and current live programming. [P1][P1] |
| Choose something already known | Favorite/channel-name Select tunes; program-cell Select opens a sheet, then Watch; available sports may open broadcast choice. | Up-front title information supports deciding before play; this source does not establish exact Select counts. [N1][N1] | Live hub → Guide → program options provides a route to details and saving. Availability is represented in the guide. [D4][D4] | Settings distinguish details-page Resume from starting directly via Continue Watching. Guide channel selection returns to full screen in the supported mini-player flow. [P2][P2], [P1][P1] |
| Save an interest and find it later | Channel favorites differ from enabled channels; recent streams are a separate, deduplicated Quick Switch history. No favorite-team preference in this assessed path. | Personal hub includes My List and Continue Watching as distinct collections. [N1][N1] | Title page → plus control → Watchlist; unfinished viewing remains separate. [D2][D2] | Details or TV-grid long press → add title; Watchlist → availability/details. It is not a promise that saved content is playable. [P3][P3] |
| Browse without unwanted audiovisual changes | Guide starts a muted preview after 1.1-second dwell; Sports preview is artwork. | Preview autoplay can be disabled per profile through documented mobile/web controls. [N2][N2] | Selected navigation sources do not establish a TV preview-disable setting. No assumption made. | Apple TV can disable show theme music; this is not evidence of a video-preview switch. [P2][P2] |
| Read status or use captions | Some supporting text is 8–12 points; Captions button is absent while tracks are empty. Couch legibility and assistive navigation remain untested. | Help documents screen readers and caption styling, not tvOS browse-text enlargement. [N3][N3] | Apple TV caption appearance is configured through device settings. [D3][D3] | Apple TV help exposes subtitle-size presets. [P2][P2] |

## Six conclusions for future sprints

### 1. Make familiar live viewing direct; keep details where they resolve uncertainty

**Problem/J:** the current guide-program route repeats information already above the grid: Select → program sheet → Watch Select → player (`JoeTVGuideView.body`, `JoeTVProgramActionsView`). Channel-name buttons already avoid this step. Unavailable Sports entries can return without visible action in `JoeTVSportsView.activate`.

**Evidence/inference:** Netflix's up-front metadata and Plex's differentiated resume routes support separating decision support from execution. Disney's program-options route remains useful when further information matters. None proves Joe-TV must mimic its exact actions. [N1][N1], [P2][P2], [D4][D4]

**P — adapt/preserve:** one Select should tune a currently airing guide program; preserve future-program details, explicit baseball feeds and the 15-minute gate. Explain schedule-only/unavailable sports in the selected header, with useful details on Select. Do not invent rights or blackout reasons Joe-TV cannot determine.

**Smallest validation/dependency:** App/Playback prototype current/future/expired/no-source fixtures; Services confirms availability semantics; QA compares two source-derived Select presses with the proposed one. Accept only with no focus-triggered tune, no misleading future playback, and preserved origin focus. Confidence high in source friction, medium in usability benefit; small-to-medium scope.

### 2. Borrow navigation predictability before choosing a sidebar

**Problem/J:** Joe's requested left navigation could simplify destination access, but horizontal guide time and card rails already consume Left. `restoreFocus` methods and nested broadcast Back currently assign fixed targets (M0 D-F4); runtime consequences still need QA.

**Evidence/inference:** TV products disagree about placement: Netflix documents top navigation; Disney and Plex document sidebars. Plex's remembered tab is an explicit context mechanism, not proof of restoring the same item. [N1][N1], [D1][D1], [P1][P1], [P2][P2]

**P — adapt/preserve/defer:** first restore the invoking item, scroll position and layer predictably in the existing shell. Then compare a compact left rail with today's top bar. Preserve Home/Live TV/Sports, the full-width event board and player Back hierarchy. Defer Plex-like multiple library tabs and extensive pinning controls: Joe-TV has three main destinations.

**Smallest validation/dependency:** Design/App storyboard Home → Sports → game → Back and guide horizontal browsing → navigation → return. QA later records presses, wrong destinations and corrective focus moves under matched conditions. Accept a rail only if Joe finds these journeys easier without Left stealing content navigation. PM allocates shared origin-state edits. High confidence in the tradeoff; medium effort, unmeasured benefit.

### 3. Curate Home from explicit channels and teams before building recommendations

**Problem/J:** favorite channels supply Home's hero; Patriots/Bruins games require a Sports journey. `JoeTVHomeView.featuredChannel` and `nowAndNext` do not express favorite teams.

**Evidence/inference:** competitor Home surfaces combine discovery with useful personal context; Plex specifically documents a current-live row. These support purposeful grouping, not a need for Netflix-scale behavioral recommendation machinery. [N1][N1], [D1][D1], [P1][P1]

**P — adapt/preserve:** trial a small favorite-team game area alongside existing channel favorites. Explain inclusion with team identity and distinguish Live, Upcoming and schedule-only. Keep current favorites intact; no new profiles, prediction scores, infinite rows or real-time resorting beneath focus. Offseason falls back to channels without a giant empty panel. This remains a future Home exploration.

**Smallest validation/dependency:** four static states—one game, overlapping games, unmatched source, offseason. Joe should find the intended team game from Home and predict watchability. Services supplies stable league/team/event/date matching through Mac mini → Personal Media API; App owns additive preferences; QA checks deduplication and migration. Medium confidence/effort; metadata quality is the gate, not decorative artwork.

### 4. Keep “favorite,” “recent,” and “saved for later” understandable

**Problem/J:** a favorite-team Home could blur persistent interests with expiring events and session-only playback history. Joe-TV already separates enabled channels, favorite channels and Quick Switch recents (`AppModel.favoriteLiveChannels`, `quickSwitchEntries`; `PlaybackHistoryPolicy`).

**Evidence/inference:** Disney separates saved titles from unfinished viewing; Plex separates saving from current availability and opens availability details from Watchlist. A saved item is an intention, not an entitlement. [D2][D2], [P3][P3]

**P — preserve/defer:** preserve existing distinctions and add team-following as an explicit interest. Defer a general movie-style watchlist, reminders and accounts. If saving a particular game later becomes valuable, specify event expiry/completion and what happens when no source exists first; do not silently turn a followed team into a queue of every past game.

**Smallest validation/dependency:** ask Joe to predict where a favorited channel, followed Bruins team and recently watched stream reappear, then remove each in a static flow. Accept only if removal has an obvious effect and does not alter unrelated visibility/preferences. Design/App; Services for event lifecycle; PM scopes persistence. High confidence in preserving semantics; small exploration, larger implementation only if selected.

### 5. Offer calm browsing without confusing it with faster playback

**Problem/J:** guide focus schedules muted playback after a deliberate 1.1-second dwell (`schedulePreview`); source inspection cannot tell whether perceived lag comes from focus rendering, metadata or stream preparation. Home/Sports artwork does not require that preview stream.

**Evidence/inference:** Netflix lets viewers disable preview autoplay; Plex separately controls browsing theme music. These demonstrate user control over distraction, not a performance guarantee or common Apple TV preview API. [N2][N2], [P2][P2]

**P — adapt/preserve:** prototype an artwork-only guide-preview preference while preserving immediate metadata feedback and explicit Select-to-watch. Keep Sports artwork and the one-player/serialized-provider constraints. Defer cinematic autoplay everywhere and avoid reducing the dwell simply to appear faster.

**Smallest validation/dependency:** later QA/App compare fixed-catalog artwork-only and existing-preview fixtures: input-to-focus, focus-to-metadata, Select-to-preparation, Select-to-first-frame, and preview starts/cancellations. Same hardware/cache/media conditions; report medians and tail behavior, not invented budgets. Playback/Services confirm cancellation and provider cost. Medium confidence; bounded experiment before any live validation or preference rollout.

### 6. Make readability and accessible controls part of polish acceptance

**Problem/J:** `JoeTVSportsGuideCard` compresses availability/status labels; `PlayerSessionView.playerControls` hides Captions when `subtitleOptions` is empty. M0 also identifies inconsistent Reduce Motion handling. These are source conditions; unreadability or screen-reader failure is not reproduced here.

**Evidence/inference:** all three services document accessibility or subtitle controls, with device-specific routes. Their existence is a useful expectation; no cited document proves a universal font size, contrast score or flawless VoiceOver behavior. [N3][N3], [D3][D3], [P2][P2]

**P — adapt/preserve:** retain RALLY's focus/selected distinction, simplify essential status text, and keep a discoverable caption action with checking/available/unavailable states. Validate system caption styling where supported rather than adding an elaborate custom editor. Do not import Netflix's mobile-only font-size claim as Apple TV evidence.

**Smallest validation/dependency:** QA later uses long titles, light/dark missing artwork, no-track/available-track clear media, VoiceOver and Reduce Motion; Joe checks normal seating distance. Accept visible unclipped focus, understandable availability without color alone, reachable caption state and stable return focus. App/Playback own implementation; Design reviews captures; PM allocates shared track-state symbols. High confidence in source gaps; medium confidence in the precise visual remedy.

## Proposed sequence and verification boundary

For PM's future-sprint plan: scope conclusions **1, 2's restoration work, and 6** as the first polish package; use **5** to diagnose responsiveness with measurements. Explore **2's left rail and 3's team Home** afterward. **4** prevents those explorations from becoming an unnecessary on-demand product. This report authorizes none of that implementation.

Checks performed: clean branch/HEAD inspection; reread TEAM-2 and M0 addendum; read governing TEAM-3 and R1 assignment; re-inspected active source paths; official web research with dates/platform qualifications. All ten Markdown citation references resolve; six conclusions are present. Staged whitespace and path checks passed with only this report included. No build or runtime tests were run. Remaining unknowns include installed competitor app/version behavior, exact competitor press counts, Joe-TV frame timing, physical-remote focus restoration, couch readability and caption rendering. Availability, personalization and visual prominence are documented capabilities—not demonstrated advantages over Joe-TV.

[N1]: https://www.netflix.com/tudum/articles/netflix-new-tv-layout
[N2]: https://help.netflix.com/en/node/2102
[N3]: https://help.netflix.com/en/node/116022
[D1]: https://help.disneyplus.com/en-GB/article/disneyplus-en-mc-navigate-app
[D2]: https://help.disneyplus.com/en-GB/article/disneyplus-en-lc-managing-watchlist
[D3]: https://help.disneyplus.com/article/disneyplus-en-lt-format-captions
[D4]: https://help.disneyplus.com/es-UY/article/disneyplus-live-guide
[P1]: https://support.plex.tv/articles/navigating-the-big-screen-apps/
[P2]: https://support.plex.tv/articles/settings-plex-for-apple-tv/
[P3]: https://support.plex.tv/articles/universal-watchlist/
