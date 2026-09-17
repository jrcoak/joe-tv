# Joe-TV specialist charters

These roles support the existing application. Their first assignment is M0, an assessment plus grounded innovation proposals. Do not implement the greenfield startup tasks from the original attachment.

## Product Design

Own the experience specification, interaction intent, visual tokens, storyboards, and visual review. Read the adopted RALLY design and Joe's subsequent decisions. Review Home, Live TV, Sports, Fantasy Zone, player controls, and loading/error/empty states.

Inspect couch readability, artwork, focus/selected/disabled distinctions, clipping, motion, navigation hierarchy, and Back/focus restoration. Production UI is implemented by tvOS App, with player code coordinated through Playback.

M0: report the strongest existing design decisions, specific inconsistencies with source evidence, and two or three thoughtful opportunities. Include at least one concrete user journey or compact storyboard. Avoid another half-split Sports layout or reverting the scorebug to the rejected full-height rail. Distinguish visual hypotheses from simulator observations.

Owned M0 output: `docs/assessments/design.md`.

## tvOS App

Own app shell, navigation, SwiftUI/UIKit screen code, focus, artwork presentation, screen-level state, and accessibility semantics. Preserve stable identities, saved settings, and focus after details/overlays/playback. Do not duplicate service or playback internals.

Primary code: `Views/RootView.swift`, `Views/JoeTVExperience.swift`, `Views/DesignSystem.swift`, and scoped UI orchestration in `App/AppModel.swift`. AppModel is shared; edits require a symbol assignment. Coordinate `PlayerScreen.swift` through Playback.

M0: map navigation/state boundaries, inspect performance and accessibility risks, identify stale documentation, and propose two or three improvements with minimal implementation paths. Evaluate the accepted focus contract rather than assuming every old workaround is correct.

Owned M0 output: `docs/assessments/app.md`.

## Playback

Own AVPlayer lifecycle, custom player surface/chrome, tracks/captions, seek/live-edge behavior, Quick Switch handoff/recovery, observer cleanup, FairPlay, and sanitized diagnostics. Services owns authorization/network requests; App owns browsing and navigation integration.

Primary code: `Views/PlayerScreen.swift`, `Playback/FairPlayResourceLoader.swift`, and assigned playback types/functions in `Models/Models.swift` and `App/AppModel.swift`.

The current custom AVPlayerLayer experience is deliberate. Assess its tradeoffs; replacing it with AVPlayerViewController requires a specific agreed benefit and scope, not mechanical application of the original charter. Preserve one active playback session and conventional remote behavior.

M0: trace preparation, switching, cleanup, captions, seekability, Back handling, and provider-specific FairPlay contracts. Identify measurable reliability improvements and two or three feature/interaction opportunities. Do not open real provider streams during the source assessment.

Owned M0 output: `docs/assessments/playback.md`.

## Services

Own provider adapters, catalog/schedule parsing, session/authorization boundaries, caching, typed failures, fixtures, and persistence contracts. Coordinate Joe-TV with Personal Media API and Mac mini publishers. Prefer the existing infrastructure.

Primary code: `Networking/`, service/domain portions of `Models/Models.swift`, and assigned orchestration in `App/AppModel.swift`. Playback owns FairPlay key handling; agree the descriptor/authorization boundary before edits. Shared model/test changes require PM allocation.

M0: map real service flows and discover exact source/deployment locations read-only. Explicitly preserve the Mac mini publishing architecture and Fantasy Zone's direct-live-data exception. Review parser fragility, data freshness, classification, identity, preference migration, and service failure isolation. Propose two or three viewer-facing improvements with backend/publisher dependencies and a compatibility plan.

Owned M0 output: `docs/assessments/services.md`. No production changes or remote publisher installation in M0.

## QA

Own independent acceptance, regression scenarios, fixture coverage, simulator/device evidence, and final quality reporting. Product Design separately owns visual review. QA routes defects to the code owner unless assigned a bounded repair.

M0: verify the exact baseline using existing offline smoke tests and an unsigned Debug simulator build; inspect available fixtures and prepare a practical simulator-first test matrix. Coordinate any UI operation through PM. Mark unavailable capabilities and physical FairPlay/remote checks pending. Identify testability improvements and how to evaluate the proposed innovations.

Owned M0 output: `docs/assessments/qa.md`. QA later adds an integrated evidence section against PM's assembled report commit. It must not silently claim checks performed by a different task or at a different commit.

## SecOps

Own security assessment, threat modeling, security acceptance criteria, and review of authentication, session/secret handling, request validation, dependencies, logs, build artifacts, API access, and publisher/deployment permissions. Remain a standing reviewer for relevant changes; this role does not imply a scheduled background monitor.

M0: inspect tracked code and configuration templates. Trace credential and token flows, cookie/Keychain/UserDefaults boundaries, signed URL lifetimes, log redaction, untrusted provider input, FairPlay authorization, distributed read-token exposure, and remote publisher trust. Identify evidence-backed risks with severity, prerequisites, impact, and proportionate mitigation. Review how Internal TestFlight artifacts and backend tokens are scoped and revoked without printing secret values.

Read private configuration only when an explicit assignment requires it; never include raw secrets in reports. Do not scan external systems, probe production authentication, rotate keys, install security software, change permissions, or publish findings during this assessment. Security research should be limited to applicable official advisories/documentation when needed.

Propose two or three practical improvements that reduce real risk or improve maintainability without turning the television UI into a technical control panel. Coordinate code fixes through App, Playback, or Services; independently review them before integration for security-sensitive changes. Escalate a confirmed serious exposure to PM promptly with redacted evidence.

Owned M0 output: `docs/assessments/secops.md`.

## Shared interfaces

Agree stable content/event/channel identity, playback descriptors, player entry/exit, session events, saved settings, catalog availability, and categorized failures before parallel coding. Start from the actual existing models. PM names one editor for every shared file/symbol overlap and serializes Xcode project changes.

## Handoff quality

All roles report: assignment/spec/baseline, inspected components, observed findings and evidence, proposed ownership/dependencies, suggested improvements, verification performed, branch/commit, and remaining limitations. Cite repository paths and exact lines or symbols; do not include secrets or signed media locations.
