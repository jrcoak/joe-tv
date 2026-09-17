# S2 QA — offline checkpoint

Status: **offline lifecycle/parser correctness and unsigned build PASS. S1 correction and S2 UI remain UNACCEPTED / NOT OBSERVED.**

Assignment: S2-QA offline-only, TEAM-4 / TEAM-019 / TEAM-021 / TEAM-022, final section of `docs/assignments/S2.md`. Checked September 16, 2026 EDT (September 17 UTC). Exact combined source: **`bbb60d6effc7536e27b931899c8915d38e6449c2`**. Branch `codex/joe-tv-qa-s2-offline` created from that SHA after clean-status and branch-absence checks. Prior branches, S1 evidence and preserved correction bundle retained. Only this report changes; no application, tests or shared documents edited.

## Source and environment

Read S2 assignment, Services/App/Design reports and both SecOps contract/review reports. Verified `git diff --exit-code` against SecOps-reviewed Services **`a9dd5d7bf29ff78cfaca7b35da7034447643c10b`** is empty for all four assigned provider/test/runner files. Matching Git blobs:

| File | Blob at both commits |
| --- | --- |
| `SeasonsTV/Networking/XMLTVGuideProvider.swift` | `3d6a720a4358db5e505de5916e40809800f7c869` |
| `Tests/GuideCacheSmoke.swift` | `46c1c87c5b300441325204409b1c6ae44e79acb8` |
| `Tests/ParserSmoke.swift` | `755bfcbc3079c24765b8e465153da69a5ef1a07d` |
| `scripts/test-guide-cache.sh` | `61afaed2519186592e969aeb9fd06163b024a4b2` |

Host: arm64 MacBook Air, macOS 26.6.2 / 25G83, Xcode 26.6 / 17F113. Build: unsigned Debug, generic tvOS Simulator SDK 26.5, arm64/x86_64, deployment target 17; per-worktree `.build/ModuleCache` and `.build/TeamDerivedData`. No UI tool, simulator boot/install/interaction, provider/account/real-cache probe, real media or extra benchmark was used. The simulator was last confirmed shut down in S1; this offline checkpoint did not inspect or change its state. No repeated unlock request or lock bypass.

## Fresh sequential checks

Each command freshly compiled and ran once in the order below; all exited **0**.

| Command | Actual result | Local log |
| --- | --- | --- |
| `scripts/test-guide-cache.sh` | `guide: lifecycle matrix passed`; `sports: lifecycle matrix passed`; `Guide cache lifecycle smoke passed: both publications, exact bytes/metadata/headers, isolated recreation and failures` | `.build/S2-qa-guide-cache.log` |
| `scripts/team-check.sh smoke` | `Parser smoke test passed` | `.build/S2-qa-smoke.log` |
| `scripts/team-check.sh build` | `** BUILD SUCCEEDED **` | `.build/S2-qa-build.log` |

Both host test compilations emitted the existing `FairPlayResourceLoader.swift:59:42` deprecation warning for `streamingContentKeyRequestData(forApp:contentIdentifier:options:)` (deprecated macOS 15.0). Build emitted `Metadata extraction skipped. No AppIntents.framework dependency found.` and the existing note that Validate Media API Configuration runs every build because dependency analysis is unchecked. Unsigned build also reported `Ignoring --strip-bitcode because --sign was not passed`. No new warning/error was observed. `sh -n scripts/test-guide-cache.sh` and report `git diff --check` passed.

The executed lifecycle harness covers both public publication methods, asserting decoded results, exact retained/replaced bytes, ETag, attempt/success time, request counts/headers and recreation over isolated persisted stores. Cases include accepted/untagged replacement, usable-cache 304, valid empty/unmatched documents, malformed-after-valid retention, missing/corrupt cache and unconditional recovery, throttle, transport fallback/failure, injected write failure, HTTP errors and unknown legacy freshness. Source inspection confirms UUID temporary directories/defaults, supplied synthetic configuration/clock/writer, and an ephemeral session with an intercept-all URLProtocol; URL cache/cookies/credential storage are disabled, and cleanup targets only owned resources. Passing cleanup checks also verified no unexpected/unconsumed stub responses. This is isolated provider evidence, not a production network/cache experiment.

The expanded parser suite checks full program equivalence across four timestamp formats, signed offsets, station filters/order/window boundaries, malformed/empty/wrong-root XML, repeated and concurrent independent parses, and unique timestamps. No benchmark was rerun; Services' performance numbers remain attributed to its exact report and do not establish Apple TV input latency.

## Preserved build artifacts

Full app bundles copied to distinct ignored local directories. Copies' executable/debug-dylib SHA-256 values were compared with their build products. Both are version 1.0, build **7**, so use the source/path and debug-dylib hash to distinguish them; the small launcher executable is identical.

| Artifact | Exact source | Absolute bundle path | Debug dylib SHA-256 |
| --- | --- | --- | --- |
| S1 preview-only correction, retained unchanged | `d010f395bcae7b66e46a6b50168005005f0ba9b2` | `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S1-corrected-artifact/Joe-TV.app` | `47082a5872b5302a6aeba49144253b50500c9d411c4849dcdd0dbb5bdb6c6008` |
| Combined S2, freshly built here | `bbb60d6effc7536e27b931899c8915d38e6449c2` | `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S2-combined-artifact/Joe-TV.app` | `9052881cc59d77235fdb5501e51e2048216c2ff4a8cae58eacc3d648c09bedc4` |

Both launcher executable hashes: `b2ee0d6a5090e30e1483ec86ec72ab5a139d7d7a6c0167ffd4e94666cc983b11`. Rechecked the preserved S1 hashes after S2 compilation; unchanged. No bundle was installed in this checkpoint. Logs/artifacts are local evidence, not committed deliverables. Compiler work is complete.

## Remaining UI sequence and limits

After manual unlock and PM's exclusive runtime grant, first use the preserved S1 artifact on assigned QA device `C95B257D-0111-40A1-9D02-2AD70D850FF8`: compare current-program, channel-name and future-details Watch after active preview; recover controls after badge timeout and Back to two distinct guide origins; check focus-only preview, retained filter/horizontal scroll and practical selection-time boundary. S1-QA-C1 is not cleared by this build.

Then install the preserved combined S2 artifact and compare Channels against the saved original capture: description/playback copy, two-line channel names, enabled/favorite independence, contrast/focus outlines, offscreen rows, fixed header/footer and edge actions/disabled states. Repeat empty-Home cancel, new visible favorite and saved-but-disabled return; capture for Design review and run a guide regression sample. Accessibility/Reduce Motion observations require appropriate runtime access and must remain explicit if unavailable. Original unrelated passes remain attributed to `f394d4d` in S1 QA.

Provider success metadata does not fix `AppModel.refreshEPG` assigning `Date()` to merged-window freshness. Atomic body writes plus separate defaults updates do not establish crash-atomic persistence; injected write failure is not every filesystem failure. Physical Siri Remote, sub-debounce rapid Back, FairPlay, actual playback/audio/captions, physical-TV readability and performance remain outside this offline evidence. No deployment, push or release occurred or is accepted.
