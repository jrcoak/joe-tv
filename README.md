# SeasonsTV

A native SwiftUI tvOS client for a user's existing Seasons4U membership. The UI is adapted from the website's dark, editorial player design for Siri Remote focus navigation and native `AVPlayer` playback.

For architecture, authentication, parser contracts, FairPlay behavior, design decisions, verification status, known risks, and the contributor handoff, see [`docs/TECHNICAL_HANDOFF.md`](docs/TECHNICAL_HANDOFF.md).

## What is implemented

- Native email/password login against `/Account/Login`, including the server's anti-forgery token.
- Cookie-backed authenticated sessions. Passwords are used only for the login request and are not persisted by the app.
- Live catalog loading from `/Player`, including JSON-backed football and Baseball schedules, the lazy-loaded Baseball backup partial, historical server-rendered sports rows, standard streams, DRM variants, scheduled events, and remote artwork.
- A curated 66-channel Live TV lineup assembled from both `/PlayerDRMChannels` and legacy `/Player#channels` playback actions, with stable playback identities, an offline 512-pixel channel-brand library, genre rails, search, and contextual focus metadata.
- All 28 Very Local Hearst markets plus its national channel, using public station configuration, Apple-compatible HLS, public now/next guide data, and bundled high-resolution WMUR/WCVB branding. Very Local can also be opened without a Seasons4U session and does not require a second login.
- Production XMLTV guide data from Personal Media API, authenticated by a private build-injected `MEDIA_READ_TOKEN`. Guide refreshes use numeric station IDs, a five-minute floor, ETag revalidation, and a local last-known-good cache.
- Production ESPN sports schedules and normalized preview/recap details published by the Mac mini, then read from Personal Media API with the same route-limited token. Joe-TV never contacts ESPN. Featured-plus-four detail prefetch is nonblocking, limited to two concurrent reads, and uses per-event ETag/disk caching for richer hero artwork and descriptions without treating metadata as a playback source.
- Now-playing metadata plus an on-demand **Up Next** disclosure on each focused channel; schedules stay out of the way until requested, and channel playback remains independent when guide data does not exist.
- On-demand stream resolution through the site's authenticated `Watch_*` endpoints. Signed media URLs are kept only in memory.
- Native HLS playback with `AVPlayer`.
- FairPlay HLS support through `AVAssetResourceLoaderDelegate`, using the certificate, request headers, and license route supplied by each authenticated DRM page at runtime.
- Apple TV-specific Live TV browsing plus a vertical EPG-style sports master/detail surface, settings-only persistent channel visibility, a regional default that enables WCVB and WMUR while leaving other Very Local markets off, configurable persistent Sports categories (Football, Baseball, Hockey, and Basketball by default), focused-content stages, best-feed playback with collapsed alternate feeds, focus styles, refresh action, session expiry handling, and local sign-out.
- Independent Live TV and sports refresh states, focus restoration, task-specific loading feedback, and confirmed local sign-out.

## Run

1. Open `SeasonsTV.xcodeproj` in Xcode 26 or newer.
2. Choose an Apple TV simulator or a signed Apple TV device target.
3. Set your Development Team and replace the example bundle identifier if running on hardware.
4. Copy `Config/Private.example.xcconfig` to the ignored `Config/Private.xcconfig` and set the private `MEDIA_READ_TOKEN` used by the Personal Media API deployment.
5. Build and sign in with your Seasons4U account inside the app. Guide and sports metadata load automatically; there is no television pairing flow.

The login screen also offers **Watch Very Local free**. That route uses Very Local's public catalog and playback configuration; no Very Local credentials are requested or stored.

`Config/Private.xcconfig` must never be committed. Release builds fail when the token is missing, shorter than 32 characters, or still a placeholder. Debug builds remain buildable without it and show a configuration-oriented schedule error while preserving Seasons4U playback.

## Architecture notes

The website combines server-rendered markup with AngularJS JSON schedule feeds and uses ASP.NET-style anti-forgery form authentication, JSON/XHR playback resolution, several browser players for ordinary HLS, and Bitmovin configuration for DRM. The native app deliberately does not embed the site or copy credentials, cookies, entitlement headers, signed stream URLs, license tokens, or the Personal Media API read token into source control.

The provider currently advertises Widevine, PlayReady, and FairPlay on its DRM pages. tvOS uses only the FairPlay/HLS branch. If a channel exposes only DASH/Widevine, the app reports that the channel has no compatible FairPlay stream; it does not attempt to bypass DRM.

This is an independent client and should be used only with an authorized account and in accordance with the provider's terms and applicable content rights.
