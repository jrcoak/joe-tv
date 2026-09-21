import Foundation

@main
private enum PlaybackCaptionPolicySmoke {
    private static var checks = 0

    private static func check(_ condition: Bool, _ message: String) {
        checks += 1
        if !condition { fatalError(message) }
    }

    static func main() {
        var state = PlaybackCaptionPolicyState()
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: nil, state: &state) == .none,
              "Unknown volume became quiet")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: .nan, state: &state) == .none,
              "Invalid volume became quiet")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.10, state: &state) == .selectAutomatic,
              "Ten-percent entry threshold did not enable")
        check(state.quietEpisodeActive && state.automaticCaptionsActive, "Quiet episode state was not retained")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.11, state: &state) == .none,
              "Hysteresis disabled captions inside the exit band")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.121, state: &state) == .selectOff,
              "Crossing the exit threshold did not restore Off")
        check(!state.quietEpisodeActive && !state.automaticCaptionsActive, "Quiet episode did not end")

        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.05, state: &state) == .selectAutomatic,
              "Second quiet episode did not enable")
        PlaybackCaptionPolicy.selectManualOff(state: &state)
        check(state.manualOffSuppressed && !state.automaticCaptionsActive, "Manual Off did not suppress the episode")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.04, state: &state) == .none,
              "Manual Off was ignored during the same quiet episode")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.20, state: &state) == .none,
              "Manual Off caused an unnecessary automatic deselection")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.04, state: &state) == .selectAutomatic,
              "A later quiet episode remained suppressed")

        PlaybackCaptionPolicy.selectManualTrack(state: &state)
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.50, state: &state) == .none,
              "Quiet exit replaced a manual caption track")
        check(PlaybackCaptionPolicy.update(mode: .tenPercent, outputVolume: 0.01, state: &state) == .none,
              "Automatic captions replaced a manual caption track")
        check(state.manualCaptionSelected, "Manual caption intent was lost")

        PlaybackCaptionPolicy.selectManualOff(state: &state)
        check(PlaybackCaptionPolicy.changeMode(state: &state) == .none, "Mode change disabled a nonautomatic selection")
        check(PlaybackCaptionPolicy.update(mode: .disabled, outputVolume: 0, state: &state) == .none,
              "Disabled automation reacted to zero volume")

        state = PlaybackCaptionPolicyState()
        check(PlaybackCaptionPolicy.update(mode: .zeroPercent, outputVolume: 0.001, state: &state) == .none,
              "Zero-percent mode treated low volume as mute")
        check(PlaybackCaptionPolicy.update(mode: .zeroPercent, outputVolume: 0, state: &state) == .selectAutomatic,
              "Zero-percent mode did not enable at zero")
        check(PlaybackCaptionPolicy.update(mode: .zeroPercent, outputVolume: 0.01, state: &state) == .selectOff,
              "Zero-percent mode remained active above mute")
        check(PlaybackCaptionPolicy.update(mode: .zeroPercent, outputVolume: 0, state: &state) == .selectAutomatic,
              "Zero-percent mode did not start a later muted episode")
        check(PlaybackCaptionPolicy.changeMode(state: &state) == .selectOff,
              "Changing mode did not remove automatic captions")
        check(PlaybackCaptionPolicy.update(mode: .fivePercent, outputVolume: 0.05, state: &state) == .selectAutomatic,
              "Five-percent threshold boundary failed")
        check(PlaybackCaptionPolicy.update(mode: .fivePercent, outputVolume: nil, state: &state) == .selectOff,
              "Unknown signal did not end an automatic quiet episode")
        check(PlaybackCaptionPolicy.update(mode: .twentyPercent, outputVolume: 0.20, state: &state) == .selectAutomatic,
              "Twenty-percent threshold boundary failed")
        check(PlaybackCaptionPolicy.update(mode: .twentyPercent, outputVolume: 0.221, state: &state) == .selectOff,
              "Twenty-percent hysteresis boundary failed")

        check(Set(PlaybackAutoCaptionMode.allCases.map(\.rawValue)).count == PlaybackAutoCaptionMode.allCases.count,
              "Persistent mode values are not unique")

        let selectionOptions = [
            PlaybackSubtitleOption(id: "es-cc", title: "Español CC", languageCode: "es", isClosedCaption: true),
            PlaybackSubtitleOption(id: "en", title: "English", languageCode: "en-US", isClosedCaption: false),
            PlaybackSubtitleOption(id: "en-cc", title: "English CC", languageCode: "en-GB", isClosedCaption: true),
            PlaybackSubtitleOption(id: "fr-cc", title: "Français CC", languageCode: "fr", isClosedCaption: true)
        ]
        check(PlaybackCaptionSelection.preferredOptionID(from: selectionOptions, preferredLanguages: ["en-US"]) == "en",
              "Exact preferred language did not outrank accessibility characteristics")
        check(PlaybackCaptionSelection.preferredOptionID(from: selectionOptions, preferredLanguages: ["en-CA"]) == "en-cc",
              "Accessibility preference did not break a base-language tie")
        check(PlaybackCaptionSelection.preferredOptionID(from: selectionOptions, preferredLanguages: ["fr", "en"]) == "fr-cc",
              "Preferred language ordering was ignored")
        check(PlaybackCaptionSelection.preferredOptionID(from: selectionOptions, preferredLanguages: ["de"]) == "es-cc",
              "Deterministic accessibility fallback changed")
        check(PlaybackCaptionSelection.preferredOptionID(from: [], preferredLanguages: ["en"]) == nil,
              "Empty options produced an automatic selection")

        let stableIdentity = PlaybackSubtitleIdentity.baseIdentifier(
            languageCode: "en_US",
            displayName: "English CC",
            isClosedCaption: true
        )
        check(stableIdentity == PlaybackSubtitleIdentity.baseIdentifier(
            languageCode: "en-US",
            displayName: "English CC",
            isClosedCaption: true
        ), "Equivalent language tags produced different subtitle identities")
        check(!stableIdentity.contains("|0"), "Subtitle identity retained a source-order index")
        print("Playback caption policy smoke passed (\(checks) checks)")
    }
}
