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

        var isPlayable: Bool {
            if case .unavailable = playback { return false }
            return true
        }

        var isStartOver: Bool {
            if title.localizedCaseInsensitiveContains("dvr") ||
                title.localizedCaseInsensitiveContains("start over") ||
                title.localizedCaseInsensitiveContains("beginning") {
                return true
            }
            guard case .request(let request) = playback,
                  request.arguments.indices.contains(4) else { return false }
            return request.arguments[4].caseInsensitiveCompare("true") == .orderedSame
        }

        var broadcastKey: String {
            let requestFeed: String? = {
                guard case .request(let request) = playback,
                      request.arguments.indices.contains(2) else { return nil }
                return request.arguments[2]
            }()
            let titleValue = title.lowercased()
            if titleValue.contains("home") { return "home" }
            if titleValue.contains("away") { return "away" }
            if titleValue.contains("national") { return "national" }
            let value = (requestFeed ?? title).lowercased()
            if value.contains("home") { return "home" }
            if value.contains("away") { return "away" }
            if value.contains("national") { return "national" }
            if value.contains("spanish") { return "spanish" }
            if value.contains("international") || value.contains("intl") { return "international" }
            if value.contains("radio") { return "radio" }
            if value.contains("alternate") { return "alternate" }
            if value.contains("us feed") { return "us" }
            return title
                .replacingOccurrences(of: "· 5-min DVR", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "· DVR", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "DVR", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
    }

    let id: String
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let categoryID: String
    let playbackOptions: [PlaybackOption]
    let sportsEvent: SportsScheduleEvent?
    let providerEventDateCode: String?

    init(
        id: String,
        title: String,
        subtitle: String?,
        imageURL: URL?,
        categoryID: String,
        playback: Playback,
        sportsEvent: SportsScheduleEvent? = nil,
        providerEventDateCode: String? = nil
    ) {
        self.init(
            id: id,
            title: title,
            subtitle: subtitle,
            imageURL: imageURL,
            categoryID: categoryID,
            playbackOptions: [PlaybackOption(id: "default", title: "Watch", playback: playback)],
            sportsEvent: sportsEvent,
            providerEventDateCode: providerEventDateCode
        )
    }

    init(
        id: String,
        title: String,
        subtitle: String?,
        imageURL: URL?,
        categoryID: String,
        playbackOptions: [PlaybackOption],
        sportsEvent: SportsScheduleEvent? = nil,
        providerEventDateCode: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.categoryID = categoryID
        self.sportsEvent = sportsEvent
        self.providerEventDateCode = providerEventDateCode
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

enum SportsEventPhase: Equatable {
    case live
    case upcoming
    case replay
    case completed
}

extension MediaItem {
    static let sportsCoverageLeadTime: TimeInterval = 15 * 60

    var isGenericSportsChannelShortcut: Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("espn") && normalized.contains("use direct link") { return true }
        guard categoryID == "basketball" else { return false }
        return sportsEvent == nil && (normalized == "espn" || normalized == "espn 2")
    }

    func sportsPhase(at date: Date) -> SportsEventPhase {
        let statusText = [sportsEvent?.status, subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: " ")

        if Self.containsCompletionSignal(statusText) {
            return isPlayable ? .replay : .completed
        }
        if statusText.contains("replay") {
            return .replay
        }
        if Self.containsLiveSignal(statusText) {
            return .live
        }

        guard let event = sportsEvent else {
            return isPlayable ? .live : .upcoming
        }
        if event.startsAt > date {
            return .upcoming
        }
        if let end = event.endsAt, date < end {
            return .live
        }
        if event.endsAt == nil, date.timeIntervalSince(event.startsAt) < 5 * 3_600 {
            return .live
        }
        return isPlayable ? .replay : .completed
    }

    func sportsPlaybackAvailable(at date: Date) -> Bool {
        guard isPlayable else { return false }
        guard let sportsEvent else { return true }
        guard sportsPhase(at: date) == .upcoming else { return true }
        return date >= sportsEvent.startsAt.addingTimeInterval(-Self.sportsCoverageLeadTime)
    }

    var sportsCoverageStartsAt: Date? {
        sportsEvent?.startsAt.addingTimeInterval(-Self.sportsCoverageLeadTime)
    }

    private static func containsCompletionSignal(_ value: String) -> Bool {
        ["final", "complete", "ended", "full time", "post-game", "postgame"]
            .contains(where: value.contains)
    }

    private static func containsLiveSignal(_ value: String) -> Bool {
        ["live", "progress", "in progress", "halftime", "period", "quarter"]
            .contains(where: value.contains)
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

struct SportsEventDetailIdentity: Hashable, Sendable {
    let sport: String
    let league: String
    let eventID: String

    init?(event: SportsScheduleEvent) {
        guard let league = event.leagueID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else { return nil }
        let sport: String
        switch league {
        case "nfl": sport = "football"
        case "mlb": sport = "baseball"
        case "nba": sport = "basketball"
        case "nhl": sport = "hockey"
        default: return nil
        }
        guard !event.eventID.isEmpty, event.eventID.allSatisfy(\.isNumber) else { return nil }
        self.sport = sport
        self.league = league
        self.eventID = event.eventID
    }

    var cacheKey: String { "\(sport)/\(league)/\(eventID)" }
}

struct SportsEventDetailImage: Decodable, Equatable, Sendable {
    let url: URL
    let width: Int?
    let height: Int?
    let alt: String?
    let kind: String
}

struct SportsEventDetailStatus: Decodable, Equatable, Sendable {
    let state: String?
    let name: String?
    let description: String?
    let detail: String?
    let shortDetail: String?
}

struct SportsEventDetailVenue: Decodable, Equatable, Sendable {
    let name: String?
    let city: String?
    let state: String?
    let country: String?
}

struct SportsEventDetailWeather: Decodable, Equatable, Sendable {
    let displayValue: String?
    let temperature: Int?
    let condition: String?
    let wind: String?
}

struct SportsEventHighlight: Decodable, Equatable, Sendable {
    let id: String?
    let title: String
    let description: String?
    let duration: String?
    let thumbnail: SportsEventDetailImage?
}

struct SportsEventDetail: Decodable, Equatable, Sendable {
    let provider: String
    let eventID: String
    let sport: String
    let league: String
    let kind: String
    let headline: String?
    let description: String?
    let publishedAt: Date?
    let lastModifiedAt: Date?
    let heroImage: SportsEventDetailImage?
    let status: SportsEventDetailStatus?
    let venue: SportsEventDetailVenue?
    let weather: SportsEventDetailWeather?
    let highlights: [SportsEventHighlight]
    let fetchedAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case provider
        case eventID = "eventId"
        case sport
        case league
        case kind
        case headline
        case description
        case publishedAt
        case lastModifiedAt
        case heroImage
        case status
        case venue
        case weather
        case highlights
        case fetchedAt
        case expiresAt
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
        case veryLocal(VeryLocalPlaybackReference)
        case pbs(PBSLivePlaybackReference)
    }

    let id: String
    let name: String
    let logoURL: URL?
    let playback: Playback
    let genre: ChannelGenre
}

struct PlaybackTarget: Identifiable, Hashable {
    enum Source: Hashable {
        case liveChannel(channelID: String)
        case sports(categoryID: String, itemID: String)
        case espnPlus(dateCode: String, itemID: String)
    }

    let source: Source
    let playbackOptionID: String?
    let title: String
    let sourceLabel: String
    let detail: String?
    let imageURL: URL?

    var id: String {
        switch source {
        case .liveChannel(let channelID):
            return "channel:\(channelID)"
        case .sports(let categoryID, let itemID):
            return "sports:\(categoryID):\(itemID)"
        case .espnPlus(let dateCode, let itemID):
            return "espnplus:\(dateCode):\(itemID)"
        }
    }

    var channelID: String? {
        guard case .liveChannel(let channelID) = source else { return nil }
        return channelID
    }
}

struct QuickSwitchRailEntry: Identifiable, Hashable {
    enum Section: Hashable {
        case recent
        case favorite
    }

    let section: Section
    let target: PlaybackTarget

    var id: String { target.id }
}

enum PlaybackHistoryPolicy {
    static let recentLimit = 4

    static func transitioning(
        from previous: PlaybackTarget?,
        to next: PlaybackTarget,
        recents: [PlaybackTarget]
    ) -> [PlaybackTarget] {
        var updated = recents.filter { $0.id != next.id && $0.id != previous?.id }
        if let previous, previous.id != next.id {
            updated.insert(previous, at: 0)
        }
        return Array(updated.prefix(recentLimit))
    }

    static func stopping(
        current: PlaybackTarget?,
        recents: [PlaybackTarget]
    ) -> [PlaybackTarget] {
        guard let current else { return Array(recents.prefix(recentLimit)) }
        var updated = recents.filter { $0.id != current.id }
        updated.insert(current, at: 0)
        return Array(updated.prefix(recentLimit))
    }

    static func railEntries(
        recents: [PlaybackTarget],
        favorites: [PlaybackTarget],
        currentID: String?
    ) -> [QuickSwitchRailEntry] {
        var seen = Set<String>()
        if let currentID { seen.insert(currentID) }

        let recentEntries = recents.prefix(recentLimit).compactMap { target -> QuickSwitchRailEntry? in
            guard seen.insert(target.id).inserted else { return nil }
            return QuickSwitchRailEntry(section: .recent, target: target)
        }
        let favoriteEntries = favorites.compactMap { target -> QuickSwitchRailEntry? in
            guard seen.insert(target.id).inserted else { return nil }
            return QuickSwitchRailEntry(section: .favorite, target: target)
        }
        return recentEntries + favoriteEntries
    }
}

enum LiveChannelSurfPolicy {
    static func targetIndex(
        currentIndex: Int,
        offset: Int,
        channelCount: Int
    ) -> Int? {
        guard channelCount > 1,
              currentIndex >= 0,
              currentIndex < channelCount,
              offset != 0 else { return nil }
        let remainder = (currentIndex + offset) % channelCount
        return remainder >= 0 ? remainder : remainder + channelCount
    }
}

enum PlaybackSeekPolicy {
    static func targetTime(
        currentTime: Double,
        offset: Double,
        bounds: ClosedRange<Double>
    ) -> Double? {
        guard currentTime.isFinite,
              offset.isFinite,
              offset != 0,
              bounds.lowerBound.isFinite,
              bounds.upperBound.isFinite,
              bounds.lowerBound <= bounds.upperBound else { return nil }
        return min(max(currentTime + offset, bounds.lowerBound), bounds.upperBound)
    }
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

protocol SportsScheduleProviding {
    func loadSportsSchedule() async throws -> SportsScheduleSnapshot
}

protocol SportsEventDetailProviding: Sendable {
    func loadSportsEventDetail(
        identity: SportsEventDetailIdentity
    ) async throws -> SportsEventDetail?
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
    let licenseURL: URL?

    init(
        hlsURL: URL,
        certificateURL: URL,
        licenseProxyPrefix: String?,
        headers: [String: String],
        licenseURL: URL? = nil
    ) {
        self.hlsURL = hlsURL
        self.certificateURL = certificateURL
        self.licenseProxyPrefix = licenseProxyPrefix
        self.headers = headers
        self.licenseURL = licenseURL
    }
}

@MainActor
final class PlaybackSession: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let player: AVPlayer
    let isLivePlayback: Bool
    @Published private(set) var playbackError: String?
    @Published private(set) var isReady = false
    private let startAtLiveEdge: Bool
    private let resourceLoader: FairPlayResourceLoader?
    private var statusObservation: NSKeyValueObservation?
    private var preparationTimeout: Task<Void, Never>?
    private var didPositionAtLiveEdge = false
    private var readyHandler: (() -> Void)?
    private var failureHandler: ((String) -> Void)?

    init(title: String, url: URL, startAtLiveEdge: Bool = false) {
        self.title = title
        self.startAtLiveEdge = startAtLiveEdge
        self.isLivePlayback = startAtLiveEdge
        let item = AVPlayerItem(url: url)
        item.automaticallyPreservesTimeOffsetFromLive = startAtLiveEdge
        self.player = AVPlayer(playerItem: item)
        self.resourceLoader = nil
        monitor(item)
        startPreparationTimeout()
    }

    #if DEBUG
    init(debugTitle title: String, isLivePlayback: Bool = true) {
        self.title = title
        self.startAtLiveEdge = isLivePlayback
        self.isLivePlayback = isLivePlayback
        self.player = AVPlayer()
        self.resourceLoader = nil
        self.isReady = true
    }
    #endif

    init(
        title: String,
        configuration: DRMConfiguration,
        client: SeasonsClient,
        startAtLiveEdge: Bool = false
    ) {
        self.title = title
        self.startAtLiveEdge = startAtLiveEdge
        self.isLivePlayback = startAtLiveEdge
        let asset = AVURLAsset(url: configuration.hlsURL)
        let loader = FairPlayResourceLoader(configuration: configuration, client: client)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "com.seasonstv.fairplay"))
        self.resourceLoader = loader
        let item = AVPlayerItem(asset: asset)
        item.automaticallyPreservesTimeOffsetFromLive = startAtLiveEdge
        self.player = AVPlayer(playerItem: item)
        monitor(item)
        startPreparationTimeout()
    }

    private func monitor(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let statusRawValue = item.status.rawValue
            let error = item.error as NSError?
            let errorDomain = error?.domain
            let errorCode = error?.code

            Task { @MainActor [weak self] in
                self?.handlePlayerStatus(
                    rawValue: statusRawValue,
                    errorDomain: errorDomain,
                    errorCode: errorCode
                )
            }
        }
    }

    private func handlePlayerStatus(
        rawValue: Int,
        errorDomain: String?,
        errorCode: Int?
    ) {
        switch AVPlayerItem.Status(rawValue: rawValue) {
        case .readyToPlay:
            positionAtLiveEdgeIfNeeded()
            let firstReady = !isReady
            isReady = true
            preparationTimeout?.cancel()
            if firstReady {
                readyHandler?()
                clearPreparationHandlers()
            }
        case .failed:
            failPreparation("This stream could not be played. Return to browse and try again.")
            #if DEBUG
            if let errorDomain, let errorCode {
                print("AVPlayer item failed [\(errorDomain) \(errorCode)]")
            }
            #endif
        default:
            isReady = false
        }
    }

    private func positionAtLiveEdgeIfNeeded() {
        guard startAtLiveEdge, !didPositionAtLiveEdge else { return }
        didPositionAtLiveEdge = true
        player.seek(to: .positiveInfinity)
    }

    private func startPreparationTimeout() {
        preparationTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            guard let self, !self.isReady, self.playbackError == nil else { return }
            self.player.pause()
            self.failPreparation("This stream did not begin in time. Return to browse and try it again.")
        }
    }

    func setPreparationHandlers(
        onReady: @escaping () -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        if isReady {
            onReady()
        } else if let playbackError {
            onFailure(playbackError)
        } else {
            readyHandler = onReady
            failureHandler = onFailure
        }
    }

    func clearPreparationHandlers() {
        readyHandler = nil
        failureHandler = nil
    }

    @discardableResult
    func seek(by offset: Double) -> Bool {
        guard let bounds = seekBounds,
              let target = PlaybackSeekPolicy.targetTime(
                  currentTime: player.currentTime().seconds,
                  offset: offset,
                  bounds: bounds
              ) else { return false }

        if isLivePlayback, bounds.upperBound - target < 0.5 {
            player.seek(to: .positiveInfinity)
        } else {
            player.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
        return true
    }

    private var seekBounds: ClosedRange<Double>? {
        guard let item = player.currentItem else { return nil }

        for value in item.seekableTimeRanges.reversed() {
            let range = value.timeRangeValue
            let lowerBound = range.start.seconds
            let upperBound = range.end.seconds
            if lowerBound.isFinite, upperBound.isFinite, lowerBound < upperBound {
                return lowerBound...upperBound
            }
        }

        guard !isLivePlayback else { return nil }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return nil }
        return 0...duration
    }

    private func failPreparation(_ message: String) {
        isReady = false
        playbackError = message
        failureHandler?(message)
        clearPreparationHandlers()
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
            return "There was an unexpected response."
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
