# S6 QA — caption source review

## Handoff

- Assignment: bounded independent QA and final source re-review of the caption delta in original Joe-TV only.
- Baseline: `46256bc`; initial integrated PM head `aad1e78`; corrective Playback commits reviewed as `d0ca799` and `4118b3d` (cherry-picked on this QA branch as `f348ebe` and `f0271b0`).
- Branch: `codex/joe-tv-qa-s6`.
- Disposition: the three originally reported integration defects are addressed. Caption source acceptance remains blocked by the startup selection window below.
- Scope: caption-related `PlaybackSession` symbols in `SeasonsTV/Models/Models.swift`, volume-observer and compiler-extraction changes in `SeasonsTV/Views/PlayerScreen.swift`, and the focused pure policy test. The separately owned guide typography delta was not reviewed. No production edit, broad build, runtime, simulator, provider, network, media, device or screenshot operation occurred.

## Remaining blocking finding

### A session can begin with an implicitly selected subtitle before Off is installed

`PlaybackSession.makePlayer` now inserts the item while `AVPlayer.appliesMediaSelectionCriteriaAutomatically` remains enabled (`Models.swift:1517-1520`). The only explicit Off selection is made later by `installSubtitleOptions`, after the asynchronous legible-group load completes (`Models.swift:1591-1623`, `1658-1705`).

AVFoundation may apply automatic media-selection criteria when the item becomes ready. Because playback is allowed to start independently of the asynchronous legible load, a viewer whose system criteria select a legible option can have that option selected—and potentially render a cue—before `item.select(nil, in: group)` installs the session-specific Off override. The new late-group observer eventually reconciles the selection, but it does not make the initial state Off. This remains contrary to the S6 requirement that every playback session start captions Off and eliminate implicit AVFoundation caption selection.

Required correction: establish the legible-group Off override before rendered playback can expose an automatically selected subtitle, while preserving automatic preferred-audio selection. The exact timing and visible duration require the named native caption fixture; this source review establishes the unguarded ordering but does not claim that every HLS stream visibly flashes a cue.

## Original findings resolved by the corrective commits

1. **Late/failing legible-group handling:** `PlaybackSession` now observes `AVAssetMediaSelectionGroupsDidChange`, retries transient initial failures, retains an already usable group on refresh failure, and reapplies Off or the current manual/automatic policy when a late or changed group loads. Global automatic media selection is no longer held behind the legible load, preserving preferred audio. Once a group has been installed, the previously reported failure/recovery path no longer loses the ability to select Off.
2. **Queued volume delivery after stop:** `PlayerOutputVolumeMonitor` now advances an observation generation on start and stop, clears the retained observation before invalidation, and checks both generation and active observation inside the main-actor delivery. A callback captured by the stopped observation can no longer replace the unknown signal with stale quiet volume.
3. **Preferred caption language:** automatic selection now ranks the player's legible preferred languages, falls back to `Locale.preferredLanguages`, uses CC/SDH characteristics as a tie-breaker, and preserves source order as the final deterministic fallback. The focused test covers exact/base language matches, preference order, accessibility tie-breaking, deterministic fallback and an empty list.

Manual selection is reapplied across a group refresh only when its synthesized identifier remains present. That identifier includes language, display name and source index, so native dynamic-group verification should include an option-order change; the focused pure test does not instantiate media-selection groups.

## Accepted bounded behavior

The pure policy treats only finite values in `0...1` as observable volume, uses the configured entry thresholds with a two-point exit band, ends automatic captions on unknown/louder signals, retains manual track selection, and suppresses re-enabling after manual Off until the current quiet episode ends. The persistent control defaults to 10%, while each new `PlaybackSession` begins with caption policy state Off before full-screen observation supplies a valid sample. Only `PlayerSessionView` owns the volume monitor, so guide/Home previews do not participate in automatic captions. The UI exposes Off only for groups that allow empty selection.

The FairPlay resource loader, live-edge positioning, playback cleanup calls and player surface are not otherwise changed by the caption lifecycle correction. That source inspection is not evidence of DRM, rendered caption or audio-route behavior.

## Verification and native limits

- `sh scripts/test-caption-policy.sh` — passed 30 checks. The only output was the pre-existing FairPlay API deprecation warning.
- `git diff --check` passed for this report update.
- The focused runner does not instantiate AVPlayer, a real media-selection group or AVAudioSession. It confirms policy and option-ranking behavior, not startup ordering or HLS group lifecycle.

No native caption rendering, startup flash, dynamic HLS legible-group change or reordering, nonempty/forced group, focus/Back, output-volume route, external TV/receiver mute, audio selection, FairPlay playback or cleanup was observed. Physical Apple TV acceptance remains required, and `AVAudioSession.outputVolume` must not be presented as evidence of HDMI/IR receiver volume when the route does not report it.
