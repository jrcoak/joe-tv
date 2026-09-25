# S7 App handoff — Fantasy score retry and calendar window

- Assignment: S7-FIX App Fantasy score retry under the PM delegation.
- Governing baseline/spec: base Joe-TV `2340729`, TEAM-8 repository instructions.
- Branch: `codex/joe-tv-app-s7`.
- Scope: Fantasy sections of `SeasonsTV/Views/JoeTVExperience.swift` and this handoff.

## Result

Fantasy Zone now reports NFL scoreboard loading, stale retained scores, unavailable scores, and a true no-games result without exposing transport or decoder text. When cards remain after a failed refresh, the existing cards stay visible with a focused Retry action and the copy “Scores may be out of date.” When no cards remain, the view presents an honest unavailable state with a focused Retry Scores action. Loading retains the existing stream choices and uses a visible progress status. Successful empty results keep a focused no-games state.

The Fantasy upcoming filter now uses Services’ shared `NFLScoreboardCalendar.throughTuesdayCutoff(containing:)` helper, preserving the Wednesday-midnight America/New_York exclusive cutoff without a view-local calendar calculation.

## Verification

- `xcrun swiftc -frontend -parse SeasonsTV/Views/JoeTVExperience.swift`: passed (syntax parse; Services helper is supplied by the Services integration).
- `git diff --check`: passed.
- Source review confirmed retry actions call the existing `model.refreshFantasyZone()` and no raw scoreboard error string is rendered.

No simulator, provider, device, player, build, project, signing, release, or Plex-fork work was performed. PM owns the combined build and native Fantasy fixture verification. The typecheck/build must run after Services’ calendar helper is integrated into the PM branch.
