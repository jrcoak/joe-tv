import Foundation

struct PBSLivePlaybackReference {
    let streamURL: URL
    let licenseURL: URL?

    var usesFairPlay: Bool { licenseURL != nil }
}

enum PBSLiveClient {
    private static let certificateURL = URL(string: "https://static.drm.pbs.org/fairplay-cert")!

    static let channels: [LiveChannel] = [
        channel(
            id: "nhpbs:main",
            name: "NHPBS",
            stream: "https://urs-anonymous-detect.pbs.org/redirect/9acbbf378165441aa01fd41a4f8f2c28/",
            license: "https://proxy.drm.pbs.org/license/fairplay/86dcf623-1b29-4400-a9c1-8178800d041e-hls",
            logo: "https://image.pbs.org/stations/wenh-color-cobranded-logo-I1seXpP.png"
        ),
        channel(
            id: "nhpbs:explore",
            name: "NHPBS Explore",
            stream: "https://urs.pbs.org/redirect/948ca66cb55c42028a4d288ae2af7101/",
            logo: "https://image.pbs.org/stations/wenh-color-cobranded-logo-I1seXpP.png"
        ),
        channel(
            id: "nhpbs:world",
            name: "NHPBS World",
            stream: "https://urs.pbs.org/redirect/d3be347c04924c239087ca22e12bece2/",
            logo: "https://image.pbs.org/contentchannels/World_Channel_color_logo.png"
        ),
        channel(
            id: "nhpbs:kids",
            name: "PBS Kids",
            stream: "https://urs-anonymous-detect.pbs.org/redirect/405db58f21dc4e9b87dc0e26ab414753/",
            license: "https://proxy.drm.pbs.org/license/fairplay/est-cmaf-hls",
            logo: "https://image.pbs.org/contentchannels/KIDS_white_logo.png"
        )
    ]

    static func drmConfiguration(for reference: PBSLivePlaybackReference) -> DRMConfiguration? {
        guard let licenseURL = reference.licenseURL else { return nil }
        return DRMConfiguration(
            hlsURL: reference.streamURL,
            certificateURL: certificateURL,
            licenseProxyPrefix: nil,
            headers: [:],
            licenseURL: licenseURL
        )
    }

    private static func channel(
        id: String,
        name: String,
        stream: String,
        license: String? = nil,
        logo: String
    ) -> LiveChannel {
        let reference = PBSLivePlaybackReference(
            streamURL: URL(string: stream)!,
            licenseURL: license.flatMap(URL.init(string:))
        )
        return LiveChannel(
            id: id,
            name: name,
            logoURL: URL(string: logo),
            playback: .pbs(reference),
            genre: id == "nhpbs:kids" ? .kids : .entertainment
        )
    }
}
