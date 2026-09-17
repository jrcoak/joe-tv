# S4-APP — unknown game-time compatibility

Baseline: `d2468a947c4850103aaabdb3544370bfcb91af66`; assignment S4 / TEAM-4. Branch: `codex/joe-tv-app-s4`, created after clean/absence checks in the existing App worktree. Prior branches preserved. Read the S4 assignment and live-status diagnosis. Exact implementation commit is supplied in the final handoff.

## Changes

- `JoeTVExperience.swift`: Sports phase switches and shared phase eyebrow explicitly present unknown as **Time unavailable**. ESPN+ and supporting score/event cards no longer use non-replay as an implicit Live label. Raw subtitle/status fallbacks are suppressed for unknown where they could contradict the neutral label. The existing broadcast selector uses neutral stream copy for unknown without changing its feeds, selection actions or focus IDs.
- The normal Sports view displays a quiet, noninteractive notice when the enabled sports include unknown listings: **Time unavailable for some listings. They are omitted from Live and Upcoming.** Identifier: `sports.unknownListingsNotice`. It uses the same TimelineView reference date as the tab counts. Live/Upcoming grids, tab counts and category-filter counts continue to use Services' `SportsEventGuidePolicy.filteredItems`; there is no duplicate classification policy or extra tab. Empty live copy now says no live games are listed rather than asserting that nothing is live anywhere.
- `RootView.swift`: legacy sports phase switch, stage/row copy and accessibility subtitle use neutral unknown wording. Existing IDs and actions remain unchanged. Catalog routing, Channels settings and S1/S2 return behavior are untouched.
- `AppModel.makePlaybackSession` only: an explicit unknown case retains live-edge transport behavior if an available stream is independently selected elsewhere. This is not a live-game classification. Existing history/Quick Switch eligibility checks still require `.live`; direct channel playback is unchanged. No PlayerScreen edit is needed for enum compatibility.

Models/parser/tests belong to Services and were not edited. Unknown classification, timing boundaries, studio exclusion and pregame availability depend on Services' parallel S4 source. This App commit must be integrated with that enum/policy change before typechecking. No private configuration, provider requests or build plumbing were accessed; PM/QA own the configured browsing build.

## Verification and pending evidence

- Debug and non-Debug syntax-only parsing of `JoeTVExperience.swift`, `RootView.swift` and `AppModel.swift` passed using `xcrun swiftc -frontend -parse` with and without `-D DEBUG`.
- `git diff --check` and scoped source review passed. The sole AppModel delta is the new case in the assigned phase switch. All existing accessibility identifiers remain; one noninteractive notice identifier is added.
- Syntax parsing does not resolve the parallel enum addition or typecheck SwiftUI. No full build, host smoke, simulator/runtime, network, private config, or physical-device check ran in App. No performance or visual-acceptance claim is made. Competitor parity does not apply to the correction of a game phase inferred from feed playability.

QA must typecheck the integrated App/Services source, run Services' phase/parser and existing regression suites, and verify the configured normal session: unknown entries absent from Live/Upcoming and their counts; notice only for enabled sports with omitted unknown listings; future/pregame listings remain Upcoming; unknown copy never becomes Live/Upcoming/Final; feed selection/focus and S1/S2 return paths preserved. Any unknown stream selected through a separate existing path must retain transport semantics without becoming eligible as a live game in history. Configuration shape and successful schedule loading require separate PM/QA evidence.

Final/Git handoff is the established delivery path; rejected outbound callbacks were not retried.
