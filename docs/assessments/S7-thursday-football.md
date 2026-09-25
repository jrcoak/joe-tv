# S7 — Thursday football incident investigation

September 25, 2026. Joe reports that Thursday Night Football would not play from Sports in Joe-TV 1.0 (9), and the game did not appear in Fantasy Zone. This assignment is investigation only. No application source, deployed service, provider session, simulator, credentials or release was changed.

## Baselines and ownership

- Base Joe-TV release source `a85951f`, current main `e274cdc`; their application source is identical. Build8 comparison `46256bc`.
- PersonalMediaAPI local checkout `/Users/joecoakley/PersonalMediaAPI`, clean at `936ad86`. Installed Mac mini publisher revision and job status remain unverified.
- PM inspected Sports selection/resolution, metadata publication and the backend publisher source. Existing Services and Playback specialists independently inspected Fantasy data and player regression risk, both using Sol medium. No new tasks or runtime sessions were created. SHELF and Plex were excluded.
- Official [NFL Thursday schedule](https://www.nfl.com/schedules/2026/prime-time/thursday-night-football) identifies Atlanta at Green Bay on September24, 8:15PM Eastern. Public ESPN metadata identifies event `401872948`, kickoff `2026-09-25T00:15Z`.

## Confirmed current failures

1. **Fantasy's ESPN range request fails.** `ESPNScoreboardClient.swift:14-45` sends `dates=20260924-20260929&limit=100` for Thursday in Eastern time. Services executed that public request on September25: HTTP400, `Failed to get events endpoint.` The same endpoint with `dates=20260924` returned HTTP200 and the game (now Final); default current-week and `seasontype=2&week=3` requests returned HTTP200 with all16 games. These are current observations, not recovered September24 responses or proof of when range behavior changed.
2. **Fantasy hides the failure.** `AppModel.swift:768-781` sets `fantasyNFLScoreState=.failed` and retains the previous array. `JoeTVExperience.swift:1412-1475` does not display this state. A first-load failure therefore produces no game cards, and the30-second refresh loop repeats it silently. No provider stream is needed for an ESPN score-only card.
3. **Ordinary Sports publication is stale.** PM made one read-only request to the existing Personal Media API sports/schedule route using its existing scoped Internal read token, without printing/storing the token. Response: generatedAt `2026-09-15T07:00:06.142Z`, window September14–23, 181events. September24 TNF is outside this snapshot. This is a separate path from Fantasy's direct ESPN request.
4. **The publisher has the same failing request pattern.** `PersonalMediaAPI/deploy/mac/sports-schedule/fetch-sports-schedule.mjs:28-64,96-111` requests ranges and awaits each league before writing a snapshot. PM's exact first NFL query for today's default window, `dates=20260924-20261003&limit=500`, returned HTTP400. The uncaught failure prevents writing; `run-sports-schedule.sh:47` runs under `set -e`, so publication never executes. This is a strong source-level explanation for stale publication; actual installed-job/log causation still needs the Mac mini address and inspection.

## Sports playback: unresolved exact incident cause

No September24 device log, selected feed or error text is available yet. We did not request an authenticated provider stream; an expired past-event link cannot establish what failed during the game.

Build9 did not change AppModel, SeasonsClient, HTMLCatalogParser, ESPNScoreboardClient or FairPlayResourceLoader. The caption addition uses a legible-only output; installed SDK documentation says other media is unaffected. Playback starts independently of caption loading. There is no demonstrated path where the caption rendering gate suppresses video/audio. Build9 does begin async subtitle-group loading earlier, so a DRM-sensitive metadata-load interaction remains an unproven regression hypothesis, not ruled out by source review.

Existing hazards relevant to a targeted reproduction:

- Football direct HLS links are built from a signed template captured at catalog load (`HTMLCatalogParser.swift:371-377,894-916`) and used directly on selection (`AppModel.swift:1211-1214`). No refresh-at-selection or failed-link refresh exists; catalog reload is explicit. A stale signature is plausible if the app remained open, but no incident expiry was observed.
- Dynamic DRM entries expose separate U.S. and International pages without validating either (`HTMLCatalogParser.swift:875-887`). Which option was selected matters; there is no automatic alternate-feed recovery.
- A failure before entering the player occurs during stream resolution or DRM-page parsing, before caption code runs. A full-screen preparation timeout or item failure implicates the manifest/item/DRM stage instead.
- Release builds discard the underlying AVPlayer/FairPlay error domain/code and do not capture stall/waiting/access/error-log state. A ready item that stalls cancels the preparation timeout and can remain black. Certificate/license HTTP200 login content is not recognized as an authentication failure by `authenticatedData`.
- Stale ordinary metadata can prevent new NFL listings from being matched to current stream entries. Fantasy attaches playback only by matching ESPN event IDs against consolidated Sports. Missing playback association would leave a score-only card; it does not itself explain a missing Fantasy score card.

## Recommended bounded correction

Repair the ESPN request strategy in both consumers, preserving Mac-published ordinary metadata and direct Fantasy scores. A current-week NFL request works in observed responses; publisher windows need a bounded supported query strategy rather than silently narrowing coverage. Define the NFL calendar explicitly in America/New_York: a00:15Z Friday kickoff belongs to Thursday's scoreboard. Keep existing through-Tuesday presentation. Add request/HTTP contract tests rather than testing only decoded fixtures and range-string formatting. Surface unavailable/stale scoreboard data instead of silently implying no game. Inspect the installed publisher/job before any remote repair or republish.

For playback, obtain the selected feed, approximate time and visible failure stage first. Then use one serialized, currently valid physical-device probe if needed, with sanitized stage/status diagnostics (never signed URLs, cookies, SPC/CKC or license values). Avoid changing the player based only on the adjacent caption release. Competitor comparison is not relevant to this incident repair: correct listing and playback of an existing supported event is the acceptance target.

Services reran the existing offline parser smoke successfully; that suite does not exercise live ESPN query acceptance and did not detect the failure. No new build/UI/DRM success is claimed. Awaiting Joe's error/time/feed details and Mac mini hostname/IP. No code fix, push, deployment or TestFlight upload occurred during this investigation.
