# S8 live-game incident — September 27

Baseline `29fb03c`, released app `ff68e4b` (1.0 build 10). Joe reports no available live games in both Sports and Fantasy Zone around 12:51 EDT. Assignment: `docs/assignments/S8-live-games.md`. No source modification, build-number change, release or production mutation has been made.

## Measured

- At 12:53 EDT, the production schedule returned HTTP 200, generated `2026-09-27T07:00:05.9Z`, window September 26–October 5, 147 events. The daily publisher ran successfully after yesterday's repair.
- ESPN's current-week NFL request returned HTTP 200 and 16 games. Both sources contain the nine Sunday games starting at 13:00 EDT, including Patriots/Jaguars. At inspection those games were scheduled.
- An ignored Swift diagnostic compiled the released parsers, enrichment and phase/filter policy against both actual responses. At 12:53 it produced Sports NFL Live 0 / Upcoming 15 and Fantasy Live 0 / Upcoming 15. At a supplied 13:01 reference time it produced Live 9 / Upcoming 6 for both. The latter is a deterministic clock simulation, not an observation of Joe's Apple TV or proof of stream availability.
- Scheduled status in a daily snapshot does not freeze events as upcoming. Time advances their phase at kickoff; terminal/disrupted status retains precedence.

## Confirmed policy mismatch and limits

`sportsPlaybackAvailable(at:)` permits an available upcoming feed at T−15 minutes, but `SportsEventGuidePolicy.filteredItems(.live)` excludes it until kickoff. Such feeds remain in Upcoming. Fantasy falls back to upcoming score cards when no game is live. This explains the pre-kickoff Live count, but does not explain absent Fantasy cards or prove why a particular stream is unavailable.

`AppModel.makePlaybackSession(for target:)` and Quick Switch eligibility require live phase. This prevents returning to a pregame stream through Quick Switch. Initial selection instead calls `makePlaybackSession(for item:)` directly and is not blocked by that target guard. An early investigation hypothesis that the target guard blocked initial play was corrected after tracing callers; it is not an established cause of Joe's report.

Provider catalog refresh/matching and stale device caches remain hypotheses without device evidence. A schedule match without a provider feed legitimately creates an unplayable event row. No Seasons4U playback, provider catalog probe, simulator operation, Apple TV inspection or credential disclosure occurred. The user was asked whether titles are missing or visible but unplayable; that distinction remains pending.

Services independently reviewed phase and enrichment code using GPT-5.6 Sol, medium, with no edits or runtime use. PM's isolated `.build/s8` diagnostic compile completed successfully; S8-DIAGNOSTIC compilation ownership is released. No simulator or shared device state was changed.
