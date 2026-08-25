# SeasonsTV Technical Handoff

Last updated: August 15, 2026

## 1. Purpose and current scope

SeasonsTV is a native SwiftUI tvOS client for a user's existing Seasons4U membership. It reproduces the useful parts of the authenticated Seasons4U player experience without embedding the website in a `WKWebView`.

The app currently provides:

- Native email/password authentication against Seasons4U.
- Cookie-backed session restoration.
- A live sports/events catalog loaded from `/Player` markup plus its authenticated JSON schedule routes.
- A curated 66-channel lineup assembled from `/PlayerDRMChannels` and legacy `/Player#channels` actions.
- Native HLS playback for ordinary streams.
- Native FairPlay Streaming (FPS) support for the DRM channel pages.
- A tvOS-focused channel browser and absolute-time guide backed by production XMLTV data.

EPG comes from the independent Personal Media API. Guide and sports reads are authenticated with a private, app-scoped `MEDIA_READ_TOKEN` injected by the build, cached and revalidated with ETags, and matched to playback channels exclusively by numeric station ID. Seasons4U remains the source of playback; independent schedule failure must never prevent playback.

The app is an independent client. It must only be used with an authorized account and in accordance with the provider's terms and applicable content rights. It does not attempt to circumvent DRM, geo-restrictions, subscription entitlements, or blackouts.

## 2. Project status

### Confirmed

- The project builds for a generic physical tvOS destination without code signing.
- The app launches and navigates correctly in the tvOS Simulator.
- Catalog, DRM channel, HLS URL, playback payload, and DRM configuration parsing have smoke-test coverage.
- The curated channel directory, legacy channel identities, and XMLTV numeric mapping/window behavior have smoke-test coverage.
- Selecting a channel invokes the app's playback action.
- The native FairPlay request contract mirrors the authenticated website's contract.
- A signed physical Apple TV build successfully played the available FairPlay streams during August 15 validation.
- Simulator builds display an explanatory alert instead of opening a nonfunctional black FairPlay player.

### Not yet confirmed

- Login against every account state and server-side authentication variation.
- App Store distribution, provisioning, or production bundle configuration.
- Long-duration playback, stream switching, interruption recovery, or background behavior.
- Behavior for every sports controller or every future server-side markup variation.
- A server-side logout request. Current sign-out is local cookie deletion only.

Physical-device validation requires a signed build, an entitled Seasons4U account, the correct geographic/IP conditions, and a currently available channel.

## 3. Repository map

```text
SeasonsTV.xcodeproj/
  project.pbxproj                 Xcode project and tvOS build settings
Config/
  Shared.xcconfig                 Non-secret API URL and optional private include
  Private.example.xcconfig        Empty template; real Private.xcconfig is ignored
SeasonsTV/
  App/
    SeasonsTVApp.swift            SwiftUI entry point
    AppModel.swift                Main-actor application state and orchestration
  Models/
    Models.swift                  Domain models, errors, and PlaybackSession
    ChannelDirectory.swift        Curated playback identity/XMLTV station mapping
  Networking/
    SeasonsClient.swift           Authentication, HTTP, payload building, stream resolution
    HTMLCatalogParser.swift       Server-rendered HTML/JavaScript contract parsing
    MediaAPIConfiguration.swift   Private build configuration and legacy credential cleanup
    XMLTVGuideProvider.swift      MEDIA_READ_TOKEN requests, ETag caches, XMLTV parsing
  Playback/
    FairPlayResourceLoader.swift  FPS certificate/SPC/CKC exchange
  Views/
    DesignSystem.swift             Shared visual tokens and reusable state/artwork primitives
    RootView.swift                Login, catalog, live guide, shared visual system
    PlayerScreen.swift            Native AVPlayer presentation and playback errors
  Resources/
    Info.plist
    Assets.xcassets/               Colors plus 65 unique high-resolution channel logos
Tests/
  ParserSmoke.swift               Standalone parser and payload smoke test
scripts/
  import-channel-logos.sh         Rebuilds local channel assets from XMLTV icon entries
  validate-media-read-token.sh    Rejects unconfigured Release builds
README.md                         Short setup and feature summary
docs/
  TECHNICAL_HANDOFF.md            This document
```

There are no third-party dependencies, package managers, analytics SDKs, or persistence frameworks. The app consumes Seasons4U plus the separately deployed Personal Media API.

## 4. Build configuration

The single `SeasonsTV` application target has these important settings:

| Setting | Current value | Notes |
|---|---:|---|
| Platform | tvOS | Both device and Simulator are supported build destinations. |
| Deployment target | tvOS 17.0 | Chosen to allow modern SwiftUI/tvOS APIs. |
| Swift language mode | Swift 5 | Set in the project file. |
| Bundle identifier | `com.example.SeasonsTV` | Placeholder; replace before device distribution. |
| Development team | Configured locally | Confirm the intended team before physical distribution. |
| Version | 1.0 (build 1) | Initial project version. |
| Code signing | Automatic | Requires a configured Apple Developer team on hardware. |

Open `SeasonsTV.xcodeproj` in Xcode 26 or newer, select the SeasonsTV scheme, and choose a tvOS destination.

Guide and sports metadata require private build configuration:

1. Copy `Config/Private.example.xcconfig` to `Config/Private.xcconfig`.
2. Set `MEDIA_READ_TOKEN` to the same opaque, route-limited read token configured in the Personal Media API deployment.
3. Keep `Private.xcconfig` uncommitted. CI may instead inject the build setting from its secret manager.

`Config/Shared.xcconfig` supplies the non-secret base URL and optionally includes the private file. `Info.plist` exposes the expanded values to the app as `MediaAPIBaseURL` and `MediaReadToken`. Debug builds without a token remain usable for playback and show a clear schedule-configuration error. Release builds run `scripts/validate-media-read-token.sh` and fail when the token is missing, shorter than 32 characters, or a placeholder.

Generic device compilation without signing (verified successfully on August 12, 2026):

```sh
xcodebuild \
  -project SeasonsTV.xcodeproj \
  -scheme SeasonsTV \
  -sdk appletvos \
  -destination 'generic/platform=tvOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Before running on hardware:

1. Select a Development Team.
2. Replace `com.example.SeasonsTV` with a unique bundle identifier.
3. Pair/select the Apple TV in Xcode.
4. Confirm the Apple TV can reach Seasons4U under the account's required IP/region conditions.
5. Build, sign in inside the app, and test several channels.

## 5. High-level architecture

```text
SwiftUI views
    |
    v
AppModel (@MainActor, ObservableObject)
    |
    +--> SeasonsClient ------> seasons4u.com
    |       |                     |
    |       +--> cookie storage   +--> server-rendered HTML
    |       +--> URLSession       +--> JSON/XHR stream routes
    |
    +--> HTMLCatalogParser
    |       +--> catalog models
    |       +--> channel models
    |       +--> runtime DRM configuration
    |
    +--> XMLTVGuideProvider --> personal-media-api.vercel.app
    |       +--> private MEDIA_READ_TOKEN build configuration
    |       +--> independent XMLTV + sports JSON ETag caches
    |
    +--> PlaybackSession
            +--> AVPlayer
            +--> FairPlayResourceLoader --> certificate/license services
```

### Why this architecture

- **Native rather than embedded web:** tvOS needs predictable Siri Remote focus behavior and native AVPlayer presentation. The website's desktop/mobile layout is not suitable as the primary tvOS UI.
- **Runtime discovery rather than hard-coded stream data:** stream URLs, entitlement headers, certificate URLs, channel IDs, and license routes may be signed or account-specific. They are parsed at runtime and kept out of source control.
- **One application state object:** the project is still small. `AppModel` gives the views a single source of truth without adding an unnecessary architecture framework.
- **No third-party HTML parser:** avoiding dependencies keeps the project easy to open, but the regex-based parser is intentionally narrow and is a maintenance risk if upstream markup changes.
- **Separate networking and parsing:** HTTP/session concerns stay in `SeasonsClient`; interpretation of upstream HTML and JavaScript stays in `HTMLCatalogParser` so it can be tested using fixtures.

## 6. Application state and navigation

`AppModel` is `@MainActor` and owns user-visible state, including independent channel, event, EPG, and sports-schedule load states:

- `screen`: `.checkingSession`, `.signedOut`, or `.catalog`.
- `categories`: parsed sports/events catalog.
- `liveChannels`: available channels filtered and ordered by `ChannelDirectory`.
- `epgState` and `channelStationMappings`: independent guide load and numeric mapping state.
- `sportsSchedule` and `sportsScheduleState`: independent ESPN schedule metadata loaded with the same app-scoped read token.
- `enabledSportsCategoryIDs`: UserDefaults-backed category visibility; the first-run default is Football, Baseball, Hockey, and Basketball only.
- `selectedCategoryID`: selected sports/events category, initially `football`.
- `isWorking`: controls short blocking sign-in/playback preparation only; refresh is nonblocking.
- `errorMessage`: drives the global alert.
- `playbackSession`: drives the fullscreen player cover.

On initialization, `AppModel` starts `restoreSession()`:

1. It requests the sports catalog and mixed-source channel lineup concurrently. Channel loading itself requests both `/PlayerDRMChannels` and `/Player`.
2. Authentication failure enters `.signedOut`; otherwise the app can enter `.catalog` when either content source succeeds.
3. Each source keeps an independent loading/error state so partial or stale content remains usable.

The initial catch-all favors a usable login screen but now explains that restoration failed rather than silently presenting login. Manual refresh preserves successfully loaded or stale content; authentication failure returns to login with a session-expired message.

The catalog screen has two local surfaces:

- **Live TV** is the default and shows only mapped, currently discovered channels from the curated 66-channel directory.
- **Sports & events** merges `/Player` playback with Personal Media API schedule metadata, then shows only user-enabled categories. Empty enabled categories remain visible so temporary schedule gaps do not alter navigation.

Playback uses a `fullScreenCover(item:)` bound to `playbackSession`. Dismissing or exiting the player pauses AVPlayer.

## 7. Authentication and session handling

Seasons4U uses server-rendered ASP.NET-style form authentication.

### Login flow

`SeasonsClient.signIn` performs:

1. `GET https://seasons4u.com/Account/Login`.
2. Parse the hidden `__RequestVerificationToken` input.
3. `POST` the same route as `application/x-www-form-urlencoded` with:
   - `__RequestVerificationToken`
   - `Username`
   - `Password`
   - `RememberMe`
4. Let `URLSession` follow normal redirects and accept response cookies.
5. Treat a response URL under `/Account/Login`, or HTML still containing username/password fields, as rejected credentials.

`SeasonsClient` uses a `URLSessionConfiguration.default` session connected to `HTTPCookieStorage.shared`. Cookies received during login are automatically applied to later catalog, stream-resolution, certificate, and license requests.

### Security decisions

- Passwords are passed only to the login request and are not written to app storage.
- The Personal Media API read token is injected from ignored local configuration or a CI secret, expanded into the private app artifact, and used only for the approved guide/sports GET routes. It is never committed or logged. The server limits it to read-only schedule access and can revoke it centrally.
- A one-time upgrade cleanup deletes only the obsolete schedule pairing Keychain item. The app no longer reads or writes paired-device credentials.
- Authentication cookies are managed by the system cookie store; no cookie or token values are committed to the repository.
- Signed media URLs and runtime DRM values are kept in memory.
- Debug FairPlay logging includes only an error domain and numeric code, never request URLs, headers, SPC/CKC bytes, cookies, or tokens.
- The custom user agent is `SeasonsTV/1.0 (AppleTV; tvOS)`; the client does not impersonate a desktop browser.
- Response caching is disabled to reduce use of stale authenticated pages and signed URLs.

### Session expiry detection

The client considers the session invalid when:

- the server returns HTTP 401 or 403;
- a page redirects to `/Account/Login`; or
- the returned HTML contains the login form fields.

### Sign-out limitation

`AppModel.signOut()` pauses playback, clears in-memory models, and deletes local cookies whose domain contains `seasons4u.com`. It does **not** call a Seasons4U logout endpoint, so it does not revoke the server-side session. Add a remote logout call if the provider requires server-side invalidation.

## 8. Upstream website contracts

The implementation is based on authenticated inspection of these routes:

| Route | Purpose in the app |
|---|---|
| `/Account/Login` | Anti-forgery token and form login. |
| `/Player` | Sports/event shell, historical server-rendered rows, and ordinary playback invocations. |
| `/Player/WeeksList` | Available football weeks for the currently selected season. |
| `/Player/GameList` | Populated football schedule for a selected week; this is the authoritative source for current football rows. |
| `/Player/GameList_BSB` | Populated Baseball schedule and the authoritative live Home/Away media choices. |
| `/Player/BSBEventsPartial` | Lazy-loaded Baseball matchup rows and temporary direct backup streams. |
| `/Player/Watch*` | XHR endpoints that resolve ordinary events to HLS URLs. |
| `/PlayerDRMChannels` | Complete DRM channel lineup and playback page links. |
| `/PlayerDRMChannels/{id}` | Per-channel HLS, FPS certificate, headers, and license behavior. |
| `/PlayerDRMChannels/International/{id}` | International variant; may prefix the transformed license URL with a proxy route. |
| `GET https://personal-media-api.vercel.app/api/v1/guide/xmltv` | `MEDIA_READ_TOKEN`-authenticated, gzip-encoded XMLTV document with ETag revalidation. |
| `GET https://personal-media-api.vercel.app/api/v1/sports/schedule` | `MEDIA_READ_TOKEN`-authenticated normalized sports JSON with a separate ETag/cache lifecycle and no playback URLs. |

These are private implementation contracts rather than a documented public API. Every one should be treated as changeable.

## 9. Catalog and channel parsing

### Sports/events catalog

`HTMLCatalogParser.parseCatalog` maps historical server section IDs to native categories:

| Native category | Recognized upstream IDs |
|---|---|
| Football | `football` |
| Soccer | `st`, `worldcup`, `uefac`, `mls` |
| Basketball | `basketball`, `marchmadness` |
| Hockey | `hockey` |
| Baseball | `baseball` |
| College | `ncaaf` |
| Channels | `channels`, `espnp` |
| Combat | `mma` |
| Racing | `f1` |
| More | `others`, plus ungrouped rows |

Rows and dynamic schedule records produce a cleaned title, optional image, and one of four playback representations:

- `.hls(URL)` when an invocation contains a literal direct HLS URL.
- `.request(PlaybackRequest)` when an AngularJS-style `controller.Watch(...)` call must be resolved through an XHR route.
- `.drmPage(URL)` when the row links to a UUID-bearing DRM channel page.
- `.unavailable` when a schedule record is valid but the provider has not published a stream yet.

Dynamic Angular template placeholders such as `live.id` are rejected. Only quoted literal IDs without executable syntax or integer IDs are accepted. This prevents the native client from trying to evaluate server-provided JavaScript expressions.

Rows are deduplicated by playback identity, not display title. The app deliberately does not synthesize a Featured category because upstream 24/7 channel rows can appear inside event-oriented containers; Football is the deterministic default and every provider category remains directly available.

The current website no longer renders football matchups into the initial `/Player` response. Its Angular controller first posts the active year to `/Player/WeeksList`, chooses the first returned week, and posts that week/year/type tuple to `/Player/GameList`. `SeasonsClient.loadCatalog()` mirrors that authenticated sequence and replaces the historical Football category with the returned schedule. `parseDynamicGames` treats JSON keys case-insensitively, creates visible rows for scheduled matchups even before a stream exists, and retains every published playback choice. Those choices include Home/Away direct feeds and their DVR variants, domestic/international DRM routes, and alternate controller streams. The UI recommends one highest-quality compatible option and keeps the remaining choices in a collapsed Other Feeds section. Scheduled events without content use `.unavailable` and never present a working Play affordance. Football times are formatted in the provider's documented Eastern Time context rather than the simulator's local time zone.

This split is intentional: parsing only the initial HTML silently drops all current football games because that response contains `ng-repeat` templates rather than populated rows. If another sport migrates fully to a JSON-only feed, add its route in `SeasonsClient` and reuse the dynamic parser rather than attempting to evaluate Angular expressions.

Baseball has a related but distinct two-source contract. `/Player/GameList_BSB` is the authoritative schedule, and its parallel arrays split a live broadcast across `Media[index]` (Home/Away feed and playback ID) and `MediaOptionsForPlayer[index]` (the corresponding direct URL). The dynamic parser pairs those objects by index, orders Home before Away, and preserves both choices.

`/Player/BSBEventsPartial` can simultaneously publish a separately named backup feed for a game whose official schedule record has no media. `SeasonsClient` therefore loads both surfaces and merges supplemental playback by normalized matchup identity (for example, `Cardinals @ Cubs` matches `St. Louis Cardinals vs. Chicago Cubs`). The official title, status, ordering, and identity remain authoritative; a playable supplemental feed replaces the false unavailable state. If the official route is empty, the supplemental list becomes the Baseball category. Rows marked “Game has ended” have no playback identity and remain excluded.

### Live channel lineup

`parseDRMChannels` finds anchors with the `pdrm-chan` class, then extracts:

- name from `.pdrm-chan__name`, falling back to image `alt`;
- optional logo URL;
- playback page URL;
- channel ID from the URL's last path component.

Only paths containing a UUID-like identifier are accepted. `parseLegacyChannels` separately turns literal `/Player#channels` `bkb.Watch` and `hky.Watch` actions into identities of the form `legacy:<controller>:<type>:<id>`.

`SeasonsClient.loadLiveChannels()` requests `/PlayerDRMChannels` and `/Player` concurrently, parses both sources, then passes the discovered union to `ChannelDirectory.curate`. The directory is an intentional product allowlist of 66 mappings. Each mapping contains a canonical display name, stable Seasons4U playback identity, numeric XMLTV station ID, and XMLTV call sign. Only currently discovered mapped channels appear; arbitrary upstream additions do not leak into the product. Two CBS playback variants intentionally share station `16689`.

### Genre grouping

Genres are inferred locally from channel names using keyword rules: Sports, News, Entertainment, Lifestyle, Kids, and Spanish. Spanish is checked before Sports so names such as Spanish sports networks group as Spanish. Entertainment is the fallback.

This is intentionally presentation metadata, not provider truth. Genre selection and channel-name search are entirely local and generate no server requests.

### Why regex parsing was accepted

The parsed elements are narrowly constrained and the project has no dependency manager. Regex parsing made the first native client small and inspectable. Mitigations include fixture tests, bounded section scans, deduplication, literal-ID validation, and fallbacks for small markup variations.

It remains the most fragile layer. If server HTML changes materially, prefer replacing the parser with a proper HTML library and saved, sanitized fixtures rather than continuously expanding broad regular expressions.

## 10. Ordinary HLS playback

Some catalog items already contain a direct `.m3u8` URL. Those create `PlaybackSession(title:url:)` immediately.

Other items contain a `PlaybackRequest`. `PlaybackPayloadBuilder` converts the parsed controller and arguments into the JSON contract used by the website:

| Controller family | Endpoint |
|---|---|
| `fbl` / `p` | `/Player/Watch` |
| `bkb` / `bkbc` | `/Player/Watch_BKB` |
| `bsb` / `bsbc` | `/Player/Watch_BSB` |
| `hky` / `hkyc` | `/Player/Watch_HKY` |
| `ncf`, `ncaaf`, `xfl` variants | `/Player/Watch_NCAAF` |
| `mm`, `oli` variants | `/Player/Watch_OLI` |
| `mls` variants | `/Player/Watch_MLS` |

Baseball, college football/XFL, and MLS requests include .NET ticks calculated as Unix milliseconds multiplied by 10,000 plus `621355968000000000`.

Resolution requests are authenticated JSON `POST`s with `X-Requested-With: XMLHttpRequest` and a `/Player` referer. Successful payloads are scanned for an HLS URL. Known provider messages are translated into user-facing entitlement, temporary availability, authorization, or blackout errors. HTTP 500-class responses use a retry-oriented message because this behavior was observed from the provider.

The resolved URL is not persisted. `PlaybackSession` creates an `AVPlayerItem`, observes its status, and publishes a sanitized AVFoundation domain/code when playback fails.

## 11. FairPlay playback

### Runtime configuration

For a live channel, a physical-device build first fetches its authenticated playback page and parses:

- the HLS `.m3u8` URL;
- `certificateURL`;
- FairPlay request headers, observed to include values such as `Env`, `User-Id`, and `Channel-Id`;
- an optional international license proxy prefix.

No production values are hard-coded because they can be channel-, user-, environment-, or session-specific.

### Key exchange

`PlaybackSession(title:configuration:client:)` creates an `AVURLAsset`, retains a `FairPlayResourceLoader`, and assigns it as the asset resource-loader delegate on a private serial queue.

For each `skd://` key request, `FairPlayResourceLoader`:

1. Downloads the application certificate using the runtime headers and authenticated session.
2. Uses the **entire SKD URL string** as the content identifier. This matches the website's `prepareContentId` behavior, which returns the identifier unchanged.
3. Generates the SPC using AVFoundation.
4. Converts `skd://...` to `https://...` for the license URL.
5. Prepends the parsed proxy prefix for applicable international pages.
6. Sends the raw SPC as `application/octet-stream`, plus runtime headers.
7. Returns the raw response bytes as CKC to AVFoundation.

The website's inspected player configuration used raw SPC and raw CKC byte arrays; therefore the app does not base64-wrap, JSON-wrap, or otherwise transform those payloads.

Outstanding key tasks are retained in a dictionary keyed by loading request identity. Cancellation removes and cancels the corresponding Swift concurrency task. Access is protected by `NSLock` because AVFoundation delegate callbacks and task completion can occur across threads.

### Simulator behavior

FairPlay-protected video cannot be validated in the tvOS Simulator. During development, selecting AMC did reach the native AV player, but AVFoundation/CoreMedia reported stream/player errors and displayed a black player with a prohibited symbol.

`AppModel.makeDRMPlaybackSession` now uses `#if targetEnvironment(simulator)` to throw `fairPlayRequiresDevice` before opening the player. The Simulator therefore proves focus/action wiring but does not fetch or validate per-channel DRM configuration. A physical Apple TV follows the real configuration and key-exchange path.

### FairPlay risks and future work

- The final end-to-end key exchange has not yet been observed on hardware.
- The resource-loader flow uses `streamingContentKeyRequestData(forApp:contentIdentifier:options:)`. The standalone macOS smoke compilation reports it as deprecated on macOS 15; evaluate migration to `AVContentKeySession` or the modern asynchronous content-key request API for long-term maintenance.
- Certificate/license services may require additional headers or change response encoding.
- Persistent/offline keys are not implemented and are out of current scope.
- Do not add logging of SKD/license URLs or headers without redaction; they may contain entitlement-sensitive values.

## 12. TV guide, sports schedule, and private build authentication

`XMLTVGuideProvider` implements `EPGProviding` and `SportsScheduleProviding`. The Personal Media API is intentionally a separate authentication and failure domain from Seasons4U.

### Credential selection

This client calls only `/api/v1/guide/xmltv` and `/api/v1/sports/schedule` on the Personal Media API. Each request receives `Authorization: Bearer <MEDIA_READ_TOKEN>` individually; the token is not installed as a global `URLSession` header and is never sent to Seasons4U, publishing, pairing, discovery, history, feedback, or refresh routes. There is no television pairing screen or pairing-code exchange.

`MediaAPIConfiguration` loads the base URL and token from the built app's Info.plist expansion and rejects a missing URL, a token shorter than 32 characters, or an unexpanded/placeholder value. This is source-control protection and an operational guard, not tamper-proof secret storage: a person with the private app bundle can extract the token. The server-side read-only route scope and central revocation boundary are therefore required.

### Retrieval and caching

Guide requests send the app-scoped bearer token and `Accept: application/xml`. URLSession transparently decodes the response's gzip content encoding. The provider:

- never polls more frequently than once every five minutes;
- stores the strong ETag in UserDefaults and sends `If-None-Match`;
- writes the last successful decompressed XML document atomically into the Caches directory;
- keeps the cached document on 304 and uses it as a network-failure fallback;
- treats 404 as “not published,” 401 as a missing/stale/mismatched build token, and 503 as missing server configuration;
- preserves playback and presents schedule configuration/service failures inline instead of redirecting to pairing.

The ETag and refresh date are not secrets. The read token is never placed in UserDefaults or either cache.

Sports schedule requests use the same route-limited read token but call `/api/v1/sports/schedule` with `Accept: application/json`. They have separate five-minute attempt tracking, ETag, refresh timestamp, and atomic last-known-good JSON cache. The decoded event model preserves league, teams, scores, status, time, venue, thumbnail, team logos, and broadcast networks. Schedule-only events use `.unavailable`; matching a schedule record to a Seasons4U item enriches presentation while preserving the Seasons4U playback identity and options. The UI prefers the schedule thumbnail, then composes high-resolution home/away logos, and uses Seasons4U artwork only as the last fallback.

### Parsing and mapping

The XML parser reads `<channel>` and `<programme>` elements, preserving title, description, category, optional icon, absolute start, and absolute end. It filters to programs overlapping the requested window. A program is accepted only when its `programme@channel` numeric ID appears in both the curated allowed station set and an XMLTV `<channel id>` element. Display names and call signs are never used for runtime matching.

Browse cards use the matching current program. When upcoming data exists, the selected channel exposes a compact Up Next disclosure containing the next five programs. Schedule absence, stale cache, parse failure, build-configuration failure, token rotation, and service unavailability do not change the channel playback identity or availability.

## 13. UI and tvOS decisions

The visual design uses a restrained dark editorial character with warm gold accents, disciplined system typography, and native SwiftUI focus and controls.

Important decisions:

- **Live TV is the default surface** because channel playback became the immediate priority.
- **Rows, not tiny inline controls, are focusable.** Each channel/event row is one large Siri Remote target; focus updates a spatially stable contextual stage.
- **EPG is production-backed but playback-neutral.** Browse cards automatically show now-playing titles when present, Up Next appears only with useful schedule data, and playback never depends on EPG availability.
- **Live TV is one surface.** Search sits above genre-grouped channels. Right from a channel enters its Up Next disclosure; Select toggles the next five programs; Left returns to the channel; Back closes the disclosure before returning to global navigation. There is no Browse/Guide subnavigation or full-grid guide.
- **Curated channel branding is authoritative in Live TV.** The 66-channel directory resolves to 65 unique 512×384 asset-catalog images (the two CBS New York feeds share one station asset). Browse rows and the Live TV stage use those assets immediately and offline. XMLTV program icons are not promoted into the stage because upstream images can be generic or incorrectly associated with another network.
- **The logo library is reproducible.** `scripts/import-channel-logos.sh /path/to/xmltv.xml` reads numeric station IDs from `ChannelDirectory.swift`, resolves each XMLTV `<channel><icon>`, requests the existing TMS source at 512 pixels, validates the result, and regenerates the matching image sets. Confirm provider/TMS redistribution rights before public distribution.
- **Blocking loading is limited.** Sign-in and playback preparation use a task-specific overlay. Refresh preserves interaction and reports source-specific failures inline.
- **Errors are actionable.** Source refresh failures appear inline while stale content remains usable; session-wide errors use an alert; AVPlayer failures use an in-player overlay with “Return to Browse.”

The top bar keeps destination switching prominent and moves Refresh plus confirmed local Sign Out into the low-emphasis More menu. Pull-to-refresh is also present on both catalog surfaces.

Sports uses the same master/detail rhythm as Live TV: a vertically scrolling event list remains fixed on the left while the selected event's artwork, metadata, recommended feed, and collapsed alternate feeds remain stable on the right. Select on a row immediately plays the recommended feed; Right enters the detail actions; Left restores the originating event. Its explicit upward focus chain is event row → selected category → active top-navigation destination. Entering Sports no longer programmatically steals focus from the destination bar, and the handoff back to the bar is synchronous so a rapid Up–Left sequence cannot be swallowed by a deferred focus update.

## 14. Error model

`SeasonsError` centralizes user-facing failures:

- `authenticationRequired`
- `invalidCredentials`
- `invalidResponse`
- `emptyCatalog`
- `streamUnavailable`
- `fairPlayUnavailable`
- `fairPlayRequiresDevice`
- arbitrary provider-facing `message(String)`

Network validation accepts HTTP 200–399, maps 401/403 to authentication expiry, and otherwise reports the status. Playback resolution has a specialized response validator to make provider 500s less technical for the user.

AVPlayer failures are separate because they occur after the network orchestration has returned. `PlaybackSession` observes `AVPlayerItem.status` and publishes a sanitized message containing the error domain and numeric code. This is enough to distinguish common AVFoundation failures without exposing media URLs.

## 15. Testing and verification

`Tests/ParserSmoke.swift` is a standalone executable rather than an XCTest target. It currently verifies:

- `/Player` row and category parsing;
- rejection of dynamic template placeholders;
- dynamic football schedule parsing, including DRM, alternate-only, and scheduled/unavailable rows;
- official Baseball schedule parsing, including parallel `Media`/`MediaOptionsForPlayer` Home/Away choices;
- lazy-loaded Baseball partial parsing and exclusion of ended rows;
- controller canonicalization and endpoints;
- basketball, hockey, football, and timestamped baseball payloads;
- DRM page discovery;
- DRM channel sorting and genre grouping;
- mixed DRM/legacy channel identity parsing and the complete 66-channel directory;
- XMLTV numeric-only station matching, overlap filtering, metadata, and ordering;
- normalized sports JSON decoding, network/logo preservation, and schedule-to-playback enrichment without playback-identity changes;
- escaped HLS URL parsing;
- FPS HLS/certificate/header/international-proxy parsing.

It does not make live network requests and does not test form login, cookie persistence, session expiry, or real media playback.

Run it with a repository-local module cache:

```sh
mkdir -p .build/ModuleCache
swiftc \
  -parse-as-library \
  -swift-version 5 \
  -module-cache-path .build/ModuleCache \
  SeasonsTV/Models/Models.swift \
  SeasonsTV/Models/ChannelDirectory.swift \
  SeasonsTV/Networking/MediaAPIConfiguration.swift \
  SeasonsTV/Networking/HTMLCatalogParser.swift \
  SeasonsTV/Networking/SeasonsClient.swift \
  SeasonsTV/Networking/XMLTVGuideProvider.swift \
  SeasonsTV/Playback/FairPlayResourceLoader.swift \
  Tests/ParserSmoke.swift \
  -o .build/parser-smoke
.build/parser-smoke
```

Expected final output:

```text
Parser smoke test passed
```

The smoke command compiles against the host SDK and may emit a deprecation warning for the older AVAsset resource-loader SPC API. That warning is tracked as FairPlay technical debt; it is not a parser test failure.

Recommended validation after every upstream parser or playback change:

1. Run the parser smoke test.
2. Build the generic physical tvOS target.
3. Run the app in Simulator and verify login/restore, refresh, focus movement, filters, and both catalog surfaces.
4. Confirm a channel selection shows the physical-device FairPlay alert in Simulator.
5. Run a signed hardware test for ordinary HLS and several FPS channels.
6. Inspect logs for secrets before sharing diagnostics.

## 16. Known limitations and maintenance risks

### Highest priority

1. **Physical Apple TV FPS hardening:** initial playback works; complete long-duration, interruption, failure, and cancellation testing on hardware.
2. **Upstream contract fragility:** the application relies on private HTML, Angular invocation, and player-script shapes. Add sanitized real-page fixtures and failure telemetry before broad distribution.
3. **Production schedule-token validation:** configuration parsing and build injection are covered locally, but the matching private `MEDIA_READ_TOKEN` still needs end-to-end verification against the deployed API on both Simulator and physical Apple TV. Repeated 200/304 cycles, stale-cache behavior, and the full published station set also require extended observation.

### Other limitations

- Startup treats any catalog failure as signed-out, which can hide provider/network downtime as a login prompt.
- Catalog and channel refresh are coupled with `async let`; failure of either prevents both from updating.
- `HTTPCookieStorage.shared` is convenient but not an explicitly isolated per-account session store.
- Local sign-out does not revoke the server session.
- The app-scoped read token is extractable from a distributed private app artifact by design; its security depends on narrow server scope, controlled distribution, and coordinated revocation/rotation.
- The API supports one active `MEDIA_READ_TOKEN`, so rotation has no overlap window and requires a coordinated app/API rollout.
- No retry/backoff, reachability UI, request timeout policy, or cancellation from the loading overlay.
- No automated UI tests or XCTest target.
- No accessibility audit, localization, telemetry, crash reporting, or privacy manifest work has been completed.
- No app icon/top-shelf assets or production launch branding have been completed.
- Channel genres are heuristic and English-name dependent.
- The parser manually decodes only a small set of HTML entities.
- Channel logos are bundled locally; other event/program artwork has no custom cache or explicit storage budget.
- Only HLS/FairPlay is supported on tvOS. DASH/Widevine/PlayReady sources are intentionally ignored.

## 17. Recommended next steps

### Milestone A: hardware playback hardening

1. Retain the validated signing configuration and replace the example bundle ID before wider distribution.
2. Test a small matrix: domestic channel, international channel, ordinary HLS event, unauthorized channel, and expired session.
3. Capture only sanitized error domains/codes and HTTP statuses.
4. Correct any certificate/license response assumptions and add fixtures/tests for them.

### Milestone B: harden the integration

1. Save sanitized HTML/JSON fixtures representing `/Player`, lineup, domestic DRM, and international DRM pages.
2. Move the smoke checks into an XCTest target.
3. Expand the existing independent catalog/channel/EPG refresh states with explicit request cancellation and retry policy.
4. Distinguish network/provider outages from authentication failure during startup.
5. Add explicit request timeouts, cancellation, and conservative retry behavior.
6. Decide whether to isolate cookies in a dedicated persistent cookie store.

### Milestone C: schedule-token validation and polish

1. Inject the same private read token into Simulator and hardware builds, then observe repeated production 200/304 cycles across restart and reinstall.
2. Verify that missing/wrong client configuration and missing server configuration produce the intended inline errors while playback remains usable.
3. Validate every curated station against a published XMLTV document and flag unmapped/missing stations without matching by name.
4. Exercise current-time positioning, now-playing state, missing programs, malformed entries, and missing artwork against production payloads.
5. Add explicit stale-data age presentation if the last-known-good cache is used for an extended outage.
6. Preserve the invariant that guide outages never break live playback.

### Milestone D: release readiness

1. Complete branding, app icon, top shelf, privacy disclosures, accessibility, and localization.
2. Review provider authorization and distribution constraints.
3. Add production logging/crash reporting with strict secret redaction.
4. Run long-duration and network-interruption testing on multiple Apple TV generations/tvOS versions.

## 18. Rules for future contributors

- Never commit credentials, cookies, signed stream URLs, certificate/license URLs, entitlement headers, SPC, or CKC data.
- Preserve the rule that server-provided JavaScript is parsed as data, never evaluated.
- Do not weaken UUID/path checks merely to make malformed DRM links appear playable.
- Do not add a DRM bypass or substitute a non-FairPlay source when a channel is not entitled.
- Treat Simulator success as UI/network-parser confidence only, never as FPS playback proof.
- Keep EPG data and Seasons4U playback contracts as separate domains.
- Add or update fixtures whenever parser behavior changes.
- Test both domestic and international license URL construction after FairPlay changes.
- Keep user-facing errors concise and logs sanitized.

## 19. Primary implementation entry points

For an incoming engineer, read the code in this order:

1. `SeasonsTV/App/AppModel.swift` — lifecycle, state transitions, and orchestration.
2. `SeasonsTV/Networking/SeasonsClient.swift` — HTTP/session and playback payload contracts.
3. `SeasonsTV/Networking/HTMLCatalogParser.swift` — all upstream markup assumptions.
4. `SeasonsTV/Models/ChannelDirectory.swift` — authoritative playback/XMLTV mapping.
5. `SeasonsTV/Models/Models.swift` — domain and playback ownership.
6. `SeasonsTV/Networking/MediaAPIConfiguration.swift` — private build configuration validation and legacy schedule-token cleanup.
7. `SeasonsTV/Networking/XMLTVGuideProvider.swift` — route-scoped read-token requests, ETag caches, and XMLTV parser.
8. `SeasonsTV/Playback/FairPlayResourceLoader.swift` — FPS exchange.
9. `SeasonsTV/Views/RootView.swift` — login, guide, catalog UI, and schedule failure presentation.
10. `SeasonsTV/Views/PlayerScreen.swift` — AVPlayer presentation.
11. `Tests/ParserSmoke.swift` — executable examples of expected upstream shapes.

This order follows the actual data flow and makes implicit upstream assumptions visible before UI details.
