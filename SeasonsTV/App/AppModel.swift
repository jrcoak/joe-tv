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

    enum PlaybackPresentation {
        case standard
        case fantasyZone
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
    @Published private(set) var fantasyZoneEnabled = false
    @Published private(set) var fantasyUsername = ""
    @Published private(set) var fantasyLeagueID = ""
    @Published private(set) var fantasyUserID = ""
    @Published private(set) var fantasyLeagueChoices: [FantasyLeagueChoice] = []
    @Published private(set) var fantasyLeague: FantasyLeagueProfile?
    @Published private(set) var fantasyMatchup: FantasyMatchupSnapshot?
    @Published var fantasyState: ContentLoadState = .idle
    @Published private(set) var fantasyNFLScoreboard: [SportsScheduleEvent] = []
    @Published var fantasyNFLScoreState: ContentLoadState = .idle
    @Published private(set) var sportsSchedule: SportsScheduleSnapshot?
    @Published private(set) var sportsEventDetails: [String: SportsEventDetail] = [:]
    @Published var sportsScheduleState: ContentLoadState = .idle
    @Published private(set) var espnPlusItems: [MediaItem] = []
    @Published private(set) var consolidatedSportsItems: [MediaItem] = []
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
    @Published private(set) var playbackPresentation: PlaybackPresentation = .standard
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
    private let fantasyFootballProvider: FantasyFootballProviding
    private let liveNFLScoreProvider: LiveNFLScoreProviding
    private let defaults: UserDefaults
    private var playbackCategories: [CatalogCategory] = []
    private var epgRequestID = UUID()
    private var sportsScheduleRequestID = UUID()
    private var fantasyRequestID = UUID()
    private var fantasyNFLScoreRequestID = UUID()
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
    private static let fantasyZoneEnabledKey = "fantasyZone.enabled"
    private static let fantasyUsernameKey = "fantasyZone.username"
    private static let fantasyLeagueIDKey = "fantasyZone.leagueID"
    private static let fantasyUserIDKey = "fantasyZone.userID"
    private static let currentFavoriteDefaultsVersion = 1
    private static let defaultFavoriteChannelIDs: Set<String> = ["nhpbs:main"]
    private static let fantasyWatchChannelIDs = [
        "89b2ae46-d203-4198-b483-95b69bbb5cfb", // NFL RedZone
        "029726c2-a92a-447d-a256-964259ce95ca"  // NFL Network
    ]
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
    private static let defaultSportsCategoryIDs = Set(SportsCategoryOption.all.map(\.id))

    init(
        client: SeasonsClient = SeasonsClient(),
        veryLocalClient: VeryLocalClient = VeryLocalClient(),
        epgProvider: EPGProviding? = XMLTVGuideProvider(),
        fantasyFootballProvider: FantasyFootballProviding = SleeperClient(),
        liveNFLScoreProvider: LiveNFLScoreProviding = ESPNScoreboardClient(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.veryLocalClient = veryLocalClient
        self.epgProvider = epgProvider
        self.sportsScheduleProvider = epgProvider as? SportsScheduleProviding
        self.sportsEventDetailProvider = epgProvider as? SportsEventDetailProviding
        self.fantasyFootballProvider = fantasyFootballProvider
        self.liveNFLScoreProvider = liveNFLScoreProvider
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
            let supported = Set(SportsCategoryOption.all.map(\.id))
            var normalized = Set(stored).intersection(supported)
            if stored.contains("college") { normalized.insert("football") }
            self.enabledSportsCategoryIDs = normalized
            if normalized != Set(stored) {
                defaults.set(Array(normalized).sorted(), forKey: Self.enabledSportsCategoriesKey)
            }
        } else {
            self.enabledSportsCategoryIDs = Self.defaultSportsCategoryIDs
        }
        self.directionalChannelSurfingEnabled = defaults.bool(
            forKey: Self.directionalChannelSurfingKey
        )
        self.fantasyZoneEnabled = defaults.bool(forKey: Self.fantasyZoneEnabledKey)
        self.fantasyUsername = defaults.string(forKey: Self.fantasyUsernameKey) ?? ""
        self.fantasyLeagueID = defaults.string(forKey: Self.fantasyLeagueIDKey) ?? ""
        self.fantasyUserID = defaults.string(forKey: Self.fantasyUserIDKey) ?? ""
        adoptNewDefaultFavoritesIfNeeded()
        #if DEBUG
        if ProcessInfo.processInfo.environment["JOE_TV_DEBUG_FANTASY_ZONE"] == "1" {
            configureFantasyZoneDebugFixture()
            return
        }
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

    var fantasyNFLScoreItems: [MediaItem] {
        fantasyNFLScoreboard.map { event in
            let playableItem = consolidatedSportsItems.first {
                $0.sportsEvent?.eventID == event.eventID
            }
            return MediaItem(
                id: playableItem?.id ?? "espn-score:\(event.eventID)",
                title: event.title,
                subtitle: event.status,
                imageURL: playableItem?.imageURL ?? event.thumbnailURL,
                categoryID: "football",
                playbackOptions: playableItem?.playbackOptions ?? [
                    MediaItem.PlaybackOption(
                        id: "scoreboard-only",
                        title: "Scoreboard",
                        playback: .unavailable
                    )
                ],
                sportsEvent: event,
                providerEventDateCode: playableItem?.providerEventDateCode
            )
        }
    }

    var fantasyWatchChannels: [LiveChannel] {
        let channelsByID = Dictionary(uniqueKeysWithValues: liveChannels.map { ($0.id, $0) })
        return Self.fantasyWatchChannelIDs.compactMap { channelsByID[$0] }
    }

    var fantasyUserTeam: FantasyTeamProfile? {
        fantasyLeague?.team(forUserID: fantasyUserID)
    }

    var fantasyOpponentTeam: FantasyTeamProfile? {
        fantasyLeague?.team(forRosterID: fantasyMatchup?.opponentRosterID)
    }

    var hasFantasyConfiguration: Bool {
        !fantasyLeagueID.isEmpty && !fantasyUserID.isEmpty
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

    func setFantasyZoneEnabled(_ enabled: Bool) {
        fantasyZoneEnabled = enabled
        defaults.set(enabled, forKey: Self.fantasyZoneEnabledKey)
        if enabled, hasFantasyConfiguration {
            Task { await refreshFantasyZone() }
        }
    }

    func discoverFantasyZone(username: String) async {
        let requestID = UUID()
        fantasyRequestID = requestID
        fantasyState = .loading

        do {
            let discovery = try await fantasyFootballProvider.discoverNFLLeagues(username: username)
            guard !discovery.leagues.isEmpty else { throw SleeperAPIError.noLeagues }
            guard fantasyRequestID == requestID else { return }

            fantasyUsername = discovery.user.username
            fantasyUserID = discovery.user.id
            fantasyLeagueChoices = discovery.leagues
            defaults.set(fantasyUsername, forKey: Self.fantasyUsernameKey)
            defaults.set(fantasyUserID, forKey: Self.fantasyUserIDKey)

            let choice = discovery.leagues.first(where: { $0.id == fantasyLeagueID })
                ?? (discovery.leagues.count == 1 ? discovery.leagues.first : nil)
            guard let choice else {
                fantasyLeagueID = ""
                fantasyLeague = nil
                fantasyMatchup = nil
                fantasyState = .loaded
                defaults.removeObject(forKey: Self.fantasyLeagueIDKey)
                return
            }
            try await finishFantasyConnection(
                leagueID: choice.id,
                userID: discovery.user.id,
                requestID: requestID
            )
        } catch {
            guard fantasyRequestID == requestID else { return }
            fantasyState = .failed(error.localizedDescription)
        }
    }

    func selectFantasyLeague(_ leagueID: String) async {
        guard !fantasyUserID.isEmpty,
              fantasyLeagueChoices.contains(where: { $0.id == leagueID }) else { return }
        let requestID = UUID()
        fantasyRequestID = requestID
        fantasyState = .loading
        do {
            try await finishFantasyConnection(
                leagueID: leagueID,
                userID: fantasyUserID,
                requestID: requestID
            )
        } catch {
            guard fantasyRequestID == requestID else { return }
            fantasyState = .failed(error.localizedDescription)
        }
    }

    func refreshFantasyZone(refreshNFLScoreboard: Bool = true) async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["JOE_TV_DEBUG_FANTASY_ZONE"] == "1" {
            return
        }
        #endif
        guard fantasyZoneEnabled, hasFantasyConfiguration else {
            fantasyState = .idle
            return
        }
        if refreshNFLScoreboard {
            async let fantasy: Void = refreshFantasyMatchup()
            async let scores: Void = refreshFantasyNFLScoreboard()
            _ = await (fantasy, scores)
        } else {
            await refreshFantasyMatchup()
        }
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
              let channel = liveChannels.first(where: { $0.id == channelID }) else { return nil }
        return guideProgram(for: channel, at: date)
    }

    func guideProgram(for channel: LiveChannel, at date: Date = Date()) -> EPGProgram? {
        guard let stationID = channelStationMappings[channel.id] else { return nil }
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
            rebuildConsolidatedSportsItems()
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
        async let schedule: Void = refreshSportsSchedule()
        async let espnPlus: Void = loadESPNPlusSportsWindow()
        _ = await (schedule, espnPlus)
    }

    private func loadESPNPlusSportsWindow(referenceDate: Date = Date()) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let requestID = UUID()
        espnPlusRequestID = requestID
        espnPlusDate = today
        espnPlusState = .loading

        async let todayResult = capture {
            try await self.client.loadESPNPlusEvents(for: today, calendar: calendar)
        }
        async let tomorrowResult = capture {
            try await self.client.loadESPNPlusEvents(for: tomorrow, calendar: calendar)
        }
        let results = await [todayResult, tomorrowResult]
        guard espnPlusRequestID == requestID else { return }

        if results.contains(where: { result in
            if case .failure(let error) = result { return isAuthenticationError(error) }
            return false
        }) {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
            espnPlusItems = []
            rebuildConsolidatedSportsItems()
            espnPlusState = .failed("Sign in again to load ESPN+.")
            return
        }

        var seen = Set<String>()
        let loadedItems = results.flatMap { result -> [MediaItem] in
            if case .success(let items) = result { return items }
            return []
        }.filter { item in
            let dateCode = item.providerEventDateCode ?? "undated"
            return seen.insert("\(dateCode)|\(item.id)").inserted
        }
        espnPlusItems = loadedItems
        rebuildConsolidatedSportsItems()

        let errors = results.compactMap { result -> Error? in
            if case .failure(let error) = result { return error }
            return nil
        }
        if loadedItems.isEmpty, let error = errors.first {
            espnPlusState = .failed(error.localizedDescription)
        } else if let error = errors.first {
            espnPlusState = .failed("Some ESPN+ events could not be loaded. \(error.localizedDescription)")
        } else {
            espnPlusState = .loaded
        }
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
            rebuildConsolidatedSportsItems()
            espnPlusState = .loaded
        } catch SeasonsError.authenticationRequired {
            guard espnPlusRequestID == requestID else { return }
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
            espnPlusState = .failed("Sign in again to load ESPN+.")
        } catch {
            guard espnPlusRequestID == requestID else { return }
            espnPlusItems = []
            rebuildConsolidatedSportsItems()
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
            rebuildConsolidatedSportsItems()
            reconcileSelectedCategory()
            sportsScheduleState = .loaded
        } catch {
            guard sportsScheduleRequestID == requestID else { return }
            sportsScheduleState = .failed(error.localizedDescription)
        }
    }

    private func refreshFantasyMatchup() async {
        let requestID = UUID()
        fantasyRequestID = requestID
        fantasyState = .loading

        do {
            let league: FantasyLeagueProfile
            if let cached = fantasyLeague, cached.id == fantasyLeagueID {
                league = cached
            } else {
                league = try await fantasyFootballProvider.loadLeague(leagueID: fantasyLeagueID)
            }
            guard let team = league.team(forUserID: fantasyUserID) else {
                throw SleeperAPIError.rosterNotFound
            }
            let matchup = try await fantasyFootballProvider.loadMatchup(
                leagueID: fantasyLeagueID,
                rosterID: team.rosterID
            )
            guard fantasyRequestID == requestID else { return }
            fantasyLeague = league
            fantasyMatchup = matchup
            fantasyState = .loaded
        } catch {
            guard fantasyRequestID == requestID else { return }
            fantasyState = .failed(error.localizedDescription)
        }
    }

    private func refreshFantasyNFLScoreboard() async {
        let requestID = UUID()
        fantasyNFLScoreRequestID = requestID
        fantasyNFLScoreState = .loading

        do {
            let events = try await liveNFLScoreProvider.loadNFLScoreboard(referenceDate: Date())
            guard fantasyNFLScoreRequestID == requestID else { return }
            fantasyNFLScoreboard = events
            fantasyNFLScoreState = .loaded
        } catch {
            guard fantasyNFLScoreRequestID == requestID else { return }
            fantasyNFLScoreState = .failed(error.localizedDescription)
        }
    }

    private func finishFantasyConnection(
        leagueID: String,
        userID: String,
        requestID: UUID
    ) async throws {
        let league = try await fantasyFootballProvider.loadLeague(leagueID: leagueID)
        guard let team = league.team(forUserID: userID) else {
            throw SleeperAPIError.rosterNotFound
        }
        let matchup = try await fantasyFootballProvider.loadMatchup(
            leagueID: leagueID,
            rosterID: team.rosterID
        )
        guard fantasyRequestID == requestID else { return }

        fantasyLeagueID = leagueID
        fantasyUserID = userID
        fantasyLeague = league
        fantasyMatchup = matchup
        fantasyZoneEnabled = true
        fantasyState = .loaded
        defaults.set(leagueID, forKey: Self.fantasyLeagueIDKey)
        defaults.set(userID, forKey: Self.fantasyUserIDKey)
        defaults.set(true, forKey: Self.fantasyZoneEnabledKey)
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
                    var batchDetails: [String: SportsEventDetail] = [:]
                    for await (cacheKey, detail) in group {
                        guard !Task.isCancelled, let detail else { continue }
                        batchDetails[cacheKey] = detail
                    }
                    if !Task.isCancelled, !batchDetails.isEmpty, let self {
                        var updatedDetails = self.sportsEventDetails
                        updatedDetails.merge(batchDetails) { _, incoming in incoming }
                        self.sportsEventDetails = updatedDetails
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
        prefetchSportsEventDetails(for: consolidatedSportsItems)
    }

    private func rebuildConsolidatedSportsItems() {
        consolidatedSportsItems = SportsEventGuidePolicy.consolidatedItems(
            categories: categories,
            espnPlusItems: espnPlusItems
        )
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
            target: makePlaybackTarget(for: item, option: option, source: .sports),
            presentation: .standard
        )
    }

    func playFromFantasyZone(_ item: MediaItem, option: MediaItem.PlaybackOption? = nil) async {
        await playMediaItem(
            item,
            option: option,
            target: makePlaybackTarget(for: item, option: option, source: .sports),
            presentation: .fantasyZone
        )
    }

    func playESPNPlus(_ item: MediaItem, option: MediaItem.PlaybackOption? = nil) async {
        await playMediaItem(
            item,
            option: option,
            target: makePlaybackTarget(for: item, option: option, source: .espnPlus),
            presentation: .standard
        )
    }

    private func playMediaItem(
        _ item: MediaItem,
        option: MediaItem.PlaybackOption?,
        target: PlaybackTarget,
        presentation: PlaybackPresentation
    ) async {
        workingMessage = "Preparing \(option?.title ?? item.title)…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let session = try await makePlaybackSession(for: item, option: option)
            installPlaybackSession(session, target: target, presentation: presentation)
        } catch SeasonsError.authenticationRequired {
            screen = .signedOut
            errorMessage = "Your session expired. Sign in again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ channel: LiveChannel) async {
        await playLiveChannel(channel, presentation: .standard)
    }

    func playFromFantasyZone(_ channel: LiveChannel) async {
        await playLiveChannel(channel, presentation: .fantasyZone)
    }

    private func playLiveChannel(
        _ channel: LiveChannel,
        presentation: PlaybackPresentation
    ) async {
        workingMessage = "Preparing \(channel.name)…"
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let session = try await makePreviewSession(for: channel)
            installPlaybackSession(
                session,
                target: makePlaybackTarget(channel),
                presentation: presentation
            )
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
        let playback = option?.playback ?? item.playback
        #if DEBUG
        if case .request(let request) = playback, request.endpoint == "debug" {
            return PlaybackSession(debugTitle: item.title, isLivePlayback: startAtLiveEdge)
        }
        #endif
        switch playback {
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

    private func installPlaybackSession(
        _ session: PlaybackSession,
        target: PlaybackTarget,
        presentation: PlaybackPresentation? = nil
    ) {
        let transitionID = UUID()
        playbackTransitionID = transitionID
        let previousSession = playbackSession
        let previousTarget = activePlaybackTarget
        let previousPresentation = playbackPresentation

        if previousSession != nil {
            switchingPlaybackTargetID = target.id
            playbackSwitchMessage = nil
        }
        previousSession?.player.pause()
        if let presentation {
            playbackPresentation = presentation
        }
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
                self.playbackPresentation = previousPresentation
                self.playbackSwitchMessage = "Couldn’t switch to \(target.title). \(message)"
                self.switchingPlaybackTargetID = nil
                previousSession.player.play()
            }
        )
    }

    #if DEBUG
    private func configureFantasyZoneDebugFixture() {
        let now = Date()
        let showsUpcoming = ProcessInfo.processInfo.environment["JOE_TV_DEBUG_FANTASY_UPCOMING"] == "1"
        let request = PlaybackRequest(endpoint: "debug", controller: "debug", arguments: [])

        func game(
            id: String,
            away: String,
            awayCode: String,
            awayScore: Int?,
            home: String,
            homeCode: String,
            homeScore: Int?,
            status: String,
            offset: TimeInterval,
            network: String = "CBS"
        ) -> MediaItem {
            let event = SportsScheduleEvent(
                eventID: id,
                title: "\(away) at \(home)",
                sport: "Football",
                leagueID: "nfl",
                league: "NFL",
                startsAt: now.addingTimeInterval(offset),
                endsAt: now.addingTimeInterval(offset + 3.5 * 3_600),
                status: status,
                venue: nil,
                country: "United States",
                homeTeamID: homeCode,
                homeTeam: home,
                homeTeamLogoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(homeCode).png"),
                awayTeamID: awayCode,
                awayTeam: away,
                awayTeamLogoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(awayCode).png"),
                homeScore: homeScore,
                awayScore: awayScore,
                thumbnailURL: nil,
                sourceDate: nil,
                sourceTime: nil,
                broadcasts: [
                    SportsBroadcast(channelID: nil, channel: network, country: "US", logoURL: nil)
                ]
            )
            return MediaItem(
                id: "debug-nfl-\(id)",
                title: event.title,
                subtitle: status,
                imageURL: nil,
                categoryID: "football",
                playback: .request(request),
                sportsEvent: event
            )
        }

        let games = showsUpcoming
            ? [
                game(id: "1", away: "Miami Dolphins", awayCode: "mia", awayScore: nil, home: "Buffalo Bills", homeCode: "buf", homeScore: nil, status: "Scheduled", offset: 5 * 3_600, network: "CBS"),
                game(id: "2", away: "New England Patriots", awayCode: "ne", awayScore: nil, home: "New York Jets", homeCode: "nyj", homeScore: nil, status: "Scheduled", offset: 25 * 3_600, network: "FOX"),
                game(id: "3", away: "Philadelphia Eagles", awayCode: "phi", awayScore: nil, home: "Seattle Seahawks", homeCode: "sea", homeScore: nil, status: "Scheduled", offset: 49 * 3_600, network: "NBC"),
                game(id: "4", away: "Los Angeles Rams", awayCode: "lar", awayScore: nil, home: "San Francisco 49ers", homeCode: "sf", homeScore: nil, status: "Scheduled", offset: 73 * 3_600, network: "ESPN")
            ]
            : [
                game(id: "1", away: "Miami Dolphins", awayCode: "mia", awayScore: 17, home: "Buffalo Bills", homeCode: "buf", homeScore: 20, status: "3rd · 7:42", offset: -7_200),
                game(id: "2", away: "New England Patriots", awayCode: "ne", awayScore: 13, home: "New York Jets", homeCode: "nyj", homeScore: 10, status: "Halftime", offset: -5_400),
                game(id: "3", away: "Philadelphia Eagles", awayCode: "phi", awayScore: 7, home: "Seattle Seahawks", homeCode: "sea", homeScore: 16, status: "2nd · 2:18", offset: -3_600),
                game(id: "4", away: "Los Angeles Rams", awayCode: "lar", awayScore: 10, home: "San Francisco 49ers", homeCode: "sf", homeScore: 10, status: "2nd · 11:06", offset: -2_700)
            ]

        let fantasyChannels = [
            LiveChannel(
                id: Self.fantasyWatchChannelIDs[0],
                name: "NFL RedZone",
                logoURL: nil,
                playback: .request(request),
                genre: .sports
            ),
            LiveChannel(
                id: Self.fantasyWatchChannelIDs[1],
                name: "NFL Network",
                logoURL: nil,
                playback: .request(request),
                genre: .sports
            )
        ]
        liveChannels = fantasyChannels
        availableLiveChannels = fantasyChannels

        playbackCategories = [CatalogCategory(id: "football", title: "Football", symbol: "football.fill", items: games)]
        categories = playbackCategories
        rebuildConsolidatedSportsItems()
        sportsSchedule = SportsScheduleSnapshot(
            provider: "ESPN",
            generatedAt: now,
            windowStart: "debug-today",
            windowEnd: "debug-tuesday",
            events: games.compactMap(\.sportsEvent)
        )
        sportsScheduleState = .loaded
        fantasyNFLScoreboard = games.compactMap(\.sportsEvent)
        fantasyNFLScoreState = .loaded
        espnPlusState = .loaded
        fantasyZoneEnabled = true
        fantasyUsername = "jrcoakley"
        fantasyLeagueID = "123456789"
        fantasyUserID = "987654321"
        fantasyLeagueChoices = [
            FantasyLeagueChoice(id: fantasyLeagueID, name: "Sunday Ticket Society", avatarURL: nil)
        ]
        fantasyLeague = FantasyLeagueProfile(
            id: fantasyLeagueID,
            name: "Sunday Ticket Society",
            avatarURL: nil,
            teams: [
                FantasyTeamProfile(rosterID: 3, userID: fantasyUserID, name: "Fourth & Long", avatarURL: nil),
                FantasyTeamProfile(rosterID: 8, userID: "opponent", name: "Sunday Scaries", avatarURL: nil)
            ]
        )
        fantasyMatchup = FantasyMatchupSnapshot(
            leagueID: fantasyLeagueID,
            week: 1,
            matchupID: 4,
            userRosterID: 3,
            opponentRosterID: 8,
            userPoints: 104.36,
            opponentPoints: 97.18,
            fetchedAt: now
        )
        fantasyState = .loaded
        selectedCategoryID = "football"
        destination = .sports
        screen = .catalog
    }

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
            #if DEBUG
            if request.endpoint == "debug" {
                return PlaybackSession(debugTitle: channel.name)
            }
            #endif
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
        playbackPresentation = .standard
        activeLiveChannelID = nil
        activePlaybackTarget = nil
        recentPlaybackTargets = []
        switchingPlaybackTargetID = nil
        playbackSwitchMessage = nil
        client.clearLocalSession()
        categories = []
        playbackCategories = []
        espnPlusItems = []
        rebuildConsolidatedSportsItems()
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
        playbackPresentation = .standard
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
