# S8 Playback — provider user agent transport repair

September 28, 2026. Assignment `S8-TRANSPORT`, baseline `d0f4de587313e10d7547d55ab3890423f34c8fc4`, branch `codex/s8-playback-transport`. Playback owns the bounded `PlaybackSession` URL initializer, the shared Seasons4U user-agent constant, the S4U-only AppModel call sites and this report.

PM's scoped native-app session trace isolated the CBS legacy route `legacy:bkb:channel:5012`: `/Player/Watch_BKB` returned HTTP 200 and a resolved non-FairPlay HLS master. Requesting that same master with a default Python user agent returned HTTP 403; requesting it with `Joe-TV/1.0 (AppleTV; tvOS)` returned HTTP 200 and a valid HLS playlist. The same app user agent plus a public Origin/Referer also returned 200, and no provider cookies were forwarded to the CDN. This establishes the HTTP user agent as the discriminating request identity in the observed master request. It does not yet prove child-resource or end-to-end playback success because the trace did not fetch the guarded child host or start media playback.

`SeasonsClient.playbackUserAgent` now owns the existing literal used by the authenticated URLSession. The non-DRM `PlaybackSession` URL initializer accepts an optional `httpUserAgent`; when present, it creates an `AVURLAsset` with only `AVURLAssetHTTPUserAgentKey`. Apple documents that public option as the User-Agent applied to HTTP requests made by the asset, available on tvOS 16 and later. With the project's tvOS 17 minimum, no availability branch is needed.

AppModel supplies the shared constant at exactly three S4U playback construction points:

- Sports direct HLS after current football metadata selection.
- Sports request-resolved HLS after `SeasonsClient.resolveStream`.
- Live-channel request-resolved HLS in `makePreviewSession`, which is shared by preview, full-screen selection and live-channel switching.

The optional initializer default preserves the system user agent for the caption URL fixture, Very Local and non-DRM PBS streams. The separate DRM initializer and its FairPlay certificate/license flow are unchanged because this evidence covers only non-FairPlay HLS. No cookies, Origin, Referer, generic headers, retries, alternate sources or fallback were added.

Offline verification passed: complete tvOS source type-check at the tvOS 17 deployment target, frontend parse of the three changed Swift files and `git diff --check`; `sh scripts/test-playback-failure.sh` passes 89 checks and `sh scripts/test-football-playback-refresh.sh` passes 35 checks. The existing FairPlay deprecation warning is unchanged. A new implementation-mirroring unit test was intentionally omitted; compiler validation and existing behavior suites cover this narrow option plumbing while PM retains the necessary end-to-end acceptance.

No Xcode build, simulator/device input, provider request, stream, installation, deployment or release ran in this worktree. PM must perform one serialized simulator validation of CBS `legacy:bkb:channel:5012` on the integrated candidate and confirm the master and child resources reach ready playback without a new support code. Physical-device FairPlay and NFL remain separate. Competitor comparison does not apply to this transport compatibility repair.
