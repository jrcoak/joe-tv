# S4-SERVICES — truthful sports phases

Baseline `d2468a947c4850103aaabdb3544370bfcb91af66`; assignment `docs/assignments/S4.md`. Clean/branch-absence checks preceded creating `codex/joe-tv-services-s4`; prior branches are preserved. Exact source/test commit: `ef8945acaddd6d1d67e5b3da03b60853857622f5`. Final report commit/clean status accompany the handoff.

## Correction

`SportsEventPhase.unknown` represents insufficient timing evidence and is excluded from both Live/Upcoming by the existing policy filter. Playability, datecode, generic status or live transport type alone never establish a live game. Explicit completion/replay retains precedence. Delayed, postponed, canceled/cancelled, suspended, abandoned, unknown and TBD statuses yield unknown. Otherwise valid structured dates determine future/current/ended phase at the caller's clock; generic Live/Upcoming cannot bypass them. The existing five-hour no-end inference remains bounded, with no new freshness SLA. Word-aware status recognition prevents quarterfinal/semifinal (and Final Round/Final Four) tournament labels from implying completion.

ESPN+ parsing retains replay evidence, published status and structured dates instead of manufacturing permanent Live/Upcoming labels at parse time. Fractional ISO timestamps now work alongside existing plain ISO, numeric and provider date forms. The established time-only plus requested-day/calendar behavior remains; no localized display-only string is converted into an invented absolute date. Provider IDs, date/feed matching and playback resolution are unchanged.

The separately allocated shared studio list adds only Good Morning Football and SEC In 60/In60. No other taxonomy change. The 15-minute pregame availability helper is unchanged: a known upcoming event becomes watchable before becoming live. Unknown phase does not remove the underlying transport; App owns its neutral copy and enum-switch compatibility.

## Evidence and limits

Fresh `scripts/team-check.sh smoke` passed on the final implementation. Fixed-clock regressions use September 17, 2026 at 15:15 UTC and cover missing enrichment/time, future+Live, ended+Live/Upcoming/Scheduled/in-progress, the five-hour boundary, invalid ranges/dates, actual in-window game statuses, disrupted/conflicting signals, final/replay, quarterfinal, parser-to-start/end advancement, fractional/offset/time-only dates, tomorrow/stale rows, consolidation conflict, studio exclusions, stable ESPN+ identity/date/feed, and start−901/start−900/start coverage. Existing timeless ESPN+ Live expectation was replaced with unknown. Existing series/datecode/replay/feed tests still pass.

Staged/full-diff whitespace checks passed. Only the pre-existing macOS FairPlay API deprecation warning was emitted. Local ignored output: `.build/s4-parser-smoke.log`. Changed files: owned sports portions of `Models.swift`, `HTMLCatalogParser.swift`, affected `ParserSmoke.swift` regressions, and this report.

No app build, simulator, network, private configuration, normal cache/account or playback operation ran. Source/smoke success is not configured-app or on-screen acceptance. PM/App/QA handle integration, enum compatibility, configured build and normal-session evidence. Untimed unenriched games intentionally remain unknown until timing exists; this does not repair missing build configuration. Time-bounded inference is still not proof of real-time game status or scores from a daily publication. No polling or provider freshness architecture was added.
