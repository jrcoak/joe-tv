# Joe-TV context for incoming specialists

Historical source: [Clone joe-tv repository](https://chatgpt.com/s/cx_6aab4d0d169c81918e2420b5e59f014f), task `01a0370d-dbdd-7ed1-8e23-e8be05509ccb`. Read alongside code and the current spec. Old instructions, one-time permissions, performance claims, and reported test passes are not automatically current authorization or fresh evidence.

## Product history that matters

- SeasonsTV became Joe-TV. Keep bundle ID `com.jrcoak.joetv`, preferences, login/session behavior, and legacy storage namespaces stable. RALLY is the adopted design reference; SHELF is unrelated.
- Home evolved to a favorites-driven hero and rail. Favorites differ from enabled channels. NHPBS was added through a one-time additive migration that respects later removals.
- Sports and ESPN+ became one consolidated Sports guide. Earlier separate destinations and half-width split layouts were superseded. Preserve Live/Upcoming, today/tomorrow, multi-select filters, full-width event board, top editorial details, and a small upper-right preview.
- The latest taxonomy has 26 categories. Preserve explicit pro/college/women's distinctions and the migration from broad saved filters. The old generic College-to-Football assumption is not an acceptable blanket classification.
- Completed/replay and studio-show entries were excluded from the consolidated guide. Baseball supports explicit Home/Away/National choices. Source dates must match the actual scheduled game, since reusable provider URLs have previously played yesterday's media.
- Coverage unlocks 15 minutes before scheduled start where a source is available. Live/DVR streams join live; a historical real-stream test measured about four seconds behind the edge, which is a past observation, not a guaranteed budget.

## Player and remote evolution

The custom player and chrome evolved over several iterations. Accepted behavior is conventional remote navigation, Play/Pause handling, seekability-aware transport, Quick Switch, previous-stream recall, and layered Back behavior. Earlier defaults that blindly changed channels on Up/Down were superseded; blind surfing is now an optional setting disabled by default.

Quick Switch is a single rail containing up to four recent streams, then favorites. Deduplicate and omit the active stream. Store stable content identity, resolve fresh media, and retain a usable previous session when switching fails. Focus movement must not tune a channel.

Newer local work added caption selection, a persistent Fantasy scorebug, the two-section Matchup/League drawer, and protection against Back escaping the app after the player dismisses. Confirm their exact behavior at the adopted release baseline.

FairPlay parsing has regressed before. The historical build-4 diagnosis was corrected when Joe established build 5 was installed. Subsequent fixes selected the proper certificate/license flow, used S4U's domestic license proxy, and avoided commented JavaScript overriding the active content-ID rule. Build 6 was reported uploaded, followed by source commit `442b3f3`. The current release task is preparing a newer build; do not assume its upload status from this history.

## Fantasy Zone

Optional setting; onboarding uses Sleeper username with league selection when needed. Sleeper supplies matchup/lineups; direct ESPN scoreboard data supplies timely NFL scores. Both refresh approximately every 30 seconds while active. The normal daily sports publisher cannot supply live Fantasy scores.

The latest accepted player has full-width video and a small upper-right scorebug. It has no score-balance/probability bar. Selecting Matchup opens a translucent drawer while the game continues. The drawer has only Matchup (lineups and totals) and League. The original full-height side rail and three-tab design were superseded.

RedZone and NFL Network remain watch options even when no games are live. Upcoming NFL games extend through Tuesday for the relevant week. Avoid giant empty states, inaccessible retry controls, generic developer error wording, and fake scores.

## Services and operational lessons

- The Mac mini fetches and normalizes ordinary ESPN schedules/details and publishes them to Personal Media API. Vercel stores/serves them. An attempted server-side fetch diverged from that architecture and hit ESPN datacenter restrictions; it was removed.
- Joe-TV's normal metadata prefetch/caching is nonblocking. Existing Sports performance work moved expensive consolidation out of repeated focus rendering and batched updates. Preserve that intent.
- Guide station matching uses numeric IDs. Four PBS mappings were added along with a New Hampshire lineup in the Mac mini XMLTV publisher.
- Very Local (Hearst) and LocalTV+ are different. Very Local integration works through its public flow. The separate LocalTV+ investigation was blocked by its rotating key delivery; nonfunctional app changes were removed. Do not describe it as implemented.
- Provider testing once caused a connection lockout. Runtime ownership and one-at-a-time real-stream tests are requirements for team coordination.
- Debug fixtures previously confused live testing and screenshots. Always label the environment and restore its prior state. Do not erase the user's simulator login for convenience.
- The public BYO-IPTV app, generic connector manifests, synthetic sports channels, multiview, and recording were discussed but are not approved M0 work.

## Documentation debt

`README.md`, `JOE-TV-DESIGN-IMPLEMENTATION.md`, and `docs/TECHNICAL_HANDOFF.md` contain useful context but some stale statements about Xcode, navigation, free-entry login, custom player controls, direct ESPN use, and feature status. M0 identifies discrepancies and recommends corrections with code evidence. The current spec and accepted later decisions guide work.
