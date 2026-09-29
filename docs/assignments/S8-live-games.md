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

## S8-TRANSPORT — resumed September 28

Joe requires the original playback failure resolved and the earlier simulator-test authorization remains applicable. PM owns S8-TRANSPORT: serialized provider resolver/playlist inspection and, if needed, dedicated QA simulator C95B only, through a discriminating result and cleanup. At 16:37 EDT browser Football has no media and existing DRM video remains paused; no team stream is active. User's separate simulator remains excluded. Do not change account/network authorization or relax TLS. No release authorization is inferred.

The first bounded trace will reuse only the dedicated QA app's existing Seasons4U session in memory to call its existing resolver and inspect at most a master and one child playlist. No credential copy/export, bulk scanning, video download, or parallel stream. Output only allowlisted HTTP/transport/content-shape facts, never cookies, signed URLs, raw headers/bodies/license values. PM owns ignored harness files and evidence. Existing shared app code is unchanged pending a demonstrated repair.

### Confirmed request-identity mismatch

The bounded CBS resolver returned HTTP 200 and one parseable HLS URL. The exact same freshly resolved master returned 403 under the default Python identity and 200/valid unencrypted HLS under `Joe-TV/1.0 (AppleTV; tvOS)`, without cookies or Origin/Referer. A separate Joe-TV plus Origin/Referer request also returned 200. Child inspection stopped at the host-scope guard; no child, media segment or key was fetched. These are transport observations, not AVPlayer success. The native player currently drops the resolver identity by constructing bare AVPlayerItem(url:).

Playback owns a bounded repair from `d0f4de5`: optional HTTP user-agent support in PlaybackSession's URL initializer (Models.swift), the relevant S4U clear/resolved-HLS AppModel call sites, and a single shared SeasonsClient request-identity constant replacing its identical literal. Use public AVURLAssetHTTPUserAgentKey (local SDK confirms tvOS16+, app minimum17). Explicit shared-symbol assignment granted. Preserve public Very Local/PBS, debug fixtures, FairPlay license/key handling, existing DRM construction, navigation/captions/settings. No cookie/header forwarding, credentials or retry/fallback additions. Playback may run offline tests/compiler in its own worktree; PM retains all provider/runtime/build ownership. Model GPT-5.6 Sol medium. SecOps reviews exact change; PM performs final simulator reproduction.

### Repair acceptance and session closure

Playback `8df76ea` was integrated as `c59d175` after SecOps acceptance. PM passed fresh parser smoke, 89 playback-failure checks and configured simulator build, then verified advancing video from the previously failing CBS route. QA independently reviewed all three S4U construction paths and passed 35 football-refresh checks; report `ace9904` was integrated as `24f59ef`. QA and SecOps used GPT-5.6 Luna medium; Playback used GPT-5.6 Sol medium. Their bounded assignments are complete.

The app was terminated and dedicated QA simulator shut down; a fresh simctl inventory confirms only Joe's excluded E98B simulator remains booted. Browser playback was left unchanged. S8-TRANSPORT and all compilation ownership are released. Installed QA app retains saved data and is version 1.0/build 10 from source `c59d175`; no release number, signing, account or production configuration was changed. The candidate is locally accepted for the reproduced clear-HLS repair, with original NFL-feed and hardware FairPlay validation still pending. Push/main integration and the next TestFlight delivery require Joe's specific authorization.

### S8-RELEASE-11 — September 29

Joe approved the explicit main push and build 11 TestFlight delivery: “yes. push the build to testflight.” PM owns project version changes, release documentation, main integration/push, exclusive original-checkout checks, signed physical-tvOS archive and upload through completion. Starting source `54e45cc`; freshly fetched origin/main `29fb03c` is an ancestor, with no divergent changes. All prior specialist runs are complete. No simulator, provider stream, credential change, publisher deployment or tester-setting change is assigned.

Version remains 1.0; build advances 10 to 11. Use isolated `.build/Release11DerivedData` and `.build/releases/1.0-11`, existing Release/Internal configuration and signing. Rerun parser, guide-cache, failure-diagnostics, football-refresh and configured simulator compilation on the release candidate; then signed archive/configuration preflight. SecOps receives a bounded read-only release-wrapper/configuration review using GPT-5.6 Luna medium. Keep private values out of source and logs. Release success requires the upload receipt; tester availability requires separate Apple status evidence.

Completed: release source `4ef845f` pushed to main; all assigned release checks and strict code-signature verification passed. SecOps accepted the wrapper/configuration review without blockers. Apple accepted 1.0/build 11 at September 29 09:47:19 EDT and reported processing/upload success; export exited 0. App Store Connect browser is signed out, so tester availability remains unconfirmed. No tester settings, simulator, provider stream or production service changes occurred. S8-RELEASE-11 ownership is released. See `../releases/1.0-11.md` for receipts and limitations.
