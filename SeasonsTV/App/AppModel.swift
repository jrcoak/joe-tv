import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Destination: Hashable {
        case liveTV
        case sports
    }

    enum Screen {
        case checkingSession
        case signedOut
        case catalog
    }

    @Published var screen: Screen = .checkingSession
    @Published var categories: [CatalogCategory] = []
    @Published var liveChannels: [LiveChannel] = []
    @Published var selectedCategoryID = "football"
    @Published var destination: Destination = .liveTV
    @Published var liveSearchQuery = ""
    @Published var selectedChannelGenre: ChannelGenre?
    @Published var guideTimeAnchor = Date()
    @Published var lastFocusedLiveID: String?
    @Published var lastFocusedEventID: String?
    @Published var epgState: EPGLoadState = .unavailable
    @Published var isEPGPaired = false
    @Published var isPairingEPG = false
    @Published private(set) var enabledSportsCategoryIDs: Set<String>
    @Published private(set) var sportsSchedule: SportsScheduleSnapshot?
    @Published var sportsScheduleState: ContentLoadState = .idle
    @Published var channelStationMappings: [String: String] = [:]
    @Published var channelState: ContentLoadState = .idle
    @Published var eventState: ContentLoadState = .idle
    @Published var isRefreshing = false
    @Published var isWorking = false
    @Published var workingMessage = "Loading…"
    @Published var errorMessage: String?
    @Published var playbackSession: PlaybackSession?

    let client: SeasonsClient
    private let epgProvider: EPGProviding?
    private let epgPairingProvider: EPGPairingProviding?
    private let sportsScheduleProvider: SportsScheduleProviding?
    private let defaults: UserDefaults
    private var playbackCategories: [CatalogCategory] = []
    private var epgRequestID = UUID()
    private var sportsScheduleRequestID = UUID()

    private static let enabledSportsCategoriesKey = "sports.enabledCategories"
    private static let defaultSportsCategoryIDs: Set<String> = [
        "football", "baseball", "hockey", "basketball"
    ]

    init(
        client: SeasonsClient = SeasonsClient(),
        epgProvider: EPGProviding? = XMLTVGuideProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.epgProvider = epgProvider
        self.epgPairingProvider = epgProvider as? EPGPairingProviding
        self.sportsScheduleProvider = epgProvider as? SportsScheduleProviding
        self.defaults = defaults
        if let stored = defaults.array(forKey: Self.enabledSportsCategoriesKey) as? [String] {
            self.enabledSportsCategoryIDs = Set(stored)
        } else {
            self.enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        }
        self.isEPGPaired = self.epgPairingProvider?.isPaired ?? false
        Task { await restoreSession() }
    }

    var visibleSportsCategories: [CatalogCategory] {
        SportsCategoryOption.all.compactMap { option in
            guard enabledSportsCategoryIDs.contains(option.id) else { return nil }
            return categories.first(where: { $0.id == option.id })
                ?? CatalogCategory(id: option.id, title: option.title, symbol: option.symbol, items: [])
        }
    }

    var selectedCategory: CatalogCategory? {
        visibleSportsCategories.first(where: { $0.id == selectedCategoryID }) ?? visibleSportsCategories.first
    }

    func isSportsCategoryEnabled(_ categoryID: String) -> Bool {
        enabledSportsCategoryIDs.contains(categoryID)
    }

    func setSportsCategory(_ categoryID: String, enabled: Bool) {
        if enabled {
            enabledSportsCategoryIDs.insert(categoryID)
        } else {
            enabledSportsCategoryIDs.remove(categoryID)
        }
        defaults.set(Array(enabledSportsCategoryIDs).sorted(), forKey: Self.enabledSportsCategoriesKey)
        reconcileSelectedCategory()
    }

    func restoreDefaultSportsCategories() {
        enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        defaults.set(Array(enabledSportsCategoryIDs).sorted(), forKey: Self.enabledSportsCategoriesKey)
        reconcileSelectedCategory()
    }

    func restoreSession() async {
        do {
            try await loadContent(blocking: false)
            screen = .catalog
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
        } catch {
            screen = .signedOut
            errorMessage = "We couldn’t restore your session because Seasons4U could not be reached. You can retry by signing in."
        }
    }

    func signIn(email: String, password: String, rememberMe: Bool) async -> Bool {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return false
        }

        workingMessage = "Signing in…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await client.signIn(username: email, password: password, rememberMe: rememberMe)
            try await loadContent(blocking: false)
            screen = .catalog
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func loadContent(blocking: Bool) async throws {
        if blocking {
            workingMessage = "Refreshing…"
            isWorking = true
        } else {
            isRefreshing = true
        }
        channelState = .loading
        eventState = .loading
        defer {
            isWorking = false
            isRefreshing = false
        }

        async let catalogResult = capture { try await self.client.loadCatalog() }
        async let channelResult = capture { try await self.client.loadLiveChannels() }
        let (events, channels) = await (catalogResult, channelResult)

        if case .failure(let error) = events, isAuthenticationError(error) {
            throw SeasonsError.authenticationRequired
        }
        if case .failure(let error) = channels, isAuthenticationError(error) {
            throw SeasonsError.authenticationRequired
        }

        switch events {
        case .success(let loadedCategories):
            playbackCategories = loadedCategories
            categories = sportsSchedule.map { SportsScheduleEnricher.merge($0, into: loadedCategories) }
                ?? loadedCategories
            eventState = .loaded
            reconcileSelectedCategory()
            Task { await refreshSportsSchedule() }
        case .failure(let error):
            eventState = .failed(error.localizedDescription)
        }

        switch channels {
        case .success(let loadedChannels):
            liveChannels = loadedChannels
            channelState = .loaded
            Task { await refreshEPG(for: loadedChannels, around: Date()) }
        case .failure(let error):
            channelState = .failed(error.localizedDescription)
        }

        if case .failure(let eventError) = events,
           case .failure = channels {
            throw eventError
        }
    }

    func loadEPG(around date: Date) async {
        await refreshEPG(for: liveChannels, around: date)
    }

    func pairEPG(code: String) async -> Bool {
        guard let epgPairingProvider else {
            errorMessage = "Guide pairing is not available in this build."
            return false
        }
        isPairingEPG = true
        errorMessage = nil
        defer { isPairingEPG = false }
        do {
            try await epgPairingProvider.pair(
                code: code,
                deviceName: "SeasonsTV Apple TV"
            )
            isEPGPaired = true
            await refreshEPG(for: liveChannels, around: Date())
            await refreshSportsSchedule()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func disconnectEPG() {
        epgPairingProvider?.disconnect()
        isEPGPaired = false
        epgState = .unavailable
        channelStationMappings = [:]
        epgRequestID = UUID()
        sportsSchedule = nil
        sportsScheduleState = .idle
        sportsScheduleRequestID = UUID()
        categories = playbackCategories
    }

    func loadSportsSchedule() async {
        await refreshSportsSchedule()
    }

    private func refreshSportsSchedule() async {
        let requestID = UUID()
        sportsScheduleRequestID = requestID
        guard let sportsScheduleProvider else {
            sportsScheduleState = .idle
            return
        }
        guard isEPGPaired || epgPairingProvider == nil else {
            sportsScheduleState = .idle
            return
        }

        sportsScheduleState = .loading
        do {
            let snapshot = try await sportsScheduleProvider.loadSportsSchedule()
            guard sportsScheduleRequestID == requestID else { return }
            sportsSchedule = snapshot
            categories = SportsScheduleEnricher.merge(snapshot, into: playbackCategories)
            reconcileSelectedCategory()
            sportsScheduleState = .loaded
        } catch {
            guard sportsScheduleRequestID == requestID else { return }
            if case EPGServiceError.authorizationExpired = error {
                errorMessage = error.localizedDescription
            }
            sportsScheduleState = .failed(error.localizedDescription)
        }
    }

    private func reconcileSelectedCategory() {
        let visible = visibleSportsCategories
        if !visible.contains(where: { $0.id == selectedCategoryID }) {
            selectedCategoryID = visible.first?.id ?? "football"
            lastFocusedEventID = nil
        }
    }

    private func refreshEPG(for channels: [LiveChannel], around date: Date) async {
        let requestID = UUID()
        epgRequestID = requestID
        guard let epgProvider else {
            epgState = .unavailable
            channelStationMappings = [:]
            return
        }
        guard isEPGPaired || epgPairingProvider == nil else {
            isEPGPaired = false
            epgState = .unavailable
            channelStationMappings = [:]
            return
        }

        let cached: EPGGuideWindow? = {
            switch epgState {
            case .loaded(let window): return window
            case .failed(_, let window): return window
            case .loading(let window): return window
            default: return nil
            }
        }()
        epgState = .loading(cached: cached)

        let start = Calendar.current.date(byAdding: .hour, value: -2, to: date) ?? date
        let end = Calendar.current.date(byAdding: .hour, value: 8, to: date) ?? date
        do {
            let result = try await epgProvider.loadGuide(for: channels, from: start, to: end)
            guard epgRequestID == requestID else { return }
            channelStationMappings = result.mappings.reduce(into: [:]) { mappings, mapping in
                mappings[mapping.channelID] = mapping.stationID
            }
            epgState = .loaded(result.window)
        } catch {
            guard epgRequestID == requestID else { return }
            if case EPGServiceError.authorizationExpired = error {
                errorMessage = error.localizedDescription
            }
            epgState = .failed(message: error.localizedDescription, cached: cached)
        }
    }

    func reload() async {
        errorMessage = nil
        do {
            try await loadContent(blocking: false)
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }

    private func isAuthenticationError(_ error: Error) -> Bool {
        if case SeasonsError.authenticationRequired = error { return true }
        return false
    }

    func play(_ item: MediaItem, option: MediaItem.PlaybackOption? = nil) async {
        workingMessage = "Preparing \(option?.title ?? item.title)…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            switch option?.playback ?? item.playback {
            case .hls(let url):
                playbackSession = PlaybackSession(title: item.title, url: url)
            case .request(let request):
                let url = try await client.resolveStream(request)
                playbackSession = PlaybackSession(title: item.title, url: url)
            case .drmPage(let pageURL):
                playbackSession = try await makeDRMPlaybackSession(title: item.title, pageURL: pageURL)
            case .unavailable:
                throw SeasonsError.message("This event is scheduled, but Seasons4U has not published a playable stream yet.")
            }
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ channel: LiveChannel) async {
        workingMessage = "Preparing \(channel.name)…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            switch channel.playback {
            case .drmPage(let pageURL):
                playbackSession = try await makeDRMPlaybackSession(title: channel.name, pageURL: pageURL)
            case .request(let request):
                let url = try await client.resolveStream(request)
                playbackSession = PlaybackSession(title: channel.name, url: url)
            }
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeDRMPlaybackSession(title: String, pageURL: URL) async throws -> PlaybackSession {
        #if targetEnvironment(simulator)
        throw SeasonsError.fairPlayRequiresDevice
        #else
        let configuration = try await client.loadDRMConfiguration(from: pageURL)
        return PlaybackSession(title: title, configuration: configuration, client: client)
        #endif
    }

    func signOut() {
        playbackSession?.player.pause()
        playbackSession = nil
        client.clearLocalSession()
        categories = []
        playbackCategories = []
        liveChannels = []
        selectedCategoryID = "football"
        destination = .liveTV
        liveSearchQuery = ""
        selectedChannelGenre = nil
        guideTimeAnchor = Date()
        lastFocusedLiveID = nil
        lastFocusedEventID = nil
        epgState = .unavailable
        sportsSchedule = nil
        sportsScheduleState = .idle
        channelStationMappings = [:]
        epgRequestID = UUID()
        sportsScheduleRequestID = UUID()
        channelState = .idle
        eventState = .idle
        isRefreshing = false
        screen = .signedOut
    }

    func pausePlayback() {
        playbackSession?.player.pause()
    }
}
