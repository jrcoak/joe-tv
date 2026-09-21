# S6 integration and acceptance

Base Joe-TV only; baseline 46256bc, integration branch codex/base-guide-captions. Preserve bundle, build number, data and the unrelated SHELF directory. No release is authorized for this slice.

PM runtime grant: sole operator of dedicated base QA simulator C95B257D-0111-40A1-9D02-2AD70D850FF8 (tvOS 26.5), beginning September 20, 2026 local evening, checkpoint after guide and caption verification or 30 minutes. In-place installation only. Other simulators, Plex fork, authenticated provider streams and shared settings are excluded. Navigation uses isolated deterministic fixtures; captions may use Apple's public clear HLS sample. PM stops media and returns this initially shut-down simulator to shutdown at cleanup. Specialists have no runtime access during this grant.

Baseline parser smoke and unsigned Debug simulator build passed. Only the existing deprecated FairPlay API compiler warnings were observed.

Automatic-caption initial preference: 10%, configurable. This is the stated PM assumption after the optional question received no answer; normal-volume captions remain Off. External TV/receiver volume must not be represented as observable without evidence.

First native guide pass (7bb7206) on dedicated QA: Standard remained eight dense visible rows; Standard/Large were reachable from the filter row using remote arrow keys. Selecting Large retained the screen and moved down to the selected current program. Eleven Down presses reached channel 12 and scrolled its long current title into view, keeping channel/program rows aligned and two-line text contained. Native inspection showed the initial Large text increase was insufficient for the photo; App follow-up 95492a7 increases titles to24, times18 and ruler20 with about six rows in a600-point viewport. This final typography requires a new native check.

The first native pass also opened channel12's future program details, then Back returned to that same future program and retained the vertical/horizontal guide position. This validates the unchanged focus structure, not the final typography.

Combined parser smoke and caption policy25 checks passed. First combined signed simulator build exposed a SwiftUI expression type-check timeout in PlayerScreen body (not present in baseline); Playback owns decomposition before final build. No runtime failure has been inferred from this compiler failure.

Caption research: [Apple's subtitle behavior](https://support.apple.com/guide/tv/change-subtitle-settings-atvb7d97de8b/tvos) is the relevant comparator. [Media-selection API](https://developer.apple.com/documentation/avfoundation/avplayer/appliesmediaselectioncriteriaautomatically) explains inherited automatic choices; per-group explicit selection must preserve preferred audio. [Output volume](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume) is public and observable, but actual external receiver/IR volume is not established by a finite value. Physical route verification remains distinct from policy tests. Apple's public streaming example manifest was checked and includes both subtitle and closed-caption groups; it is suitable for clear-stream rendering tests, not FairPlay acceptance.

Final guide typography native pass at ab486a3: Large persisted across app update/relaunch. Standard restored the original eight-row density; Large restored roughly six rows. Titles/times/ruler visibly enlarged, with two-line names/titles contained. Down from Large reached the selected current program; eleven additional Down presses scrolled to channel12, whose two-line long title and time stayed inside the focused row. Channel/program alignment remained intact. No provider or real media was involved in guide tests.

Native captions at38a9e6f: Apple's clear BipBop stream played, initially without captions. The caption dialog showed Off checked and Automatic10% checked. Manual EnglishCC visibly rendered Bip/Bop captions; reopening showed EnglishCC checked. Selecting Off removed rendered captions. The menu fit the screen and was reachable via Down then Right through player controls. This sample observation does not prove absence of a startup race: QA identified unguarded ordering before asyncOff installation, so a legible-rendering-only startup guard remains required. The public sample was stopped after this pass; no authenticated provider stream ran.

## Final acceptance

Application source is `219b4b1`; independent QA acceptance is `7b4fc82` (specialist report `bb4db9f`). The startup guard now attaches a suppressing legible output before the item enters AVPlayer and removes it only after explicit selection. QA accepted the bounded correction; the earlier compiler and caption-source blockers above are resolved.

Fresh final checks passed: `scripts/team-check.sh smoke`, `scripts/test-caption-policy.sh` (34), `scripts/test-guide-sizing.sh` (9), `scripts/team-check.sh build` (unsigned Debug simulator), ad-hoc signed arm64 Debug simulator build, and `git diff --check`. Existing FairPlay deprecation warnings remain. No release configuration, bundle identity or build number changed.

Final native caption acceptance on the dedicated tvOS 26.5 QA simulator used Apple's public clear BipBop stream and the DEBUG-only caption fixture. With injected volume0, EnglishCC was automatically selected and rendered Bip/Bop at startup. Manual Off removed the captions and kept them absent for more than20seconds with the same injected quiet signal. A fresh session with injected volume1 displayed no captions; the dialog confirmed Off checked and Automatic10% checked. These injected values verify application behavior, not physical output-volume reporting. The previous real-monitor sample also started Off and supported manual CC.

Artifact: `.build/S6SimulatorDerivedData/Build/Products/Debug-appletvsimulator/Joe-TV.app`. Debug dylib SHA-256: `a0c30db41d563e7a076bfd39127fcdde3ebe134ddfc434af9080964226b7c8c6`.

Remaining evidence limits: physical Siri Remote/TV/receiver volume reporting, remote mute signaling, FairPlay playback, and dynamic HLS group changes were not exercised. IR-controlled TV volume may not be observable, so the app cannot promise automatic captions for that route. Nonempty/required legible groups cannot offer normal Off selection and remain a media-format limit documented by Playback. No provider credentials, real provider streams, remote service changes, push or TestFlight upload were used.

Final normal-volume session also manually selected EnglishCC and visibly rendered Bip/Bop, verifying manual captions after the rendering guard was removed. Cleanup stopped the public sample and returned the dedicated simulator to shutdown, preserving app data. Runtime ownership is released. App, Playback and QA have completed their bounded assignments; no new work was dispatched.

## Independent-controls follow-up

Joe requested separate captions-on-mute and low-volume threshold settings. Mute captions default On; the optional threshold defaults Off unless an explicit prior choice exists. Automatic captions restore Off when neither enabled condition applies, at the exact threshold boundary, while manual On survives. Playback owns the bounded implementation on its existing branch; PM handles source review and native acceptance.

New PM runtime grant: sole operator of dedicated base QA simulator C95B257D-0111-40A1-9D02-2AD70D850FF8 for up to 20 minutes or final follow-up acceptance, whichever checkpoint arrives first. Public Apple clear-caption sample and DEBUG volume injection only. Other simulators and provider accounts excluded. PM stops media and returns QA to shutdown afterward, preserving saved data.
