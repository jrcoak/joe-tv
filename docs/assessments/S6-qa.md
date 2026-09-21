# S6 QA — caption source review

## Handoff

- Assignment: bounded independent QA of the caption delta in original Joe-TV only.
- Baseline: `46256bc`; integrated PM head `aad1e78` (`7bb7206` guide plus Playback delivery integrated from `11314df`).
- Branch: `codex/joe-tv-qa-s6`.
- Disposition: caption source acceptance is blocked by three integration findings below. The pure threshold/manual-override policy passes its focused test.
- Scope: `PlaybackSession` caption symbols in `SeasonsTV/Models/Models.swift` and caption integration in `SeasonsTV/Views/PlayerScreen.swift`. The separately owned guide typography delta was not reviewed. No production edits, full build, runtime, simulator, provider, network, media, device or screenshot operation occurred.

## Blocking findings

### 1. Legible-load failure and late group changes can bypass the session's explicit Off state

`PlaybackSession.makePlayer` disables `AVPlayer.appliesMediaSelectionCriteriaAutomatically` globally while the initial legible group loads. A successful group that allows an empty selection receives `item.select(nil, in: group)`, which creates the required group-specific override. The nil and error branches, however, call `completeInitialCaptionSelection`, which restores global automatic selection without an explicit legible-group override (`Models.swift:1478-1484`, `1543-1569`, `1631-1636`, `1655-1659`).

The installed tvOS 26.5 AVFoundation headers state that automatic criteria are applied when an item becomes ready and when system preferences change, while only a specific `selectMediaOption` call overrides automation for that group until `selectMediaOptionAutomatically` is called. The SDK also publishes `AVAssetMediaSelectionGroupsDidChangeNotification` for groups that appear or change after their initial load. This implementation does not observe that notification. A legible load that initially returns nil/fails and later exposes a group can therefore receive AVFoundation's implicit caption choice after global automation has been restored, violating the per-session Off requirement.

The refresh path has a second form of the same defect. `clearSubtitleOptions` drops the retained group and clears only policy bookkeeping; it does not turn off an already auto-selected option. If a later refresh fails while automatic captions are active, an unknown/louder volume cannot issue `select(nil)` because `subtitleGroup` is nil. Reinstalling the group does not apply initial Off again because `didInstallInitialCaptionSelection` is already true, so the automatic caption can remain selected after the quiet episode ended (`Models.swift:1646-1694`).

Required correction: keep explicit Off authority for every empty-selectable legible group across initial failure, late appearance and refresh failure/recovery. Do not restore implicit legible selection without first installing or preserving that override. Observe/reconcile group changes or otherwise prove late groups are handled. The correction must also preserve preferred audio selection; the current global hold makes audible automatic selection depend on the legible load settling and has no bounded recovery if that load remains pending.

### 2. A queued volume KVO callback can publish after monitoring stops

`PlayerOutputVolumeMonitor.start` converts each KVO callback into an unscoped main-actor `Task`. `stop` invalidates the observation and sets `outputVolume` to nil, but it does not invalidate callbacks already queued in those Tasks (`PlayerScreen.swift:37-61`). A callback captured before `stop()` can run afterward and replace nil with the stale quiet volume. `PlayerSessionView.onDisappear` first calls `stop()` and explicitly supplies unknown to end the automatic episode, but a subsequent stale publication can reach the view's `onChange` and re-enable captions after the full-screen owner has left (`PlayerScreen.swift:201-215`, `282-284`).

Required correction: add an observation generation/active token checked inside the main-actor delivery, and invalidate it before publishing nil during stop. A stopped monitor must never publish a captured sample.

### 3. Automatic caption selection ignores preferred language

`applyCaptionPolicyAction(.selectAutomatic)` chooses the first CC/SDH option, then the first option overall (`Models.swift:1681-1689`). It does not rank options by the viewer's preferred language or the AVPlayer's legible media-selection criteria. A stream ordered with a nonpreferred-language CC track before a preferred-language subtitle will automatically select the wrong language even though the requirement is to preserve a useful preferred caption choice.

Required correction: rank compatible options by current legible language preference and accessibility characteristics with a deterministic fallback. Keep manual track choice authoritative for the rest of that playback session.

## Accepted bounded behavior

The pure policy treats only finite values in `0...1` as observable volume, uses the configured entry thresholds with a two-point exit band, ends automatic captions on unknown/louder signals, retains manual track selection, and suppresses re-enabling after manual Off until the current quiet episode ends. The persistent control defaults to 10%, while each new `PlaybackSession` begins with caption policy state Off before full-screen observation supplies a valid sample. Only `PlayerSessionView` owns the volume monitor, so guide/Home previews do not participate in automatic captions. The UI exposes Off only for groups that allow empty selection and retains ordinary manual track selection.

The FairPlay resource loader, live-edge positioning, playback cleanup calls and player surface are not otherwise changed by the caption delta. That source inspection is not evidence of DRM or audio-route behavior.

## Verification and native limits

- `sh scripts/test-caption-policy.sh` — passed 25 checks. The only output was the pre-existing FairPlay API deprecation warning.
- `git diff --check` passed before this report was committed.
- The focused policy runner does not instantiate AVPlayer, a real media-selection group or AVAudioSession; it cannot cover the three integration findings.

No native caption rendering, startup flash, dynamic HLS legible-group change, nonempty/forced group, preferred-language ordering, focus/Back, output-volume route, external TV/receiver mute, audio selection, FairPlay playback or cleanup was observed. Physical Apple TV acceptance remains required, and `AVAudioSession.outputVolume` must not be presented as evidence of HDMI/IR receiver volume when the route does not report it.
