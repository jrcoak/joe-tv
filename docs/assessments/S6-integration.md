# S6 integration and acceptance

Base Joe-TV only; baseline 46256bc, integration branch codex/base-guide-captions. Preserve bundle, build number, data and the unrelated SHELF directory. No release is authorized for this slice.

PM runtime grant: sole operator of dedicated base QA simulator C95B257D-0111-40A1-9D02-2AD70D850FF8 (tvOS 26.5), beginning September 20, 2026 local evening, checkpoint after guide and caption verification or 30 minutes. In-place installation only. Other simulators, Plex fork, authenticated provider streams and shared settings are excluded. Navigation uses isolated deterministic fixtures; captions may use Apple's public clear HLS sample. PM stops media and returns this initially shut-down simulator to shutdown at cleanup. Specialists have no runtime access during this grant.

Baseline parser smoke and unsigned Debug simulator build passed. Only the existing deprecated FairPlay API compiler warnings were observed.

Automatic-caption initial preference: 10%, configurable. This is the stated PM assumption after the optional question received no answer; normal-volume captions remain Off. External TV/receiver volume must not be represented as observable without evidence.

First native guide pass (7bb7206) on dedicated QA: Standard remained eight dense visible rows; Standard/Large were reachable from the filter row using remote arrow keys. Selecting Large retained the screen and moved down to the selected current program. Eleven Down presses reached channel 12 and scrolled its long current title into view, keeping channel/program rows aligned and two-line text contained. Native inspection showed the initial Large text increase was insufficient for the photo; App follow-up 95492a7 increases titles to24, times18 and ruler20 with about six rows in a600-point viewport. This final typography requires a new native check.

Combined parser smoke and caption policy25 checks passed. First combined signed simulator build exposed a SwiftUI expression type-check timeout in PlayerScreen body (not present in baseline); Playback owns decomposition before final build. No runtime failure has been inferred from this compiler failure.

Caption research: [Apple's subtitle behavior](https://support.apple.com/guide/tv/change-subtitle-settings-atvb7d97de8b/tvos) is the relevant comparator. [Media-selection API](https://developer.apple.com/documentation/avfoundation/avplayer/appliesmediaselectioncriteriaautomatically) explains inherited automatic choices; per-group explicit selection must preserve preferred audio. [Output volume](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume) is public and observable, but actual external receiver/IR volume is not established by a finite value. Physical route verification remains distinct from policy tests. Apple's public streaming example manifest was checked and includes both subtitle and closed-caption groups; it is suitable for clear-stream rendering tests, not FairPlay acceptance.
