# SeasonsTV Redesign Working Notes

Status: documentation synthesis completed before repository implementation audit on August 12, 2026.

Historical note: this file intentionally records the pre-redesign state. For current behavior and verification, use `REDESIGN_IMPLEMENTATION_REPORT.md` and `TECHNICAL_HANDOFF.md`.

Product clarification received after the documentation audit: EPG data will be included shortly. The redesign must therefore treat the EPG as committed near-term scope, while still accurately describing its absence from the current repository. `REDESIGN_PLAN.md` supersedes the handoff's “later” timing assumption for design and implementation architecture.

Authoritative sources read in full:

- `README.md`
- `docs/TECHNICAL_HANDOFF.md`

These notes capture documented intent and claims. Each implementation claim remains subject to code verification; discrepancies will be recorded rather than silently resolved in favor of either source.

## Product Purpose

SeasonsTV is intended to be a native SwiftUI tvOS client for an existing Seasons4U member. It replaces the provider website's unsuitable desktop/mobile player UI with a television-first experience using Siri Remote focus navigation and native AVPlayer playback. It serves authorized subscribers who want to browse live channels and sports/events and play compatible streams on Apple TV. It is an independent client and must preserve provider entitlements, geographic restrictions, blackouts, and DRM.

## Core User Experience

On launch, the app attempts to restore a cookie-backed authenticated session by loading both catalog sources. A valid session enters the catalog, with Live TV as the default surface. A user browses or filters the channel lineup, selects an entire focusable channel row, and enters native playback. Sports & events is a secondary surface organized into parsed categories and content cards. If no valid session exists, the user signs in with email/username and password. Refresh and local sign-out are globally available. Playback is presented full-screen and exits back to browsing.

The current guide is a structural shell rather than a true guide: every channel is labeled “Live Now,” while horizontal timeline space is reserved for a future independent EPG integration.

## Major Features

- Native email/password sign-in using an ASP.NET anti-forgery token.
- Cookie-backed session restoration and local cookie deletion on sign-out.
- Live sports/events catalog parsed from `/Player`.
- Live channel lineup parsed from `/PlayerDRMChannels`.
- Local channel search and heuristic genre filters.
- Direct and resolved HLS playback through authenticated provider routes.
- Runtime FairPlay configuration discovery and native FPS playback on hardware.
- Simulator-specific explanation instead of attempting nonfunctional FairPlay playback.
- Blocking work state, global actionable errors, refresh, and player-local failure handling.
- Parser and payload smoke coverage through a standalone Swift executable.

Explicitly absent: real EPG/program data, profiles, account switching, credential storage, persistent/offline DRM keys, non-HLS playback, and confirmed production distribution support.

## Architecture

- Single SwiftUI tvOS application target; documented deployment target tvOS 17.0 and Swift 5 language mode.
- `SeasonsTVApp` is the entry point.
- A single `@MainActor ObservableObject`, `AppModel`, owns lifecycle and visible application state.
- `RootView` switches between session checking, signed-out, and catalog states.
- The catalog has two local surfaces: Live TV and Sports & events.
- `SeasonsClient` owns URLSession, cookie-backed authentication, HTTP validation, and stream resolution.
- `HTMLCatalogParser` interprets private server-rendered HTML and JavaScript-shaped data without evaluating JavaScript.
- Domain models and `PlaybackSession` hold parsed content and AVPlayer ownership.
- `FairPlayResourceLoader` performs certificate/SPC/CKC exchange.
- Playback is presented through an item-bound full-screen cover and pauses when dismissed.
- No documented third-party dependencies, package manager, analytics SDK, persistence framework, or backend component.

## Data and Service Relationships

- Provider: `seasons4u.com`, using private and changeable server-rendered contracts.
- Authentication: `GET` and form `POST` to `/Account/Login`, with `__RequestVerificationToken`; system shared cookie storage supplies subsequent authenticated requests.
- Sports/events: `/Player`, plus controller-family-specific `/Player/Watch*` JSON/XHR routes that resolve some items to HLS.
- Channel lineup: `/PlayerDRMChannels`; channel playback pages under domestic or international route variants.
- Media: HLS through AVPlayer. Ordinary URLs may be direct or resolved at selection time and remain in memory only.
- DRM: runtime HLS URL, certificate URL, entitlement headers, and optional international proxy information are parsed from the authenticated channel page. The app supports only FairPlay/HLS on tvOS.
- Presentation metadata: channel genres are inferred locally from English channel-name keywords and are not provider truth.
- Imagery: remote channel logos and content images currently use `AsyncImage`; failure falls back to SF Symbols; no custom cache is documented.
- Persistence: shared cookies only. Credentials, stream URLs, license material, and playback configuration are intentionally not persisted.
- Near-term EPG: must remain a separate data domain from provider playback contracts so guide failure cannot prevent channel playback. It requires explicit station mapping, absolute time-aware programs, bounded cached windows, current-time navigation, and truthful unmapped/gap states.

## Important User Flows

- First launch/session restoration → concurrent catalog requests → catalog or signed-out state.
- Sign in → anti-forgery token fetch → credential post → catalog load → Live TV.
- Browse Live TV → optionally search/filter locally → focus channel row → select → hardware runtime DRM configuration → full-screen player.
- Simulator channel selection → explanatory FairPlay-requires-device alert without opening the player.
- Browse Sports & events → choose category → choose item → direct HLS, resolved HLS request, or DRM-page playback → player/error.
- Refresh either catalog surface → coupled reload of both data sources → updated content or surfaced error/session-expiry response.
- Playback failure after presentation → player overlay → return to channels/browse.
- Exit player → pause playback → return to prior catalog context.
- Sign out → pause playback → clear models and local provider cookies → login.

Flows documented as absent or not supported include onboarding beyond sign-in, profile selection, account switching, favorites/watchlist, recently viewed, continue watching, EPG navigation, subtitles/audio selection UI, autoplay/next episode, and persistent resume state.

## Known Constraints

- Only authorized accounts and provider-permitted access may be used; no DRM, entitlement, geographic, or blackout circumvention.
- Server contracts are private, undocumented, and markup-sensitive.
- Server JavaScript must only be parsed as data and never evaluated.
- Runtime credentials, cookies, signed URLs, certificate/license URLs, headers, SPC, and CKC material must never be committed or logged unsafely.
- tvOS supports only HLS/FairPlay; DASH/Widevine/PlayReady-only sources must remain unsupported with an honest error.
- Simulator cannot establish FairPlay success; hardware validation is mandatory.
- EPG and provider playback contracts must stay technically independent.
- Current small-project architecture intentionally uses one app model and no architecture framework.
- Physical deployment requires signing, a real bundle identifier, an entitled account, reachable provider service, and appropriate IP/region conditions.

## Known Problems or Incomplete Areas

- End-to-end FairPlay is not confirmed on physical Apple TV; this is the highest product risk.
- The guide has placeholder “Live Now” content and no actual program data, timeline model, station mapping, current-time indicator, or day navigation.
- Startup maps any catalog failure to signed-out, potentially misrepresenting network/provider failure as an authentication problem.
- Catalog and lineup refresh are coupled; one failure prevents both surfaces from updating.
- Local sign-out does not revoke the server-side session.
- No retry/backoff, explicit reachability/offline state, request timeout policy, or cancellation from the blocking overlay.
- Shared cookie storage is not isolated per account.
- Regex parsing and partial HTML entity decoding are fragile.
- The older AVAsset resource-loader SPC API is technical debt.
- No custom artwork cache or storage budget.
- No automated UI tests or XCTest target; live authentication and playback are not automated.
- No completed accessibility audit, localization, analytics/telemetry, crash reporting, privacy manifest work, app icon, top-shelf assets, or production launch branding.
- Long-duration playback, stream switching, interruptions, backgrounding, and broad provider/account variants are unverified.

## Important Terminology

- **Sports & events catalog:** parsed `/Player` sections and rows; not the same as the Live TV lineup.
- **Live TV / channel lineup:** channel list parsed from `/PlayerDRMChannels`.
- **Guide shell:** current channel rows plus placeholder timeline space; it is not an EPG.
- **Sports default:** Football opens first; a synthetic Featured category was removed because upstream channel rows can be misclassified as event content.
- **PlaybackRequest:** a parsed provider controller invocation requiring an authenticated `/Player/Watch*` resolution request.
- **DRM page:** authenticated per-channel page containing runtime HLS/FairPlay configuration.
- **FPS / FairPlay Streaming:** Apple DRM path used by tvOS.
- **SPC / CKC:** FairPlay key-request and key-response byte payloads.
- **Domestic/international DRM:** page variants with different license URL construction; international pages may use a proxy prefix.
- **Presentation genre:** local heuristic grouping derived from channel names, not provider metadata.
- **Playback identity:** deduplication key for catalog rows; titles alone are not treated as unique.

## Design-Relevant Context

- Live TV is intentionally the default and current highest-priority surface; sports/events remains important but secondary.
- The existing visual intent is dark and editorial, with warm orange/gold accents and serif display headings, adapted from the site. The audit must decide what to preserve based on usability and current implementation rather than discard it automatically.
- Channel rows are deliberately large, single focus targets for Siri Remote use. Tiny inline controls should not be introduced.
- Search and genre filters currently sit above the channel list partly to accommodate horizontal EPG expansion. The redesign will implement a real guide-ready hierarchy and two-dimensional focus model rather than replace the guide with a directory-only dead end.
- The home/catalog information architecture is two-surface rather than a broad streaming-service library. A generic multi-tab Netflix clone would overstate the product's actual content model.
- The first decision on a channel is immediate playback, not inspecting a rich detail page; provider metadata currently appears too sparse to justify invented detail surfaces.
- Sports/event items can have three different playback paths but should present one consistent selection interaction to users.
- Signed media and DRM configuration are ephemeral; redesign work must not introduce persistence or diagnostics that leak them.
- Global blocking work UI currently protects against duplicate login, refresh, and playback requests, but its interaction cost and failure granularity need audit.
- Artwork availability and quality vary. Large cinematic backdrops cannot be assumed; logo/image fallbacks, aspect-ratio safety, and restrained hero usage are necessary.
- Focus restoration, async content arrival, player dismissal, and modal/alert dismissal are critical audit targets because the documented architecture does not specify their exact behavior.
- Native player conventions should be preserved unless code proves a compelling deficiency. Custom playback chrome must not be invented without a functional requirement.

## Documentation Claims to Verify Against Code

- Deployment target, Swift mode, targets, build settings, and absence of packages.
- Repository map completeness and whether multiple UI generations or unlisted files exist.
- Exact AppModel state ownership, startup error handling, concurrent load behavior, refresh coupling, and sign-out semantics.
- Root navigation implementation, local surface selection, full-screen playback presentation, focus defaults, and restoration.
- Search/filter behavior and whether guide placeholders match the stated intent.
- Exact loading, empty, partial, error, offline, and session-expiry states.
- Authentication token parsing, cookie behavior, redirect/login-form detection, and secret handling.
- Playback request mappings, FairPlay runtime parsing, simulator behavior, cancellation, and error sanitation.
- AsyncImage usage and fallbacks; any undocumented cache behavior.
- Accessibility labels, reduced-motion handling, localization, analytics, tests, previews, and sample-data support.
- Any implemented functionality not represented in either document, and any documented behavior now stale or incomplete.
