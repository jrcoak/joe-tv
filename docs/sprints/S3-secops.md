# S3-SECOPS — guide merge source review

## Verdict and provenance

**Accept the reviewed source for sequential integration and independent QA. No material SecOps blocker or required source correction was identified within the S3 contract.** This is a source-review verdict, not compilation, runtime, UI, network, account, or release acceptance.

- Assignment: TEAM-4 / TEAM-019 / TEAM-024 and `docs/assignments/S3.md`.
- Baseline: `a8301bcaa22f965ad4b4d5cf37ad2d583f36fb6b`.
- Reviewed Services source: `88061c7fbf8a4e41e90ed4e3d10b1dbd7b25272e`.
- Review task: `01a0ad34-c2ad-7e22-ae18-3468ca71fa88`.
- Review branch/worktree: `codex/joe-tv-secops-s3-review`, `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV`.

The review covered the complete four-file source/test delta plus the existing request lifecycle and sign-out paths. Competitor parity does not apply to this internal merge-correctness policy.

## Merge policy findings

`EPGGuideMergePolicy` receives an explicit requested-channel set for each source. Loaded mappings are restricted to that set; program rows must match an accepted station, have a valid interval, and overlap both the requested viewport and their source window. Failed or unavailable sources can retain only cached mappings belonging to their requested channels. Unrequested mappings, foreign station rows, invalid ranges, and out-of-window rows cannot enter the result.

Loaded sources are authoritative even when their publication is empty or removes a mapping. Their current and prior station claims suppress stale cached rows from a failed source, including the ambiguous shared-station case. Failed-source retention remains available for unaffected requested stations. The current production namespaces are disjoint, but the policy and tests conservatively handle overlap.

The PM-selected disjoint-viewport exception is implemented narrowly. A cached program retains its original times and must independently overlap both the cached window and the new request. That program can prove applicability across disjoint viewport bounds; a mapping with no such program cannot. When viewport bounds overlap, mapping-only retention remains possible for a failed source as required by the existing last-known association contract.

Age handling is conservative. Every successful publication, including an authoritative empty result, contributes its `fetchedAt`; applicable retained data contributes the cached aggregate timestamp; the merged value is their minimum. `.distantPast` remains unknown age rather than becoming current. The existing single aggregate timestamp cannot reconstruct per-source freshness across repeated partial results, so it may remain older than one source warrants. S3 adds no per-source persistence or networking.

## Lifecycle, error, and test review

`AppModel.refreshEPG` captures the cached window and mappings before suspension. The existing request ID guard remains after all provider awaits and before both merged writes, with no intervening await. `signOut` still clears guide/mapping state and rotates the request ID, so an older completion cannot repopulate signed-out state through this path. Provider order and the existing localized failure strings are unchanged; unavailable XMLTV continues using the generic programming-details message. The delta adds no URL, token, credential, or private configuration exposure.

`Tests/GuideMergeSmoke.swift` constructs pure guide values and invokes the production policy directly. Its assertions cover the prior partial-loss behavior, either source failing, repeated partial/recovery, authoritative success-empty and remapping, requested-channel and station filtering, invalid/time-window rows, conservative age, unknown age, source absence, shared-station authority, deterministic deduplication/order, and the selected disjoint-viewport exception. The cross-viewport case requires a real overlapping long-running program and separately proves that mapping-only and expired disjoint data are removed.

The isolated runner compiles an explicit source list into the ignored worktree `.build` directory. The inspected test path does not construct `AppModel`, providers, sessions, defaults, credentials, or normal caches, and contains no network or account operation. Services reports a fresh final pass of this targeted runner. Services also reports that the full smoke suite passed before the final viewport-exception adjustment; that older pass is not evidence for the final source.

## Evidence limits and handoff

SecOps performed read-only diff/source/test tracing and report scope/whitespace checks. I did not compile or execute Swift, run the app or simulator, access a network/account/private configuration, or retry the pending S1/S2 UI work. Very Local's suppression of individual station failures inside an otherwise successful provider result remains explicitly outside S3. No claim is made about hidden per-station failures, DRM, hardware behavior, or measured user benefit.

QA should run fresh final smoke and unsigned build checks on the exact integrated candidate, then verify affected guide failure/empty/recovery behavior. This review approves the bounded source for that sequence; it does not authorize deployment, production access, credential changes, or release.
