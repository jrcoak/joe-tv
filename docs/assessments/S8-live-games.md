# S8 live-game incident — September 27

Baseline `29fb03c`, released app `ff68e4b` (1.0 build 10). Joe initially reported no available live games in both Sports and Fantasy Zone around 12:51 EDT, then supplied a photo confirming an AVPlayer failure after selection. Assignment: `docs/assignments/S8-live-games.md`. Local diagnostic improvement `5b6a681` is verified; the underlying transport failure is unresolved. No build-number change, release or production mutation has been made.

## Measured

- At 12:53 EDT, the production schedule returned HTTP 200, generated `2026-09-27T07:00:05.9Z`, window September 26–October 5, 147 events. The daily publisher ran successfully after yesterday's repair.
- ESPN's current-week NFL request returned HTTP 200 and 16 games. Both sources contain the nine Sunday games starting at 13:00 EDT, including Patriots/Jaguars. At inspection those games were scheduled.
- An ignored Swift diagnostic compiled the released parsers, enrichment and phase/filter policy against both actual responses. At 12:53 it produced Sports NFL Live 0 / Upcoming 15 and Fantasy Live 0 / Upcoming 15. At a supplied 13:01 reference time it produced Live 9 / Upcoming 6 for both. The latter is a deterministic clock simulation, not an observation of Joe's Apple TV or proof of stream availability.
- Scheduled status in a daily snapshot does not freeze events as upcoming. Time advances their phase at kickoff; terminal/disrupted status retains precedence.

## Confirmed policy mismatch and limits

`sportsPlaybackAvailable(at:)` permits an available upcoming feed at T−15 minutes, but `SportsEventGuidePolicy.filteredItems(.live)` excludes it until kickoff. Such feeds remain in Upcoming. Fantasy falls back to upcoming score cards when no game is live. This explains the pre-kickoff Live count, but does not explain absent Fantasy cards or prove why a particular stream is unavailable.

`AppModel.makePlaybackSession(for target:)` and Quick Switch eligibility require live phase. This prevents returning to a pregame stream through Quick Switch. Initial selection instead calls `makePlaybackSession(for item:)` directly and is not blocked by that target guard. An early investigation hypothesis that the target guard blocked initial play was corrected after tracing callers; it is not an established cause of Joe's report.

At this initial checkpoint, provider catalog refresh/matching and stale device caches remained hypotheses without device evidence. A schedule match without a provider feed legitimately creates an unplayable event row. No Seasons4U playback or simulator operation occurred. The subsequent photo below resolved the title-versus-playback ambiguity.

Services independently reviewed phase and enrichment code using GPT-5.6 Sol, medium, with no edits or runtime use. PM's isolated `.build/s8` diagnostic compile completed successfully; S8-DIAGNOSTIC compilation ownership is released. No simulator or shared device state was changed.

## User photo and provider inspection

Joe clarified that opening game links produces the full-player failure overlay; his photo shows “This stream could not be played. Return to browse and try again.” This is specifically `AVPlayerItem.Status.failed`, not the preparation timeout or a pre-session missing-feed error. The released UI discards the underlying error evidence. Exact game/feed is not yet identified. The earlier schedule/pregame interpretation does not explain this failure.

PM inspected existing Seasons4U browser context without selecting a feed or playing media. The account's current network is shown unlocked. The current Player catalog selects Week 3 and lists Patriots/Jaguars with four feed rows. The provider status page reports all services operational; this does not prove that individual feeds work. The menu uses channel, channel-int, dvr and dvr-int requests, alternate live/DVR identities, and a separate NFL+ action. No account/access settings changed.

The existing dynamic request routes match the observed US/international and alternate menu call shapes. The relationship between legacy type-14/15 direct-HLS construction and the current NFL+ menu is unverified; no feed has been removed, reprioritized or replaced on that hypothesis. Requests for public JavaScript returned errors and browser asset navigation was blocked; no source was obtained through those attempts.

Playback confirmed player/FairPlay, parser and PlayerScreen source is unchanged between build 9 and build 10, except for the separate AppModel/SeasonsClient selection-time URL refresh. This narrows the investigation but does not prove provider fault. Playback has a bounded safe-error-code implementation assignment. One real-stream test is pending Joe's confirmation that other streams are stopped; no concurrent probe is allowed.

## Local diagnostic acceptance

Playback commit `cd2cc67` was integrated as `5b6a681` on `codex/s8-live-games`. A failed AVPlayer item now produces an allowlisted, bounded support code and a friendly known cause, rather than discarding all failure evidence. No URLs, arbitrary domains, localized error strings, headers, response bodies, identifiers or credential values are included. The existing preparation timeout and media selection/player configuration remain unchanged. See `S8-playback.md` for ownership and limitations; this is diagnostic support, not a demonstrated fix for Joe's stream failure.

PM ran fresh `scripts/team-check.sh smoke`, `scripts/test-playback-failure.sh` (89 checks), and `scripts/team-check.sh build`; all passed on the integrated source. Logs are retained under ignored `.build/s8`, with existing Debug/Internal token values redacted before writing. No simulator was launched. SecOps independently accepted `cd2cc67` with no security blocker (GPT-5.6 Luna, medium). PM build ownership is released.

At 13:05:57 EDT, a further public ESPN read confirmed nine NFL games actually in progress, including Patriots/Jaguars. Provider inspection started no media; the existing Chrome DRM player was observed paused and left unchanged. PM closed its temporary catalog/status/source-inspection tabs. Joe's device test and selection details remain pending; there has been no live playback test, new TestFlight upload, production modification or account/access change.

## September 28 authorized simulator reproduction

PM owned S8-SIM-PLAYBACK, dedicated Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8` (tvOS 26.5), using configured Debug app source `5b6a681`, version 1.0/build 10, installed over saved data. Joe authorized a different stream and current simulator testing. Existing browser DRM video was paused and Player had no media; no browser stream was started. User's separate booted simulator was excluded.

- The current Sports listing, The Aftermath (ESPN+), raised the explicit FairPlay-requires-device alert before any player/media session. This establishes that particular route is configured as FairPlay, not that all sports feeds are. The incident photograph remains ambiguous about transport.
- PM tested the non-FairPlay CBS - New York route (`legacy:bkb:channel:5012`) through Live TV, first its normal muted preview, then the full player after preview teardown. Full player failed with `P-URLN1100-CMN12938`, observed around 14:56 EDT. The URL error is `URLError.fileDoesNotExist`; neither that nor the numeric CoreMedia observation identifies an HTTP status or whether the main manifest, child playlist, or segment failed. No raw error comments, URLs, headers, tokens or response bodies were exported. This reproduces a non-DRM AVPlayer failure; it does not establish that Joe's NFL feed has the same cause.
- The resolver POST must have returned a parseable HLS URL to reach this full-player state. Current app cache has no retained resolver or manifest response for offline analysis. No extra manifest/media network probes were run. The app was terminated after the failure.
- First launch displayed Sports Live 1 / Upcoming 0 and unknown-timing notice under Joe's existing five-sport filter. Its disk schedule had already refreshed to September 28's 131-event snapshot, including tonight's Eagles/Bears. The identical published payload passes an offline parse/enrichment/consolidation probe and yields NFL Live 0 / Upcoming 1 at 15:00 EDT; public ESPN agrees.
- A metadata-only relaunch displayed Upcoming 10 and visibly showed Eagles/Bears at 20:15, coverage beginning 20:00. No filters were changed. This supports the concurrent schedule refresh/cache race under investigation, separately from the player failure. Services has a bounded single-flight fix/test assignment.

Playback independently reviewed the support code using GPT-5.6 Luna, medium. Resolver shape, child-resource access and format/decoder failure remain competing hypotheses. Do not add cookie/header forwarding, retry loops or feed substitutions without evidence. Exact failing NFL route and hardware FairPlay playback remain unverified. No release or production changes were made.

## Schedule correction acceptance

Services `8a106a6` was integrated as `7f98d55` on `codex/s8-live-games`. Shared in-flight sports requests now return the same fresh snapshot or error; success/failure cleanup preserves later refreshes. Existing guide loading, cache validation, conditional requests, authorization and transport fallback are unchanged. See `S8-services.md` for the source-confirmed race and precise scope. The first simulator run was not instrumented with request IDs, so that exact interleaving remains an inference from the source and observed first-launch/relaunch difference.

PM independently reviewed the change and reran `scripts/team-check.sh smoke`, `sh scripts/test-guide-cache.sh`, and `scripts/team-check.sh build` on the integrated source: all passed. Fresh logs under ignored `.build/s8/sept28-*-redacted.log` redact private configuration values before writing. A separate ignored negative-control provider reinstated the original uncoalesced behavior with only a second-entry test signal; the same regression then failed with “sports: overlapping refresh returned stale cached content” (exit 133). This demonstrates the stale-result failure independently of the fixed implementation's join observer. No real network was used by these regression tests.

The integrated fix was compiled, not installed or tested on Apple TV. No new simulator session was opened after cleanup. Dedicated QA device is confirmed shutdown, user's separate device remains booted and untouched, browser Player is restored to Football with no media, and the existing browser DRM player remains paused. S8-SIM-PLAYBACK and S8-INTEGRATION-SEP28 are released. No push, TestFlight upload, account change or production deployment. The reproduced CBS transport failure and original NFL/Fantasy playback failure remain open; schedule correctness does not prove playback correctness.
