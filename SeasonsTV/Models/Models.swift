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
        .init(id: "nfl", title: "NFL", symbol: "football.fill"),
        .init(id: "college-football", title: "College Football / NCAAF", symbol: "graduationcap.fill"),
        .init(id: "cfl", title: "CFL", symbol: "football.fill"),
        .init(id: "xfl", title: "XFL", symbol: "football.fill"),
        .init(id: "mlb", title: "MLB", symbol: "baseball.fill"),
        .init(id: "college-baseball", title: "College Baseball", symbol: "graduationcap.fill"),
        .init(id: "softball", title: "Softball", symbol: "baseball.fill"),
        .init(id: "little-league", title: "Little League", symbol: "baseball.fill"),
        .init(id: "banana-ball", title: "Banana Ball", symbol: "baseball.fill"),
        .init(id: "nhl", title: "NHL", symbol: "hockey.puck.fill"),
        .init(id: "college-hockey", title: "NCAA Ice Hockey", symbol: "graduationcap.fill"),
        .init(id: "womens-college-hockey", title: "NCAA Women’s Ice Hockey", symbol: "graduationcap.fill"),
        .init(id: "field-hockey", title: "Field Hockey", symbol: "figure.field.hockey"),
        .init(id: "nba", title: "NBA", symbol: "basketball.fill"),
        .init(id: "wnba", title: "WNBA", symbol: "basketball.fill"),
        .init(id: "mens-college-basketball", title: "Men’s College Basketball", symbol: "graduationcap.fill"),
        .init(id: "womens-college-basketball", title: "Women’s College Basketball", symbol: "graduationcap.fill"),
        .init(id: "soccer", title: "Soccer", symbol: "soccerball"),
        .init(id: "tennis", title: "Tennis", symbol: "tennis.racket"),
        .init(id: "pickleball", title: "Pickleball", symbol: "tennis.racket"),
        .init(id: "golf", title: "Golf", symbol: "figure.golf"),
        .init(id: "combat", title: "Combat", symbol: "figure.boxing"),
        .init(id: "wrestling", title: "Wrestling / WWE", symbol: "figure.wrestling"),
        .init(id: "racing", title: "Racing", symbol: "flag.checkered"),
        .init(id: "lacrosse", title: "Lacrosse", symbol: "figure.lacrosse"),
        .init(id: "other", title: "Other", symbol: "square.grid.2x2.fill")
    ]

    static let footballCategoryIDs: Set<String> = ["nfl", "college-football", "cfl", "xfl"]
    static let baseballCategoryIDs: Set<String> = ["mlb", "college-baseball", "softball", "little-league", "banana-ball"]
    static let hockeyCategoryIDs: Set<String> = ["nhl", "college-hockey", "womens-college-hockey", "field-hockey"]
    static let basketballCategoryIDs: Set<String> = ["nba", "wnba", "mens-college-basketball", "womens-college-basketball"]

    static func option(for id: String) -> SportsCategoryOption? {
        all.first(where: { $0.id == id })
    }

    static func migratingLegacySelection(_ stored: Set<String>) -> Set<String> {
        let supported = Set(all.map(\.id))
        var migrated = stored.intersection(supported)
        let legacyGroups: [String: Set<String>] = [
            "football": footballCategoryIDs,
            "college": ["college-football"],
            "baseball": baseballCategoryIDs,
            "hockey": hockeyCategoryIDs,
            "basketball": basketballCategoryIDs,
            "tennis": ["tennis", "pickleball"],
            "combat": ["combat", "wrestling"],
            "volleyball": ["other"]
        ]
        for legacyID in stored {
            migrated.formUnion(legacyGroups[legacyID] ?? [])
        }
        return migrated
    }
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
    case unknown
    case live
    case upcoming
    case replay
    case completed
}

enum SportsGuideScope: String, CaseIterable, Identifiable {
    case live = "Live"
    case upcoming = "Upcoming"

    var id: String { rawValue }
}

extension MediaItem {
    static let sportsCoverageLeadTime: TimeInterval = 15 * 60

    var isGenericSportsChannelShortcut: Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("espn") && normalized.contains("use direct link") { return true }
        return sportsEvent == nil && (normalized == "espn" || normalized == "espn 2")
    }

    func sportsPhase(at date: Date) -> SportsEventPhase {
        let statusText = [sportsEvent?.status, subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: " ")

        if Self.containsCompletionSignal(statusText) {
            return isPlayable ? .replay : .completed
        }
        if Self.hasStatusSignal(#"\breplay\b"#, in: statusText) {
            return .replay
        }
        if Self.containsUncertainSignal(statusText) { return .unknown }
        // Transport availability and generic status copy do not establish timing.
        guard let event = sportsEvent, event.startsAt.timeIntervalSince1970.isFinite,
              event.endsAt.map({ $0.timeIntervalSince1970.isFinite && $0 > event.startsAt }) ?? true else {
            return .unknown
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
        // Ignore stage names while preserving a separate terminal status, e.g.
        // "Quarter-final · Final OT". Word boundaries also exclude quarterfinal.
        let status = value.replacingOccurrences(
            of: #"\b(?:quarter|semi)[\s-]+finals?\b"#, with: "", options: .regularExpression
        )
        return hasStatusSignal(#"\b(?:final(?!\s+(?:round|four)\b)|complete|completed|ended|full[ -]time|post[ -]?game)\b"#, in: status)
    }

    private static func containsUncertainSignal(_ value: String) -> Bool {
        hasStatusSignal(#"\b(?:unknown|tbd|delayed|postponed|cancelled|canceled|suspended|abandoned)\b"#, in: value)
    }

    private static func hasStatusSignal(_ pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

}

enum SportsCategoryClassifier {
    static func categoryID(
        title: String,
        subtitle: String? = nil,
        upstreamCategory: String? = nil,
        sport: String? = nil,
        league: String? = nil
    ) -> String? {
        let value = normalized([title, subtitle, upstreamCategory, sport, league]
            .compactMap { $0 }
            .joined(separator: " "))

        if isESPNStudioProgramming(value) { return nil }

        let mentionsWomen = containsAny(value, ["women", "womens", "women s", "female"])
        let mentionsCollege = containsAny(value, ["college", "collegiate", "ncaa", "ncaaf", "ncaab", "ncaam", "ncaaw"])

        if containsAny(value, ["high school football", "american legion baseball", "women s pro baseball", "womens pro baseball"]) {
            return "other"
        }
        if containsAny(value, ["little league", "junior league baseball"]) { return "little-league" }
        if containsAny(value, ["banana ball", "savannah bananas"]) { return "banana-ball" }
        if containsAny(value, ["softball"]) { return "softball" }
        if containsAny(value, ["college baseball", "ncaa baseball", "necb"]) ||
            (mentionsCollege && containsAny(value, ["baseball"])) {
            return "college-baseball"
        }
        if containsAny(value, ["mlb", "major league baseball", "baseball"]) { return "mlb" }

        if containsAny(value, ["field hockey"]) { return "field-hockey" }
        if mentionsWomen && mentionsCollege && containsAny(value, ["ice hockey", "hockey"]) {
            return "womens-college-hockey"
        }
        if mentionsCollege && containsAny(value, ["ice hockey", "hockey"]) { return "college-hockey" }
        if containsAny(value, ["nhl", "national hockey league", "ice hockey", "hockey"]) { return "nhl" }

        if containsAny(value, ["wnba", "women s national basketball association"]) { return "wnba" }
        if mentionsWomen && mentionsCollege && containsAny(value, ["basketball", "ncaaw", "wcbb"]) {
            return "womens-college-basketball"
        }
        if mentionsCollege && containsAny(value, ["basketball", "ncaab", "ncaam", "mcbb"]) {
            return "mens-college-basketball"
        }
        if containsAny(value, ["nba", "national basketball association", "basketball"]) { return "nba" }

        if containsAny(value, ["cfl", "canadian football league"]) { return "cfl" }
        if containsAny(value, ["xfl"]) { return "xfl" }
        if containsAny(value, ["ncaaf", "college football", "ncaa football", "cfb"]) ||
            (mentionsCollege && containsAny(value, ["football"])) {
            return "college-football"
        }
        if containsAny(value, ["nfl", "national football league", "football"]) { return "nfl" }

        if containsAny(value, [
            "soccer", "futbol", "la liga", "laliga", "eredivisie", "nwsl", "usl", "uefa", "fifa", "mls",
            "northern super league", "german 3 liga", "fa community shield"
        ]) {
            return "soccer"
        }
        if containsAny(value, ["golf", "pga", "lpga", "ryder cup"]) { return "golf" }
        if containsAny(value, ["pickleball"]) { return "pickleball" }
        if containsAny(value, ["tennis", "us open", "wimbledon", "atp", "wta", "roland garros", "australian open"]) {
            return "tennis"
        }
        if containsAny(value, ["wwe", "wrestling"]) { return "wrestling" }
        if containsAny(value, ["boxing", "mma", "ufc", "professional fighters league", "pfl", "most valuable promotions"]) {
            return "combat"
        }
        if containsAny(value, ["racing", "nascar", "formula 1", "formula one", "indycar", "motogp", "grand prix"]) { return "racing" }
        if containsAny(value, ["lacrosse", "premier lacrosse", "womens lacrosse", "women s lacrosse", "pll", "wll"]) { return "lacrosse" }
        if containsAny(value, ["volleyball", "surf", "surfing", "water polo", "nineball", "nine ball", "billiard", "billiards", "sport fishing", "fishing", "poker", "other"]) {
            return "other"
        }
        return nil
    }

    static func categoryID(for item: MediaItem) -> String? {
        let combinedValue = normalized([
            item.title,
            item.subtitle,
            item.categoryID,
            item.sportsEvent?.sport,
            item.sportsEvent?.league
        ]
        .compactMap { $0 }
        .joined(separator: " "))
        if isESPNStudioProgramming(combinedValue) { return nil }

        let canonicalIDs = Set(SportsCategoryOption.all.map(\.id))
        if canonicalIDs.contains(item.categoryID) { return item.categoryID }
        if item.categoryID == "channels" { return nil }
        let classified = categoryID(
            title: item.title,
            subtitle: item.subtitle,
            upstreamCategory: item.categoryID,
            sport: item.sportsEvent?.sport,
            league: item.sportsEvent?.league
        )
        if let classified { return classified }
        if item.categoryID == "college" { return "college-football" }
        return "other"
    }

    private static func normalized(_ value: String) -> String {
        " " + value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) + " "
    }

    private static func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains { value.contains(normalized($0)) }
    }

    private static func isESPNStudioProgramming(_ value: String) -> Bool {
        [
            "espn fc daily", "futbol w", "futbol americas", "fairways of life",
            "flames central", "pardon the interruption", "pat mcafee show", "the golics",
            "mecum auctions", "sportscenter", "first take", "around the horn", "daily wager",
            "college football countdown", "college gameday", "monday night countdown",
            "sunday nfl countdown", "fantasy football now", "nfl live", "the huddle",
            "the insiders", "read react", "baseball tonight", "nba today", "nhl tonight",
            "good morning football", "sec in 60", "sec in60"
        ].contains(where: value.contains)
    }
}

enum SportsEventGuidePolicy {
    static func consolidatedItems(
        categories: [CatalogCategory],
        espnPlusItems: [MediaItem]
    ) -> [MediaItem] {
        var result: [MediaItem] = []
        let candidates = categories.flatMap(\.items) + espnPlusItems

        for candidate in candidates where !candidate.isGenericSportsChannelShortcut {
            guard let categoryID = SportsCategoryClassifier.categoryID(for: candidate) else { continue }
            let item = replacingCategory(of: candidate, with: categoryID)
            if let index = result.firstIndex(where: { describeSameEvent($0, item) }) {
                result[index] = merge(result[index], item, categoryID: categoryID)
            } else {
                result.append(item)
            }
        }

        return result.sorted(by: chronologicalOrder)
    }

    static func filteredItems(
        _ items: [MediaItem],
        scope: SportsGuideScope,
        selectedCategoryIDs: Set<String>,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [MediaItem] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        let upcomingCutoff = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: tomorrow)) ?? .distantFuture

        return items.filter { item in
            guard selectedCategoryIDs.contains(item.categoryID) else { return false }
            switch (scope, item.sportsPhase(at: date)) {
            case (.live, .live):
                return true
            case (.upcoming, .upcoming):
                guard let start = item.sportsEvent?.startsAt else { return true }
                return start < upcomingCutoff
            default:
                return false
            }
        }
        .sorted(by: chronologicalOrder)
    }

    static func sourceLabels(for item: MediaItem) -> [String] {
        var labels: [String] = []
        for option in item.playbackOptions where option.isPlayable {
            let label: String
            switch option.playback {
            case .drmPage(let url) where url.path.localizedCaseInsensitiveContains("PlayerDRMEP"):
                label = "ESPN+"
            case .request, .hls, .drmPage:
                label = "S4U"
            case .unavailable:
                continue
            }
            if !labels.contains(label) { labels.append(label) }
        }
        return labels
    }

    private static func replacingCategory(of item: MediaItem, with categoryID: String) -> MediaItem {
        MediaItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            imageURL: item.imageURL,
            categoryID: categoryID,
            playbackOptions: item.playbackOptions,
            sportsEvent: item.sportsEvent,
            providerEventDateCode: item.providerEventDateCode
        )
    }

    private static func merge(_ preferred: MediaItem, _ incoming: MediaItem, categoryID: String) -> MediaItem {
        let metadataItem: MediaItem
        let secondaryItem: MediaItem
        if preferred.sportsEvent != nil || incoming.sportsEvent == nil {
            metadataItem = preferred
            secondaryItem = incoming
        } else {
            metadataItem = incoming
            secondaryItem = preferred
        }

        var optionSignatures = Set<String>()
        let options = (preferred.playbackOptions + incoming.playbackOptions).filter { option in
            guard option.isPlayable else { return false }
            return optionSignatures.insert(playbackSignature(option.playback)).inserted
        }

        return MediaItem(
            id: metadataItem.id,
            title: metadataItem.title,
            subtitle: metadataItem.subtitle ?? secondaryItem.subtitle,
            imageURL: metadataItem.imageURL ?? secondaryItem.imageURL,
            categoryID: categoryID,
            playbackOptions: options,
            sportsEvent: metadataItem.sportsEvent ?? secondaryItem.sportsEvent,
            providerEventDateCode: metadataItem.providerEventDateCode ?? secondaryItem.providerEventDateCode
        )
    }

    private static func describeSameEvent(_ lhs: MediaItem, _ rhs: MediaItem) -> Bool {
        if lhs.id == rhs.id { return true }
        guard titlesDescribeSameEvent(lhs.title, rhs.title) else { return false }
        switch (lhs.sportsEvent?.startsAt, rhs.sportsEvent?.startsAt) {
        case let (left?, right?):
            return abs(left.timeIntervalSince(right)) < 6 * 3_600
        default:
            return lhs.providerEventDateCode == nil || rhs.providerEventDateCode == nil ||
                lhs.providerEventDateCode == rhs.providerEventDateCode
        }
    }

    private static func titlesDescribeSameEvent(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = competitors(in: lhs), let right = competitors(in: rhs) else {
            return normalizedEventTitle(lhs) == normalizedEventTitle(rhs)
        }
        return teamsMatch(left.0, right.0) && teamsMatch(left.1, right.1)
            || teamsMatch(left.0, right.1) && teamsMatch(left.1, right.0)
    }

    private static func competitors(in title: String) -> (String, String)? {
        let cleaned = title
            .replacingOccurrences(of: #"\b(?:live|espn\+|mlb|nfl|nba|nhl|ncaa)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+(?:@|at|vs\.?|versus)\s+"#, with: "|", options: [.regularExpression, .caseInsensitive])
        let teams = cleaned.split(separator: "|", maxSplits: 1).map(normalizedTitle)
        guard teams.count == 2, teams.allSatisfy({ !$0.isEmpty }) else { return nil }
        return (teams[0], teams[1])
    }

    private static func normalizedEventTitle(_ title: String) -> String {
        normalizedTitle(
            title.replacingOccurrences(
                of: #"\b(?:live|espn\+|mlb|nfl|nba|nhl|ncaa)\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        )
    }

    private static func teamsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasSuffix(" " + rhs) || rhs.hasSuffix(" " + lhs)
    }

    private static func normalizedTitle<S: StringProtocol>(_ value: S) -> String {
        String(value)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func playbackSignature(_ playback: MediaItem.Playback) -> String {
        switch playback {
        case .drmPage(let url): return "drm|\(url.absoluteString)"
        case .hls(let url): return "hls|\(url.absoluteString)"
        case .request(let request): return "request|\(request.endpoint)|\(request.arguments.joined(separator: "|"))"
        case .unavailable: return "unavailable"
        }
    }

    private static func chronologicalOrder(_ lhs: MediaItem, _ rhs: MediaItem) -> Bool {
        let leftDate = lhs.sportsEvent?.startsAt ?? .distantFuture
        let rightDate = rhs.sportsEvent?.startsAt ?? .distantFuture
        if leftDate != rightDate { return leftDate < rightDate }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
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

struct FantasyTeamProfile: Identifiable, Equatable, Sendable {
    let rosterID: Int
    let userID: String?
    let name: String
    let avatarURL: URL?

    var id: Int { rosterID }
}

struct FantasyUserProfile: Equatable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let avatarURL: URL?
}

struct FantasyLeagueChoice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let avatarURL: URL?
}

struct FantasyAccountDiscovery: Equatable, Sendable {
    let user: FantasyUserProfile
    let leagues: [FantasyLeagueChoice]
}

struct FantasyLeagueProfile: Equatable, Sendable {
    let id: String
    let name: String
    let avatarURL: URL?
    let teams: [FantasyTeamProfile]

    func team(forUserID userID: String) -> FantasyTeamProfile? {
        teams.first { $0.userID == userID }
    }

    func team(forRosterID rosterID: Int?) -> FantasyTeamProfile? {
        guard let rosterID else { return nil }
        return teams.first { $0.rosterID == rosterID }
    }
}

struct FantasyMatchupSnapshot: Equatable, Sendable {
    let leagueID: String
    let week: Int
    let matchupID: Int?
    let userRosterID: Int
    let opponentRosterID: Int?
    let userPoints: Double
    let opponentPoints: Double?
    let fetchedAt: Date
    let userStarters: [FantasyPlayerWeek]
    let opponentStarters: [FantasyPlayerWeek]
    let leagueMatchups: [FantasyLeagueMatchup]

    init(
        leagueID: String,
        week: Int,
        matchupID: Int?,
        userRosterID: Int,
        opponentRosterID: Int?,
        userPoints: Double,
        opponentPoints: Double?,
        fetchedAt: Date,
        userStarters: [FantasyPlayerWeek] = [],
        opponentStarters: [FantasyPlayerWeek] = [],
        leagueMatchups: [FantasyLeagueMatchup] = []
    ) {
        self.leagueID = leagueID
        self.week = week
        self.matchupID = matchupID
        self.userRosterID = userRosterID
        self.opponentRosterID = opponentRosterID
        self.userPoints = userPoints
        self.opponentPoints = opponentPoints
        self.fetchedAt = fetchedAt
        self.userStarters = userStarters
        self.opponentStarters = opponentStarters
        self.leagueMatchups = leagueMatchups
    }
}

struct FantasyPlayerWeek: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let position: String?
    let nflTeam: String?
    let points: Double
}

struct FantasyMatchupParticipant: Identifiable, Equatable, Sendable {
    let rosterID: Int
    let points: Double
    let starters: [FantasyPlayerWeek]

    var id: Int { rosterID }
}

struct FantasyLeagueMatchup: Identifiable, Equatable, Sendable {
    let id: String
    let matchupID: Int?
    let participants: [FantasyMatchupParticipant]
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

/// Combines source outcomes for one requested viewport. The window bounds describe
/// that viewport, not a promise that every provider covers every instant in it.
enum EPGGuideMergePolicy {
    struct Source {
        let channelIDs: Set<String>
        let outcome: Outcome
    }

    enum Outcome {
        case loaded(window: EPGGuideWindow, mappings: [ChannelStationMapping])
        case failed(message: String)
        case unavailable
    }

    struct Merge {
        let state: EPGLoadState
        let mappings: [String: String]
    }

    static func merge(
        sources: [Source], cached: EPGGuideWindow?, cachedMappings: [String: String],
        from start: Date, to end: Date
    ) -> Merge {
        let sources = sources.filter { !$0.channelIDs.isEmpty }
        guard !sources.isEmpty else { return Merge(state: .unavailable, mappings: [:]) }

        var mappings: [String: String] = [:]
        var programs: [String: [EPGProgram]] = [:]
        var timestamps: [Date] = []
        var errorMessage: String?
        var successfulStations = Set<String>()
        var retainedMappings: [String: String] = [:]

        func relevantPrograms(_ window: EPGGuideWindow, stationID: String) -> [EPGProgram] {
            return (window.programsByStationID[stationID] ?? []).filter {
                $0.stationID == stationID && $0.start < $0.end &&
                $0.start < end && $0.end > start &&
                $0.start < window.end && $0.end > window.start
            }
        }

        for source in sources {
            switch source.outcome {
            case .loaded(let window, let sourceMappings):
                // Prior claims also count: a successful empty/mapping-removal
                // result must not resurrect its old rows through a failed source.
                successfulStations.formUnion(source.channelIDs.compactMap { cachedMappings[$0] })
                let acceptedMappings = sourceMappings.filter { source.channelIDs.contains($0.channelID) }
                    .reduce(into: [String: String]()) { $0[$1.channelID] = $1.stationID }
                successfulStations.formUnion(acceptedMappings.values)
                mappings.merge(acceptedMappings) { _, incoming in incoming }
                for stationID in Set(acceptedMappings.values) {
                    programs[stationID, default: []].append(contentsOf: relevantPrograms(window, stationID: stationID))
                }
                // An authoritative empty publication still has known provenance.
                timestamps.append(window.fetchedAt)
            case .failed(let message):
                if errorMessage == nil { errorMessage = message }
                for channelID in source.channelIDs {
                    if let stationID = cachedMappings[channelID] { retainedMappings[channelID] = stationID }
                }
            case .unavailable:
                if errorMessage == nil { errorMessage = "Programming details are unavailable." }
                for channelID in source.channelIDs {
                    if let stationID = cachedMappings[channelID] { retainedMappings[channelID] = stationID }
                }
            }
        }

        if let cached, !retainedMappings.isEmpty {
            // Original program times can prove useful coverage even when the old
            // and requested viewports are disjoint. Mapping-only retention cannot.
            let retainedPrograms = Dictionary(uniqueKeysWithValues:
                Set(retainedMappings.values).subtracting(successfulStations).map {
                    ($0, relevantPrograms(cached, stationID: $0))
                }
            )
            let viewportsOverlap = cached.start < end && cached.end > start
            let applicableMappings = retainedMappings.filter {
                viewportsOverlap || !(retainedPrograms[$0.value] ?? []).isEmpty
            }
            if !applicableMappings.isEmpty {
                // Successful station claims override ambiguous old shared rows.
                mappings.merge(applicableMappings) { existing, _ in existing }
                for stationID in Set(applicableMappings.values).subtracting(successfulStations) {
                    programs[stationID] = retainedPrograms[stationID]
                }
                timestamps.append(cached.fetchedAt)
            }
        }

        programs = programs.mapValues { rows in
            var seen = Set<String>()
            return rows.filter { seen.insert($0.id).inserted }.sorted {
                $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
            }
        }
        let window = timestamps.min().map {
            EPGGuideWindow(start: start, end: end, programsByStationID: programs, fetchedAt: $0)
        }
        if let errorMessage { return Merge(state: .failed(message: errorMessage, cached: window), mappings: mappings) }
        guard let window else { return Merge(state: .unavailable, mappings: [:]) }
        return Merge(state: .loaded(window), mappings: mappings)
    }
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

protocol FantasyFootballProviding: Sendable {
    func discoverNFLLeagues(username: String) async throws -> FantasyAccountDiscovery
    func loadLeague(leagueID: String) async throws -> FantasyLeagueProfile
    func loadMatchup(leagueID: String, rosterID: Int) async throws -> FantasyMatchupSnapshot
}

protocol LiveNFLScoreProviding: Sendable {
    func loadNFLScoreboard(referenceDate: Date) async throws -> [SportsScheduleEvent]
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

enum DRMContentIdentifierStrategy: Equatable {
    case fullSKDURL
    case schemeStripped(dropFirst: Int)

    func identifier(for skdURL: URL) -> String {
        switch self {
        case .fullSKDURL:
            return skdURL.absoluteString
        case .schemeStripped(let dropCount):
            let withoutScheme = skdURL.absoluteString.replacingOccurrences(of: "skd://", with: "")
            return String(withoutScheme.dropFirst(max(0, dropCount)))
        }
    }
}

struct DRMConfiguration {
    let hlsURL: URL
    let certificateURL: URL
    let licenseProxyPrefix: String?
    let headers: [String: String]
    let licenseURL: URL?
    let contentIdentifierStrategy: DRMContentIdentifierStrategy

    init(
        hlsURL: URL,
        certificateURL: URL,
        licenseProxyPrefix: String?,
        headers: [String: String],
        licenseURL: URL? = nil,
        contentIdentifierStrategy: DRMContentIdentifierStrategy = .fullSKDURL
    ) {
        self.hlsURL = hlsURL
        self.certificateURL = certificateURL
        self.licenseProxyPrefix = licenseProxyPrefix
        self.headers = headers
        self.licenseURL = licenseURL
        self.contentIdentifierStrategy = contentIdentifierStrategy
    }
}

struct PlaybackSubtitleOption: Identifiable, Equatable {
    let id: String
    let title: String
    let languageCode: String?
    let isClosedCaption: Bool
}

@MainActor
final class PlaybackSession: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let player: AVPlayer
    let isLivePlayback: Bool
    @Published private(set) var playbackError: String?
    @Published private(set) var isReady = false
    @Published private(set) var subtitleOptions: [PlaybackSubtitleOption] = []
    @Published private(set) var selectedSubtitleOptionID: String?
    private let startAtLiveEdge: Bool
    private let resourceLoader: FairPlayResourceLoader?
    private var statusObservation: NSKeyValueObservation?
    private var preparationTimeout: Task<Void, Never>?
    private var subtitleLoadTask: Task<Void, Never>?
    private var subtitleGroup: AVMediaSelectionGroup?
    private var subtitleMediaOptions: [String: AVMediaSelectionOption] = [:]
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
            refreshSubtitleOptions()
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

    var selectedSubtitleTitle: String? {
        guard let selectedSubtitleOptionID else { return nil }
        return subtitleOptions.first(where: { $0.id == selectedSubtitleOptionID })?.title
    }

    func refreshSubtitleOptions() {
        subtitleLoadTask?.cancel()
        guard let item = player.currentItem else {
            clearSubtitleOptions()
            return
        }

        let asset = item.asset
        subtitleLoadTask = Task { @MainActor [weak self, weak item] in
            do {
                guard let group = try await asset.loadMediaSelectionGroup(for: .legible),
                      !Task.isCancelled,
                      let self,
                      let item,
                      item === self.player.currentItem else { return }
                self.installSubtitleOptions(group, for: item)
            } catch {
                guard !Task.isCancelled else { return }
                self?.clearSubtitleOptions()
            }
        }
    }

    func selectSubtitle(_ identifier: String?) {
        guard let item = player.currentItem,
              let subtitleGroup else { return }

        if let identifier,
           let option = subtitleMediaOptions[identifier] {
            item.select(option, in: subtitleGroup)
            selectedSubtitleOptionID = identifier
        } else if subtitleGroup.allowsEmptySelection {
            item.select(nil, in: subtitleGroup)
            selectedSubtitleOptionID = nil
        }
    }

    private func installSubtitleOptions(_ group: AVMediaSelectionGroup, for item: AVPlayerItem) {
        let entries = group.options.enumerated().map { index, option -> (PlaybackSubtitleOption, AVMediaSelectionOption) in
            let languageCode = option.extendedLanguageTag ?? option.locale?.identifier
            let isClosedCaption = option.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility)
                || option.hasMediaCharacteristic(.describesMusicAndSoundForAccessibility)
            let title = isClosedCaption
                        && !option.displayName.localizedCaseInsensitiveContains("CC")
                        && !option.displayName.localizedCaseInsensitiveContains("SDH")
                ? "\(option.displayName) · CC"
                : option.displayName
            let identifier = [languageCode ?? "und", option.displayName, String(index)]
                .joined(separator: "|")
            return (
                PlaybackSubtitleOption(
                    id: identifier,
                    title: title,
                    languageCode: languageCode,
                    isClosedCaption: isClosedCaption
                ),
                option
            )
        }

        subtitleGroup = group
        subtitleOptions = entries.map { $0.0 }
        subtitleMediaOptions = Dictionary(uniqueKeysWithValues: entries.map { ($0.0.id, $0.1) })

        if let selected = item.currentMediaSelection.selectedMediaOption(in: group) {
            selectedSubtitleOptionID = entries.first(where: { $0.1.isEqual(selected) })?.0.id
        } else {
            selectedSubtitleOptionID = nil
        }
    }

    private func clearSubtitleOptions() {
        subtitleGroup = nil
        subtitleOptions = []
        subtitleMediaOptions = [:]
        selectedSubtitleOptionID = nil
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
        subtitleLoadTask?.cancel()
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
