# S1/S2 resumed UI QA — access checkpoint

Status: **UI NOT OBSERVED; acceptance remains pending.** Checked September 17, 2026. Assignment: PM's bounded S1/S2 UI resumption, TEAM-4 quality cycles; only this report is owned/changed. Branch `codex/joe-tv-qa-s2-ui` created after clean-status and branch-absence checks from exact PM revision **`638a75a57a3db6bc31355c1d45adfb38ad7aa7bf`**. Prior branches and evidence retained. Read the supplied AGENTS instructions and candidate `docs/sprints/quality-cycles.md`; pending sequences and source provenance remain in `S2-qa.md`.

## Fresh access observations

1. First supported read-only CUA call, `cua.getState()`, **succeeded**, returning app/browser inventory and listing Simulator as running. It did not report a locked Mac. An app inventory alone does not establish usable Simulator input or current screen state.
2. Selected that listed app with `cua.getApp("com.apple.iphonesimulator")`. It failed with **`Computer Use server error -10005: timeoutReached`**. No Simulator accessibility tree or screenshot was returned, and no app interaction was possible.

No auto-unlock command, credential entry, lock bypass or alternative input mechanism was attempted. The prior locked-state result is historical; this checkpoint establishes a **CUA app-access timeout**, not that the Mac is currently locked. PM was informed promptly. No corrected guide outcome, Channels layout observation or new PNG can be claimed.

PM subsequently authorized exactly one bounded retry selecting the already-listed Simulator with a longer tool execution timeout. Repeated `cua.getApp("com.apple.iphonesimulator")` with `timeout_ms: 60000`; the server again returned **`Computer Use server error -10005: timeoutReached`**, after approximately 5.5 seconds. The longer outer limit did not resolve the connection failure. No tree/screenshot or lock message was returned. Runtime attempts stopped after this retry; UI access remains unavailable, and current lock state remains unestablished. No simulator commands or input followed. Report baseline remains `638a75a` as explicitly permitted by PM; its later stream-preference documentation revision does not change the tested artifacts.

## Preserved artifacts and runtime scope

Rechecked both preserved debug-dylib hashes before the access attempt; they match the previous QA records:

| Bundle | Tested build source | Debug dylib SHA-256 |
| --- | --- | --- |
| `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-corrected-artifact/Joe-TV.app` | `d010f395bcae7b66e46a6b50168005005f0ba9b2` | `47082a5872b5302a6aeba49144253b50500c9d411c4849dcdd0dbb5bdb6c6008` |
| `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S2-combined-artifact/Joe-TV.app` | `bbb60d6effc7536e27b931899c8915d38e6449c2` | `9052881cc59d77235fdb5501e51e2048216c2ff4a8cae58eacc3d648c09bedc4` |

Both bundles remain version 1.0/build 7; no recompilation or offline-test repetition. PM granted only dedicated QA simulator `C95B257D-0111-40A1-9D02-2AD70D850FF8`. No simulator command, boot, install, launch, media session or input occurred in this checkpoint, so no new stop/shutdown cleanup was necessary. Current device state was not queried; last observed Shutdown belongs to the earlier S1 checkpoint. No other device, provider/account/real-cache probe, settings reset or real media was used. Stream discovery is outside this QA scope; PM's latest direction drops all leads except WBZ.

## Remaining verification

Resume only when supported Simulator UI access is available under PM coordination. Use retained S1 first for active-preview current-program/channel-name/future-Watch entry, controls after badge timeout, Back and two originating guide cells/rows, then practical filter/scroll and selection-time boundary cases. Install retained S2 second for Channels text/state/focus/footer/offscreen traversal and empty-Home cancel/add/disabled-favorite returns, plus a guide sample. Save verified PNGs for Design. S1-QA-C1 remains uncleared, and S2 visual acceptance remains unobserved.

Existing fresh offline PASS evidence remains attributed to its exact source in `S2-qa.md`; no new performance inference follows from this access failure. Physical Siri Remote, rapid duplicate Back below debounce, VoiceOver/Reduce Motion, FairPlay, actual playback/audio/captions and physical-TV readability/performance retain their stated limits. No application source edit, deployment, push or release occurred.
