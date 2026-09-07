import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Destination: Hashable {
        case home
        case liveTV
        case sports
        case espnPlus
    }

    enum Screen {
        case checkingSession
        case signedOut
        case catalog
    }

    private enum MediaPlaybackTargetSource {
        case sports
        case espnPlus
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
    @Published private(set) var favoriteChannelIDs: Set<String>
    @Published private(set) var enabledSportsCategoryIDs: Set<String>
    @Published private(set) var directionalChannelSurfingEnabled = false
    @Published private(set) var sportsSchedule: SportsScheduleSnapshot?
    @Published private(set) var sportsEventDetails: [String: SportsEventDetail] = [:]
    @Published var sportsScheduleState: ContentLoadState = .idle
    @Published private(set) var espnPlusItems: [MediaItem] = []
    @Published private(set) var espnPlusDate = Calendar.current.startOfDay(for: Date())
    @Published var espnPlusState: ContentLoadState = .idle
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
    @Published private(set) var activeLiveChannelID: String?
    @Published private(set) var activePlaybackTarget: PlaybackTarget?
    @Published private(set) var recentPlaybackTargets: [PlaybackTarget] = []
    @Published private(set) var switchingPlaybackTargetID: String?
    @Published private(set) var playbackSwitchMessage: String?

    let client: SeasonsClient
    let veryLocalClient: VeryLocalClient
    private let epgProvider: EPGProviding?
    private let sportsScheduleProvider: SportsScheduleProviding?
    private let sportsEventDetailProvider: SportsEventDetailProviding?
    private let defaults: UserDefaults
    private var playbackCategories: [CatalogCategory] = []
    private var epgRequestID = UUID()
    private var sportsScheduleRequestID = UUID()
    private var espnPlusRequestID = UUID()
    private var sportsDetailPrefetchTask: Task<Void, Never>?
    private var sportsDetailFocusTask: Task<Void, Never>?
    private var hasStoredFavoriteChannelSelection: Bool
    private var playbackTransitionID = UUID()
    #if DEBUG
    private var debugQuickSwitchTargetIDs: Set<String> = []
    #endif

    private static let enabledSportsCategoriesKey = "sports.enabledCategories"
    private static let disabledChannelsKey = "channels.disabledIDs"
    private static let favoriteChannelsKey = "channels.favoriteIDs"
    private static let favoriteDefaultsVersionKey = "channels.favoriteDefaultsVersion"
    private static let directionalChannelSurfingKey = "playback.directionalChannelSurfing"
    private static let currentFavoriteDefaultsVersion = 1
    private static let defaultFavoriteChannelIDs: Set<String> = ["nhpbs:main"]
    private static let sportsDetailPrefetchLimit = 12
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
        if let stored = defaults.array(forKey: Self.favoriteChannelsKey) as? [String] {
            self.favoriteChannelIDs = Set(stored)
            self.hasStoredFavoriteChannelSelection = true
        } else {
            self.favoriteChannelIDs = []
            self.hasStoredFavoriteChannelSelection = false
        }
        if let stored = defaults.array(forKey: Self.enabledSportsCategoriesKey) as? [String] {
            self.enabledSportsCategoryIDs = Set(stored)
        } else {
            self.enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        }
        self.directionalChannelSurfingEnabled = defaults.bool(
            forKey: Self.directionalChannelSurfingKey
        )
        adoptNewDefaultFavoritesIfNeeded()
        #if DEBUG
        if ProcessInfo.processInfo.environment["JOE_TV_DEBUG_QUICK_SWITCH"] == "1" {
            configureQuickSwitchDebugFixture()
            return
        }
        if ProcessInfo.processInfo.environment["JOE_TV_DEBUG_DESTINATION"] == "sports" {
            self.destination = .sports
        }
        #endif
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

    var favoriteLiveChannels: [LiveChannel] {
        liveChannels.filter { favoriteChannelIDs.contains($0.id) }
    }

    var quickSwitchEntries: [QuickSwitchRailEntry] {
        let recentTargets = recentPlaybackTargets.filter(isQuickSwitchTargetAvailable)
        let favoriteTargets = favoriteLiveChannels.map(makePlaybackTarget)
        return PlaybackHistoryPolicy.railEntries(
            recents: recentTargets,
            favorites: favoriteTargets,
            currentID: activePlaybackTarget?.id
        )
    }

    var lastPlaybackTarget: PlaybackTarget? {
        recentPlaybackTargets.first {
            $0.id != activePlaybackTarget?.id && isQuickSwitchTargetAvailable($0)
        }
    }

    func quickSwitchNowPlayingTitle(for target: PlaybackTarget, at date: Date = Date()) -> String? {
        guideProgram(for: target, at: date)?.title
    }

    func guideProgram(for target: PlaybackTarget, at date: Date = Date()) -> EPGProgram? {
        guard let channelID = target.channelID,
              let stationID = channelStationMappings[channelID] else { return nil }
        return usableGuideWindow?.programsByStationID[stationID]?
            .first(where: { $0.contains(date) })
    }

    func quickSwitchNextProgramTitle(for target: PlaybackTarget, at date: Date = Date()) -> String? {
        nextGuideProgram(for: target, at: date)?.title
    }

    func nextGuideProgram(for target: PlaybackTarget, at date: Date = Date()) -> EPGProgram? {
        guard let channelID = target.channelID,
              let stationID = channelStationMappings[channelID] else { return nil }
        return usableGuideWindow?.programsByStationID[stationID]?
            .first(where: { $0.start > date })
    }

    func isChannelFavorite(_ channelID: String) -> Bool {
        favoriteChannelIDs.contains(channelID)
    }

    func setChannelFavorite(_ channelID: String, favorite: Bool) {
        hasStoredFavoriteChannelSelection = true
        if favorite {
            favoriteChannelIDs.insert(channelID)
        } else {
            favoriteChannelIDs.remove(channelID)
        }
        persistFavoriteChannels()
    }

    func clearFavoriteChannels() {
        hasStoredFavoriteChannelSelection = true
        favoriteChannelIDs.removeAll()
        persistFavoriteChannels()
    }

    func setDirectionalChannelSurfing(enabled: Bool) {
        directionalChannelSurfingEnabled = enabled
        defaults.set(enabled, forKey: Self.directionalChannelSurfingKey)
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
        let publicChannels = veryLocalChannels + PBSLiveClient.channels
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
            replaceAvailableChannels(with: loadedChannels + publicChannels)
            channelState = .loaded
            Task { await refreshEPG(for: liveChannels, around: Date()) }
        case .failure(let error):
            replaceAvailableChannels(with: publicChannels)
            if publicChannels.isEmpty {
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

    func loadESPNPlus(for date: Date? = nil) async {
        let requestedDate = Calendar.current.startOfDay(for: date ?? espnPlusDate)
        let requestID = UUID()
        espnPlusRequestID = requestID
        espnPlusDate = requestedDate
        espnPlusState = .loading

        do {
            let items = try await client.loadESPNPlusEvents(for: requestedDate)
            guard espnPlusRequestID == requestID else { return }
            espnPlusItems = items
            espnPlusState = .loaded
        } catch SeasonsError.authenticationRequired {
            guard espnPlusRequestID == requestID else { return }
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
            espnPlusState = .failed("Sign in again to load ESPN+.")
        } catch {
            guard espnPlusRequestID == requestID else { return }
            espnPlusItems = []
            espnPlusState = .failed(error.localizedDescription)
        }
    }

    func moveESPNPlusDate(by dayOffset: Int) async {
        guard let date = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: espnPlusDate
        ) else { return }
        await loadESPNPlus(for: date)
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
            .filter {
                guard seenItems.insert($0.id).inserted, $0.sportsEvent != nil else { return false }
                let phase = $0.sportsPhase(at: date)
                return phase == .live || phase == .upcoming
            }
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
        }.prefix(Self.sportsDetailPrefetchLimit).map { $0 }
    }

    private func isSportsItemLive(_ item: MediaItem, at date: Date) -> Bool {
        item.sportsPhase(at: date) == .live
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
            if destination == .espnPlus {
                await loadESPNPlus(for: espnPlusDate)
            }
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
        await playMediaItem(
            item,
            option: option,
            target: makePlaybackTarget(for: item, option: option, source: .sports)
        )
    }

    func playESPNPlus(_ item: MediaItem, option: MediaItem.PlaybackOption? = nil) async {
        await playMediaItem(
            item,
            option: option,
            target: makePlaybackTarget(for: item, option: option, source: .espnPlus)
        )
    }

    private func playMediaItem(
        _ item: MediaItem,
        option: MediaItem.PlaybackOption?,
        target: PlaybackTarget
    ) async {
        workingMessage = "Preparing \(option?.title ?? item.title)…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let session = try await makePlaybackSession(for: item, option: option)
            installPlaybackSession(session, target: target)
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
            let session = try await makePreviewSession(for: channel)
            installPlaybackSession(session, target: makePlaybackTarget(channel))
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchPlayback(to target: PlaybackTarget) async {
        guard playbackSession != nil,
              switchingPlaybackTargetID == nil,
              target.id != activePlaybackTarget?.id else { return }

        switchingPlaybackTargetID = target.id
        playbackSwitchMessage = nil
        do {
            let session = try await makePlaybackSession(for: target)
            installPlaybackSession(session, target: target)
        } catch SeasonsError.authenticationRequired {
            switchingPlaybackTargetID = nil
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            playbackSwitchMessage = "Couldn’t switch to \(target.title). \(error.localizedDescription)"
            switchingPlaybackTargetID = nil
        }
    }

    func adjacentLiveChannel(by offset: Int) -> LiveChannel? {
        guard let activeLiveChannelID,
              let currentIndex = liveChannels.firstIndex(where: { $0.id == activeLiveChannelID }),
              let targetIndex = LiveChannelSurfPolicy.targetIndex(
                  currentIndex: currentIndex,
                  offset: offset,
                  channelCount: liveChannels.count
              ) else { return nil }
        return liveChannels[targetIndex]
    }

    func changeLiveChannel(by offset: Int) async {
        guard switchingPlaybackTargetID == nil,
              let channel = adjacentLiveChannel(by: offset) else { return }
        await switchPlayback(to: makePlaybackTarget(channel))
    }

    func switchToLastPlayback() async {
        guard let target = lastPlaybackTarget else { return }
        await switchPlayback(to: target)
    }

    func clearPlaybackSwitchMessage() {
        playbackSwitchMessage = nil
    }

    private func makePlaybackSession(for target: PlaybackTarget) async throws -> PlaybackSession {
        #if DEBUG
        if debugQuickSwitchTargetIDs.contains(target.id) {
            return PlaybackSession(debugTitle: target.title)
        }
        #endif
        switch target.source {
        case .liveChannel(let channelID):
            guard let channel = liveChannels.first(where: { $0.id == channelID }) else {
                throw SeasonsError.message("That channel is no longer available.")
            }
            return try await makePreviewSession(for: channel)

        case .sports(let categoryID, let itemID):
            guard let item = mediaItem(categoryID: categoryID, itemID: itemID, in: categories)
                ?? mediaItem(categoryID: categoryID, itemID: itemID, in: playbackCategories),
                  item.sportsPhase(at: Date()) == .live,
                  item.sportsPlaybackAvailable(at: Date()) else {
                throw SeasonsError.message("That event is no longer live.")
            }
            return try await makePlaybackSession(
                for: item,
                option: playbackOption(withID: target.playbackOptionID, in: item)
            )

        case .espnPlus(let dateCode, let itemID):
            guard dateCode == Self.dateCode(for: espnPlusDate),
                  let item = espnPlusItems.first(where: { $0.id == itemID }),
                  item.sportsPhase(at: Date()) == .live else {
                throw SeasonsError.message("That ESPN+ event is no longer live.")
            }
            return try await makePlaybackSession(
                for: item,
                option: playbackOption(withID: target.playbackOptionID, in: item)
            )
        }
    }

    private func makePlaybackSession(
        for item: MediaItem,
        option: MediaItem.PlaybackOption?
    ) async throws -> PlaybackSession {
        let startAtLiveEdge: Bool = {
            switch item.sportsPhase(at: Date()) {
            case .live, .upcoming:
                return true
            case .replay, .completed:
                return false
            }
        }()
        switch option?.playback ?? item.playback {
        case .hls(let url):
            return PlaybackSession(title: item.title, url: url, startAtLiveEdge: startAtLiveEdge)
        case .request(let request):
            let url = try await client.resolveStream(request)
            return PlaybackSession(title: item.title, url: url, startAtLiveEdge: startAtLiveEdge)
        case .drmPage(let pageURL):
            return try await makeDRMPlaybackSession(
                title: item.title,
                pageURL: pageURL,
                startAtLiveEdge: startAtLiveEdge
            )
        case .unavailable:
            throw SeasonsError.message("This event is scheduled, but Seasons4U has not published a playable stream yet.")
        }
    }

    private func installPlaybackSession(_ session: PlaybackSession, target: PlaybackTarget) {
        let transitionID = UUID()
        playbackTransitionID = transitionID
        let previousSession = playbackSession
        let previousTarget = activePlaybackTarget

        if previousSession != nil {
            switchingPlaybackTargetID = target.id
            playbackSwitchMessage = nil
        }
        previousSession?.player.pause()
        playbackSession = session

        session.setPreparationHandlers(
            onReady: { [weak self, weak session] in
                guard let self, let session,
                      self.playbackTransitionID == transitionID,
                      self.playbackSession === session else { return }
                self.recentPlaybackTargets = PlaybackHistoryPolicy.transitioning(
                    from: previousTarget,
                    to: target,
                    recents: self.recentPlaybackTargets
                )
                self.activePlaybackTarget = target
                self.activeLiveChannelID = target.channelID
                self.switchingPlaybackTargetID = nil
                self.playbackSwitchMessage = nil
            },
            onFailure: { [weak self, weak session] message in
                guard let self, let session,
                      self.playbackTransitionID == transitionID,
                      self.playbackSession === session else { return }
                guard let previousSession, let previousTarget else { return }
                session.player.pause()
                self.playbackSession = previousSession
                self.activePlaybackTarget = previousTarget
                self.activeLiveChannelID = previousTarget.channelID
                self.playbackSwitchMessage = "Couldn’t switch to \(target.title). \(message)"
                self.switchingPlaybackTargetID = nil
                previousSession.player.play()
            }
        )
    }

    #if DEBUG
    private func configureQuickSwitchDebugFixture() {
        let request = PlaybackRequest(endpoint: "debug", controller: "debug", arguments: [])
        let channels = [
            LiveChannel(id: "debug:live", name: "Live Desk", logoURL: nil, playback: .request(request), genre: .news),
            LiveChannel(id: "debug:espn", name: "ESPN", logoURL: nil, playback: .request(request), genre: .sports),
            LiveChannel(id: "debug:nbc", name: "NBC · Boston", logoURL: nil, playback: .request(request), genre: .news),
            LiveChannel(id: "debug:cbs", name: "CBS · New York", logoURL: nil, playback: .request(request), genre: .news),
            LiveChannel(id: "debug:wcvb", name: "WCVB 5 · Boston", logoURL: nil, playback: .request(request), genre: .news),
            LiveChannel(id: "debug:nhpbs", name: "NHPBS", logoURL: nil, playback: .request(request), genre: .entertainment)
        ]
        liveChannels = channels
        availableLiveChannels = channels
        favoriteChannelIDs = Set(channels.dropFirst().map(\.id))

        let recentTargets = [
            makePlaybackTarget(channels[4]),
            makePlaybackTarget(channels[5])
        ]
        recentPlaybackTargets = recentTargets

        let current = makePlaybackTarget(channels[0])
        debugQuickSwitchTargetIDs = Set(recentTargets.map(\.id))
            .union(channels.map(makePlaybackTarget).map(\.id))
        screen = .catalog
        installPlaybackSession(PlaybackSession(debugTitle: current.title), target: current)
    }
    #endif

    private func makePlaybackTarget(_ channel: LiveChannel) -> PlaybackTarget {
        PlaybackTarget(
            source: .liveChannel(channelID: channel.id),
            playbackOptionID: nil,
            title: channel.name,
            sourceLabel: "LIVE TV",
            detail: nil,
            imageURL: channel.logoURL
        )
    }

    private func makePlaybackTarget(
        for item: MediaItem,
        option: MediaItem.PlaybackOption?,
        source: MediaPlaybackTargetSource
    ) -> PlaybackTarget {
        let selectedOption = option ?? item.playbackOptions.first(where: \.isPlayable)
        let targetSource: PlaybackTarget.Source
        let sourceLabel: String
        switch source {
        case .sports:
            targetSource = .sports(categoryID: item.categoryID, itemID: item.id)
            sourceLabel = (item.sportsEvent?.league ?? item.categoryID).uppercased()
        case .espnPlus:
            targetSource = .espnPlus(dateCode: Self.dateCode(for: espnPlusDate), itemID: item.id)
            sourceLabel = "ESPN+"
        }
        let optionTitle = selectedOption?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlaybackTarget(
            source: targetSource,
            playbackOptionID: selectedOption?.id,
            title: item.title,
            sourceLabel: sourceLabel,
            detail: optionTitle == nil || optionTitle?.caseInsensitiveCompare("Watch") == .orderedSame
                ? item.subtitle
                : optionTitle,
            imageURL: item.sportsEvent?.thumbnailURL ?? item.imageURL
        )
    }

    private func playbackOption(
        withID optionID: String?,
        in item: MediaItem
    ) -> MediaItem.PlaybackOption? {
        if let optionID,
           let option = item.playbackOptions.first(where: { $0.id == optionID && $0.isPlayable }) {
            return option
        }
        return item.playbackOptions.first(where: \.isPlayable)
    }

    private func mediaItem(
        categoryID: String,
        itemID: String,
        in categories: [CatalogCategory]
    ) -> MediaItem? {
        categories.first(where: { $0.id == categoryID })?.items.first(where: { $0.id == itemID })
    }

    private func isQuickSwitchTargetAvailable(_ target: PlaybackTarget) -> Bool {
        switch target.source {
        case .liveChannel(let channelID):
            return liveChannels.contains(where: { $0.id == channelID })
        case .sports(let categoryID, let itemID):
            guard let item = mediaItem(categoryID: categoryID, itemID: itemID, in: categories)
                ?? mediaItem(categoryID: categoryID, itemID: itemID, in: playbackCategories) else {
                return false
            }
            return item.sportsPhase(at: Date()) == .live && item.sportsPlaybackAvailable(at: Date())
        case .espnPlus(let dateCode, let itemID):
            guard dateCode == Self.dateCode(for: espnPlusDate),
                  let item = espnPlusItems.first(where: { $0.id == itemID }) else { return false }
            return item.sportsPhase(at: Date()) == .live
        }
    }

    private static func dateCode(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    func makePreviewSession(for channel: LiveChannel) async throws -> PlaybackSession {
        switch channel.playback {
        case .drmPage(let pageURL):
            return try await makeDRMPlaybackSession(
                title: channel.name,
                pageURL: pageURL,
                startAtLiveEdge: true
            )
        case .request(let request):
            let url = try await client.resolveStream(request)
            return PlaybackSession(title: channel.name, url: url, startAtLiveEdge: true)
        case .veryLocal(let reference):
            let url = try await veryLocalClient.resolveStream(reference)
            return PlaybackSession(title: channel.name, url: url, startAtLiveEdge: true)
        case .pbs(let reference):
            if let configuration = PBSLiveClient.drmConfiguration(for: reference) {
                #if targetEnvironment(simulator)
                throw SeasonsError.fairPlayRequiresDevice
                #else
                return PlaybackSession(
                    title: channel.name,
                    configuration: configuration,
                    client: client,
                    startAtLiveEdge: true
                )
                #endif
            }
            return PlaybackSession(title: channel.name, url: reference.streamURL, startAtLiveEdge: true)
        }
    }

    private func makeDRMPlaybackSession(
        title: String,
        pageURL: URL,
        startAtLiveEdge: Bool
    ) async throws -> PlaybackSession {
        #if targetEnvironment(simulator)
        throw SeasonsError.fairPlayRequiresDevice
        #else
        let configuration = try await client.loadDRMConfiguration(from: pageURL)
        return PlaybackSession(
            title: title,
            configuration: configuration,
            client: client,
            startAtLiveEdge: startAtLiveEdge
        )
        #endif
    }

    func signOut() {
        sportsDetailPrefetchTask?.cancel()
        sportsDetailFocusTask?.cancel()
        playbackTransitionID = UUID()
        playbackSession?.clearPreparationHandlers()
        playbackSession?.player.pause()
        playbackSession = nil
        activeLiveChannelID = nil
        activePlaybackTarget = nil
        recentPlaybackTargets = []
        switchingPlaybackTargetID = nil
        playbackSwitchMessage = nil
        client.clearLocalSession()
        categories = []
        playbackCategories = []
        espnPlusItems = []
        espnPlusDate = Calendar.current.startOfDay(for: Date())
        espnPlusState = .idle
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
        dismissPlayback()
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

    func dismissPlayback() {
        playbackTransitionID = UUID()
        playbackSession?.clearPreparationHandlers()
        playbackSession?.player.pause()
        recentPlaybackTargets = PlaybackHistoryPolicy.stopping(
            current: activePlaybackTarget,
            recents: recentPlaybackTargets
        )
        playbackSession = nil
        activePlaybackTarget = nil
        activeLiveChannelID = nil
        switchingPlaybackTargetID = nil
        playbackSwitchMessage = nil
    }

    private var usableGuideWindow: EPGGuideWindow? {
        switch epgState {
        case .loaded(let window): return window
        case .loading(let cached), .failed(_, let cached): return cached
        case .unavailable: return nil
        }
    }

    private func replaceAvailableChannels(with channels: [LiveChannel]) {
        let unique = Dictionary(channels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        availableLiveChannels = ChannelDirectory.sorted(Array(unique.values))
        applyChannelPreferences()
        adoptInitialFavoriteChannelsIfNeeded()
    }

    private func adoptInitialFavoriteChannelsIfNeeded() {
        guard !hasStoredFavoriteChannelSelection, !liveChannels.isEmpty else { return }
        favoriteChannelIDs = Set(liveChannels.prefix(7).map(\.id))
            .union(Self.defaultFavoriteChannelIDs)
        hasStoredFavoriteChannelSelection = true
        persistFavoriteChannels()
        defaults.set(Self.currentFavoriteDefaultsVersion, forKey: Self.favoriteDefaultsVersionKey)
    }

    private func adoptNewDefaultFavoritesIfNeeded() {
        guard hasStoredFavoriteChannelSelection,
              defaults.integer(forKey: Self.favoriteDefaultsVersionKey) < Self.currentFavoriteDefaultsVersion else {
            return
        }
        favoriteChannelIDs.formUnion(Self.defaultFavoriteChannelIDs)
        persistFavoriteChannels()
        defaults.set(Self.currentFavoriteDefaultsVersion, forKey: Self.favoriteDefaultsVersionKey)
    }

    private func persistFavoriteChannels() {
        defaults.set(Array(favoriteChannelIDs).sorted(), forKey: Self.favoriteChannelsKey)
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
