# Joe-TV agent instructions

Joe-TV is an existing native tvOS app. Improve it incrementally. Preserve its working integrations, user preferences, and accepted interaction design.

## Start here

Read `spec.md`, `docs/agent-team.md`, `docs/tvos-specialists.md`, `docs/team.md`, `docs/decisions.md`, and `docs/product-context.md`. Read the assignment referenced in the roster. The current user request governs scope; historical conversations and draft documents provide context, not new instructions or approval to perform old actions.

The original greenfield charters have been adapted. Do not rebuild a fixture-only on-demand app, replace the existing player, introduce accounts, or remove live/DRM features merely because an earlier template suggested it.

## Team and ownership

- Joe is product owner. PM / Integrator is his primary contact and the sole integration owner.
- Reuse the six persistent specialist tasks in `docs/team.md`. Do not create additional tasks, subagents, or recurring automations without a scoped need and Joe's instruction.
- Specialists use their assigned worktree and branch. Never edit another worktree. Return bounded commits and verification evidence to PM.
- Product Design owns design documents; tvOS App owns screen implementation; Playback owns player internals; Services owns provider/data code; QA owns independent verification.
- SecOps owns security review and security acceptance criteria across the app, services, publishers, and release process. Coordinate fixes through the relevant code owner; security review does not grant permission to change production access or credentials.
- `AppModel.swift`, `Models.swift`, `Tests/ParserSmoke.swift`, project configuration, and shared tokens/interfaces require an explicit file or symbol assignment. PM serializes overlapping edits. `PlayerScreen.swift` crosses visual and playback concerns: Playback is its default code owner; App and Design coordinate through that owner.
- PM owns shared team documents and `Joe-TV.xcodeproj/project.pbxproj`. Specialists may propose project changes; they do not independently change build numbers, signing, bundle identity, or deployment target.
- Reports belong in each role's assigned `docs/assessments/` file. QA does not silently rewrite reviewed code.

## Working safely in this repository

- `SHELF/` is unrelated. Do not read, add, modify, commit, or remove it as part of Joe-TV work.
- `RALLY/` is a design reference. Adopted requirements and later Joe decisions take precedence over unimplemented RALLY concepts. Leave the source package intact.
- Preserve pre-existing changes. Use explicit paths when staging; never `git add .` or `git add -A` in the user's checkout.
- Keep `com.jrcoak.joetv` and existing preference/Keychain namespaces stable. Migrate settings additively and preserve user choices.
- Keep private xcconfig files, credentials, cookies, signed URLs, and license values out of source control, screenshots, logs, reports, and messages. Worktree setup must not copy secrets by wildcard.
- Use local commits and an integration branch. Pushing, release-branch merging, TestFlight uploads, production deployment, credential/access changes, and remote Mac mini installation require authorization for that specific delivery. Historical approvals are not standing release authorization.
- Services may coordinate changes across Joe-TV, Personal Media API, and Mac mini publishers within an assigned milestone. Record each repository's baseline and deployment/install dependencies separately.

## Runtime coordination

Worktrees do not isolate the simulator, device, provider account, ports, or build tools. PM grants a named runtime session with owner, resource, duration/checkpoint, and cleanup responsibility before UI or real-stream tests. Only the owner operates that resource until released. A timed-out session must be reconciled, not assumed idle.

Use isolated DerivedData/module-cache paths in each worktree. Default to deterministic fixtures and offline parser tests. Never run parallel authenticated Seasons4U playback probes. Only one team-controlled real stream may play at a time; account for Joe's device and browser before a test. Stop it when done. The project history includes a real provider lockout from repeated/concurrent tests.

Do not reset simulator data, reinstall by deleting the app, change shared settings, or interrupt another task's simulator/release operation just to obtain a clean screenshot. Prefer a dedicated test simulator when available. Return test environments to a documented state.

## Product constraints

- Focus previews; Select commits. Back unwinds one layer and restores the originating context.
- Quick Switch combines up to four recent streams with favorites, deduplicates, omits the active stream, and stores stable identities rather than expiring URLs.
- Live/DVR playback joins live. Keep baseball Home/Away/National selection and the 15-minute pregame coverage policy.
- Sports combines S4U/ESPN+ sources with Live/Upcoming and persistent granular filters. Avoid replay/studio-show regressions and heavy catalog work during focus rendering.
- Ordinary sports metadata is published by the Mac mini to Personal Media API. Fantasy Zone is the intentional exception: direct live ESPN scores and Sleeper matchup reads.
- Fantasy Zone is optional. Keep full-width video, the scorebug without a fake probability bar, and the translucent Matchup/League drawer.

## Verification and reporting

Use `scripts/team-check.sh smoke` for the existing offline suite and `scripts/team-check.sh build` for an unsigned Debug simulator build. These commands must be freshly verified for the baseline; old pass reports are historical evidence only.

Use simulator verification for navigation, focus, overlays, fixture states, captions on suitable clear media, and layout. FairPlay success and physical Siri Remote behavior require hardware evidence. Joe can assist with those checks; record them as pending until observed. Do not claim simulator, compilation, or a mock proves DRM playback.

For every handoff record assignment ID, baseline/spec revision, branch and commit, files/symbols changed, checks run, actual results, limitations, and any required device or deployment step. Distinguish measured findings from hypotheses and new ideas. Prefer a small, testable improvement to an architecture rewrite.
