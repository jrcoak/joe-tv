import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Destination: Hashable {
        case home
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
    @Published private(set) var availableLiveChannels: [LiveChannel] = []
    @Published var selectedCategoryID = "football"
    @Published var destination: Destination = .home
    @Published var liveSearchQuery = ""
    @Published var selectedChannelGenre: ChannelGenre?
    @Published var guideTimeAnchor = Date()
    @Published var lastFocusedLiveID: String?
    @Published var lastFocusedEventID: String?
    @Published var epgState: EPGLoadState = .unavailable
    @Published private(set) var disabledChannelIDs: Set<String>
    @Published private(set) var enabledSportsCategoryIDs: Set<String>
    @Published private(set) var sportsSchedule: SportsScheduleSnapshot?
    @Published private(set) var sportsEventDetails: [String: SportsEventDetail] = [:]
    @Published var sportsScheduleState: ContentLoadState = .idle
    @Published var channelStationMappings: [String: String] = [:]
    @Published var channelState: ContentLoadState = .idle
    @Published private(set) var veryLocalState: ContentLoadState = .idle
    @Published private(set) var isVeryLocalOnly = false
    @Published var eventState: ContentLoadState = .idle
    @Published var isRefreshing = false
    @Published var isWorking = false
    @Published var workingMessage = "Loading…"
    @Published var errorMessage: String?
    @Published var playbackSession: PlaybackSession?

    let client: SeasonsClient
    let veryLocalClient: VeryLocalClient
    private let epgProvider: EPGProviding?
    private let sportsScheduleProvider: SportsScheduleProviding?
    private let sportsEventDetailProvider: SportsEventDetailProviding?
    private let defaults: UserDefaults
    private var playbackCategories: [CatalogCategory] = []
    private var epgRequestID = UUID()
    private var sportsScheduleRequestID = UUID()
    private var sportsDetailPrefetchTask: Task<Void, Never>?
    private var sportsDetailFocusTask: Task<Void, Never>?

    private static let enabledSportsCategoriesKey = "sports.enabledCategories"
    private static let disabledChannelsKey = "channels.disabledIDs"
    private static let defaultDisabledChannelIDs: Set<String> = [
        // Seasons4U
        "6eb90a9b-2da1-4469-bd63-9801c8df705b", // UNIVERSO
        "legacy:bkb:channel:604", // Fox Deportes

        // Very Local: keep only WCVB Boston and WMUR Manchester enabled by default.
        "verylocal:htv-national-desk",
        "verylocal:koat",
        "verylocal:wbal",
        "verylocal:wvtm",
        "verylocal:wptz",
        "verylocal:wlwt",
        "verylocal:kcci",
        "verylocal:wbbh",
        "verylocal:khbs",
        "verylocal:wyff",
        "verylocal:wapt",
        "verylocal:kmbc",
        "verylocal:wgal",
        "verylocal:wlky",
        "verylocal:wisn",
        "verylocal:ksbw",
        "verylocal:wdsu",
        "verylocal:koco",
        "verylocal:ketv",
        "verylocal:wesh",
        "verylocal:wtae",
        "verylocal:wmtw",
        "verylocal:wmor",
        "verylocal:kcra",
        "verylocal:wjcl",
        "verylocal:wpbf",
        "verylocal:wxii"
    ]
    private static let defaultSportsCategoryIDs: Set<String> = [
        "football", "baseball", "hockey", "basketball"
    ]

    init(
        client: SeasonsClient = SeasonsClient(),
        veryLocalClient: VeryLocalClient = VeryLocalClient(),
        epgProvider: EPGProviding? = XMLTVGuideProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.veryLocalClient = veryLocalClient
        self.epgProvider = epgProvider
        self.sportsScheduleProvider = epgProvider as? SportsScheduleProviding
        self.sportsEventDetailProvider = epgProvider as? SportsEventDetailProviding
        self.defaults = defaults
        LegacyScheduleCredentialCleanup.run(defaults: defaults)
        if let stored = defaults.array(forKey: Self.disabledChannelsKey) as? [String] {
            self.disabledChannelIDs = Set(stored)
        } else {
            self.disabledChannelIDs = Self.defaultDisabledChannelIDs
            defaults.set(
                Array(Self.defaultDisabledChannelIDs).sorted(),
                forKey: Self.disabledChannelsKey
            )
        }
        if let stored = defaults.array(forKey: Self.enabledSportsCategoriesKey) as? [String] {
            self.enabledSportsCategoryIDs = Set(stored)
        } else {
            self.enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        }
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
        prefetchFeaturedSportsDetails()
    }

    func restoreDefaultSportsCategories() {
        enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        defaults.set(Array(enabledSportsCategoryIDs).sorted(), forKey: Self.enabledSportsCategoriesKey)
        reconcileSelectedCategory()
        prefetchFeaturedSportsDetails()
    }

    func isChannelEnabled(_ channelID: String) -> Bool {
        !disabledChannelIDs.contains(channelID)
    }

    func setChannel(_ channelID: String, enabled: Bool) {
        if enabled {
            disabledChannelIDs.remove(channelID)
        } else {
            disabledChannelIDs.insert(channelID)
        }
        defaults.set(Array(disabledChannelIDs).sorted(), forKey: Self.disabledChannelsKey)
        applyChannelPreferences()
        Task { await refreshEPG(for: liveChannels, around: guideTimeAnchor) }
    }

    func enableAllChannels() {
        disabledChannelIDs.removeAll()
        defaults.set([], forKey: Self.disabledChannelsKey)
        applyChannelPreferences()
        Task { await refreshEPG(for: liveChannels, around: guideTimeAnchor) }
    }

    func restoreDefaultChannels() {
        disabledChannelIDs = Self.defaultDisabledChannelIDs
        defaults.set(Array(disabledChannelIDs).sorted(), forKey: Self.disabledChannelsKey)
        applyChannelPreferences()
        Task { await refreshEPG(for: liveChannels, around: guideTimeAnchor) }
    }

    func restoreSession() async {
        do {
            try await loadContent(blocking: false)
            screen = .catalog
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
        } catch {
            screen = .signedOut
            // A failed background restore should not block the public Very Local entry point.
            // An explicit sign-in still reports its own actionable error.
            errorMessage = nil
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
        veryLocalState = .loading
        eventState = .loading
        defer {
            isWorking = false
            isRefreshing = false
        }

        async let catalogResult = capture { try await self.client.loadCatalog() }
        async let channelResult = capture { try await self.client.loadLiveChannels() }
        let (events, channels) = await (catalogResult, channelResult)
        let veryLocalChannels = veryLocalClient.loadChannels()
        veryLocalState = veryLocalChannels.isEmpty ? .failed("Very Local did not publish any stations.") : .loaded

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
            replaceAvailableChannels(with: loadedChannels + veryLocalChannels)
            channelState = .loaded
            Task { await refreshEPG(for: liveChannels, around: Date()) }
        case .failure(let error):
            replaceAvailableChannels(with: veryLocalChannels)
            if veryLocalChannels.isEmpty {
                channelState = .failed(error.localizedDescription)
            } else {
                channelState = .loaded
                Task { await refreshEPG(for: liveChannels, around: Date()) }
            }
        }

        if case .failure(let eventError) = events,
           case .failure = channels {
            throw eventError
        }
    }

    func loadEPG(around date: Date) async {
        await refreshEPG(for: liveChannels, around: date)
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
        sportsScheduleState = .loading
        do {
            let snapshot = try await sportsScheduleProvider.loadSportsSchedule()
            guard sportsScheduleRequestID == requestID else { return }
            sportsSchedule = snapshot
            categories = SportsScheduleEnricher.merge(snapshot, into: playbackCategories)
            reconcileSelectedCategory()
            sportsScheduleState = .loaded
            prefetchFeaturedSportsDetails()
        } catch {
            guard sportsScheduleRequestID == requestID else { return }
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

    func sportsEventDetail(for item: MediaItem) -> SportsEventDetail? {
        guard let event = item.sportsEvent,
              let identity = SportsEventDetailIdentity(event: event) else { return nil }
        return sportsEventDetails[identity.cacheKey]
    }

    func prefetchSportsEventDetails(for items: [MediaItem], at date: Date = Date()) {
        guard let provider = sportsEventDetailProvider else { return }
        let identities = featuredAndNextDetailIdentities(from: items, at: date)
            .filter { sportsEventDetails[$0.cacheKey] == nil }
        guard !identities.isEmpty else { return }

        sportsDetailPrefetchTask?.cancel()
        sportsDetailPrefetchTask = Task { [weak self] in
            for batchStart in stride(from: 0, to: identities.count, by: 2) {
                guard !Task.isCancelled else { return }
                let batchEnd = min(batchStart + 2, identities.count)
                let batch = Array(identities[batchStart..<batchEnd])
                await withTaskGroup(of: (String, SportsEventDetail?).self) { group in
                    for identity in batch {
                        group.addTask {
                            let detail = try? await provider.loadSportsEventDetail(identity: identity)
                            return (identity.cacheKey, detail ?? nil)
                        }
                    }
                    for await (cacheKey, detail) in group {
                        guard !Task.isCancelled, let detail else { continue }
                        self?.sportsEventDetails[cacheKey] = detail
                    }
                }
            }
        }
    }

    func focusSportsEvent(_ event: SportsScheduleEvent?) {
        sportsDetailFocusTask?.cancel()
        guard let event,
              let identity = SportsEventDetailIdentity(event: event),
              sportsEventDetails[identity.cacheKey] == nil,
              let provider = sportsEventDetailProvider else { return }

        sportsDetailFocusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled,
                  let detail = try? await provider.loadSportsEventDetail(identity: identity),
                  !Task.isCancelled else { return }
            self?.sportsEventDetails[identity.cacheKey] = detail
        }
    }

    private func prefetchFeaturedSportsDetails() {
        prefetchSportsEventDetails(for: visibleSportsCategories.flatMap(\.items))
    }

    private func featuredAndNextDetailIdentities(
        from items: [MediaItem],
        at date: Date
    ) -> [SportsEventDetailIdentity] {
        var seenItems = Set<String>()
        let uniqueItems = items
            .filter { seenItems.insert($0.id).inserted && $0.sportsEvent != nil }
            .sorted {
                ($0.sportsEvent?.startsAt ?? .distantFuture)
                    < ($1.sportsEvent?.startsAt ?? .distantFuture)
            }
        let liveItems = uniqueItems.filter { isSportsItemLive($0, at: date) }
        let laterItems = uniqueItems.filter { item in
            guard let start = item.sportsEvent?.startsAt else { return false }
            return start > date && Calendar.current.isDate(start, inSameDayAs: date)
        }
        let featured = liveItems.first(where: \.isPlayable)
            ?? liveItems.first
            ?? laterItems.first
            ?? uniqueItems.first

        var ordered: [MediaItem] = []
        if let featured { ordered.append(featured) }
        ordered.append(contentsOf: liveItems)
        ordered.append(contentsOf: laterItems)
        ordered.append(contentsOf: uniqueItems)

        var seenIdentities = Set<SportsEventDetailIdentity>()
        return ordered.compactMap { item in
            guard let event = item.sportsEvent,
                  let identity = SportsEventDetailIdentity(event: event),
                  seenIdentities.insert(identity).inserted else { return nil }
            return identity
        }.prefix(5).map { $0 }
    }

    private func isSportsItemLive(_ item: MediaItem, at date: Date) -> Bool {
        guard let event = item.sportsEvent else { return false }
        let normalizedStatus = (event.status ?? "").lowercased()
        if normalizedStatus.contains("live") || normalizedStatus.contains("progress") { return true }
        guard event.startsAt <= date else { return false }
        if let end = event.endsAt { return date < end }
        return date.timeIntervalSince(event.startsAt) < 5 * 3_600
    }

    private func refreshEPG(for channels: [LiveChannel], around date: Date) async {
        let requestID = UUID()
        epgRequestID = requestID
        guard !channels.isEmpty else {
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
        let veryLocalChannels = channels.filter { $0.id.hasPrefix("verylocal:") }
        let seasonsChannels = channels.filter { !$0.id.hasPrefix("verylocal:") }
        var loadedResults: [(window: EPGGuideWindow, mappings: [ChannelStationMapping])] = []
        var errors: [Error] = []

        if !veryLocalChannels.isEmpty {
            do {
                loadedResults.append(
                    try await veryLocalClient.loadGuide(
                        for: veryLocalChannels,
                        from: start,
                        to: end
                    )
                )
            } catch {
                errors.append(error)
            }
        }

        if !seasonsChannels.isEmpty, let epgProvider {
            do {
                loadedResults.append(
                    try await epgProvider.loadGuide(
                        for: seasonsChannels,
                        from: start,
                        to: end
                    )
                )
            } catch {
                errors.append(error)
            }
        }

        guard epgRequestID == requestID else { return }
        guard !loadedResults.isEmpty else {
            epgState = .failed(
                message: errors.first?.localizedDescription ?? "Programming details are unavailable.",
                cached: cached
            )
            return
        }

        var programsByStationID: [String: [EPGProgram]] = [:]
        var mappings: [ChannelStationMapping] = []
        for result in loadedResults {
            programsByStationID.merge(result.window.programsByStationID) { existing, incoming in
                (existing + incoming).sorted { $0.start < $1.start }
            }
            mappings.append(contentsOf: result.mappings)
        }
        channelStationMappings = mappings.reduce(into: [:]) { result, mapping in
            result[mapping.channelID] = mapping.stationID
        }
        let mergedWindow = EPGGuideWindow(
            start: start,
            end: end,
            programsByStationID: programsByStationID,
            fetchedAt: Date()
        )
        if let error = errors.first {
            epgState = .failed(message: error.localizedDescription, cached: mergedWindow)
        } else {
            epgState = .loaded(mergedWindow)
        }
    }

    func reload() async {
        errorMessage = nil
        if isVeryLocalOnly {
            replaceAvailableChannels(with: veryLocalClient.loadChannels())
            channelState = availableLiveChannels.isEmpty
                ? .failed("Very Local did not publish any stations.")
                : .loaded
            veryLocalState = channelState
            await refreshEPG(for: liveChannels, around: Date())
            return
        }
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
            case .veryLocal(let reference):
                let url = try await veryLocalClient.resolveStream(reference)
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
        sportsDetailPrefetchTask?.cancel()
        sportsDetailFocusTask?.cancel()
        playbackSession?.player.pause()
        playbackSession = nil
        client.clearLocalSession()
        categories = []
        playbackCategories = []
        liveChannels = []
        availableLiveChannels = []
        isVeryLocalOnly = false
        selectedCategoryID = "football"
        destination = .home
        liveSearchQuery = ""
        selectedChannelGenre = nil
        guideTimeAnchor = Date()
        lastFocusedLiveID = nil
        lastFocusedEventID = nil
        epgState = .unavailable
        sportsSchedule = nil
        sportsEventDetails = [:]
        sportsScheduleState = .idle
        channelStationMappings = [:]
        epgRequestID = UUID()
        sportsScheduleRequestID = UUID()
        channelState = .idle
        veryLocalState = .idle
        eventState = .idle
        isRefreshing = false
        screen = .signedOut
    }

    func openVeryLocal() {
        playbackSession?.player.pause()
        playbackSession = nil
        errorMessage = nil
        isVeryLocalOnly = true
        destination = .home
        liveSearchQuery = ""
        selectedChannelGenre = nil
        lastFocusedLiveID = nil
        guideTimeAnchor = Date()
        epgState = .unavailable
        channelStationMappings = [:]
        replaceAvailableChannels(with: veryLocalClient.loadChannels())
        channelState = availableLiveChannels.isEmpty
            ? .failed("Very Local did not publish any stations.")
            : .loaded
        veryLocalState = channelState
        screen = .catalog
        Task { await refreshEPG(for: liveChannels, around: Date()) }
    }

    func pausePlayback() {
        playbackSession?.player.pause()
    }

    private func replaceAvailableChannels(with channels: [LiveChannel]) {
        availableLiveChannels = channels
        applyChannelPreferences()
    }

    private func applyChannelPreferences() {
        liveChannels = availableLiveChannels.filter { !disabledChannelIDs.contains($0.id) }
        if let lastFocusedLiveID {
            let channelID = lastFocusedLiveID.replacingOccurrences(of: "channel:", with: "")
            if !liveChannels.contains(where: { $0.id == channelID }) {
                self.lastFocusedLiveID = liveChannels.first.map { "channel:\($0.id)" }
            }
        }
    }
}
