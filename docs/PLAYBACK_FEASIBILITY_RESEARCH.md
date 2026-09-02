# Playback interaction and ESPN+ feasibility

Research date: 2026-09-01. This document records design and feasibility findings only. The quick-guide overlay, Picture in Picture, DVR, and ESPN+ consolidation described here are not implemented by this change.

## Quick switching while video remains visible

The strongest pattern across established live-TV apps is a lightweight overlay rather than reopening a full, opaque guide:

- Channels DVR opens a Quick Guide over video with current and next programs on favorite channels; its remote mappings also expose a timeline, last channel, and configurable guide/surfing sources.
- Sling documents a channel-surfing surface that keeps playback visible and a hold-Select previous-channel action.
- YouTube TV documents long-pressing Select to return to the last channel.

Recommended Joe-TV design: pressing Down while watching opens a translucent bottom **Quick Bar** with two rows or tabs:

1. **Recent** — the last 5–8 resolved content identities from this session, spanning Live TV, Sports, and ESPN+.
2. **Favorites** — favorite live channels with now/next metadata.

The current video should remain visible behind a dark gradient. Select changes streams, Menu closes the overlay, and long-press Select recalls the previous stream. Store stable provider/content descriptors in history, not raw stream URLs: provider URLs, cookies, and DRM licenses can expire and should be resolved again when selected. Keep only one active playback session so switching does not create overlapping provider connections.

Implementation options:

- **Recent carousel only:** smallest change and easiest focus model.
- **Favorites Quick Guide only:** best traditional channel-surfing feel, but does not span live sports and ESPN+.
- **Combined Quick Bar:** recommended; a little more state and focus work, but solves both cases without recreating the full guide over video.

Sources: [Channels remote controls](https://getchannels.com/docs/apps/remote-control/general/), [Channels Live TV and Quick Guide](https://getchannels.com/docs/apps/usage/live-tv/), [Channels settings](https://getchannels.com/docs/apps/usage/settings/), [Sling player controls](https://www.sling.com/help/en/learn-about-sling/using-sling/player-controls), [Sling channel-surfing features](https://www.sling.com/whatson/announcements/new-features), and [YouTube TV last-channel control](https://support.google.com/youtubetv/answer/7067974?hl=en).

## Picture in Picture

Feasibility is high. Apple explicitly supports PiP in tvOS through `AVPlayerViewController`. The clean path is to replace the full-screen SwiftUI `VideoPlayer` wrapper with an owned `AVPlayerViewController`, configure the background-audio capability/session, enable PiP, and implement the restoration delegate callback. FairPlay and ordinary HLS remain on the same `AVPlayer`; every provider still needs physical-device testing.

This is single-video PiP, not a multi-game mosaic. tvOS also supports swapping full-screen and PiP content, but Joe-TV would need to retain the controller/session and carefully resolve replacement streams before a swap. Apple's PiP sample requires a physical device.

Sources: [AVPlayerViewController](https://developer.apple.com/documentation/avkit/avplayerviewcontroller), [standard-player PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player), [tvOS PiP sample](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-playback-in-tvos), and [AVPictureInPictureController](https://developer.apple.com/documentation/AVKit/AVPictureInPictureController?changes=_8).

## DVR and time shifting

Durable DVR is not a good on-device tvOS feature. Apple limits persistent local storage to small `UserDefaults` data and treats downloaded/cache data as purgeable. A short, discardable live buffer is realistic; a dependable recording library is not.

A real **Record this show** feature should run on an always-on Mac mini or NAS service:

1. Save a recording request against stable EPG station/program IDs.
2. Resolve an authorized stream near the scheduled start.
3. Capture HLS segments to durable server storage.
4. Publish the recording library and playback manifests through the Personal Media API.
5. Enforce retention, disk quotas, cancellation, padding, and duplicate-recording rules.

The existing Mac mini publisher is the natural host. Phase one could add a purgeable 60–90 minute in-app time-shift buffer. Phase two could record explicitly permitted, non-DRM sources on the Mac mini. FairPlay sources must not be treated as recordable merely because Joe-TV can play them; offline/persistent content keys and recording rights require provider authorization and policy support.

Sources: [Apple's tvOS storage limits](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/) and [FairPlay Streaming overview](https://developer.apple.com/streaming/fps/FairPlayStreamingOverview.pdf). Channels provides a useful architectural comparison: its device app can buffer live TV, while durable DVR uses a separate server ([Channels Live TV](https://getchannels.com/docs/apps/usage/live-tv/), [Channels overview](https://getchannels.com/docs/getting-started/quick-start-guide/what-is-channels/)).

## ESPN+ consolidation inventory

The authenticated Seasons4U ESPN+ calendar was sampled across the previous 21 days, not just today's unusually narrow listing. Categories observed included:

- **College:** NCAA Football, NCAA Men's Soccer, NCAA Women's Soccer, NCAA Women's Volleyball, NCAA Women's Field Hockey, NCAA Men's Water Polo, High School Football.
- **Soccer:** Spanish LALIGA, Spanish LALIGA 2, Dutch Eredivisie, German 3. Liga, NWSL, Northern Super League, USL Championship, USL League One, UEFA Champions League Qualifying, UEFA Europa League Qualifying, English FA Community Shield.
- **Golf and racing:** PGA TOUR, NASCAR O'Reilly Auto Parts Series.
- **Combat:** Boxing, Professional Fighters League, Most Valuable Promotions, WWE NXT.
- **Tennis and other events:** US Open, World Surf League, Premier Lacrosse League, Women's Lacrosse League, World Nineball Tour, Sport Fishing Championship, Association of Pickleball Players, World Series of Poker.
- **Baseball and softball:** American Legion Baseball, Junior League Baseball, Little League Baseball, The New England Collegiate Baseball League, Banana Ball, Athletes Unlimited Softball, Women's Pro Baseball League.
- **Non-event/studio entries also mixed into the source:** ESPN FC Daily, Futbol W, Fútbol Americas, Fairways of Life, Flames Central, Pardon the Interruption, The Pat McAfee Show, The Golics, date-specific talk-show entries, and Mecum Auctions.

Folding real ESPN+ events into Sports is realistic because the existing parser already exposes category identity, title, and items. The source taxonomy is transient, however. Before implementing it, add a canonical category layer and an allowlist so newly named NCAA/soccer categories can map to stable user-facing groups while studio shows and replay-like noise stay excluded or live in a separate optional group. Persist preferences against the canonical IDs, not the upstream labels. The current separate ESPN+ calendar remains the safer presentation until that normalization exists.
