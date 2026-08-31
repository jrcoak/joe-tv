# JOE-TV design implementation

This document maps the delivered design proposal to the production tvOS app. It is deliberately honest about which surfaces use real app capabilities today and which concepts need product or backend work before they should appear in the interface.

## Implemented in the app

- **JOE-TV identity:** The visible app name, navigation wordmark, dialogs, sign-in language, and tvOS display name use JOE-TV.
- **Visual foundation:** Warm black (`#080A0D`), paper (`#F4F2ED`), live-signal coral (`#FF5B35`), and focus-only volt (`#D6FF4B`). Remote focus uses a four-point volt outline and 160 ms motion.
- **Primary navigation:** Home, Live TV, and Sports are peers. Playback remains an immersive full-screen layer, while channel and sports configuration remain inside the settings menu.
- **Home:** A real live or imminent sports event is selected from the loaded schedule when possible. Otherwise, JOE-TV promotes a currently airing channel. The Now & Next rail is built from the real channel lineup and EPG.
- **Live TV guide:** Moving focus previews a channel or program without tuning it. Select opens a reversible program layer. The grid uses real duration-aware EPG cells, an actual current-time line, channel artwork, a pinned preview panel, category filters, and vertical access to the full enabled lineup.
- **Sports Today:** Events are combined across the enabled sports instead of being isolated behind league-only lists. The surface shows one featured event, games live now, and events later today using real schedule, score, team-art, and stream availability data.
- **Broadcast selection:** Existing alternate feeds, including baseball home, away, and national options, are presented in a human-language chooser. Choosing a feed uses the app's existing playback resolver.
- **Live player:** Playback owns the screen. A compact live identifier and lower live edge appear briefly, then leave the video unobstructed. Existing loading and failure behavior remains intact.
- **Existing account and provider behavior:** Seasons4U sign-in, the free Very Local entry point, channel enable/disable settings, sports-category settings, EPG refresh, DRM handling, and HLS playback are preserved.

## Deliberately deferred

These ideas were shown in the proposal but do not have a complete product or service implementation in the current app. JOE-TV does not expose dead controls for them.

- **Start Over / Catch Up:** Needs a reliable archive or time-shift capability and entitlement rules.
- **Recording, reminders, and replay library:** Needs persistence, scheduling, notification behavior, and a recording/replay service.
- **Multiview and the automatic “Tonight's plan”:** Needs concurrent player/session management, connection-limit rules, audio-focus behavior, and performance testing on physical Apple TV hardware.
- **Spoiler Shield:** Needs a saved preference and comprehensive redaction across scores, thumbnails, titles, progress, replay durations, and notifications—not only a cosmetic score toggle.
- **Favorites, My Teams, and broadcast memory:** Needs user preference models and migration behavior. Channel enable/disable is not treated as the same thing as favoriting.
- **Schedule, Leagues, and Replays destinations:** Today works from current data; the other destinations need durable historical and future schedule queries.
- **Search and profile:** Needs product decisions about search scope and profile ownership.
- **Recommendation model:** Home currently uses deterministic, explainable live/imminent selection. Personal ranking and “since you left” require viewing history and preference data.
- **Silent rights resolution and blocked-feed recovery:** JOE-TV uses the feeds supplied by its current providers. Turning an unavailable feed into another valid path requires a formal rights/availability service.
- **True moving preview in the guide:** The pinned guide preview currently uses program/channel artwork. A live muted player should only be added after connection-limit and stream-session behavior are defined.
- **Custom caption and audio controls:** The native tvOS player owns available media controls today. A custom control layer needs media-option discovery and accessibility testing.

## Production asset note

The proposal's editorial stadium photography was reference material and was not copied into the app. JOE-TV uses provider artwork, channel/team assets, and generated gradients so the implementation does not silently ship unlicensed reference imagery.

## Validation checklist

- Build the Debug tvOS Simulator target without code signing.
- Verify Home, Live TV, and Sports can each receive and restore focus using only directional input, Select, and Back/Menu.
- Confirm focus movement never starts playback.
- Confirm program Select opens a layer and Back returns to the same guide context.
- Confirm a single-feed event starts directly and a multi-feed event opens the broadcast chooser.
- Confirm channel and sports settings remain available only from the More menu.
- Re-test DRM playback and performance on a physical Apple TV before considering player or Multiview work complete.
