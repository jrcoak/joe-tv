import AVFoundation
import Combine
import Foundation

struct CatalogCategory: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var items: [MediaItem]
}

struct SportsCategoryOption: Identifiable {
    let id: String
    let title: String
    let symbol: String

    static let all: [SportsCategoryOption] = [
        .init(id: "football", title: "Football", symbol: "football.fill"),
        .init(id: "baseball", title: "Baseball", symbol: "baseball.fill"),
        .init(id: "hockey", title: "Hockey", symbol: "hockey.puck.fill"),
        .init(id: "basketball", title: "Basketball", symbol: "basketball.fill"),
        .init(id: "soccer", title: "Soccer", symbol: "soccerball"),
        .init(id: "college", title: "College", symbol: "graduationcap.fill"),
        .init(id: "channels", title: "Channels", symbol: "tv.fill"),
        .init(id: "combat", title: "Combat", symbol: "figure.boxing"),
        .init(id: "racing", title: "Racing", symbol: "flag.checkered"),
        .init(id: "other", title: "More", symbol: "square.grid.2x2.fill")
    ]
}

struct MediaItem: Identifiable {
    enum Playback {
        case request(PlaybackRequest)
        case drmPage(URL)
        case hls(URL)
        case unavailable
    }

    struct PlaybackOption: Identifiable {
        let id: String
        let title: String
        let playback: Playback
    }

    let id: String
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let categoryID: String
    let playbackOptions: [PlaybackOption]
    let sportsEvent: SportsScheduleEvent?

    init(
        id: String,
        title: String,
        subtitle: String?,
        imageURL: URL?,
        categoryID: String,
        playback: Playback,
        sportsEvent: SportsScheduleEvent? = nil
    ) {
        self.init(
            id: id,
            title: title,
            subtitle: subtitle,
            imageURL: imageURL,
            categoryID: categoryID,
            playbackOptions: [PlaybackOption(id: "default", title: "Watch", playback: playback)],
            sportsEvent: sportsEvent
        )
    }

    init(
        id: String,
        title: String,
        subtitle: String?,
        imageURL: URL?,
        categoryID: String,
        playbackOptions: [PlaybackOption],
        sportsEvent: SportsScheduleEvent? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.categoryID = categoryID
        self.sportsEvent = sportsEvent
        self.playbackOptions = playbackOptions.isEmpty
            ? [PlaybackOption(id: "unavailable", title: "Unavailable", playback: .unavailable)]
            : playbackOptions
    }

    var playback: Playback {
        playbackOptions.first?.playback ?? .unavailable
    }

    var hasMultiplePlaybackOptions: Bool {
        playbackOptions.filter(\.isPlayable).count > 1
    }

    var isPlayable: Bool {
        playbackOptions.contains(where: \.isPlayable)
    }
}

struct SportsBroadcast: Decodable, Equatable {
    let channelID: String?
    let channel: String
    let country: String?
    let logoURL: URL?

    enum CodingKeys: String, CodingKey {
        case channelID = "channelId"
        case channel
        case country
        case logoURL = "logoUrl"
    }
}

struct SportsScheduleEvent: Decodable, Equatable, Identifiable {
    let eventID: String
    let title: String
    let sport: String?
    let leagueID: String?
    let league: String?
    let startsAt: Date
    let endsAt: Date?
    let status: String?
    let venue: String?
    let country: String?
    let homeTeamID: String?
    let homeTeam: String?
    let homeTeamLogoURL: URL?
    let awayTeamID: String?
    let awayTeam: String?
    let awayTeamLogoURL: URL?
    let homeScore: Int?
    let awayScore: Int?
    let thumbnailURL: URL?
    let sourceDate: String?
    let sourceTime: String?
    let broadcasts: [SportsBroadcast]

    var id: String { eventID }

    var broadcastChannels: [String] {
        var seen = Set<String>()
        return broadcasts.map(\.channel).filter { seen.insert($0.lowercased()).inserted }
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "eventId"
        case title
        case sport
        case leagueID = "leagueId"
        case league
        case startsAt
        case endsAt
        case status
        case venue
        case country
        case homeTeamID = "homeTeamId"
        case homeTeam
        case homeTeamLogoURL = "homeTeamLogoUrl"
        case awayTeamID = "awayTeamId"
        case awayTeam
        case awayTeamLogoURL = "awayTeamLogoUrl"
        case homeScore
        case awayScore
        case thumbnailURL = "thumbnailUrl"
        case sourceDate
        case sourceTime
        case broadcasts
    }
}

struct SportsScheduleSnapshot: Decodable, Equatable {
    let provider: String
    let generatedAt: Date
    let windowStart: String
    let windowEnd: String
    let events: [SportsScheduleEvent]
}

private extension MediaItem.PlaybackOption {
    var isPlayable: Bool {
        if case .unavailable = playback { return false }
        return true
    }
}

struct PlaybackRequest {
    let endpoint: String
    let controller: String
    let arguments: [String]
}

enum ChannelGenre: String, CaseIterable, Identifiable {
    case sports
    case news
    case entertainment
    case lifestyle
    case kids
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sports: return "Sports"
        case .news: return "News"
        case .entertainment: return "Entertainment"
        case .lifestyle: return "Lifestyle"
        case .kids: return "Kids"
        case .spanish: return "Spanish"
        }
    }

    var symbol: String {
        switch self {
        case .sports: return "sportscourt.fill"
        case .news: return "newspaper.fill"
        case .entertainment: return "sparkles.tv.fill"
        case .lifestyle: return "house.fill"
        case .kids: return "face.smiling.fill"
        case .spanish: return "globe.americas.fill"
        }
    }
}

struct LiveChannel: Identifiable {
    enum Playback {
        case drmPage(URL)
        case request(PlaybackRequest)
    }

    let id: String
    let name: String
    let logoURL: URL?
    let playback: Playback
    let genre: ChannelGenre
}

struct EPGProgram: Identifiable, Equatable {
    let id: String
    let stationID: String
    let title: String
    let start: Date
    let end: Date
    let synopsis: String?
    let category: String?
    let imageURL: URL?

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

struct EPGGuideWindow: Equatable {
    let start: Date
    let end: Date
    let programsByStationID: [String: [EPGProgram]]
    let fetchedAt: Date
}

struct EPGTimelineLayout {
    let windowStart: Date
    let windowEnd: Date
    let pointsPerMinute: Double

    var width: Double {
        max(0, windowEnd.timeIntervalSince(windowStart) / 60 * pointsPerMinute)
    }

    func frame(for program: EPGProgram) -> (offset: Double, width: Double)? {
        let visibleStart = max(program.start, windowStart)
        let visibleEnd = min(program.end, windowEnd)
        guard visibleStart < visibleEnd else { return nil }
        return (
            offset: visibleStart.timeIntervalSince(windowStart) / 60 * pointsPerMinute,
            width: visibleEnd.timeIntervalSince(visibleStart) / 60 * pointsPerMinute
        )
    }
}

struct ChannelStationMapping: Equatable {
    enum Provenance: Equatable {
        case explicit
        case provider
    }

    let channelID: String
    let stationID: String
    let provenance: Provenance
}

protocol EPGProviding {
    func loadGuide(
        for channels: [LiveChannel],
        from start: Date,
        to end: Date
    ) async throws -> (window: EPGGuideWindow, mappings: [ChannelStationMapping])
}

protocol EPGPairingProviding {
    var isPaired: Bool { get }

    func pair(code: String, deviceName: String) async throws
    func disconnect()
}

protocol SportsScheduleProviding {
    func loadSportsSchedule() async throws -> SportsScheduleSnapshot
}

enum EPGLoadState: Equatable {
    case unavailable
    case loading(cached: EPGGuideWindow?)
    case loaded(EPGGuideWindow)
    case failed(message: String, cached: EPGGuideWindow?)
}

enum ContentLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    var errorMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }

    var isLoading: Bool {
        self == .loading
    }
}

struct DRMConfiguration {
    let hlsURL: URL
    let certificateURL: URL
    let licenseProxyPrefix: String?
    let headers: [String: String]
}

@MainActor
final class PlaybackSession: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let player: AVPlayer
    @Published private(set) var playbackError: String?
    @Published private(set) var isReady = false
    private let resourceLoader: FairPlayResourceLoader?
    private var statusObservation: NSKeyValueObservation?
    private var preparationTimeout: Task<Void, Never>?

    init(title: String, url: URL) {
        self.title = title
        let item = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: item)
        self.resourceLoader = nil
        monitor(item)
        startPreparationTimeout()
    }

    init(title: String, configuration: DRMConfiguration, client: SeasonsClient) {
        self.title = title
        let asset = AVURLAsset(url: configuration.hlsURL)
        let loader = FairPlayResourceLoader(configuration: configuration, client: client)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "com.seasonstv.fairplay"))
        self.resourceLoader = loader
        let item = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: item)
        monitor(item)
        startPreparationTimeout()
    }

    private func monitor(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isReady = true
                    self?.preparationTimeout?.cancel()
                case .failed:
                    self?.isReady = false
                    self?.playbackError = "This stream could not be played. Return to browse and try again."
                    #if DEBUG
                    if let error = item.error as NSError? {
                        print("AVPlayer item failed [\(error.domain) \(error.code)]")
                    }
                    #endif
                default:
                    self?.isReady = false
                }
            }
        }
    }

    private func startPreparationTimeout() {
        preparationTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            guard let self, !self.isReady, self.playbackError == nil else { return }
            self.player.pause()
            self.playbackError = "This stream did not begin in time. Return to browse and try it again."
        }
    }

    deinit {
        preparationTimeout?.cancel()
    }
}

enum SeasonsError: LocalizedError {
    case authenticationRequired
    case invalidCredentials
    case invalidResponse
    case emptyCatalog
    case streamUnavailable
    case fairPlayUnavailable
    case fairPlayRequiresDevice
    case message(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Sign in to continue."
        case .invalidCredentials:
            return "That email or password was not accepted."
        case .invalidResponse:
            return "Seasons4U returned an unexpected response."
        case .emptyCatalog:
            return "No playable events or channels were found."
        case .streamUnavailable:
            return "This stream is not available right now."
        case .fairPlayUnavailable:
            return "This DRM channel did not provide a compatible FairPlay stream."
        case .fairPlayRequiresDevice:
            return "FairPlay channels cannot play in tvOS Simulator. Run this build on a physical Apple TV to test DRM playback."
        case .message(let message):
            return message
        }
    }
}
