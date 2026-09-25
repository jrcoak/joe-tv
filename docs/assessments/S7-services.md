# S7 — NFL scoreboard request repair

- Assignment: S7-FIX Services
- Baseline: `234072927fea47a842921a4d66d20e983dbc89a7`
- Branch: `codex/joe-tv-services-s7`
- Scope: direct Fantasy NFL scoreboard request, shared NFL calendar helper and dedicated offline request tests

## Result

`ESPNScoreboardClient` no longer sends the unsupported `dates=start-end` query that returned HTTP 400 during the September 24 incident. It now uses the observed working current-week scoreboard request with only `limit=100`. The existing 20-second successful-response throttle, injected `referenceDate`, parser, response validation and thrown error behavior remain intact. Failed responses still do not replace the last successful cache; a healthy empty response remains a successful cacheable result.

`NFLScoreboardCalendar` is a pure shared helper with an explicit `America/New_York` Gregorian calendar. `window(containing:)` returns the Eastern start of the reference day, an exclusive Wednesday-midnight cutoff after Tuesday, a stable date-window identity and `contains(_:)`. `throughTuesdayCutoff(containing:)` exposes the cutoff directly for the App-owned Fantasy projection. The Client keys its throttle cache by that identity, preventing a cached prior Eastern day from crossing midnight even when fewer than 20 seconds elapsed.

## Verification

- `scripts/test-espn-scoreboard-client.sh`: passed. `URLProtocol` intercepts every request and proves the actual Client sends only `limit=100`; HTTP 400 is rejected; retry can accept a healthy empty result; empty success is throttled; a later response recovers with event `401872948` at `2026-09-25T00:15Z`; the parser remains unchanged; and the Eastern day/window identity changes correctly across midnight without using the unsupported range.
- `scripts/team-check.sh smoke`: passed. The existing FairPlay deprecation warning remains.
- `git diff --check`: passed.

No provider request, credential read, simulator, app build, playback probe, publisher change, deployment or release was performed. App owns replacing its `Calendar.current` Tuesday cutoff and presenting scoreboard failure/delay. PM owns the separate Mac publisher repair and Sports playback investigation.
