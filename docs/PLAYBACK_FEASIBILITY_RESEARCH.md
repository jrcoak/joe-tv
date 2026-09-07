# Playback interaction and ESPN+ feasibility

Research date: 2026-09-01. The quick-switch overlay was implemented on 2026-09-06 and the conventional Siri Remote mapping was implemented on 2026-09-07. Picture in Picture, DVR, and ESPN+ consolidation remain feasibility findings only.

## Quick switching while video remains visible

The strongest pattern across established live-TV apps is a lightweight overlay rather than reopening a full, opaque guide:

- Channels DVR opens a Quick Guide over video with current and next programs on favorite channels; its remote mappings also expose a timeline, last channel, and configurable guide/surfing sources.
- Sling documents a channel-surfing surface that keeps playback visible and a hold-Select previous-channel action.
- YouTube TV documents long-pressing Select to return to the last channel.

Implemented Joe-TV design: while video is unobstructed, Select, Up, or Down reveals playback controls with Play/Pause focused. A second Down opens the translucent bottom **Quick Switch** rail. A 0.6-second Select hold returns live playback to the last stream; it has no custom meaning during on-demand playback. The physical Play/Pause command toggles immediately. Left/Right seeks in ten-second steps only when AVPlayer reports a valid DVR or on-demand seek window, with repeated remote movement providing continued scrubbing. Page Up/Down changes live channels. Back closes the rail, then controls, then playback. The optional **Up/Down button channel surfing** preference restores blind channel surfing for users who want it, but is disabled by default so directional gestures follow the established playback-controls convention.

The controls surface includes the current EPG program, real start/end times, elapsed progress, and next-program title when guide data is available. The Quick Switch rail is one continuous focus path:

1. **Recent** — at most four resolved content identities from this session, newest first, spanning Live TV, Sports, and ESPN+.
2. **Favorites** — favorite live channels with now/next metadata, excluding the current stream and any favorite already present in Recent.

The current video remains visible behind a dark gradient. Select resolves and changes streams, Up returns to playback controls, and Menu/Back reverses one layer at a time before leaving playback. History stores stable provider/content descriptors rather than raw stream URLs, so provider URLs, cookies, and DRM licenses are resolved again when selected. Only one player is active; a failed Quick Switch, last-stream, or channel-surf attempt restores the prior session and reports the error without dismissing playback. Compile and policy tests cover the mapping and seek-window clamping; exact swipe/hold feel and Page Up/Down direction still require a physical Siri Remote check.

Implementation options:

- **Recent carousel only:** smallest change and easiest focus model.
- **Favorites Quick Guide only:** best traditional channel-surfing feel, but does not span live sports and ESPN+.
- **Combined Quick Bar:** implemented; it solves both cases without recreating the full guide over video.

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
