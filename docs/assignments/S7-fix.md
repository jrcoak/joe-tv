# S7-FIX — TNF playback and missing Fantasy score repair

Joe authorized fixes on September25, 2026 after the S7 investigation. Scope is base Joe-TV 1.0(9), not the Plex fork. Baseline Joe-TV2340729 (applicatione274cdc/a85951f), PersonalMediaAPI936ad86. Competitor comparison does not apply to repairing supported existing behavior.

## Ownership

- PM/Integrator: local integration branch `codex/tnf-investigation`, shared reports, DEBUG Fantasy fixture isolation/states in AppModel initializer and configureFantasyZoneDebugFixture, final tests. PersonalMediaAPI publisher code/tests/docs in isolated `/tmp/joe-tv-s7-publisher`, branch `codex/tnf-publisher-fix`.
- Services: existing task/worktree, ESPNScoreboardClient + dedicated HTTP tests/runner, narrow old ParserSmoke date helper assertion. Sol medium.
- Playback: existing task/worktree, SeasonsClient football refresh and AppModel makePlaybackSession(item,option) only, dedicated tests/runner. Sol medium.
- App: existing task/worktree, JoeTVExperience Fantasy status/retry/calendar/focus only. Luna medium.
- QA: existing task/worktree, independent bounded source/test review. Sol medium. No reviewed code edits.
- SecOps: existing task/worktree, bounded source review across both repositories and player refresh. Sol medium.

No new agents, persistent tasks, automations, release, push, or live-stream probes. Specialists are not assigned simulator/build ownership. Existing user simulator and Plex simulator are excluded.

## Runtime grant

PM owns S7-FIX-UI: dedicated `Joe-TV Team QA` simulator C95B257D-0111-40A1-9D02-2AD70D850FF8 and main-checkout `.build/TeamDerivedData`, through final combined build/UI checkpoint. Initial device state: shutdown. Offline DEBUG Fantasy loading/failed/stale/empty states only; no authenticated stream. Install over existing app without deleting data; debug preferences isolated. PM terminates fixture and shuts this dedicated device down on completion. User's booted E98B device is untouched. No physical FairPlay success is implied.

## Deployment boundary

Publisher local tests do not repair the installed Mac mini. `joes-mac-mini.local` is discovered/reachable but batch SSH as josephcoakley lacks authentication; await the existing connection method. No credentials requested in chat, no remote mutation yet. App release requires specific delivery authorization after this candidate is reviewable. Exact September24 stream failure cause remains unproven; stale-link fix is a confirmed code hazard repair.

## Runtime closure

S7-FIX-UI released September 25 after final `67fc994` simulator build and status/focus checks. Dedicated QA device was shut down; user E98B device left booted. See `docs/assessments/S7-fix.md` for results and operational blockers.

## Direct file access and installation approval

September 25 follow-up: the Mac mini home share is available in Finder at `/Volumes/josephcoakley`. Installed source/log/job inspection is complete and rollback is staged. Automatic approval review blocked the specific production script replacement; an explicit install approval question is pending. Do not use another route to perform that rejected replacement without approval. Details and hashes are in `docs/assessments/S7-fix.md`.

## Installation completion

Joe approved the specific publisher installation on September 26. PM replaced the script through Finder/SMB and verified the remote read-back hash matches `a076dbb`. The prior review block is resolved. Production publication remains pending the configured job run or an authorized remote execution method; no job configuration or credentials changed. See the installation checkpoint in `docs/assessments/S7-fix.md`.

## Publication completion

Joe ran the existing publisher manually on the Mac mini. September 26 API checks confirmed fresh schedule and event details, including Thursday's game. Publisher deployment is complete; app release and physical playback validation remain separate. See the production verification checkpoint in `docs/assessments/S7-fix.md`.

## App release authorization — September 26

After fresh production metadata verification, Joe authorized the proposed next TestFlight build. PM owns S7-RELEASE-10, including the 9→10 project build-number change, final release checks, main integration/push, signed archive and upload. All runtime/build resources are exclusively PM-owned until upload completion; no simulator or provider stream is needed. Release record: `docs/releases/1.0-10.md`. No new tester, credentials or distribution policy changes are included.
