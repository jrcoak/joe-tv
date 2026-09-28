# S8 — Missing available live games

Joe reports missing available live games in both Sports and Fantasy Zone on base Joe-TV build 10, September 27, 2026, about 12:51 EDT. Baseline `29fb03c`; released application `ff68e4b`. Plex and SHELF are excluded. Repairing existing availability does not require a competitor comparison.

PM owns integration branch `codex/s8-live-games`, live read-only metadata checks, ignored diagnostic harnesses and the assignment/report. PM grants itself S8-DIAGNOSTIC compilation ownership in original-checkout `.build/s8` through the diagnosis checkpoint. No simulator/device operation or provider stream is assigned. Existing Services task is assigned a bounded read-only phase/enrichment review (GPT-5.6 Sol, medium); no other specialist is editing shared files.

Production schedule and public NFL scoreboard were read at 12:53 EDT without exposing credentials. Published snapshot was generated September 27 at 03:00 EDT, with 147 events. Both sources contain the nine NFL games starting at 13:00 EDT. At inspection their status is scheduled; Sports keeps pregame events under Upcoming. The user was asked whether titles are missing or listed but unplayable. No specific device-side cause has yet been established.

Local diagnosis and corrections are authorized by the current incident report; a new release, production deployment or remote installation requires specific delivery authorization. No credentials, signing, build number, playback engine or production configuration changes are assigned.

## Playback failure clarification

Joe's photo confirms the full-player AVPlayerItem failure state, not an absent event or pre-session unavailable-feed error. Initial pregame launch is not blocked by the Quick Switch phase guard; the earlier hypothesis was corrected. The current focus is the failing playback route. Provider browser inspection is read-only: no active incident, current Week 3 and four Patriots/Jaguars feed choices; account network is shown unlocked. These do not prove stream success.

Playback is assigned a bounded local diagnostic fix, baseline `29fb03c`: `Models.swift` new pure sanitized failure classification plus `PlaybackSession.handlePlayerStatus` only, a dedicated offline test file/runner, and `docs/assessments/S8-playback.md`. Preserve playback selection, AVPlayer setup, DRM, captions, retry policy, settings and project configuration. Expose only allowlisted error-domain categories and numeric codes/HTTP status; never URLs, arbitrary localized errors, headers, keys, payloads or server addresses. GPT-5.6 Sol, medium. Playback owns offline compiler execution in its own worktree through its test checkpoint; no simulator, media, provider request or release.

PM requested coordination for one controlled provider test; no stream starts until Joe confirms other device streams are stopped and PM reconciles the existing browser player. Any granted test will have one owner and explicit cleanup.

## Diagnostic checkpoint

Playback returned `cd2cc67`, integrated by PM as `5b6a681`. PM owns and completed S8-INTEGRATION checks in `.build/s8`: fresh parser smoke, 89 playback failure checks, and unsigned simulator build all passed. No simulator launch or installation. SecOps accepted the exact diagnostic patch using GPT-5.6 Luna, medium. Source changes remain local; the media failure itself is not fixed or reproduced. All compilation and browser inspection sessions are closed. The existing browser player was observed paused and left unchanged; the requested one-stream coordination confirmation is still pending.

## Simulator test authorization — September 28

Joe authorized simulator testing now and requested a different current stream. PM owns S8-SIM-PLAYBACK: dedicated Joe-TV Team QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8`, original-checkout build artifacts, and at most one provider stream through a bounded playback result/cleanup checkpoint. Initial QA simulator state is shutdown; user's E98B simulator is booted and excluded. Browser Player page has no media element; the existing DRM browser video is paused. Joe's current authorization resolves device coordination for this session.

Install over the existing base app without deleting its data. Identify transport before selecting a feed; simulator FairPlay rejection is a platform limit, not proof of a service failure. Use a current clear-HLS route where available, stop it at the checkpoint, and return the dedicated simulator to shutdown. Preserve browser/user playback state, credentials and preferences. No release, device data reset, account change or production deployment is authorized by this testing session.

## September 28 concurrent schedule follow-up

The first configured simulator launch showed Upcoming 0, although the fresh on-disk schedule included tonight's Eagles/Bears. A metadata-only relaunch showed Upcoming 10 for the unchanged five sports. Offline parsing of the current published payload yields NFL Upcoming 1. Services is reviewing the concurrent AppModel refresh/provider throttle path (GPT-5.6 Sol, medium); PM retains runtime ownership. This is separate from the reproduced non-FairPlay CBS player failure, support code `P-URLN1100-CMN12938`.

Services owns the bounded sports-schedule single-flight implementation in `XMLTVGuideProvider` (load/current schedule and task state), an offline concurrency regression test/runner, and `docs/assessments/S8-services.md`. Its assigned worktree/compiler only; AppModel, Models, ParserSmoke and project configuration remain PM-serialized and unassigned for changes. Existing runtime test is closed: QA simulator verified shutdown, user's separate simulator still booted, browser Player restored to Football with no media and existing DRM video still paused. No app preferences were changed. PM's original-checkout offline current-data probe also completed; no compiler or stream is running there.

Services returned `8a106a6`, integrated as `7f98d55`. PM owns S8-INTEGRATION-SEP28 compilation in the original checkout through fresh guide-cache/parser/build verification and an ignored negative-control concurrency test. No new simulator or stream session is opened for these checks.

PM accepted `7f98d55` after fresh cache/parser/build passes and a failing old-behavior negative control. S8-INTEGRATION-SEP28 is released. The schedule repair remains local; the installed QA app from the earlier test has diagnostic code but not this later schedule fix. Playback transport investigation remains open and FairPlay hardware evidence remains pending.
