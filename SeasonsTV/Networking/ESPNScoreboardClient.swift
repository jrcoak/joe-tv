import Foundation

actor ESPNScoreboardClient: LiveNFLScoreProviding {
    private static let minimumRefreshInterval: TimeInterval = 20
    private let session: URLSession
    private var cachedEvents: [SportsScheduleEvent] = []
    private var cachedDateKey = ""
    private var lastRefresh: Date?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadNFLScoreboard(referenceDate: Date = Date()) async throws -> [SportsScheduleEvent] {
        let dateKey = Self.dateRangeKey(referenceDate)
        if dateKey == cachedDateKey,
           let lastRefresh,
           referenceDate.timeIntervalSince(lastRefresh) < Self.minimumRefreshInterval {
            return cachedEvents
        }

        var components = URLComponents(
            string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
        )!
        components.queryItems = [
            URLQueryItem(name: "dates", value: dateKey),
            URLQueryItem(name: "limit", value: "100")
        ]
        guard let url = components.url else { throw ESPNScoreboardError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ESPNScoreboardError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ESPNScoreboardError.httpStatus(http.statusCode)
        }
        let events = try ESPNScoreboardParser.decode(data)
        cachedEvents = events
        cachedDateKey = dateKey
        lastRefresh = referenceDate
        return events
    }

    static func dateRangeKey(_ date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let tuesdayWeekday = 3
        let daysThroughTuesday = (tuesdayWeekday - weekday + 7) % 7
        let end = calendar.date(byAdding: .day, value: daysThroughTuesday, to: start) ?? start
        return "\(dateKey(start, calendar: calendar))-\(dateKey(end, calendar: calendar))"
    }

    private static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum ESPNScoreboardParser {
    static func decode(_ data: Data) throws -> [SportsScheduleEvent] {
        let decoder = JSONDecoder()
        let internetDateFormatter = ISO8601DateFormatter()
        let fractionalDateFormatter = ISO8601DateFormatter()
        fractionalDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let minuteDateFormatter = DateFormatter()
        minuteDateFormatter.calendar = Calendar(identifier: .gregorian)
        minuteDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        minuteDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        minuteDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"
        decoder.dateDecodingStrategy = .custom { valueDecoder in
            let container = try valueDecoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractionalDateFormatter.date(from: value)
                ?? internetDateFormatter.date(from: value)
                ?? minuteDateFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ESPN date: \(value)"
            )
        }
        let response = try decoder.decode(Response.self, from: data)
        return response.events.compactMap(makeEvent).sorted { $0.startsAt < $1.startsAt }
    }

    private static func makeEvent(_ event: Event) -> SportsScheduleEvent? {
        guard let competition = event.competitions.first else { return nil }
        let home = competition.competitors.first(where: { $0.homeAway == "home" })
        let away = competition.competitors.first(where: { $0.homeAway == "away" })
        guard home != nil || away != nil else { return nil }
        let state = competition.status?.type.state ?? event.status?.type.state
        let completed = competition.status?.type.completed ?? event.status?.type.completed ?? false
        let type = competition.status?.type ?? event.status?.type
        let detail = type?.shortDetail ?? type?.detail ?? type?.description
        let status: String?
        if state == "in" {
            status = detail.map { "Live · \($0)" } ?? "Live"
        } else if completed || state == "post" {
            status = detail.map { "Final · \($0)" } ?? "Final"
        } else {
            status = detail ?? type?.description
        }
        let scoresArePublished = state != "pre"

        return SportsScheduleEvent(
            eventID: event.id,
            title: event.name,
            sport: "Football",
            leagueID: "nfl",
            league: "NFL",
            startsAt: competition.date ?? event.date,
            endsAt: nil,
            status: status,
            venue: competition.venue?.fullName,
            country: competition.venue?.address?.country,
            homeTeamID: home?.team.id,
            homeTeam: home?.team.displayName,
            homeTeamLogoURL: home?.team.logo,
            awayTeamID: away?.team.id,
            awayTeam: away?.team.displayName,
            awayTeamLogoURL: away?.team.logo,
            homeScore: scoresArePublished ? integerScore(home?.score) : nil,
            awayScore: scoresArePublished ? integerScore(away?.score) : nil,
            thumbnailURL: nil,
            sourceDate: nil,
            sourceTime: nil,
            broadcasts: competition.broadcasts.flatMap { broadcast in
                broadcast.names.map {
                    SportsBroadcast(channelID: nil, channel: $0, country: "US", logoURL: nil)
                }
            }
        )
    }

    private static func integerScore(_ value: String?) -> Int? {
        guard let value, let score = Double(value) else { return nil }
        return Int(score.rounded())
    }

    private struct Response: Decodable {
        let events: [Event]
    }

    private struct Event: Decodable {
        let id: String
        let name: String
        let date: Date
        let status: Status?
        let competitions: [Competition]
    }

    private struct Competition: Decodable {
        let date: Date?
        let venue: Venue?
        let broadcasts: [Broadcast]
        let status: Status?
        let competitors: [Competitor]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decodeIfPresent(Date.self, forKey: .date)
            venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
            broadcasts = try container.decodeIfPresent([Broadcast].self, forKey: .broadcasts) ?? []
            status = try container.decodeIfPresent(Status.self, forKey: .status)
            competitors = try container.decodeIfPresent([Competitor].self, forKey: .competitors) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case date, venue, broadcasts, status, competitors
        }
    }

    private struct Status: Decodable {
        let type: StatusType
    }

    private struct StatusType: Decodable {
        let state: String?
        let completed: Bool?
        let description: String?
        let detail: String?
        let shortDetail: String?
    }

    private struct Competitor: Decodable {
        let homeAway: String
        let score: String?
        let team: Team
    }

    private struct Team: Decodable {
        let id: String
        let displayName: String
        let logo: URL?
    }

    private struct Broadcast: Decodable {
        let names: [String]
    }

    private struct Venue: Decodable {
        let fullName: String?
        let address: Address?
    }

    private struct Address: Decodable {
        let country: String?
    }
}

enum ESPNScoreboardError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "ESPN returned an unreadable NFL scoreboard."
        case .httpStatus(let status):
            return "ESPN's NFL scoreboard returned HTTP \(status)."
        }
    }
}
