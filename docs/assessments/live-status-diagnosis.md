# Live sports overcount — user-session diagnosis

Observed September 17, 2026 around 11:15–11:20 America/New_York. Running normal-mode S3 app source `9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d`; inspected PM source `915fb4648fc8b8c98e8f296ebd84151b8437ec98` has identical app code. Joe owns the simulator. PM performed a read-only CUA app selection/screenshot; no input, network, account, media, restart or install action.

## Confirmed observations

Sports displayed Live 24 / Upcoming 3 with five sports enabled. A banner explicitly reported missing sports-schedule build configuration. Brewers @ Pirates was selected with LIVE and a displayed September 17 11:35 AM ET start, still future at inspection. Other visible rows included Good Morning Football, SEC In 60 and numerous NFL team pairings. These are UI observations, not externally verified actual game schedules.

A value-redacted local check confirmed the preserved S3 bundle has no valid-shaped MediaReadToken. The main checkout has existing private Debug/Internal config files with valid-shaped tokens; the team/QA worktrees do not. Values were not printed/copied, no credential was changed, and validity/authorization at the server was not tested. PM mistakenly opened the offline QA artifact as a normal browsing build without checking this prerequisite.

## Source causes confirmed by Services and PM

- `parseDynamicGames` renders provider schedule text into subtitle but does not attach a structured sportsEvent.
- `MediaItem.sportsPhase` classifies any playable item with no sportsEvent as live. Failed/missing schedule enrichment exposes this fallback. A playable transport is not evidence that its named game is happening now.
- Live-like substrings in status/subtitle return live before structured start/end checks. Generic or stale Live can override future/expired timing. A minute-based TimelineView cannot correct a frozen status shortcut.
- ESPN+ parsing manufactures Live/Upcoming labels using parse-time Date(), including Live for a current/past-day non-replay row without usable start time, and does not use its end time in that label. Existing tests explicitly encode one timeless-live assumption that needs to change.
- Studio-program exclusions omit the two visible examples; this contributes non-game entries separately from phase overcount.

Missing configuration is verified. The direct playable-without-event fallback explains why unenriched entries can inflate the Live count. Individual feed truth and the contribution of every path to all 24 rows were not measured. S1–S3 did not alter these sports phase/parser paths.

## Next repair contract

1. Prepare a normal browsing build using only the existing explicit private Debug configuration; do not copy secrets by wildcard, expose tokens in logs, reuse release credentials unnecessarily, or claim configuration shape proves server access. Preflight the resulting bundle without printing values. Preserve offline QA artifacts separately and label their capabilities correctly.
2. Distinguish insufficient evidence from Live/Upcoming/Replay. Playability, datecode alone, generic Live copy and transport type must not establish a live game. Preserve structured instants and reevaluate at a supplied reference time; future starts and known ended windows cannot be overridden by generic stale labels. Keep the 15-minute pregame playback rule separate from live status. App/Playback must explicitly coordinate any new enum state and neutral presentation; do not silently mislabel unknown as Upcoming or redesign the entire Sports screen.
3. Cover missing enrichment, nil/invalid times, future+Live, ended+Live, parse-to-boundary advancement, fractional timestamps, genuine in-game evidence, final/replay and pregame boundaries using fixed-clock tests. Preserve source/date/feed matching and current publisher architecture. No new provider polling or timestamp freshness SLA is inferred here.
4. Before replacing the currently running build, coordinate a runtime handoff with Joe. Do not interrupt his inspection session or claim the fix shipped based on this diagnosis.

Diagnosis only: no source changes, configured rebuild, new tests, or runtime replacement occurred in this checkpoint. The next repair remains to be scoped and implemented; full S1/S2 visual acceptance remains separate.
