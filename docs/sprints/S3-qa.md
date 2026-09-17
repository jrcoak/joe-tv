# S3 QA — independent offline checkpoint

Status: **fresh pure-policy tests, parser smoke and unsigned build PASS. Async lifecycle and UI NOT VERIFIED.**

Assignment: S3-QA, TEAM-4 / TEAM-019 / TEAM-024, final QA section of `docs/assignments/S3.md`. Checked September 17, 2026. Exact integrated candidate **`9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d`**; clean new branch `codex/joe-tv-qa-s3-offline` created after clean-status and branch-absence checks. Prior branches and S1/S2 evidence/artifacts preserved. Only this report changes; no source/test/shared-document edits.

## Source equality and checks

Read the final assignment and Services, App-review and SecOps reports. `git diff --exit-code` confirms all four S3 implementation/test/runner files exactly match reviewed Services **`88061c7fbf8a4e41e90ed4e3d10b1dbd7b25272e`**. Matching blobs:

| File | Blob at reviewed and integrated source |
| --- | --- |
| `SeasonsTV/App/AppModel.swift` | `4074afa323a915b4bb671e413b68e5ba5cc180fc` |
| `SeasonsTV/Models/Models.swift` | `4e9d382f0ab7c5bd6921f57af6dca52a55a73628` |
| `Tests/GuideMergeSmoke.swift` | `48c574c4a04d4949712e0c1f7f8de88a377694ff` |
| `scripts/test-guide-merge.sh` | `a5f91b574eb619005a38a85b5c5bd1a1d2c7561e` |

The S2 provider, lifecycle tests/runner and ParserSmoke are unchanged from independently tested combined `bbb60d6effc7536e27b931899c8915d38e6449c2` (empty diff). No new relevant provider concern was identified; per assignment, its lifecycle suite and benchmark were not repeated. Full parser smoke was freshly rerun because Models changed.

Host: arm64 MacBook Air, macOS 26.6.2 / 25G83, Xcode 26.6 / 17F113. Worktree-local `.build/ModuleCache` and `.build/TeamDerivedData`. Checks run freshly and sequentially:

| Command | Result | Local log |
| --- | --- | --- |
| `scripts/test-guide-merge.sh` | PASS, exit 0: `Guide merge smoke passed: loss reproduction, partial retention, authoritative empty, remapping, filtering, provenance, recovery and absence` | `.build/S3-qa-guide-merge.log` |
| `scripts/team-check.sh smoke` | PASS, exit 0: `Parser smoke test passed` | `.build/S3-qa-smoke.log` |
| `scripts/team-check.sh build` | PASS, exit 0: `** BUILD SUCCEEDED **`; unsigned Debug generic tvOS Simulator SDK 26.5, arm64/x86_64, deployment target 17 | `.build/S3-qa-build.log` |

Both host compilations emitted only the existing `FairPlayResourceLoader.swift:59:42` macOS 15.0 deprecation warning for `streamingContentKeyRequestData(forApp:contentIdentifier:options:)`. Build emitted the existing AppIntents no-dependency warning, always-run Validate Media API Configuration note, and unsigned `Ignoring --strip-bitcode because --sign was not passed` message. No new warning/error observed. Runner `sh -n` passed. Final report whitespace/staging checks accompany handoff.

## What the evidence establishes

The merge harness constructs pure guide values and calls the production `EPGGuideMergePolicy`; it does not instantiate AppModel, providers, URL sessions, defaults or normal caches. Its assertions reproduce the old loaded-results-only loss and verify either source failing, repeated partials and recovery, authoritative empty/remapping, requested-channel/station/time filtering, original program intervals and identities, conservative/unknown age, provider absence, shared-station success precedence, deduplication/order and long-program retention across disjoint viewports. Mapping-only/expired disjoint data is explicitly rejected. Reordered source-array tests establish policy ordering behavior, not asynchronous request completion safety.

Direct source inspection confirms main-actor `refreshEPG` captures prior window/mappings before suspension and invokes that same tested policy. It preserves Very Local then XMLTV request order, applies the request-ID guard after awaits and before both result assignments with no intervening await, and `signOut` clears state/mappings and rotates the ID. This corroborates App's source audit; **no controlled async stale-completion/sign-out execution occurred**. The dormant, pre-existing `openVeryLocal` invalidation caveat remains attributed to App's report, not a reproduced S3 failure.

The old merged `Date()` stamp is replaced in this production path by contributing timestamps. The single aggregate date remains conservative and cannot reconstruct per-source ages after repeated partials. Very Local's internally suppressed per-station failures remain outside the visible failure contract. Successful shared-station claims override old failed-source rows by the reviewed policy; current source namespaces are disjoint.

## Preserved artifacts

Copied the complete fresh version **1.0 / build 7** bundle from exact source `9d3cd8ab798d5bb094a2a6e2f761a6d7f2daaa4d` to `/Users/joecoakley/.codex/worktrees/5350/SeasonsTV/.build/S3-combined-artifact/Joe-TV.app`. Copied launcher/debug-dylib hashes match the original build products. Debug dylib SHA-256: **`745bdeba6efacc6254bb9b4a5a99543743f4866d0ebb46b5bb71e2fe927b719d`**. Launcher SHA-256: `b2ee0d6a5090e30e1483ec86ec72ab5a139d7d7a6c0167ffd4e94666cc983b11`.

After this build, both retained S1/S2 launcher hashes still equal the launcher value above. Retained debug-dylib hashes also remain unchanged:

- `.build/S1-corrected-artifact/Joe-TV.app`, source `d010f395bcae7b66e46a6b50168005005f0ba9b2`: `47082a5872b5302a6aeba49144253b50500c9d411c4849dcdd0dbb5bdb6c6008`.
- `.build/S2-combined-artifact/Joe-TV.app`, source `bbb60d6effc7536e27b931899c8915d38e6449c2`: `9052881cc59d77235fdb5501e51e2048216c2ff4a8cae58eacc3d648c09bedc4`.

All bundles/logs are ignored local evidence, not committed. Identical version/build labels and launcher hashes do not distinguish these artifacts; use their source-specific path and debug-dylib hash. No bundle installed. Compiler work complete.

## Runtime and acceptance limits

No simulator boot/install/query, UI retry, network/account/media probe, real-cache operation, benchmark or deployment ran. No runtime resource was started, so no new shutdown cleanup is required; historical device state is not asserted as a fresh observation. S1/S2 UI acceptance remains independently pending.

The existing navigation fixture returns before `refreshEPG`; running it later cannot prove S3 partial-refresh orchestration. Actual async failure/recovery, out-of-order completion, sign-out invalidation and visual focus/selection during updates need separately authorized controllable runtime evidence. Pure-policy passes plus source audit and compilation must not be labeled async or visual acceptance. Physical remote, rapid Back, FairPlay, real playback/captions and Apple TV performance remain unverified. No numerical performance benefit or competitor parity is claimed for this internal correctness contract.
