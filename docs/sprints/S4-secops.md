# S4-SECOPS — configured simulator build review

## Verdict and provenance

**Accept the final configured-build helper and synthetic tests for PM/QA's controlled Debug build sequence. No material SecOps blocker remains in the reviewed source.** This verdict does not establish that the private token is authorized, that metadata loads successfully, or that the app/build/runtime has passed.

- Assignment: TEAM-4 and `docs/assignments/S4.md`; supporting diagnosis `docs/assessments/live-status-diagnosis.md`.
- Assignment baseline: `d2468a9`.
- Initial helper: `f090047806afd82631e65c73ecba6a0ea61b8898`.
- Final reviewed helper/tests: `2e92607`.
- Review task: `01a0ad34-c2ad-7e22-ae18-3468ca71fa88`.
- Review branch/worktree: `codex/joe-tv-secops-s4`, `/Users/joecoakley/.codex/worktrees/345c/SeasonsTV`.

The review covered only `scripts/build-configured-simulator.py` and `Tests/ConfiguredBuildTests.py`. Competitor comparison does not apply to this local credential-handling and build-preflight control.

## Findings and corrections

The initial helper accepted any resolved file named `Private.xcconfig`, which did not enforce S4's authorization of the one existing Debug file. PM corrected this in `4ecba5d`: the helper asks Git for the absolute common Git directory, derives the original checkout's `Config/Private.xcconfig`, and requires the supplied path to resolve exactly to it. In this worktree the Git common-directory result identifies the expected original checkout. A synthetic test accepts that derived path and rejects an alternate worktree's same-named file and `Internal.xcconfig`, without reading any real configuration.

The initial bundle check also accepted hostless strings beginning with `https://`, although production `MediaAPIConfiguration` requires a host. PM corrected this in `2e92607`: `urlsplit` must now produce the HTTPS scheme and a nonempty hostname, and unresolved build-setting markers remain forbidden. The synthetic matrix rejects `https://`, `https:///only-path`, `https://?query`, HTTP, empty, and unresolved values.

No remaining source correction was identified:

- The helper reads one explicit `MEDIA_READ_TOKEN` assignment and rejects missing, duplicate, short, whitespace-containing, placeholder, and build-setting-reference values. Error paths are generic and do not print the value.
- The build command is an argument list rather than a shell command. It explicitly selects Debug, the tvOS simulator SDK, unsigned output, the caller-validated `-xcconfig` path, a worktree-local DerivedData directory, and two jobs. It neither copies configuration nor uses wildcard file operations. The inherited token environment variable is removed.
- Combined build output is consumed in-process. Lines naming the token setting are replaced wholesale; literal, HTML, URL, JSON, and Xcode-style escaped token variants are replaced before the retained log is written. The helper emits only generic failures or final paths and non-secret bundle metadata, not the token or metadata base URL.
- Bundle preflight requires the embedded token to match the selected Debug value, plus a resolved HTTPS metadata URL with a hostname. A mismatch or malformed plist fails before installation. This proves configuration shape and selection only, not server acceptance.
- Synthetic tests use temporary files and plists, import the helper without bytecode output, and do not invoke `main`, Git discovery, `xcodebuild`, a provider, the network, an account, or an app runtime.

## Verification and limits

Fresh command at final `2e92607`: `python3 Tests/ConfiguredBuildTests.py` — **4 tests passed**. Full-delta whitespace and file-scope checks passed; only the helper and its synthetic test are present between the S4 assignment and reviewed source. The review worktree remained clean after execution.

I did not read the real private configuration, compile the project, invoke Xcode, inspect a real bundle, access the network/account, use the simulator, or alter the current user-owned runtime. The configured app necessarily embeds its read token; its ignored `.build/ConfiguredDerivedData` output should remain local and handled as sensitive build material. This review verifies the helper's captured-output redaction, not the contents of Xcode's internal build records.

PM/QA should invoke the helper with the exact authorized path and keep configuration presence, successful metadata loading, server authorization, sports behavior, and simulator replacement as separate observations. Runtime replacement still requires the assigned handoff and must preserve the current login/preferences; this report grants no release, upload, production-access, credential-change, or playback authority.
