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

## S4 studio follow-up observed during S5 QA

Assignment: PM's bounded S4 studio follow-up, TEAM-4; baseline `228fb4eedc13dc28b6410115dd9f41283a2c0399`, clean branch `codex/joe-tv-services-s4-studio`. QA reported that metadata enrichment added ESPN+ “NFL Total Access” to Live, then observed “ACC Network Football Podcast” after enabling NCAAF. Added only those two title phrases to the existing `SportsCategoryClassifier.isESPNStudioProgramming` exclusion list used by `SportsEventGuidePolicy.consolidatedItems`. No timing, phase or provider request behavior changed. Competitor parity does not apply: this corrects an observed violation of the accepted game-only guide contract.

Fixed-clock regression in `Tests/ParserSmoke.swift` supplies playable, enriched, in-window listings for both shows with “Live coverage”, including uppercase title normalization. It verifies consolidation excludes the shows while retaining NFL and college-football games and the correct Live result/count. Game timestamps are synthetic fixtures, not an assessment of QA's observed Towson game status. Fresh `scripts/team-check.sh smoke` passed after the NFL change and ran again after PM supplied the additional observed ACC title; the final combined run passed (exit 0; existing FairPlay macOS API deprecation warning only). `git diff --check` passed. Local ignored final log: `.build/s4-studio-smoke.log`. Changed files are `Models.swift`, `ParserSmoke.swift`, and this appended report; exact source commit accompanies the PM handoff.

No simulator, app build, configuration, backend or network work occurred. Integrated normal-session verification remains with PM/QA; no deployment or device step is introduced by this source change.
