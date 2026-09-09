import Foundation

actor SleeperClient: FantasyFootballProviding {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.sleeper.app/v1/")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func discoverNFLLeagues(username: String) async throws -> FantasyAccountDiscovery {
        let username = try SleeperAPIParser.validatedUsername(username)
        async let userData = data(path: "user/\(username)", notFoundError: .userNotFound)
        async let stateData = data(path: "state/nfl")
        let (user, state) = try await (
            SleeperAPIParser.user(data: userData),
            SleeperAPIParser.nflState(data: stateData)
        )
        let leaguesData = try await data(path: "user/\(user.id)/leagues/nfl/\(state.season)")
        return FantasyAccountDiscovery(
            user: user,
            leagues: try SleeperAPIParser.leagueChoices(data: leaguesData)
        )
    }

    func loadLeague(leagueID: String) async throws -> FantasyLeagueProfile {
        let leagueID = try SleeperAPIParser.validatedIdentifier(leagueID, label: "league")
        async let leagueData = data(path: "league/\(leagueID)")
        async let usersData = data(path: "league/\(leagueID)/users")
        async let rostersData = data(path: "league/\(leagueID)/rosters")
        return try await SleeperAPIParser.league(
            leagueData: leagueData,
            usersData: usersData,
            rostersData: rostersData
        )
    }

    func loadMatchup(leagueID: String, rosterID: Int) async throws -> FantasyMatchupSnapshot {
        let leagueID = try SleeperAPIParser.validatedIdentifier(leagueID, label: "league")
        async let stateData = data(path: "state/nfl")
        let state = try await SleeperAPIParser.nflState(data: stateData)
        let matchupsData = try await data(path: "league/\(leagueID)/matchups/\(state.week)")
        return try SleeperAPIParser.matchup(
            leagueID: leagueID,
            rosterID: rosterID,
            week: state.week,
            data: matchupsData
        )
    }

    private func data(
        path: String,
        notFoundError: SleeperAPIError = .leagueNotFound
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SleeperAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SleeperAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 { throw notFoundError }
            throw SleeperAPIError.httpStatus(http.statusCode)
        }
        return data
    }
}

enum SleeperAPIParser {
    struct NFLState: Equatable {
        let week: Int
        let season: String
    }

    static func validatedIdentifier(_ value: String, label: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.allSatisfy(\.isNumber) else {
            throw SleeperAPIError.invalidIdentifier(label)
        }
        return normalized
    }

    static func validatedUsername(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        guard !normalized.isEmpty,
              normalized.unicodeScalars.allSatisfy(allowed.contains) else {
            throw SleeperAPIError.invalidUsername
        }
        return normalized
    }

    static func user(data: Data) throws -> FantasyUserProfile {
        let user = try JSONDecoder().decode(UserResponse.self, from: data)
        guard !user.userID.isEmpty else { throw SleeperAPIError.userNotFound }
        return FantasyUserProfile(
            id: user.userID,
            username: firstNonempty([user.username]) ?? user.userID,
            displayName: firstNonempty([user.displayName, user.username]) ?? user.userID,
            avatarURL: avatarURL(user.avatar)
        )
    }

    static func leagueChoices(data: Data) throws -> [FantasyLeagueChoice] {
        try JSONDecoder().decode([LeagueResponse].self, from: data)
            .map {
                FantasyLeagueChoice(id: $0.leagueID, name: $0.name, avatarURL: avatarURL($0.avatar))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func league(
        leagueData: Data,
        usersData: Data,
        rostersData: Data
    ) throws -> FantasyLeagueProfile {
        let decoder = JSONDecoder()
        let league = try decoder.decode(LeagueResponse.self, from: leagueData)
        let users = try decoder.decode([UserResponse].self, from: usersData)
        let rosters = try decoder.decode([RosterResponse].self, from: rostersData)
        guard !league.leagueID.isEmpty else { throw SleeperAPIError.leagueNotFound }

        let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.userID, $0) })
        let teams = rosters.map { roster -> FantasyTeamProfile in
            let user = roster.ownerID.flatMap { usersByID[$0] }
            let teamName = firstNonempty([
                user?.metadata?.teamName,
                user?.displayName,
                user?.username,
                "Roster \(roster.rosterID)"
            ]) ?? "Roster \(roster.rosterID)"
            return FantasyTeamProfile(
                rosterID: roster.rosterID,
                userID: roster.ownerID,
                name: teamName,
                avatarURL: avatarURL(user?.avatar)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return FantasyLeagueProfile(
            id: league.leagueID,
            name: league.name,
            avatarURL: avatarURL(league.avatar),
            teams: teams
        )
    }

    static func nflState(data: Data) throws -> NFLState {
        let state = try JSONDecoder().decode(NFLStateResponse.self, from: data)
        let week = state.leg ?? state.week ?? state.displayWeek
        guard let week, week > 0 else { throw SleeperAPIError.weekUnavailable }
        guard let season = firstNonempty([state.leagueSeason, state.season]) else {
            throw SleeperAPIError.seasonUnavailable
        }
        return NFLState(week: week, season: season)
    }

    static func matchup(
        leagueID: String,
        rosterID: Int,
        week: Int,
        data: Data,
        fetchedAt: Date = Date()
    ) throws -> FantasyMatchupSnapshot {
        let entries = try JSONDecoder().decode([MatchupResponse].self, from: data)
        guard let user = entries.first(where: { $0.rosterID == rosterID }) else {
            throw SleeperAPIError.rosterNotFound
        }
        let opponent = user.matchupID.flatMap { matchupID in
            entries.first { $0.rosterID != rosterID && $0.matchupID == matchupID }
        }
        return FantasyMatchupSnapshot(
            leagueID: leagueID,
            week: week,
            matchupID: user.matchupID,
            userRosterID: rosterID,
            opponentRosterID: opponent?.rosterID,
            userPoints: user.customPoints ?? user.points ?? 0,
            opponentPoints: opponent.map { $0.customPoints ?? $0.points ?? 0 },
            fetchedAt: fetchedAt
        )
    }

    private static func firstNonempty(_ values: [String?]) -> String? {
        values.compactMap { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { return nil }
            return trimmed
        }.first
    }

    private static func avatarURL(_ avatarID: String?) -> URL? {
        guard let avatarID = firstNonempty([avatarID]) else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatarID)")
    }

    private struct LeagueResponse: Decodable {
        let leagueID: String
        let name: String
        let avatar: String?

        enum CodingKeys: String, CodingKey {
            case leagueID = "league_id"
            case name
            case avatar
        }
    }

    private struct UserResponse: Decodable {
        let userID: String
        let username: String?
        let displayName: String?
        let avatar: String?
        let metadata: UserMetadata?

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case username
            case displayName = "display_name"
            case avatar
            case metadata
        }
    }

    private struct UserMetadata: Decodable {
        let teamName: String?

        enum CodingKeys: String, CodingKey {
            case teamName = "team_name"
        }
    }

    private struct RosterResponse: Decodable {
        let rosterID: Int
        let ownerID: String?

        enum CodingKeys: String, CodingKey {
            case rosterID = "roster_id"
            case ownerID = "owner_id"
        }
    }

    private struct NFLStateResponse: Decodable {
        let week: Int?
        let leg: Int?
        let displayWeek: Int?
        let season: String?
        let leagueSeason: String?

        enum CodingKeys: String, CodingKey {
            case week
            case leg
            case displayWeek = "display_week"
            case season
            case leagueSeason = "league_season"
        }
    }

    private struct MatchupResponse: Decodable {
        let rosterID: Int
        let matchupID: Int?
        let points: Double?
        let customPoints: Double?

        enum CodingKeys: String, CodingKey {
            case rosterID = "roster_id"
            case matchupID = "matchup_id"
            case points
            case customPoints = "custom_points"
        }
    }
}

enum SleeperAPIError: LocalizedError {
    case invalidUsername
    case invalidIdentifier(String)
    case userNotFound
    case noLeagues
    case leagueNotFound
    case rosterNotFound
    case weekUnavailable
    case seasonUnavailable
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Enter a valid Sleeper username."
        case .invalidIdentifier(let label):
            return "Enter a valid numeric Sleeper \(label) ID."
        case .userNotFound:
            return "Sleeper could not find that username."
        case .noLeagues:
            return "That Sleeper account has no NFL league for the active season."
        case .leagueNotFound:
            return "Sleeper could not find that league."
        case .rosterNotFound:
            return "That Sleeper user does not own a roster in this league."
        case .weekUnavailable:
            return "Sleeper has not published the current NFL week."
        case .seasonUnavailable:
            return "Sleeper has not published the active NFL season."
        case .invalidResponse:
            return "Sleeper returned an unreadable response."
        case .httpStatus(let status):
            return "Sleeper returned HTTP \(status)."
        }
    }
}
