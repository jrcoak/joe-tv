# S1-APP — ordinary watching and returning

## Scope and provenance

Implemented the assigned App slice under **TEAM-4**, starting at `22f0fdf51b9b105bfb5b34cf5ecc2bb6e72a1340`. Branch: `codex/joe-tv-app-s1`; worktree: `/Users/joecoakley/.codex/worktrees/0b9c/SeasonsTV`; task: `01a0ad34-a194-7232-bde5-886ee0c7fb35`. Clean status and branch absence were checked before creating this branch; the completed assessment branch is preserved. The exact implementation commit is supplied in the final-response handoff.

Read the S1 assignment, TEAM-4, team guidance, roadmap, evaluation method, discovery conclusions 1/2/6, and Design's criteria at `3abf5256f27dee318cb59629e0a54a36f45a9e5c`. The selected changes adapt the already-researched distinction between deciding and watching and preserve Joe-TV's accepted Back contract. No new competitor capability or usability claim is made; see [the accepted comparisons](../research/streaming-discovery.md) and [S1 Design](S1-design.md). Exact focus restoration is a Joe-TV correctness requirement, not a claim about competitor internals.

Only `SeasonsTV/Views/RootView.swift`, `SeasonsTV/Views/JoeTVExperience.swift`, the allocated parts of `SeasonsTV/App/AppModel.swift`, and this report changed. PlayerScreen, networking, DRM, shared models/tests/tokens, project settings, release work and other worktrees are untouched.

## Behavior changes

| Journey | Before | Implemented behavior; runtime acceptance pending QA |
| --- | --- | --- |
| Current guide program → watch | Select opened details, then Watch required another Select | `JoeTVGuideView.activateProgram` evaluates `EPGProgram.contains(Date())` at activation. Current programs tune directly: two activations become one from the focused cell. No full-journey timing claim. |
| Future / expired program → details | Channel action could be confused with watching the listed program | Retains details and actual schedule time. CTA is **Watch channel now**, with **Plays what is on this channel now.** Close/Back returns to the program. Missing-synopsis copy no longer calls a future/expired program live. |
| Home/guide/Sports → playback → Back | Generic entry targets/framework restoration could lose the invoking item | Capture stable browse origin before playing or opening/dismissing a sheet. Catalog issues a separate return request only when a non-nil playback session becomes nil. Quick Switch session replacements do not overwrite origin. |
| Missing origin | Program bookmarks were treated as channel IDs; fallback was inconsistent | Preserve valid program bookmarks through channel preferences. Guide falls back to the same visible channel row, then nearest visible row; Home/Sports use prior displayed index within the unchanged visible context. Empty results have an explicit action target. |
| Empty Home → favorites | Text-only instruction to find settings through More | **Choose Favorites** opens the existing Channels sheet. Down from the hero reaches it; Up returns. Done/Back returns to the CTA if still empty, otherwise the first enabled favorite in existing order. Disabled favorites remain saved. |
| Ordinary top-navigation selection | Child `onAppear` could request hero/filter/scope focus | Child appearance no longer requests content focus. Initial catalog entry focuses the selected navigation destination once; Down enters content. Home's explicit Open guide action still requests guide content. |

Return handling uses the destination currently selected by the app. Therefore the player's explicit Guide command still goes to Live TV instead of restoring a Home/Sports origin. The implementation does not alter that player control. The browse hierarchy stays mounted beneath playback, preserving view-local filter/scope/selection and scroll containers; it is disabled and hidden from accessibility while covered. Restoration does not recreate the screen or reset the guide anchor. Exact viewport behavior remains a required simulator check, especially lazy Sports cards and horizontal guide positions.

Guide and Sports remember sheet origins before presentation. A local launch flag prevents sheet dismissal from restoring focus while playback is being prepared. Guide preview work is canceled before tuning/details and is not scheduled while a playback launch, player or program sheet owns the interaction. Empty filter selection also stops its old preview. No provider or player internals changed.

The details sheet now bounds its title to two lines (with limited shrinking) and uses a 680-point height to accommodate the four-line synopsis, channel-now explanation, both buttons and focus outlines. This is a local layout accommodation, not a verified visual result. New accessibility identifiers cover the Home action/favorites, guide channels/programs/details action, Sports event cards and empty-state actions. Guide cells now provide channel/title/time context and an action hint.

## Exact AppModel symbols changed

- `isNavigationFixture`: immutable flag, false outside Debug fixture launches; used to disable provider/account menu actions only in the new fixture.
- `init(client:veryLocalClient:epgProvider:fantasyFootballProvider:liveNFLScoreProvider:defaults:)`: detects the Debug navigation fixture, uses a separate resettable defaults suite, skips credential cleanup in that fixture, leaves guide/detail providers unset, installs the fixture and returns before session restoration. Normal initialization retains its existing defaults and providers.
- `configureNavigationDebugFixture()`: new Debug-only catalog, EPG and sports setup described below.
- `loadSportsSchedule()`, `refreshEPG(for:around:)`, `reload()`: only Debug fixture early returns, keeping fixture refreshes/settings operations offline and preserving its static guide. Existing non-fixture behavior is unchanged.
- `applyChannelPreferences()`: resolves a `program:` bookmark through station/program mappings before validating its channel. Preserves a valid bookmark; chooses a nearby surviving channel if its channel disappears, or nil for an empty lineup. No preference namespace or enable/favorite policy changes.

Other AppModel changes are not included. In particular playback resolution, switching, authentication, and preference mutation methods retain their existing behavior.

## QA fixture invocation and data

QA exclusively owns launches/builds/simulator. These are **launch environment variables**, not commands run by App:

```text
JOE_TV_DEBUG_NAVIGATION=1
JOE_TV_DEBUG_DESTINATION=guide
```

`JOE_TV_DEBUG_DESTINATION` accepts `guide`, `sports`, or defaults to Home. Add `JOE_TV_DEBUG_EMPTY_FAVORITES=1` to begin with no favorite channels. For a boundary test, add `JOE_TV_DEBUG_NAVIGATION_PROGRAM_SECONDS=10` (finite values are clamped to 1–3600 seconds; default 3300). In a simulator launch through simctl, QA should use its usual `SIMCTL_CHILD_` environment prefixes. Unset other older fixture flags; this fixture takes initialization precedence, and its Sports entry clears the older Fantasy display flag.

- Twelve stable channels: `debug:navigation:1` through `:12`, displayed as Fixture Channel 01–12. Every third channel is Sports; the others are News. All begin enabled. The default first eight are favorites, allowing rail scrolling and Quick Switch.
- Each channel has four programs with IDs `fixture-program-N-expired`, `-current`, `-future`, `-later`. Times are relative to one captured launch time `T`: expired `[T−1800, T−300)`, current `[T−300, T+D)`, future `[T+D, T+D+3600)`, later `[T+D+3600, T+D+7200)`, where `D` is the configured current duration. The guide anchor is `T−1800`; its existing three-hour rendering window is unchanged. The clock is **not frozen**: actual Select time determines direct tune versus details even before the next minute-based highlight render. Relaunch resets the relative schedule.
- Channel 01 has no synopsis. Channel 12 has long titles and a long synopsis for details-sheet wrapping checks. The remaining rows use short copy. No remote artwork URLs are included.
- Eight live fixture baseball events (`debug:navigation-game:1` through `:8`, before normal consolidation) have Home/Away options and run from `T−1800` to `T+7200`. They support Sports feed selection/cancellation/return without bypassing the existing selector policy.
- Playback and muted previews use the existing `debug` request handling and empty `AVPlayer` fixture. There is no media fetch, provider resolution, first frame/audio, or DRM exercise. Readiness is simulated by the existing `PlaybackSession(debugTitle:)` initializer.
- Fixture preferences use only `com.jrcoak.joetv.debug.navigation`, reset at each fixture launch. Choices persist during that run; normal app preference keys/domains are not reset or migrated by the fixture. Account refresh, Fantasy configuration and sign-out menu actions are disabled in this mode. Catalog/guide/sports refresh entry points return locally; metadata prefetch has no provider. Credential cleanup and automatic session restoration are skipped. This is source-inspected isolation; QA should record runtime traffic evidence separately if available.

Suggested QA sequence: Home favorite → watch → Quick Switch → Back, then repeat from another favorite; player Guide must instead go to Live TV. Guide current program on rows 2 and 10 → watch → Back; repeat after horizontal movement and using Favorites/News filters. Future/expired → Close, then → Watch channel now → Back. Leave a cell focused across the configured end boundary and Select. Empty Home → Choose Favorites → close unchanged, then add a favorite and return; separately retain only disabled favorites. Sports event → cancel feed, then choose feed → Back. Check long/no-synopsis details, VoiceOver names and repeated/spaced Back alongside Playback's integration.

The player's existing Favorite action can remove a Home origin while playing, providing an offline nearest-favorite fallback case. This fixture does not automatically delete guide programs or Sports events while playing; QA/PM should identify any additional controlled mutation needed for those missing-origin cases. Source fallback logic is not substituted for that runtime evidence.

## Checks and limitations

- `git diff --check`: passed.
- `xcrun swiftc -frontend -parse -D DEBUG SeasonsTV/Views/RootView.swift SeasonsTV/Views/JoeTVExperience.swift SeasonsTV/App/AppModel.swift`: passed.
- The same syntax-only parse without `-D DEBUG`: passed. These checks do **not** type-check framework APIs, build the application, or establish UI correctness.
- Source/diff review checked allocated files/symbols, current-time activation, origin capture before sheet dismissal, Quick Switch versus explicit Guide, preview cleanup, ordinary destination entry, preferences and fixture isolation.
- No smoke suite, type-check/build, simulator operation, provider/API request, profile, device or release test ran in this task. QA must build the exact integrated candidate and exercise the matrix before S1 acceptance. Physical remote behavior, FairPlay, real-media readiness and couch readability remain separate evidence.
- No performance optimization or measured speedup is claimed. Changes reduce the named activation step and define deterministic focus targets; actual complete journeys, focus/scroll behavior, sheet clipping and responsiveness are pending QA.

Final-response handoff is the agreed delivery path; no rejected outbound messaging was retried. No further sprint is started by this slice.

## S1 correction candidate — passive guide preview

PM authorized this bounded candidate from `a30b22893f736b72186739f1dd834de680c96fbf` on new branch `codex/joe-tv-app-s1-fix` in the same App worktree. Clean status and branch absence were verified; the prior S1 branch is preserved. Only `JoeTVExperience.swift` and this report change.

QA reported a clean guide-current-program entry failure on integrated `f394d4d356851092ae579051cff5a5a667d53cdb`: black fixture playback without usable chrome/Up/Back, while Home playback worked. Subsequent QA comparisons found that channel-name Select and future-details → Watch after an active preview initially show the custom player's badge, then ignore spaced Up after auto-hide. Thus custom-player presentation does occur, and the issue spans the tested guide origins rather than only direct current-program activation. Empty Favorites cancel/add/disabled-only roundtrips passed in QA's report. App and Playback source reviews identified the native preview-controller removal concurrent with custom-player insertion as the strongest hypothesis. That is **not a proven cause**, and this commit is not a runtime-verified fix.

`JoeTVMutedPreviewPlayer` now uses a passive `UIViewRepresentable` backed by `JoeTVPreviewSurfaceView` and `AVPlayerLayer`, following the existing main player's surface pattern. The view cannot become focused, accepts no user interaction and is hidden from accessibility. It attaches the same AVPlayer, changes that attachment only when player identity changes, and detaches on dismantle. The layer retains `.resizeAspectFill`; parent dimensions/clipping, session/mute handling and preview dwell remain unchanged. `stopPreview` still owns pause/cancellation. `playChannel`, AppModel, full-screen PlayerScreen, Back handling and all sequencing are unchanged; no delay is added.

Rationale: a decorative preview does not need an AVPlayerViewController's control, focus or presentation lifecycle. Removing that lifecycle creates a narrow comparison without introducing timer assumptions or changing the full-screen player. No competitor-internal behavior or performance benefit is claimed.

Source checks: Debug and non-Debug syntax-only parsing of `JoeTVExperience.swift` and `git diff --check` passed. Source/diff review confirmed only the preview wrapper/backing view plus its UIKit import changed. No build, simulator, media, provider, device or profiling check ran. QA must freshly build the integrated candidate and compare **after active preview dwell**: current-program Select, channel-name Select and future-details → Watch channel now. Check initial badge, Up/controls, spaced/repeated Back, exact browse-origin return, preview resumption and a second watch/return cycle. Preserve the known passing Home/Quick Switch paths. If the guide issue remains, the hypothesis is not validated and further diagnostics are required.
