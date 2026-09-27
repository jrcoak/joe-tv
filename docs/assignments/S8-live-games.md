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
