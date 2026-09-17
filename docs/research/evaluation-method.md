# How Joe-TV improvements will be evaluated

Status: proposed validation method, TEAM-3. No timing, memory or competitor usability benchmark has been run in M0/R1. Research checked September 16, 2026 EDT.

Vendor help and announcements establish patterns worth testing; they do not establish that a shipped app is faster, easier or more accessible. The two competitor reports distinguish Apple TV-specific guidance, generic TV behavior, other-device instructions and indexed-only evidence. Verify the installed app/version before calling a future result a hands-on comparison.

## Journey benchmark

Use the same starting focus, destination, data size, clock, cache and media conditions before/after a Joe-TV change. Count directional inputs, Select, Back, long presses, modal transitions and corrective focus moves separately. A reduced Select count is not a measurement of the whole journey.

| Journey | User outcome | Evidence to collect |
| --- | --- | --- |
| Home → favorite channel → Back | Watch a known channel and resume browsing | All remote inputs, first feedback, first visible/audible media, restored item |
| Guide → current program → Back | Tune what is on now without redundant decisions | Sheet/activation count; preserved row/time/scroll; expired-program behavior |
| Sports → game → feed → Back | Choose the intended available broadcast | Feed/date correctness, availability wording, no-op actions, origin restoration |
| Player → Quick Switch → failed/valid replacement | Change channels without losing control | Stable identity/history, prior pause intent, canceled work, active-player count |
| Player → Fantasy drawer → close → Back | Check scores and return predictably | Layer transitions and focused target before/after each input |
| Empty Home → favorites settings → Home | Personalize without hunting for settings | Complete path, useful initial focus, saved preferences and removal behavior |

Smallest first experiment: reproduce the two QA focus concerns and compare the current-program sheet with a direct-watch prototype using controlled fixtures. Joe judges intuitiveness; scripted correctness checks alone do not prove it.

## Responsiveness and performance

Separate input-to-focus feedback, focus-to-metadata/artwork, Select-to-resolver completion, player readiness, and first frame/audio. Existing empty-player fixtures can establish UI transitions and identity, not first-frame timing. The guide's 1.1-second preview dwell is deliberate source timing; it is not evidence of a rendering stall.

Profile repeatable guide traversal and Sports filtering with SwiftUI/Time Profiler and Hangs/Hitches where supported by the installed toolchain/runtime. Apple's Instruments guidance recommends investigating both costly and unnecessarily frequent view updates. This supports targeted measurement; it does not prove an eager collection or a particular computed property is Joe-TV's bottleneck. [Apple, Optimize SwiftUI performance with Instruments, WWDC25](https://developer.apple.com/videos/play/wwdc2025/306/).

Record exact commit, build configuration, hardware/OS, catalog size, fixture/media, network, cache state and run count. Use cold and warm runs; report individual samples plus median/range, and meaningful tail percentiles only with enough samples. Use physical Apple TV for delivery budgets; simulator measurements are diagnostic. Separate local clear-media trials from serialized provider/FairPlay trials.

Pick numerical budgets after the baseline and method are agreed. Success means a demonstrated improvement in the targeted journey without degrading other sampled journeys, playback, memory or accessibility. Do not add new provider requests simply to make a spinner disappear.

## Interaction and accessibility

Apple distinguishes focus from activation on tvOS and advises straightforward remote navigation with minimal complex input. These are platform principles, not a required top-bar/sidebar layout. [Apple focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/), [interface fundamentals](https://developer.apple.com/documentation/technologyoverviews/interface-fundamentals).

For touched screens: check focused versus selected state, stable Back destination, long titles, clipped focus edges, missing artwork, non-color availability cues, VoiceOver names/states, Reduce Motion and couch readability. For captions: use real clear media with available/no/delayed tracks and required selection before protected-device validation. Preserve system preferences where the player supports them.

## Comparison decision

Every feature brief links relevant current competitor evidence and states adopt/adapt/preserve/defer with a reason. If a correctness or security repair concerns hidden internals, explicitly say competitor internals are not available and use the Joe-TV reproduction plus platform/provider contract instead. Do not infer backend security or concurrency design from a polished competitor screen.

Recheck relevant research when a sprint starts or an app changes; do not redo the entire survey for every small fix. No subscriptions, purchases, logins, telemetry service or ongoing monitor is required by this research.
