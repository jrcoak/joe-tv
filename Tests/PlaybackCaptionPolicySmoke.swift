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
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .disabled, outputVolume: 0, state: &state
        ) == .none, "Disabled triggers reacted to mute")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: 0, state: &state
        ) == .selectAutomatic, "Mute trigger did not enable captions")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: 0.001, state: &state
        ) == .selectOff, "Unmute did not restore Off")

        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.10, state: &state
        ) == .selectAutomatic, "Low-volume threshold boundary did not enable")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.101, state: &state
        ) == .selectOff, "Volume above threshold did not restore Off")

        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .tenPercent, outputVolume: 0, state: &state
        ) == .selectAutomatic, "Combined triggers did not enable captions")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.05, state: &state
        ) == .none, "Unmute disabled captions while low-volume trigger remained active")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.11, state: &state
        ) == .selectOff, "Captions stayed automatic after both triggers ended")

        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: 0, state: &state
        ) == .selectAutomatic, "Manual-track setup did not enable")
        PlaybackCaptionPolicy.selectManualTrack(state: &state)
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: 0.5, state: &state
        ) == .none, "Unmute replaced a manually selected track")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .twentyPercent, outputVolume: 0.1, state: &state
        ) == .none, "Low-volume automation replaced a manually selected track")

        state = PlaybackCaptionPolicyState()
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .tenPercent, outputVolume: 0, state: &state
        ) == .selectAutomatic, "Manual-Off setup did not enable")
        PlaybackCaptionPolicy.selectManualOff(state: &state)
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .tenPercent, outputVolume: 0, state: &state
        ) == .none, "Manual Off did not hold during mute")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.05, state: &state
        ) == .none, "Manual Off did not hold while the other trigger remained active")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: false, lowVolumeThreshold: .tenPercent, outputVolume: 0.11, state: &state
        ) == .none, "Ending a manually suppressed episode selected Off again")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: 0, state: &state
        ) == .selectAutomatic, "A subsequent mute episode remained suppressed")
        check(PlaybackCaptionPolicy.update(
            muteEnabled: true, lowVolumeThreshold: .disabled, outputVolume: nil, state: &state
        ) == .selectOff, "Unknown volume did not end automatic captions")

        let defaults = PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil,
            existingLowVolumeThresholdRawValue: nil,
            legacyModeRawValue: nil
        )
        check(defaults == PlaybackAutoCaptionPreferences(muteEnabled: true, lowVolumeThreshold: .disabled),
              "New defaults did not enable mute independently with low volume Off")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil, existingLowVolumeThresholdRawValue: nil, legacyModeRawValue: "disabled"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: false, lowVolumeThreshold: .disabled),
              "Legacy disabled migration changed meaning")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil, existingLowVolumeThresholdRawValue: nil, legacyModeRawValue: "zeroPercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: true, lowVolumeThreshold: .disabled),
              "Legacy zero-percent migration changed meaning")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil, existingLowVolumeThresholdRawValue: nil, legacyModeRawValue: "tenPercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: true, lowVolumeThreshold: .tenPercent),
              "Legacy threshold migration changed meaning")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil, existingLowVolumeThresholdRawValue: nil, legacyModeRawValue: "fivePercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: true, lowVolumeThreshold: .fivePercent),
              "Legacy five-percent migration changed meaning")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil, existingLowVolumeThresholdRawValue: nil, legacyModeRawValue: "twentyPercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: true, lowVolumeThreshold: .twentyPercent),
              "Legacy twenty-percent migration changed meaning")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: false,
            existingLowVolumeThresholdRawValue: "fivePercent",
            legacyModeRawValue: "twentyPercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: false, lowVolumeThreshold: .fivePercent),
              "Existing new preferences were overwritten by migration")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: false,
            existingLowVolumeThresholdRawValue: nil,
            legacyModeRawValue: "twentyPercent"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: false, lowVolumeThreshold: .twentyPercent),
              "Existing mute preference was not preserved during partial migration")
        check(PlaybackAutoCaptionPreferenceMigration.resolve(
            existingMuteEnabled: nil,
            existingLowVolumeThresholdRawValue: "fivePercent",
            legacyModeRawValue: "disabled"
        ) == PlaybackAutoCaptionPreferences(muteEnabled: false, lowVolumeThreshold: .fivePercent),
              "Existing low-volume preference was not preserved during partial migration")
        check(Set(PlaybackAutoCaptionLowVolumeThreshold.allCases.map(\.rawValue)).count
                == PlaybackAutoCaptionLowVolumeThreshold.allCases.count,
              "Persistent low-volume values are not unique")

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
