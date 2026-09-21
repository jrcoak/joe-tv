# S6 QA — caption source review

## Handoff

- Assignment: bounded independent QA and final source re-review of the caption delta in original Joe-TV only.
- Baseline: `46256bc`; initial integrated PM head `aad1e78`; corrective Playback commits reviewed as `d0ca799`, `4118b3d` and `65edc4c` (cherry-picked on this QA branch as `f348ebe`, `f0271b0` and `3889fa7`).
- Branch: `codex/joe-tv-qa-s6`.
- Disposition: accepted at source level. The three original defects and the subsequent startup-selection blocker are addressed. Named native fixture and physical-device limits remain below.
- Scope: caption-related `PlaybackSession` symbols in `SeasonsTV/Models/Models.swift`, volume-observer and compiler-extraction changes in `SeasonsTV/Views/PlayerScreen.swift`, and the focused pure policy test. The separately owned guide typography delta was not reviewed. QA authored no production edit; no broad build, runtime, simulator, provider, network, media, device or screenshot operation occurred.

## Final startup correction accepted

The final delta attaches an `AVPlayerItemLegibleOutput` with `suppressesPlayerRendering = true` before the item is inserted into AVPlayer. Automatic media selection can therefore continue preparing preferred audio, while an implicitly selected legible cue cannot render during the asynchronous group load. The installed tvOS 26.5 SDK documents that only media supplied to the suppressing output is withheld; other item media is unaffected.

`installSubtitleOptions` releases and removes that gate only after applying an explicit selection: Off for an empty-selectable group, the retained manual or quiet-volume choice, or an explicit selected/preferred option for a group that cannot be empty. If no loadable legible group appears, the output stays attached and continues suppressing legible rendering without blocking other media. This resolves the previously unguarded startup ordering at source level.

The same delta removes source index from ordinary subtitle identity. Language, display name and accessibility kind now form the semantic base identifier, with duplicate ordinals used only when otherwise indistinguishable options coexist. An ordinary group reorder therefore retains a manual choice. It also makes Muted/0% exit immediately above zero and confines the finite in-range synthetic-volume override to DEBUG caption-fixture launches.

## Original findings resolved by the corrective commits

1. **Late/failing legible-group handling:** `PlaybackSession` now observes `AVAssetMediaSelectionGroupsDidChange`, retries transient initial failures, retains an already usable group on refresh failure, and reapplies Off or the current manual/automatic policy when a late or changed group loads. Global automatic media selection is no longer held behind the legible load, preserving preferred audio. Once a group has been installed, the previously reported failure/recovery path no longer loses the ability to select Off.
2. **Queued volume delivery after stop:** `PlayerOutputVolumeMonitor` now advances an observation generation on start and stop, clears the retained observation before invalidation, and checks both generation and active observation inside the main-actor delivery. A callback captured by the stopped observation can no longer replace the unknown signal with stale quiet volume.
3. **Preferred caption language:** automatic selection now ranks the player's legible preferred languages, falls back to `Locale.preferredLanguages`, uses CC/SDH characteristics as a tie-breaker, and preserves source order as the final deterministic fallback. The focused test covers exact/base language matches, preference order, accessibility tie-breaking, deterministic fallback and an empty list.

Manual selection is reapplied across a group refresh when the same semantic option remains present. Native dynamic-group verification should still include reordering and otherwise indistinguishable duplicate tracks because the focused pure test does not instantiate media-selection groups.

## Accepted bounded behavior

The pure policy treats only finite values in `0...1` as observable volume, exits Muted immediately above zero, gives percentage thresholds a two-point exit band, ends automatic captions on unknown/louder signals, retains manual track selection, and suppresses re-enabling after manual Off until the current quiet episode ends. The persistent control defaults to 10%, while each new `PlaybackSession` begins with caption policy state Off before full-screen observation supplies a valid sample. Only `PlayerSessionView` owns the volume monitor, so guide/Home previews do not participate in automatic captions. The UI exposes Off only for groups that allow empty selection.

The FairPlay resource loader, live-edge positioning, playback cleanup calls and player surface are not otherwise changed by the caption lifecycle correction. That source inspection is not evidence of DRM, rendered caption or audio-route behavior.

## Verification and native limits

- `sh scripts/test-caption-policy.sh` — passed 34 checks. The only output was the pre-existing FairPlay API deprecation warning.
- `git diff --check` passed for this report update.
- The focused runner does not instantiate AVPlayer, a real media-selection group, an `AVPlayerItemLegibleOutput` or AVAudioSession. It confirms policy, option ranking and semantic identity helpers, not rendered startup suppression or HLS group lifecycle.

No native caption rendering, startup flash, dynamic HLS legible-group change or reordering, nonempty/forced group, focus/Back, output-volume route, external TV/receiver mute, audio selection, FairPlay playback or cleanup was observed. Physical Apple TV acceptance remains required, and `AVAudioSession.outputVolume` must not be presented as evidence of HDMI/IR receiver volume when the route does not report it.

## Follow-up review

The bounded follow-up deltas `f31805f` and `6fdbe8d` are accepted against the requested requirements. Captions-on-mute defaults on independently; low-volume automation defaults Off and offers 5%, 10% and 20%; automation ends when neither trigger remains; manual tracks persist; and manual Off suppresses re-enabling within the active trigger episode. New preference keys are additive and preserve existing values while mapping the legacy mode key. Guide sizing is now Standard by default with the prior compact geometry retained under the preserved raw mapping, and its controls live in the renamed Settings sheet rather than the guide. No concrete source bug was found in these deltas. PM owns the final build and native fixture verification.
