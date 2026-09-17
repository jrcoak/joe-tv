# R1-LIVE — live-TV interaction patterns

## Scope and evidence rules

- Assignment: **R1-LIVE**, research only, governed by spec **TEAM-3**, acknowledged from PM commit `1404c9d` (`spec.md` and `docs/assignments/R1.md`).
- App baseline: `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`; research branch `codex/joe-tv-playback` began this assignment at prior M0 report commit `c54738daab34c0cfb25bec9c0ee0c82f04e375a5`. The unchanged M0 report remains evidence rather than being revised by TEAM-3.
- Research date: **September 16, 2026**. All web sources below were accessed on that date.
- Products: YouTube TV, Hulu + Live TV, and Fubo. Official help sources were prioritized. No subscriptions, logins, apps, streams, installs, simulators, or hands-on competitor tests were used.
- “Documented” means the vendor says a feature exists in the stated scope. It does not prove usability, responsiveness, universal rollout, current availability for every account, or Apple TV parity.
- “Joe-TV observed” means inspected source at the app baseline above. “Hypothesis” and “inference” require QA or user validation. Every recommendation is a future-sprint plan; TEAM-3 does not authorize implementation, and this assignment changes no application code.

The comparison is intentionally selective. Joe-TV should not accumulate features simply because a larger service has them. The useful question is whether a pattern shortens Joe's path to live TV and sports while preserving Joe-TV's fast, focused character.

## Joe-TV source-observed baseline

| Area | Current Joe-TV behavior | Evidence and limit |
| --- | --- | --- |
| Primary navigation | A persistent top bar exposes Home, Live TV, Sports, and More. Each destination restores a content focus entry point. | `SeasonsTV/Views/RootView.swift:190` (`destinationBar`) and `:287` (`destinationButton`). Source-observed; remote efficiency still needs QA. |
| Home | The hero follows the focused favorite. A Favorites rail shows now/next and launches the selected channel directly. | `SeasonsTV/Views/JoeTVExperience.swift:6` (`JoeTVHomeView`) and `:142` (`nowAndNext`). Source-observed. |
| Guide/customization | The guide has All, Favorites, Local, Entertainment, News, and Sports filters. Channel visibility and favorite status are separately persisted. | `JoeTVExperience.swift:267` (`JoeTVGuideView`), `AppModel.swift:40`, `:443`, and `:447`. Source-observed. Favorite ordering is inherited from the loaded lineup; no user-defined favorite order was found. |
| Sports | Sports has Live/Upcoming scope, persistent granular category filters, event details, and explicit feed choices including baseball Home/Away/National where supplied. | `JoeTVExperience.swift:801` (`JoeTVSportsView`), `AppModel.swift:40`, and `Models.swift:12`. Source-observed. There is no ordinary favorite-team preference or favorite-team Home module; Fantasy team data is a separate optional feature. |
| Quick switching | One rail combines up to four recent stable targets followed by favorite channels, deduplicates, omits the active stream, resolves fresh media, and rolls back on preparation failure. Long Select recalls the last stream. | `Models.swift:923–1007`, `AppModel.swift:400`, `:1102`, and `PlayerScreen.swift:584`, `:845`. Source-observed. The M0 playback report identifies cancellation and post-ready health gaps that should be resolved before expanding switching. |
| Live/DVR | Live/upcoming sports and live channels request the live edge; seekable streams support bounded ten-second skips. | `Models.swift:1214`, `:1302`, `:1421`; `AppModel.swift:1185`, `:1604`. Source-observed. The player badge describes the source as LIVE even after rewind and has no explicit Go Live action. Actual edge behavior is unmeasured here. |
| Captions | The player discovers legible options, labels CC/SDH, exposes a custom selection dialog, and reports the selected title. | `Models.swift:1313–1389`; `PlayerScreen.swift:238`, `:532`. Source-observed. The control disappears when no tracks are found, so the dialog's “No captions available” state is normally unreachable; discovery failure and genuine absence are not distinguished. |
| Player Back behavior | Back unwinds Quick Switch, controls, and the Fantasy drawer before dismissing playback; delayed dismissal suppresses event fall-through. | `PlayerScreen.swift:896–929`; `AppModel.swift:1726–1748`. Source-observed. Focused scorebug/failure/caption routes and physical Siri Remote behavior remain QA/device questions. |

## Competitor comparison

| Pattern | YouTube TV — documented behavior | Hulu + Live TV — documented behavior | Fubo — documented behavior | Joe-TV interpretation |
| --- | --- | --- | --- | --- |
| Guide and channel customization | The Live tab can hide and reorder networks; preferences set on mobile/web reflect across devices. The TV remote guide exposes upcoming programs. Scope is TV-generic, with Apple TV listed as supported; the guide-editing instructions are not explicitly Apple TV-specific. [Watch shows, sports, events & movies](https://support.google.com/youtubetv/answer/7067974?hl=en) and [Download & control YouTube TV on your TV](https://support.google.com/youtubetv/answer/7452153?hl=en), no publication/update date visible. | Live TV subscribers get Live as a main destination, a Guide for upcoming programming/channel changes, and Live Now plus Live TV Favorites on Home. TV-connected navigation may vary by device. Apple TV 4th generation and later is supported, but the navigation article does not promise exact Apple TV layout parity. [How do I use the Hulu app?](https://help.hulu.com/article/hulu-navigating-hulu), updated Aug. 28, 2026; [Supported devices](https://help.hulu.com/article/hulu-supported-devices), updated Sept. 9, 2026. | Favoriting from the Guide places channels at the beginning of Home and Guide. Fubo's Apple TV guide also documents reordering favorites. [Favorite channels](https://support.fubo.tv/hc/en-us/articles/360028439511-How-do-I-Favorite-the-channels-I-watch-most), updated May 8, 2024; [Fubo on Apple TV](https://support.fubo.tv/hc/en-us/articles/43790283314061-How-do-I-watch-Fubo-on-my-Apple-TV), updated Mar. 2, 2026. | Preserve visibility versus favorite as separate choices. Consider explicit favorite ordering and consistent promotion across Home, Guide, and Quick Switch; avoid duplicating YouTube TV's cross-device editor complexity in a single-user app. |
| Last channel and recent switching | TV remotes can select recently watched live, recording, and on-demand programs below the player. A separate official article documents long-press OK/Select for the last channel. TV-generic; Apple TV is supported, but channel up/down is explicitly not universal, so Apple TV parity should not be inferred for every shortcut. Same two Google sources above. | Selecting Live jumps directly to the live stream of the last watched channel. The documented swipe-to-change shortcut is iOS-only, not Apple TV evidence. [How do I use the Hulu app?](https://help.hulu.com/article/hulu-navigating-hulu), updated Aug. 28, 2026. | On Apple TV, holding Back returns to the previous channel. [How do I watch Fubo on my Apple TV?](https://support.fubo.tv/hc/en-us/articles/43790283314061-How-do-I-watch-Fubo-on-my-Apple-TV), updated Mar. 2, 2026. | Joe-TV already combines both ideas more visibly: a recent/favorite rail plus last-stream recall. Preserve it. Improve cueing and reliability rather than add more switch gestures. |
| Live versus delayed DVR | A recording can start at the beginning, resume, join live, or use key plays where supported. Device/league availability varies; Apple TV-specific placement is not documented on this page. [Record programs on YouTube TV](https://support.google.com/youtubetv/answer/7129564?hl=en), no publication/update date visible. | The current official navigation article documents direct entry to the last live channel but does not provide a device-specific Go Live contract. Treat absence from this research as unknown, not as evidence the feature is absent. | Connected devices choose Watch Live or Play from start. On Apple TV specifically, program info offers Play from Live after pause/rewind. [In-progress Cloud DVR](https://support.fubo.tv/hc/en-us/articles/8361914566029-How-can-I-watch-an-in-progress-Cloud-DVR-recording), updated Apr. 21, 2025. | Fubo provides the clearest Apple TV evidence for a distinct behind-live state/action. Joe-TV can adapt that clarity without adding cloud DVR or recording. |
| Sports and favorite teams | Users can search by team and add a team/event to the Library; current and upcoming airings are recorded. This documents a persistent team intent, though recording is beyond Joe-TV's scope. [Watch shows, sports, events & movies](https://support.google.com/youtubetv/answer/7067974?hl=en) and [Record programs](https://support.google.com/youtubetv/answer/7129564?hl=en), no publication/update dates visible. | Sports is a main destination, Home exposes tailored collections, and search accepts team names. The source does not document a favorite-team Home rail, so no stronger claim is made. [How do I use the Hulu app?](https://help.hulu.com/article/hulu-navigating-hulu), updated Aug. 28, 2026. | The Apple TV guide documents choosing sports/leagues/teams, scheduling events, and following a favorite team. [Fubo on Apple TV](https://support.fubo.tv/hc/en-us/articles/43790283314061-How-do-I-watch-Fubo-on-my-Apple-TV), updated Mar. 2, 2026. | Joe-TV already has the difficult event/source consolidation. A small favorite-team layer can personalize Home and ordering without importing DVR, profiles, or broad recommendations. |
| Captions and accessible player controls | On smart TVs, Down opens controls and CC selects available tracks. The page documents availability-dependent controls and says live caption appearance cannot be customized. It is smart-TV-generic, not an Apple TV-specific contract. [Accessibility on YouTube TV](https://support.google.com/youtubetv/answer/7271628?hl=en), no publication/update date visible. | No sufficiently specific current official Apple TV caption article was found in this bounded search. Hulu device support alone is not evidence of the caption interaction. | Connected-device controls expose CC, available languages, and Off; presentation may vary by device. [Turn captions on/off](https://support.fubo.tv/hc/en-us/articles/115000326292-How-can-I-turn-on-off-closed-captions), updated May 6, 2025. | Joe-TV's custom selection is competitive in capability. Its opportunity is truthful availability/loading/failure and respect for system preferences, not a denser settings panel. |
| Navigation model | Home, Live, and Library are the central surfaces; the docs do not establish an Apple TV left-rail contract. | On TV-connected devices, Left or Back opens the menu; Live and Sports are primary items. Device behavior may differ. [How do I use the Hulu app?](https://help.hulu.com/article/hulu-navigating-hulu), updated Aug. 28, 2026. | Apple TV exposes Guide, Sports, Shows, Movies, and My Stuff. Back is documented as one layer back. [Fubo on Apple TV](https://support.fubo.tv/hc/en-us/articles/43790283314061-How-do-I-watch-Fubo-on-my-Apple-TV), updated Mar. 2, 2026. | A future Joe-TV left nav should be a fast doorway to its existing Home, Live TV, Sports, and More state—not a reason to add competitor destinations. Back must still unwind local context before revealing navigation. |

## Recommended future validations

### 1. Add truthful Behind Live / Go Live state

- **Problem:** after a DVR rewind, Joe-TV continues to label the session LIVE and offers no one-action return to the current edge.
- **Existing Joe-TV behavior:** live-source classification, live-edge entry, and bounded seeking already exist. The source does not observe distance from the current seekable end.
- **Competitor evidence:** Fubo documents an Apple TV-specific Play from Live action; YouTube TV documents separate start, resume, and live choices for recordings.
- **Adapt/preserve/defer:** adapt the explicit state/action; preserve automatic live entry and ten-second seeking; defer timelines, recording, and key plays.
- **Smallest validation:** feed a local session adapter controlled current-time/seekable-range values and prototype only `At Live`, `Behind Live`, `Unknown`, and `Go Live` completion. Then use one QA-owned clear DVR fixture.
- **Success criteria:** a substantial rewind stops presenting `At Live`; Go Live reaches the latest valid edge once; missing/discontinuous ranges show no invented delay; finite media has no Go Live action; observer cleanup is stable.
- **Dependencies:** Playback implementation, Design wording/focus, App shared state if needed, QA local/simulator then physical-device coverage.

### 2. Make channel favorites consistent and user-orderable

- **Problem:** favorite channels drive Home, a Guide filter, and Quick Switch, but their order follows provider lineup order. A viewer cannot put the few most important stations first everywhere.
- **Existing Joe-TV behavior:** channel visibility and favorite state are already distinct and persisted; Home and Quick Switch reuse stable channel identities.
- **Competitor evidence:** YouTube TV documents hiding/reordering networks; Fubo documents favorite channels at the beginning of Home/Guide and Apple TV reordering.
- **Adapt/preserve/defer:** adapt a single saved favorite order used by Home, the Guide Favorites filter, and Quick Switch. Preserve enabled-versus-favorite semantics and fresh playback resolution. Defer arbitrary full-lineup reordering unless Joe asks for it.
- **Smallest validation:** a fixture with six enabled channels and three favorites; allow reorder in the existing Channels settings, then render the same order on all three surfaces. Test missing/new provider channels additively.
- **Success criteria:** one ordering change is reflected consistently; removing a favorite does not disable the channel; new channels do not reorder existing favorites; focus survives reorder/removal; preference migration preserves current choices.
- **Dependencies:** App and Design own settings/navigation, Playback consumes order in Quick Switch, PM allocates `AppModel` persistence, QA covers migration/focus.

### 3. Introduce favorite teams as a small Home lens

- **Problem:** Joe-TV organizes sports by sport category and time, but a fan still scans the board to find a team they care about. Joe's requested favorite-team Home direction has no ordinary-team preference in source.
- **Existing Joe-TV behavior:** normalized events already carry home/away IDs, names, logos, league, time, status, and playable feeds; Sports already separates Live/Upcoming and persistent sport filters. Fantasy identity remains separate.
- **Competitor evidence:** Fubo documents team/league selection and team following on Apple TV; YouTube TV treats a team as a persistent Library intent. Hulu documents team search but not a favorite-team Home rail.
- **Adapt/preserve/defer:** adapt stable favorite-team intent and a compact `Your Teams` Home rail ordered live first, then upcoming. Preserve the full Sports board as the authoritative browse surface. Defer automatic recording, notifications, recommendations, profiles, and replay catalogs.
- **Smallest validation:** start with 4–6 fixture events across two teams. Add/remove favorites from event details or a small settings list; Home shows matching live/upcoming events and opens the existing event action/feed flow.
- **Success criteria:** matching uses stable team ID where present with an explicit fallback policy; one event appears once even across sources; unavailable/blackout states remain honest; empty favorites and no-games states are useful; Home computation is cached and does not add work during focus rendering.
- **Dependencies:** Services defines canonical team identity and source dedupe, App/Design own selection and Home, QA covers source/date collisions, PM assigns shared models/persistence.

### 4. Preserve Quick Switch and make its shortcuts discoverable

- **Problem:** Joe-TV's Quick Switch is strong and already displays a Hold Select / Last Stream hint when applicable (`PlayerScreen.remoteControlHint`). Whether viewers notice and understand it is untested, and switch reliability still has M0 gaps. Adding more gestures could make the player less predictable.
- **Existing Joe-TV behavior:** Down opens a combined recent/favorites rail; long Select recalls the last stream; failed preparation can restore the prior session. M0 found that pre-install resolution can outlive dismissal and that `.readyToPlay` ends rollback before media progress is established.
- **Competitor evidence:** YouTube TV documents recent programs below the player plus long-Select last channel; Fubo documents long-Back previous channel on Apple TV; Hulu's Live destination resumes the last live channel.
- **Adapt/preserve/defer:** preserve the current rail and Back hierarchy. Evaluate and, if needed, improve the existing on-screen Last Stream cue; make the operation cancelable before considering another shortcut. Defer blind channel surfing as the primary model and keep the existing opt-in default.
- **Smallest validation:** test first-time discovery of the current hint with five scripted tasks, then compare a revised cue only if needed; independently add a delayed resolver fixture for switch/back/failure before UI expansion.
- **Success criteria:** viewers can find Quick Switch and Last Stream without instruction; no focus movement tunes content; Back during resolution never reopens playback; failure preserves target and pause intent; the rail remains recents-first, favorites-second, deduplicated, and active-free.
- **Dependencies:** Playback, Design, Services cancellation contract, App navigation, QA deterministic resolver and physical remote follow-up.

### 5. Make captions always understandable

- **Problem:** Joe-TV hides the caption control when zero tracks are loaded, which collapses loading, unavailable, and failed discovery into absence. Its Off choice can be ineffective if a media group disallows empty selection.
- **Existing Joe-TV behavior:** track discovery, language/CC labels, current selection, and a custom dialog already exist.
- **Competitor evidence:** YouTube TV and Fubo place caption access in connected-TV player controls and document availability-dependent language selection. Neither cited page proves identical Apple TV presentation.
- **Adapt/preserve/defer:** adapt an always-reachable caption entry with loading, available, unavailable, and retry states; show Off only when actionable. Preserve the lightweight player chrome. Defer rich visual style editing to tvOS/system settings unless a clear need appears.
- **Smallest validation:** use the existing `JOE_TV_DEBUG_CAPTIONS_URL` path with fixtures for known tracks, no tracks, delayed discovery, discovery error, and required selection.
- **Success criteria:** every state has understandable text; real selection updates checkmark/value and rendered captions; Off never appears as a no-op; focus returns predictably; any future saved preference is semantic and survives track reorder.
- **Dependencies:** Playback, Design/accessibility, QA clear media and physical protected-media follow-up; PM allocation for any preference persistence.

### 6. Prototype the future left navigation as a journey reduction

- **Problem:** Joe wants a future left nav and shorter, intuitive journeys. Moving the current top buttons to the left does not by itself improve navigation and could introduce a second focus trap.
- **Existing Joe-TV behavior:** the top bar already provides three primary destinations plus More, with explicit focus transfer into content and focus restoration.
- **Competitor evidence:** Hulu documents Left/Back opening its TV-connected menu and makes Live/Sports primary. Fubo documents a small set of top-level Apple TV destinations and one-layer Back. Neither source proves that its arrangement is faster for Joe-TV.
- **Adapt/preserve/defer:** prototype a compact collapsed rail containing only Home, Live TV, Sports, and More. Preserve current destination state, content focus entry, and one-layer Back semantics. Defer Library/My Stuff, Movies, Shows, profiles, and account surfaces because Joe-TV does not need them.
- **Smallest validation:** a fixture-only storyboard/prototype with the current screens. Compare current top bar versus rail on six tasks: Home → favorite channel, Home → Guide, Guide → Sports, Sports → Home, content → More, and Back to prior content focus.
- **Success criteria:** median remote actions do not increase; opening the rail never changes destination on focus; Select commits; Back closes the rail then restores the exact content focus; rail labels remain readable at couch distance; reduced-motion behavior is clean.
- **Dependencies:** Design owns journey/focus specification, App owns navigation implementation, QA logs action counts and focus failures, Playback verifies the player remains outside browse navigation.

## Priority and what to preserve

Recommended sequence for planning:

1. **Behind Live / Go Live** — small, evidence-backed playback clarity with an Apple TV-specific precedent.
2. **Cancelable/discoverable Quick Switch** — reliability before expanding player gestures.
3. **Favorite-team Home lens** — the strongest new viewer-facing personalization using data Joe-TV already carries.
4. **Consistent favorite-channel order** — useful polish and shorter scanning across existing surfaces.
5. **Caption state clarity** — accessibility and trust; pair with known-media QA.
6. **Left-nav prototype** — validate journey and focus before adopting the layout.

Across all six, preserve Joe-TV's explicit Select-to-tune behavior, stable identities instead of expiring URLs, the current live/upcoming Sports board, Home/Away/National feeds, quick-switch rollback, full-width Fantasy playback, and a shallow Back hierarchy. DVR recording, multiview, large recommendation systems, profiles, and new libraries should remain deferred: the researched services document those capabilities, but none is needed to solve the narrower Joe-TV journeys above.

## Research limitations

- Vendor documentation can lag an app release, describe staged rollouts, or combine device families. Where a page did not explicitly say Apple TV/tvOS, this report labels it TV-generic or connected-device behavior.
- Hulu's current official help exposed fewer device-specific player details than Fubo's. Missing documentation is recorded as unknown, not a feature comparison loss.
- Google search surfaced community guides, but the comparison relies on official Help pages for core claims.
- No responsiveness, focus quality, startup time, live latency, readability, reliability, or usability claim was measured for any competitor or Joe-TV in this assignment.
- All proposed success criteria require future fixture, simulator, or physical-device work under the existing resource coordination rules. FairPlay, protected captions, and Siri Remote behavior still require Apple TV evidence.

PM integration correction after QA review of 28e3406: recommendation 4 now explicitly recognizes the existing Last Stream hint, verified in PlayerScreen.remoteControlHint. This changes the research wording, not application behavior or evidence about cue discoverability.
