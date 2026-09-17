# Public stream shortlist

Research date: 2026-09-16 (America/New_York)
Baseline reviewed: `5a2dd49fe30a2a25989207301d9a40a66305eab1`

## Recommendation

The best later QA sample is **Classic Arts Showcase**, **NHK WORLD-JAPAN**, and **DW English**, in that order. Each adds programming absent from the current catalog and has both a current publisher presence and a direct-HLS lead on a broadcaster-branded delivery host. Classic Arts Showcase is the standout: it is a free, noncommercial arts service, publishes a 24-hour web stream, and explicitly provides its programming free to broadcasters. None of those facts alone grants Joe TV permission to embed its web HLS feed, so endpoint provenance and acceptable use still need review before catalog work.

This shortlist treats the [iptv-org playlist directory](https://github.com/iptv-org/iptv/blob/master/PLAYLISTS.md) as an index of leads. The repository's channel names, resolution labels, geographic labels, and URLs are unverified metadata, not quality, reliability, rights, or access findings. I read playlist text and publisher pages only. I did not request any media playlist or segment, start playback, probe codecs, bypass access controls, use credentials, or operate a simulator.

The existing baseline already contains broad US cable/news/sports coverage, including BBC World News, CNN, CNBC, Fox News, Fox Weather, Discovery, TCM, ESPN-family and league networks; Boston/New England coverage includes NBC Boston, NHPBS services, Very Local WCVB Boston, WMUR Manchester, WMTW Portland, and WPTZ Burlington/Plattsburgh. The candidates below are not exact catalog duplicates. Their partial overlaps are called out.

## Ranked candidates

### 1. Classic Arts Showcase — promote to QA

- **Editorial value:** A rare 24-hour, noncommercial mix of ballet, opera, classical music, dance, visual art, musical theater, and classic-film clips. The publisher's [FAQ](https://www.classicartsshowcase.org/frequently-asked-questions/) says a new eight-hour show is assembled weekly and repeated three times per day. It intentionally has no item-level program guide.
- **Verified publisher facts:** The [official watch page](https://www.classicartsshowcase.org/watch-classic-arts-showcase/) publishes 24-hour internet viewing. The [official broadcaster information](https://www.classicartsshowcase.org/channel-list/information-for-broadcasters/) calls the service free to broadcast, cable, and PEG channels, unencrypted and available 24 hours; it describes the satellite feed as H.264 video with MPEG-1 Layer II audio. The [official about page](https://www.classicartsshowcase.org/about-cas/) describes the service as not-for-profit, free of charge, and commercial-free.
- **Untested access/format:** The [US playlist entry](https://github.com/iptv-org/iptv/blob/master/streams/us.m3u#L2854-L2856) labels a direct HLS master as 720p on `classicarts.akamaized.net`. That URL, label, variants, codecs, startup, audio, US reach, and stability were not tested. The official satellite codec statement does not prove the web rendition uses the same codec.
- **Integration/overlap:** Likely low technical cost if the direct master survives provenance and acceptable-use review. No exact catalog duplicate; it adds a much deeper arts/music/classics lane than TCM or general entertainment channels.

### 2. NHK WORLD-JAPAN — promote to QA

- **Editorial value:** English-language international news plus Japanese culture, travel, food, science, technology, and documentaries. It offers a distinctive perspective with less US cable-news repetition than another domestic news FAST channel.
- **Verified publisher facts:** NHK publishes an [official live-TV page](https://www3.nhk.or.jp/nhkworld/en/live_tv/) and an [official program schedule](https://www3.nhk.or.jp/nhkworld/en/tv/). These first-party pages establish a public live service and useful schedule, although their player behavior was not exercised.
- **Untested access/format:** The [Japan playlist text](https://github.com/iptv-org/iptv/blob/master/streams/jp.m3u#L323-L333) lists 1080p and 720p HLS masters on `hls.nhkworld.jp`; neither entry is marked geo-blocked there. A separate PBS-carried entry is marked geo-blocked. The labels, codec, US availability, content substitutions, playback quality, and long-run stability remain untested. The NHK-branded host is strong provenance evidence, but public delivery is not itself embedding permission.
- **Integration/overlap:** Likely low technical cost if one first-party master is stable. It overlaps BBC World News at the international-news level but adds substantial Japan, Asia, culture, and documentary programming absent from the catalog.

### 3. DW English — promote to QA

- **Editorial value:** English global news mixed with documentaries and scheduled science, health, culture, environment, business, and mobility programs. That breadth makes it more useful than a pure rolling-news addition.
- **Verified publisher facts:** DW publishes a current [English weekly program guide](https://amp.dw.com/en/dw-english-weekly-program-guide/a-6703019); the page available during research linked schedules for September 2026. DW's [English live-TV page](https://www.dw.com/en/live-tv/channel-english) is the first-party viewing destination. A [2026 monthly schedule](https://static.dw.com/downloads/76519818/DW%20English%20TV%20Program%20Schedule%202026-05.pdf) depicts DW English coverage in North America, but this was not a live US access test.
- **Untested access/format:** The [Germany playlist entry](https://github.com/iptv-org/iptv/blob/master/streams/de.m3u#L1331-L1337) labels two English HLS masters 1080p; one is on DW's `dwamdstream102.akamaized.net` delivery name and another is an Amagi distribution feed. A different third-party entry is marked geo-blocked. Resolution, codecs, US access, ad or regional variants, startup, and stability remain untested.
- **Integration/overlap:** Likely low technical cost for the DW-branded lead, subject to provenance and use review. It overlaps BBC World News, CNN, and other news channels, but its scheduled documentary/science/culture blocks provide useful differentiation.

### 4. CBS News Boston — high editorial value, player integration unresolved

- **Editorial value:** The strongest Boston-specific addition found: WBZ reporting, breaking news, weather, traffic, investigations, and local sports context.
- **Verified publisher facts:** CBS calls [CBS News Boston](https://www.cbsnews.com/boston/live/news-general/) a free 24/7 local news stream. Its [WBZ viewing information](https://www.cbsnews.com/boston/wbz-tv/) lists the web, CBS News apps, Pluto TV, Apple TV, Roku, Fire TV, PlayStation, and Xbox. The site also links a program guide.
- **Untested access/format:** No stable, clearly first-party direct HLS master was identified in the iptv-org US source. Resolution and codecs are unknown. Web/app publication does not establish a reusable media URL, tvOS-native integration path, or embedding rights. US access is strongly implied by the US station and distribution list but was not tested.
- **Integration/overlap:** Medium-to-high cost unless CBS offers a documented player/feed path. It overlaps NBC Boston and Very Local's WCVB Boston, while adding WBZ's newsroom and CBS local identity. Keep it high in product priority, below the three direct-stream QA leads.

### 5. beIN SPORTS XTRA — promising direct lead; provenance review first

- **Editorial value:** A useful free sports mix beyond the catalog's league and ESPN-heavy lineup. The current guide includes soccer plus motorsports, mountain biking, sailing, combat sports, 3x3 basketball, and padel.
- **Verified publisher facts:** A [July 20, 2026 beIN article](https://www.beinsports.com/en-us/soccer/articles/get-ready-for-more-top-soccer-action-on-bein-sports-2026-07-20) advertises games live for free on beIN SPORTS XTRA/CONNECT. The [official US TV guide](https://www.beinsports.com/en-us/tv-guide) publishes an XTRA schedule.
- **Untested access/format:** The [US playlist entry](https://github.com/iptv-org/iptv/blob/master/streams/us.m3u#L2571-L2573) labels a direct Amagi HLS master 1080p. Resolution, codecs, US access, event blackouts, slate frequency, audio, and stability were not tested. The hostname names beIN and Amagi, but the distributor URL is weaker provenance than a beIN-owned host; SecOps should review it before QA.
- **Integration/overlap:** Technically likely low if approved, but provenance and rights uncertainty raise overall cost to medium. It complements the existing sports catalog rather than duplicating one network's schedule.

### 6. NASA+ — excellent science/event source; no stable linear feed identified

- **Editorial value:** Free mission coverage, launches, spacewalks, science programming, documentaries, and original series. It would add a high-trust science lane not present in the catalog.
- **Verified publisher facts:** NASA says [NASA+](https://www.nasa.gov/ways-to-watch/) is free, ad-free, requires no subscription, and is available on the web and the NASA app, including Apple TV. The [NASA+ site](https://plus.nasa.gov/) publishes live/upcoming events. NASA's [August 10, 2026 distribution announcement](https://www.nasa.gov/news-release/nasa-debuts-on-discovery-coming-soon-to-hbo-max/) also describes a continuous NASA live feed on discovery+ while stating NASA+ remains free and ad-free on NASA's app and website.
- **Untested access/format:** No stable first-party direct HLS master was identified in the playlist text reviewed. Resolution, codecs, US restrictions, player/API behavior, and whether the public site exposes a reusable continuous linear feed are unknown. Event-specific URLs may be dynamic.
- **Integration/overlap:** Medium-to-high cost without a documented stable feed. It has no exact catalog duplicate; NHPBS/PBS programming is the nearest educational overlap. Advance only if product accepts a dynamic/event source or NASA documents a durable linear endpoint.

### 7. Women's Sports Network — strong programming gap; distribution path unresolved

- **Editorial value:** Women's live games, tournament cutdowns, highlights, documentaries, and athlete/league programming fill a clear gap in the current male-league-heavy sports catalog.
- **Verified publisher facts:** The [official service site](https://womenssports.com/) describes live game action and league/team partnerships and publishes a live-TV schedule; the [official live page](https://womenssports.com/live/) is the viewing destination. Its distribution language points viewers to supported streaming-platform live-TV guides.
- **Untested access/format:** No stable direct HLS entry was identified in the iptv-org US source. Resolution, codecs, US/region limits, event blackouts, player reuse, and stream stability are unknown. A public web player and FAST-platform distribution do not establish an embeddable feed.
- **Integration/overlap:** Medium-to-high until a documented feed is available. Editorial overlap with existing sports networks is low and complementary, making it worth retaining even though it is not ready for direct QA.

### 8. Documentary+ — attractive catalog, weak endpoint provenance

- **Editorial value:** A focused documentary lane spanning history, science, biography, nature, music, sports, comedy, and crime. This is more concentrated than Discovery's general schedule.
- **Verified publisher facts:** The [official service](https://www.docplus.com/) publishes Documentary+ on the web. Its [US Apple App Store listing](https://apps.apple.com/us/app/documentary-streaming-app/id1546625549?platform=watch) identifies Documentary Plus LLC, Apple TV support, and free viewing with ads; it also advertises subscriptions/in-app purchases, so not all app content should be assumed to match the linear channel.
- **Untested access/format:** The [US playlist entries](https://github.com/iptv-org/iptv/blob/master/streams/us.m3u#L3059-L3064) label US and international MediaTailor HLS masters 1080p. The AWS host does not visibly establish first-party control. Resolution, codecs, US access, ad insertion, schedule identity, startup, and stability remain untested.
- **Integration/overlap:** Low technical cost if the feed is legitimate and approved; medium-to-high overall due to provenance and product/linear-feed ambiguity. Some topical overlap with Discovery exists, but the documentary-only schedule is meaningfully different.

## Leads rejected or deferred

- **LiveNOW from FOX:** Free live access and direct FAST-distribution leads exist, but it substantially overlaps Fox News, Fox Weather, CNN, MSNBC, and the rest of the current rolling-news catalog. The playlist endpoints are distributor feeds rather than an obviously Fox-owned master. It does not displace the stronger Boston or international-news candidates.
- **Fubo Sports Network:** The playlist lead routes through another service's distribution path, and the current catalog already has extensive sports coverage. Without clearer first-party provenance or a uniquely valuable schedule, it is weaker than beIN SPORTS XTRA and Women's Sports Network.
- **Red Bull TV:** The [official live-events page](https://www.redbull.com/us-en/live-events) has excellent action/outdoor events, but it is event-oriented rather than a clearly stable linear channel. No durable first-party HLS master was identified. Revisit as an event-source product idea, not this channel shortlist.
- **FilmRise Classic TV and similar FAST movie feeds:** They could add classic movies, but the playlist leads use generic distribution CDNs and publisher-level provenance or reusable-feed terms were not established in this pass. TCM already covers the broad classic-film need. Do not promote an arbitrary restream merely to fill the category.
- **Raw playlist rebroadcasts of existing premium/cable channels:** Many entries use bare IP addresses, unrelated domains, user-agent/referrer workarounds, or opaque restream hosts. They were excluded regardless of attractive resolution labels because the source does not establish legitimacy, durability, or permission.

## Promotion rubric for a later QA pass

A candidate should enter the app only after all of these are recorded:

1. **Provenance and access:** Confirm the endpoint belongs to the broadcaster or an authorized distributor, is reachable through ordinary US access, needs no credentials or geo bypass, and has an acceptable integration/use basis. Escalate ambiguous CDN and embedding questions to SecOps.
2. **Controlled startup observation:** Play one candidate at a time on clear media. Record request-to-first-moving-frame time and any startup slate, error, redirect, or token behavior. A playlist resolution label is not a measurement.
3. **Bounded sustained play:** Observe a defined interval long enough to cross multiple segments and, where practical, a program/ad boundary. Record stalls, retries, discontinuities, black frames, persistent slates, and terminal errors.
4. **Picture, motion, and audio:** Record the selected variant and observed codec/resolution when tooling exposes them; verify legible picture, natural motion, synchronized intelligible audio, and no persistent mute or corruption.
5. **Channel identity and schedule:** Confirm the content matches the named channel, the identity remains stable across relaunch, and a useful official schedule/EPG mapping exists or the lack of one is an intentional product choice.

A short successful sample supports a catalog decision; it does **not** establish long-term reliability, future US availability, unchanged URLs, or rights to redistribute/embed. Record the test date, network context, device/build, endpoint provenance, sample duration, and observed failures so later regressions can be compared.

## Source and evidence limits

- Sources were accessed on 2026-09-16. Publisher pages and these playlist files are mutable: [US](https://github.com/iptv-org/iptv/blob/master/streams/us.m3u), [Japan](https://github.com/iptv-org/iptv/blob/master/streams/jp.m3u), and [Germany](https://github.com/iptv-org/iptv/blob/master/streams/de.m3u).
- “First-party” above describes the publisher page. “Broadcaster-branded delivery host” is narrower evidence about a URL's name and does not prove ownership, authorization, or embedding permission.
- No media endpoint was requested. All resolution, geo, and direct-HLS statements attributed to iptv-org are playlist text claims awaiting measurement.
- No conclusion here is a legal determination. Public availability and free viewing are separate from permission to embed or redistribute a feed.
