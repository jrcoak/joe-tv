# S7-FIX — Thursday football repair

September 25, 2026. Joe authorized local fixes after the S7 incident investigation. Base Joe-TV only; Plex and SHELF excluded. Governing assignment: `docs/assignments/S7-fix.md`, adapted team/product instructions. Application baseline `2340729` (release source `a85951f`/`e274cdc`, version 1.0 (9)). No build number, signing, caption policy or bundle identity changed.

## Implemented

- Fantasy requests ESPN's current NFL week using only `limit=100`, avoiding the rejected date range. A shared America/New_York calendar controls the through-Tuesday cutoff and cache identity. The 20-second success throttle and error/cache behavior remain intact.
- Fantasy visibly distinguishes loading, a successful empty result, unavailable scores, and retained stale scores. Retry never displays raw provider errors. Header Down reaches Retry when no content exists, and reaches stale Retry before stream cards when scores are stale; Up returns to the header.
- Direct-HLS dynamic football selection refreshes `/Player` metadata with an explicit uncached GET, then the existing current-week/game metadata. Exact stable event identity plus semantic feed/live-DVR identity must match uniquely. Missing/ambiguous choices fail clearly. Fresh URLs are not borrowed from other events or feeds. Other player/DRM routes remain intact.
- Mac publisher now uses individual ESPN dates across every configured league, includes the preceding Eastern date to cover UTC-midnight starts, trims to the configured UTC publication window and deduplicates repeated event IDs. Up to two scoreboard requests run concurrently; leagues serialize. Default four-league window uses 44 calls; configured bounds allow 40 dates per league, up to 20 leagues. Failed/malformed days abort before replacing output; nontransient 4xx are not retried and response bodies are not logged.

Playback corrects a confirmed stale-link hazard. It does **not** establish the exact cause of September 24's failed stream, and neither simulator nor metadata checks establish FairPlay playback success.

## Commits and ownership

Joe-TV integration branch `codex/tnf-investigation`: Services `b6bef89`; App `9a4c6eb`, `7809249`, `67fc994`; Playback `12f239b`, `646735a`; PM isolated DEBUG fixture/assignment `54610f7`; QA report `6ab95f5`. Application candidate `67fc994`. Services and Playback used Sol medium; App used Luna medium; independent QA and SecOps used Sol medium. No new tasks or agents were created.

PersonalMediaAPI baseline `936ad86`; repair branch `codex/tnf-publisher-fix`, commits `814254b` and final `a076dbb`, in isolated worktree `/tmp/joe-tv-s7-publisher`. Original API checkout/branch left intact. Changed files: `deploy/mac/sports-schedule/fetch-sports-schedule.mjs`, `deploy/README.md`, `tests/SportsSchedulePublisherAcceptance.sh`, new `tests/SportsScoreboardRequestAcceptance.mjs`. The hosted ASP.NET API did not change.

## Verification

- `scripts/team-check.sh smoke`: passed after integrated shared-source changes.
- `scripts/test-espn-scoreboard-client.sh`: passed; real URLSession requests intercepted by URLProtocol, query/400/recovery/throttle/empty and Eastern rollover assertions.
- `scripts/test-football-playback-refresh.sh`: passed 35 checks, including refreshed signature, stable projection identities, feed/live-DVR preservation, missing/ambiguous feeds and cache policy.
- `scripts/team-check.sh build`: unsigned Debug tvOS Simulator build passed on `646735a`. Final `67fc994` build/UI checkpoint recorded below.
- Publisher: `dotnet test PersonalMedia.Api.slnx` passed 37/37 with .NET 10.0.401 in temporary SDK; BoundaryAcceptance, DeploymentAcceptance, SportsSchedulePublisherAcceptance all passed after final `a076dbb` source. Publisher suite includes offline HTTP interception, four-league 44-call window, maximum 40-date bound across DST/month rollover, concurrency, dedup, empty, malformed and 400 preservation cases.
- Public metadata check: NFL-only repair returned event `401872948` (Atlanta Falcons at Green Bay Packers, 2026-09-25T00:15Z, Final). Full configured verification then exposed MLB's same rejected range, prompting the all-league correction. Final full-window run succeeded with 156 events: 17 NFL, 78 MLB, 1 NBA, 60 NHL. These checks wrote only local `/tmp` snapshots, with details disabled and no publication or credentials.
- Independent QA reviewed exact app `646735a` and publisher `a076dbb`, with no source blocker. SecOps accepted fixed HTTPS origins, credential/log handling, bounded requests, failure preservation and feed identity checks. Final UI delta review noted below.

## Native and operational limits

PM S7-FIX-UI owns only dedicated QA simulator C95B257D-0111-40A1-9D02-2AD70D850FF8. Error fixture renders “NFL scores unavailable”; Down from Fantasy controls focuses Retry Scores and Up returns to Fantasy controls. Stale fixture retains all score and watch cards with the warning. True-empty fixture renders its own refresh state, and loading shows progress without falsely declaring no games. Native stale Retry navigation follow-up is `67fc994`. DEBUG fixture Retry intentionally does not contact a provider; HTTP retry/recovery was tested separately, not claimed as end-to-end live UI recovery.

`joes-mac-mini.local` was found in existing SSH trust and advertised by Bonjour, and was reachable. Batch authentication as `josephcoakley` was rejected. Correct account/authentication method requested from Joe without asking for a password in chat. Installed publisher revision/logs remain uninspected. **The production publisher has not been updated or republished.** Local success does not repair that deployment until access is available.

No authenticated Seasons4U playback probe, physical Apple TV test, main push, release merge, TestFlight upload, production API deployment, credential/access change or remote installation occurred. User's other booted simulator was untouched. A serialized hardware check remains necessary for current football playback and FairPlay; exact incident error/feed/time details are still unavailable.

## Final checkpoint

Final app candidate `67fc994` built successfully with `scripts/team-check.sh build`. QA accepted the final stale Retry delta by source review. PM verified native header Down → stale Retry, Retry Down → first watch card, and Retry Up → Fantasy controls. Earlier no-channel error Down/Up, loading, empty and retained-card states passed visual verification. No further code changes followed this build.

The fixture was terminated and dedicated QA simulator C95B was shut down, verified afterward. The user's E98B simulator remained booted and untouched. S7-FIX-UI runtime ownership is released. Source is committed locally; publisher deployment/authentication, hardware playback evidence and release are outstanding.

## Mounted-share follow-up — September 25

Joe clarified that direct file access is available. Verified SMB home share: `/Volumes/josephcoakley`, mounted from Joe’s Mac mini. Command-line reads fail with `Operation not permitted` even outside the sandbox, but the existing Finder connection can read/copy files. SSH authentication is therefore not required for file installation; its earlier failure is no longer the deployment access blocker.

Using Finder, PM copied only the installed publisher script, launch shell script, sports LaunchAgent plist and error log into `/tmp/joe-tv-s7-mini-inspect` for read-only comparison. No environment/credential file was copied or displayed. The installed publisher exactly matches the `936ad86` repository baseline, SHA-256 `2ba7af0cb32a0f831e9a42dca917af552baccb2e1f419cdcfcc2882ae571c12a`. Its error log contains nine HTTP 400 / “Failed to get events endpoint” failures; there are no per-entry timestamps to attribute them individually to September 24. The installed LaunchAgent runs the existing shell script daily at 03:00 and at load.

A rollback file was copied through Finder to `/Volumes/josephcoakley/sports-schedule/backups/fetch-sports-schedule.before-s7-20260925.mjs`. The tested replacement is PersonalMediaAPI `a076dbb`, SHA-256 `ae10fbf4f119a774280196a34041e4016b76f44c11102d84f11084e51b79b515`.

Automatic approval review rejected pasting/replacing the live publisher, stating that fixing code and direct file access did not clearly authorize this specific production installation. PM did not retry or route around the rejection. Explicit deployment approval was requested via the pending question. The original production script, job configuration, credentials and published data remain unchanged; the only remote write so far is the rollback copy. SMB file access does not itself provide remote process execution or prove a refreshed publication.
