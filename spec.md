# Joe-TV product specification

Revision: TEAM-1 (team adoption, September 2026)
Owner: Joe Coakley
Status: existing product; first team milestone is assessment and innovation planning

## Outcome

Make Joe-TV an enjoyable, fast, dependable Apple TV experience for live channels, live sports, and optional fantasy-football context. Continue the existing app and services. Joe works primarily with a PM who coordinates six specialists and presents integrated, verified work and concrete product ideas.

## Existing product to preserve

- Native Swift/SwiftUI tvOS app, UIKit where used, AVFoundation playback, custom player controls, HLS, and FairPlay. Deployment target is currently tvOS 17.0; the local Xcode inspection found 26.6 (17F113). Verify actual build compatibility rather than relying on old README claims.
- Seasons4U authenticated catalogs and runtime stream resolution; Very Local and NHPBS integrations; XMLTV guide and sports enrichment through Personal Media API.
- Home driven by enabled favorite channels, with the hero following the focused favorite. Channel visibility and favorites are distinct persistent choices.
- Live TV guide with channel categories, program information, predictable focus, and explicit selection to tune.
- Consolidated Sports from provider catalogs and ESPN+ with Live/Upcoming views, a full-width event board, selected-event details above, a compact preview at upper right, and persistent multi-select filtering.
- Twenty-six sports categories with separate professional/college/women's categories, Pickleball, and Wrestling/WWE. Preserve migration of old filters; unmatched/Volleyball events fall under Other.
- Baseball-family Home/Away/National feed choices; live streams start near live edge; scheduled coverage becomes available 15 minutes before game time when a playable source exists. Match events by date and stable identity.
- Quick Switch with up to four recent streams followed by favorites, no active-stream card or duplicates, fresh stream resolution, and recovery on a failed switch.
- Captions/subtitle selection when supplied by a stream, with understandable unavailable state.
- Optional Fantasy Zone: Sleeper username onboarding, live NFL data, RedZone/NFL Network options, full-width video with a compact scorebug, and a translucent two-tab Matchup/League drawer. No ungrounded win-probability bar.
- Internal TestFlight delivery with permanent bundle ID `com.jrcoak.joetv`. Maintain preferences across builds and keep private configuration out of Git.

Some older documentation describes a separate ESPN+ destination, free-entry login button, fixture-only catalog, or earlier Fantasy layouts. Current code and accepted later product decisions must be reconciled before treating those claims as requirements.

## Service boundaries

Normal sports metadata: ESPN -> Mac mini publisher -> Personal Media API storage -> Joe-TV. Hosted Personal Media API serves the published records; do not reintroduce ESPN fetching on its cache misses.

Fantasy Zone live updates: ESPN scoreboard -> Joe-TV and Sleeper -> Joe-TV, currently refreshed about every 30 seconds while the feature is active. This is a deliberate exception to the daily publisher path.

Guide data: Mac mini XMLTV publisher -> Personal Media API -> Joe-TV, with explicit numeric station matching, cached data, and failure behavior that does not disable otherwise valid playback.

Services owns coordinated work across these components. Scope each change, identify exact checkouts and baselines, and separate source changes from production deployment or remote installation.

## M0: establish the team, assess the app, propose improvements

Joe confirmed the app commit is ready and authorized team startup. Use app commit `c08e551038bfbeaf7d2fdcc60c0b3e3021cd25b8`; the existing release task separately owns its build-number bump and TestFlight work. Reconcile its final release commit later without overwriting it. Exclude `SHELF/`. M0 does not upload another build or make speculative app changes.

Deliverables:

1. Seven named persistent tasks with verified IDs, clear ownership, separate specialist worktrees/branches, and demonstrated PM-to-specialist messaging.
2. A shared product/technical context that records accepted decisions and identifies stale documentation.
3. Specialist assessments of the exact baseline. Every role provides both concrete risks and opportunities, not only a defect list.
4. Fresh offline smoke and simulator build evidence. Simulator/UI coverage is performed on an assigned resource; unsupported or inaccessible checks are explicitly pending. Physical FairPlay and remote checks remain a separate device matrix for Joe.
5. A ranked shortlist of three to five worthwhile improvements. Each includes the viewer problem, proposed behavior, evidence, expected benefit, effort, dependencies, risks, and the smallest useful prototype or validation.
6. PM's proposed next milestone, scoped so Joe can choose a direction without designing the implementation himself.

Acceptance:

- Every specialist acknowledges TEAM-1 and the same app baseline plus team-bootstrap revision.
- Each report separates observed behavior, old reports, inferred risks, and proposed ideas.
- Design ideas follow RALLY's adopted visual language and Joe's later decisions.
- At least two independently owned work packages run without conflicting source edits or runtime use.
- PM integrates reports sequentially; QA checks the assembled assessment at an identified commit and records remaining gaps.
- No app regression is introduced by this documentation/setup milestone. No new provider integration, source migration, redesign, infrastructure, or release is silently launched.

## Future milestone quality bar

Remote navigation is reachable and predictable; focus restores after overlays and playback. Text and focus treatment are readable at TV distance. UI loading does not block navigation. Only one player actively plays during switching and cleanup is reliable. Failure states have a usable recovery path. Supported captions/accessibility behavior is checked. Measure launch, navigation, playback-start, and memory against named hardware/media/network conditions before setting numerical budgets.

Every delivered change states the exact tested commit and which checks were simulator, device, fixtures, or live service. An idea becomes implementation scope only when Joe selects it or gives a bounded objective that clearly includes it.

## Out of current scope

SHELF; a fresh app; the speculative public bring-your-own-IPTV fork; synthetic sports channels; multiview/recording/replays; billing; new accounts/profiles; replacing provider authorization; automatic ongoing feature development; recurring meetings; Notion/Northstar integration. Existing implemented capabilities remain supported even when an old template excluded them.
