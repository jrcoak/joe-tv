# SeasonsTV

A native SwiftUI tvOS client for a user's existing Seasons4U membership. The UI is adapted from the website's dark, editorial player design for Siri Remote focus navigation and native `AVPlayer` playback.

For architecture, authentication, parser contracts, FairPlay behavior, design decisions, verification status, known risks, and the contributor handoff, see [`docs/TECHNICAL_HANDOFF.md`](docs/TECHNICAL_HANDOFF.md).

## What is implemented

- Native email/password login against `/Account/Login`, including the server's anti-forgery token.
- Cookie-backed authenticated sessions. Passwords are used only for the login request and are not persisted by the app.
- Live catalog loading from `/Player`, including JSON-backed football and Baseball schedules, the lazy-loaded Baseball backup partial, historical server-rendered sports rows, standard streams, DRM variants, scheduled events, and remote artwork.
- A curated 66-channel Live TV lineup assembled from both `/PlayerDRMChannels` and legacy `/Player#channels` playback actions, with stable playback identities, an offline 512-pixel channel-brand library, genre rails, search, and contextual focus metadata.
- Production XMLTV guide data from Personal Media API, paired with a short-lived six-digit code and a permanent device token stored in Keychain. Guide refreshes use numeric station IDs, a five-minute floor, ETag revalidation, and a local last-known-good cache.
- Production ESPN sports schedules from the same paired Personal Media API credential, with independent JSON/ETag caching. Schedule events enrich Seasons4U playback rows with league, score, status, broadcast networks, thumbnails, and high-resolution team logos without treating schedule data as a playback source.
- Now-playing metadata plus an on-demand **Up Next** disclosure on each focused channel; schedules stay out of the way until requested, and channel playback remains independent when guide data does not exist.
- On-demand stream resolution through the site's authenticated `Watch_*` endpoints. Signed media URLs are kept only in memory.
- Native HLS playback with `AVPlayer`.
- FairPlay HLS support through `AVAssetResourceLoaderDelegate`, using the certificate, request headers, and license route supplied by each authenticated DRM page at runtime.
- Apple TV-specific Live TV browsing plus a vertical EPG-style sports master/detail surface, configurable persistent Sports categories (Football, Baseball, Hockey, and Basketball by default), focused-content stages, best-feed playback with collapsed alternate feeds, focus styles, refresh action, session expiry handling, and local sign-out.
- Independent Live TV and sports refresh states, focus restoration, task-specific loading feedback, and confirmed local sign-out.

## Run

1. Open `SeasonsTV.xcodeproj` in Xcode 26 or newer.
2. Choose an Apple TV simulator or a signed Apple TV device target.
3. Set your Development Team and replace the example bundle identifier if running on hardware.
4. Build and sign in with your Seasons4U account inside the app.
5. To enable TV programming and sports schedule data, choose **More → Connect Schedule Data** and enter a current six-digit code from the Personal Media API admin dashboard.

## Architecture notes

The website combines server-rendered markup with AngularJS JSON schedule feeds and uses ASP.NET-style anti-forgery form authentication, JSON/XHR playback resolution, several browser players for ordinary HLS, and Bitmovin configuration for DRM. The native app deliberately does not embed the site or copy credentials, cookies, entitlement headers, signed stream URLs, or license tokens into source control.

The provider currently advertises Widevine, PlayReady, and FairPlay on its DRM pages. tvOS uses only the FairPlay/HLS branch. If a channel exposes only DASH/Widevine, the app reports that the channel has no compatible FairPlay stream; it does not attempt to bypass DRM.

This is an independent client and should be used only with an authorized account and in accordance with the provider's terms and applicable content rights.
