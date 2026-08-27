import Foundation

struct VeryLocalPlaybackReference: Equatable {
    let stationCode: String
}

enum VeryLocalError: LocalizedError {
    case unknownStation
    case invalidResponse
    case streamUnavailable
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unknownStation:
            return "That Very Local station is no longer available."
        case .invalidResponse:
            return "Very Local returned an unexpected response."
        case .streamUnavailable:
            return "Very Local has not published a playable stream for this station."
        case .serverStatus(let status):
            return "Very Local returned status \(status)."
        }
    }
}

final class VeryLocalClient {
    private struct Station {
        let code: String
        let name: String
        let logoFile: String

        var guideCode: String {
            code == "htv-national-desk" ? "national" : code
        }
    }

    private struct ConfigResponse: Decodable {
        struct Head: Decodable {
            let success: Bool
        }

        struct Payload: Decodable {
            struct FreewheelOTT: Decodable {
                let appleTVURL: String?
                let iPhoneURL: String?
                let publicaURL: String?

                enum CodingKeys: String, CodingKey {
                    case appleTVURL = "publica_url_appletv"
                    case iPhoneURL = "publica_url_iphone"
                    case publicaURL = "publica_url"
                }
            }

            let freewheelOTT: FreewheelOTT?

            enum CodingKeys: String, CodingKey {
                case freewheelOTT = "fw_ott"
            }
        }

        let head: Head
        let data: Payload?
    }

    private struct GuideResponse: Decodable {
        struct Head: Decodable {
            let success: Bool
        }

        struct Payload: Decodable {
            struct ScheduleItem: Decodable {
                let start: Date
                let end: Date
                let programID: String?
                let videoID: String?
                let thumbnail: String?
                let title: String
                let description: String?
                let genre: String?

                enum CodingKeys: String, CodingKey {
                    case start, end, thumbnail, title, description, genre
                    case programID = "programId"
                    case videoID = "videoId"
                }
            }

            let schedule: [ScheduleItem]
        }

        let head: Head
        let data: Payload?
    }

    private struct StationGuide {
        let stationCode: String
        let programs: [EPGProgram]
    }

    private static let configBaseURL = URL(string: "https://prod.magnum.htvapps.com/api/v1/")!
    private static let logoBaseURL = URL(
        string: "https://kubrick.htvapps.com/htv-prod-media.s3.amazonaws.com/htv_default_image/ott_vl_logo/"
    )!

    private static let stations: [Station] = [
        .init(code: "htv-national-desk", name: "Very Local National", logoFile: "NATIONALDESKBLUE.png"),
        .init(code: "koat", name: "KOAT · Albuquerque", logoFile: "KOATNEW.png"),
        .init(code: "wbal", name: "WBAL-TV · Baltimore", logoFile: "WBALNEW.png"),
        .init(code: "wvtm", name: "WVTM 13 · Birmingham", logoFile: "WVTMNEW.png"),
        .init(code: "wcvb", name: "WCVB 5 · Boston", logoFile: "WCVBNEW.png"),
        .init(code: "wptz", name: "NBC 5 · Burlington / Plattsburgh", logoFile: "WPTZNEW.png"),
        .init(code: "wlwt", name: "WLWT 5 · Cincinnati", logoFile: "WLWTNEW.png"),
        .init(code: "kcci", name: "KCCI 8 · Des Moines", logoFile: "KCCINEW.png"),
        .init(code: "wbbh", name: "WBBH · Fort Myers", logoFile: "WBBH.png"),
        .init(code: "khbs", name: "40/29 · Fort Smith / Fayetteville", logoFile: "KHBSNEW.png"),
        .init(code: "wyff", name: "WYFF 4 · Greenville", logoFile: "WYFFNEW.png"),
        .init(code: "wapt", name: "16 WAPT · Jackson", logoFile: "WAPTNEW.png"),
        .init(code: "kmbc", name: "KMBC 9 · Kansas City", logoFile: "KMBCNEW.png"),
        .init(code: "wgal", name: "WGAL 8 · Lancaster", logoFile: "WGALNEW.png"),
        .init(code: "wlky", name: "WLKY 32 · Louisville", logoFile: "WLKYNEW.png"),
        .init(code: "wmur", name: "WMUR 9 · Manchester", logoFile: "WMURNEW.png"),
        .init(code: "wisn", name: "WISN 12 · Milwaukee", logoFile: "WISNNEW.png"),
        .init(code: "ksbw", name: "KSBW 8 · Monterey", logoFile: "KSBWNEW.png"),
        .init(code: "wdsu", name: "WDSU 6 · New Orleans", logoFile: "WDSUNEW.png"),
        .init(code: "koco", name: "KOCO 5 · Oklahoma City", logoFile: "KOCONEW.png"),
        .init(code: "ketv", name: "KETV 7 · Omaha", logoFile: "KETVNEW.png"),
        .init(code: "wesh", name: "WESH 2 · Orlando", logoFile: "WESHNEW.png"),
        .init(code: "wtae", name: "WTAE 4 · Pittsburgh", logoFile: "WTAENEW.png"),
        .init(code: "wmtw", name: "WMTW 8 · Portland", logoFile: "WMTWNEW.png"),
        .init(code: "wmor", name: "WMOR · Tampa", logoFile: "WMORNEW.png"),
        .init(code: "kcra", name: "KCRA 3 · Sacramento", logoFile: "KCRANEW.png"),
        .init(code: "wjcl", name: "WJCL 22 · Savannah", logoFile: "WJCLNEW.png"),
        .init(code: "wpbf", name: "WPBF 25 · West Palm Beach", logoFile: "WPBFNEW.png"),
        .init(code: "wxii", name: "WXII 12 · Winston-Salem", logoFile: "WXIINEW.png")
    ]

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json",
                "User-Agent": "SeasonsTV/1.0 (tvOS; Very Local public playback)"
            ]
            self.session = URLSession(configuration: configuration)
        }
    }

    func loadChannels() -> [LiveChannel] {
        Self.stations.map { station in
            LiveChannel(
                id: "verylocal:\(station.code)",
                name: station.name,
                logoURL: Self.logoBaseURL.appending(path: station.logoFile),
                playback: .veryLocal(.init(stationCode: station.code)),
                genre: .news
            )
        }
    }

    func resolveStream(_ reference: VeryLocalPlaybackReference) async throws -> URL {
        guard Self.stations.contains(where: { $0.code == reference.stationCode }) else {
            throw VeryLocalError.unknownStation
        }

        let url = Self.configBaseURL
            .appending(path: reference.stationCode)
            .appending(path: "config")
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw VeryLocalError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw VeryLocalError.serverStatus(response.statusCode)
        }

        let config: ConfigResponse
        do {
            config = try JSONDecoder().decode(ConfigResponse.self, from: data)
        } catch {
            throw VeryLocalError.invalidResponse
        }

        guard config.head.success,
              let freewheel = config.data?.freewheelOTT,
              let value = freewheel.appleTVURL ?? freewheel.iPhoneURL ?? freewheel.publicaURL,
              let streamURL = URL(string: value),
              streamURL.scheme?.lowercased() == "https" else {
            throw VeryLocalError.streamUnavailable
        }
        return streamURL
    }

    func loadGuide(
        for channels: [LiveChannel],
        from start: Date,
        to end: Date
    ) async throws -> (window: EPGGuideWindow, mappings: [ChannelStationMapping]) {
        let requestedCodes = Set(channels.compactMap { channel -> String? in
            let prefix = "verylocal:"
            guard channel.id.hasPrefix(prefix) else { return nil }
            return String(channel.id.dropFirst(prefix.count))
        })
        let requestedStations = Self.stations.filter { requestedCodes.contains($0.code) }
        guard !requestedStations.isEmpty else {
            throw VeryLocalError.invalidResponse
        }

        let guides = await withTaskGroup(of: StationGuide?.self) { group in
            for station in requestedStations {
                group.addTask { [session] in
                    try? await Self.fetchGuide(
                        station: station,
                        start: start,
                        end: end,
                        session: session
                    )
                }
            }

            var loaded: [StationGuide] = []
            for await guide in group {
                if let guide { loaded.append(guide) }
            }
            return loaded
        }

        guard !guides.isEmpty else {
            throw VeryLocalError.invalidResponse
        }

        let programs = Dictionary(
            uniqueKeysWithValues: guides.map { ("verylocal:\($0.stationCode)", $0.programs) }
        )
        let mappings = requestedStations.map { station in
            ChannelStationMapping(
                channelID: "verylocal:\(station.code)",
                stationID: "verylocal:\(station.code)",
                provenance: .provider
            )
        }
        return (
            EPGGuideWindow(
                start: start,
                end: end,
                programsByStationID: programs,
                fetchedAt: Date()
            ),
            mappings
        )
    }

    private static func fetchGuide(
        station: Station,
        start: Date,
        end: Date,
        session: URLSession
    ) async throws -> StationGuide {
        var components = URLComponents(string: "https://epg.prod.htvapps.com/epg")!
        components.queryItems = [URLQueryItem(name: "station", value: station.guideCode)]
        guard let url = components.url else { throw VeryLocalError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw VeryLocalError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw VeryLocalError.serverStatus(response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let guide: GuideResponse
        do {
            guide = try decoder.decode(GuideResponse.self, from: data)
        } catch {
            throw VeryLocalError.invalidResponse
        }
        guard guide.head.success, let schedule = guide.data?.schedule else {
            throw VeryLocalError.invalidResponse
        }

        let stationID = "verylocal:\(station.code)"
        let programs = schedule.compactMap { item -> EPGProgram? in
            guard item.end > start, item.start < end else { return nil }
            let sourceID = item.programID ?? item.videoID ?? item.title
            return EPGProgram(
                id: "\(stationID):\(sourceID):\(item.start.timeIntervalSince1970)",
                stationID: stationID,
                title: item.title,
                start: item.start,
                end: item.end,
                synopsis: item.description,
                category: item.genre,
                imageURL: item.thumbnail.flatMap(URL.init(string:))
            )
        }
        return StationGuide(stationCode: station.code, programs: programs)
    }
}
