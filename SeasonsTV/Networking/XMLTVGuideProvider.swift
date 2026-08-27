import Foundation

enum EPGServiceError: LocalizedError {
    case configuration(MediaAPIConfigurationError)
    case authorizationInvalid
    case serviceNotConfigured
    case refreshThrottled
    case guideNotPublished
    case invalidGuide
    case sportsScheduleNotPublished
    case invalidSportsSchedule
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .configuration(let error):
            return error.localizedDescription
        case .authorizationInvalid:
            return "Schedule access was rejected. This build's MEDIA_READ_TOKEN is missing, stale, or different from the API configuration."
        case .serviceNotConfigured:
            return "Schedule data is not configured on the Personal Media API deployment."
        case .refreshThrottled:
            return "Schedule data was checked recently. Try again in a few minutes."
        case .guideNotPublished:
            return "Guide data has not been published yet. Try again later."
        case .invalidGuide:
            return "The guide service returned XMLTV data that could not be read."
        case .sportsScheduleNotPublished:
            return "Sports schedule data has not been published yet. Try again later."
        case .invalidSportsSchedule:
            return "The sports schedule service returned data that could not be read."
        case .serverStatus(let status):
            return "The schedule service returned status \(status)."
        }
    }
}

actor XMLTVGuideProvider: EPGProviding, SportsScheduleProviding {
    private static let minimumRefreshInterval: TimeInterval = 5 * 60
    private static let etagKey = "epg.xmltv.etag"
    private static let lastRefreshKey = "epg.xmltv.lastRefresh"
    private static let lastAttemptKey = "epg.xmltv.lastAttempt"
    private static let sportsETagKey = "sports.schedule.etag"
    private static let sportsLastRefreshKey = "sports.schedule.lastRefresh"
    private static let sportsLastAttemptKey = "sports.schedule.lastAttempt"

    private let session: URLSession
    private let defaults: UserDefaults
    private let configuration: MediaAPIConfiguration?
    private let configurationError: MediaAPIConfigurationError?
    private let cacheURL: URL
    private let sportsCacheURL: URL
    private var lastRefresh: Date?
    private var lastAttempt: Date?
    private var sportsLastRefresh: Date?
    private var sportsLastAttempt: Date?

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.session = session
        self.defaults = defaults
        do {
            self.configuration = try MediaAPIConfiguration.bundled(bundle)
            self.configurationError = nil
        } catch let error as MediaAPIConfigurationError {
            self.configuration = nil
            self.configurationError = error
        } catch {
            self.configuration = nil
            self.configurationError = .missingReadToken
        }
        self.lastRefresh = defaults.object(forKey: Self.lastRefreshKey) as? Date
        self.lastAttempt = defaults.object(forKey: Self.lastAttemptKey) as? Date
        self.sportsLastRefresh = defaults.object(forKey: Self.sportsLastRefreshKey) as? Date
        self.sportsLastAttempt = defaults.object(forKey: Self.sportsLastAttemptKey) as? Date
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheURL = cacheDirectory.appending(path: "seasonstv-guide.xmltv")
        self.sportsCacheURL = cacheDirectory.appending(path: "seasonstv-sports-schedule.json")
    }

    func loadGuide(
        for channels: [LiveChannel],
        from start: Date,
        to end: Date
    ) async throws -> (window: EPGGuideWindow, mappings: [ChannelStationMapping]) {
        let configuration = try requireConfiguration()
        let mappings = ChannelDirectory.explicitMappings(for: channels)
        let stationIDs = Set(mappings.map(\.stationID))
        let data = try await currentGuideData(configuration: configuration)
        let programs = try XMLTVParser.parse(
            data: data,
            from: start,
            to: end,
            allowedStationIDs: stationIDs
        )
        return (
            EPGGuideWindow(
                start: start,
                end: end,
                programsByStationID: programs,
                fetchedAt: lastRefresh ?? Date()
            ),
            mappings
        )
    }

    func loadSportsSchedule() async throws -> SportsScheduleSnapshot {
        let configuration = try requireConfiguration()
        let data = try await currentSportsScheduleData(configuration: configuration)
        do {
            let snapshot = try SportsScheduleDecoder.decode(data)
            recordSportsRefresh()
            return snapshot
        } catch {
            throw EPGServiceError.invalidSportsSchedule
        }
    }

    private func requireConfiguration() throws -> MediaAPIConfiguration {
        if let configuration { return configuration }
        throw EPGServiceError.configuration(configurationError ?? .missingReadToken)
    }

    private func currentGuideData(configuration: MediaAPIConfiguration) async throws -> Data {
        let cachedData = try? Data(contentsOf: cacheURL)
        if let lastAttempt,
           Date().timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
            guard let cachedData else { throw EPGServiceError.refreshThrottled }
            return cachedData
        }

        var request = MediaAPIRequestBuilder.makeRequest(
            configuration: configuration,
            route: .guideXMLTV
        )
        if let etag = defaults.string(forKey: Self.etagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        recordAttempt()

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EPGServiceError.invalidGuide
            }
            switch httpResponse.statusCode {
            case 200:
                guard !data.isEmpty else { throw EPGServiceError.invalidGuide }
                try data.write(to: cacheURL, options: .atomic)
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    defaults.set(etag, forKey: Self.etagKey)
                }
                recordRefresh()
                return data
            case 304:
                guard let cachedData else { throw EPGServiceError.invalidGuide }
                recordRefresh()
                return cachedData
            case 401:
                throw EPGServiceError.authorizationInvalid
            case 404:
                throw EPGServiceError.guideNotPublished
            case 503:
                throw EPGServiceError.serviceNotConfigured
            default:
                throw EPGServiceError.serverStatus(httpResponse.statusCode)
            }
        } catch {
            if error is EPGServiceError { throw error }
            if let cachedData { return cachedData }
            throw error
        }
    }

    private func currentSportsScheduleData(configuration: MediaAPIConfiguration) async throws -> Data {
        let cachedData = try? Data(contentsOf: sportsCacheURL)
        if let sportsLastAttempt,
           Date().timeIntervalSince(sportsLastAttempt) < Self.minimumRefreshInterval {
            guard let cachedData else { throw EPGServiceError.refreshThrottled }
            return cachedData
        }

        var request = MediaAPIRequestBuilder.makeRequest(
            configuration: configuration,
            route: .sportsSchedule
        )
        if let etag = defaults.string(forKey: Self.sportsETagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        recordSportsAttempt()

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EPGServiceError.invalidSportsSchedule
            }
            switch httpResponse.statusCode {
            case 200:
                guard !data.isEmpty else { throw EPGServiceError.invalidSportsSchedule }
                try data.write(to: sportsCacheURL, options: .atomic)
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    defaults.set(etag, forKey: Self.sportsETagKey)
                }
                return data
            case 304:
                guard let cachedData else { throw EPGServiceError.invalidSportsSchedule }
                return cachedData
            case 401:
                throw EPGServiceError.authorizationInvalid
            case 404:
                throw EPGServiceError.sportsScheduleNotPublished
            case 503:
                throw EPGServiceError.serviceNotConfigured
            default:
                throw EPGServiceError.serverStatus(httpResponse.statusCode)
            }
        } catch {
            if error is EPGServiceError { throw error }
            if let cachedData { return cachedData }
            throw error
        }
    }

    private func recordRefresh() {
        let now = Date()
        lastRefresh = now
        defaults.set(now, forKey: Self.lastRefreshKey)
    }

    private func recordAttempt() {
        let now = Date()
        lastAttempt = now
        defaults.set(now, forKey: Self.lastAttemptKey)
    }

    private func recordSportsRefresh() {
        let now = Date()
        sportsLastRefresh = now
        defaults.set(now, forKey: Self.sportsLastRefreshKey)
    }

    private func recordSportsAttempt() {
        let now = Date()
        sportsLastAttempt = now
        defaults.set(now, forKey: Self.sportsLastAttemptKey)
    }
}

enum SportsScheduleDecoder {
    static func decode(_ data: Data) throws -> SportsScheduleSnapshot {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: value)
                ?? standardFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 timestamp, with optional fractional seconds."
            )
        }
        return try decoder.decode(SportsScheduleSnapshot.self, from: data)
    }
}

enum XMLTVParser {
    static func parse(
        data: Data,
        from start: Date,
        to end: Date,
        allowedStationIDs: Set<String>
    ) throws -> [String: [EPGProgram]] {
        let delegate = XMLTVParserDelegate(
            windowStart: start,
            windowEnd: end,
            allowedStationIDs: allowedStationIDs
        )
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw EPGServiceError.invalidGuide }
        return delegate.programsByStationID.mapValues { programs in
            programs.sorted { $0.start < $1.start }
        }
    }
}

private final class XMLTVParserDelegate: NSObject, XMLParserDelegate {
    private struct ProgrammeDraft {
        let stationID: String
        let start: Date
        let end: Date
        var title = ""
        var synopsis = ""
        var category = ""
        var imageURL: URL?
    }

    let windowStart: Date
    let windowEnd: Date
    let allowedStationIDs: Set<String>
    private(set) var programsByStationID: [String: [EPGProgram]] = [:]
    private var documentStationIDs = Set<String>()
    private var draft: ProgrammeDraft?
    private var activeElement: String?
    private var text = ""

    init(windowStart: Date, windowEnd: Date, allowedStationIDs: Set<String>) {
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.allowedStationIDs = allowedStationIDs
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "channel":
            if let stationID = attributeDict["id"] {
                documentStationIDs.insert(stationID)
            }
        case "programme":
            guard let stationID = attributeDict["channel"],
                  allowedStationIDs.contains(stationID),
                  let rawStart = attributeDict["start"],
                  let rawEnd = attributeDict["stop"],
                  let programmeStart = Self.parseDate(rawStart),
                  let programmeEnd = Self.parseDate(rawEnd),
                  programmeStart < windowEnd,
                  programmeEnd > windowStart else {
                draft = nil
                return
            }
            draft = ProgrammeDraft(stationID: stationID, start: programmeStart, end: programmeEnd)
        case "title", "desc", "category":
            guard draft != nil else { return }
            activeElement = elementName
            text = ""
        case "icon":
            guard draft != nil, let source = attributeDict["src"] else { return }
            draft?.imageURL = URL(string: source)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard activeElement != nil else { return }
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if activeElement == elementName {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "title": draft?.title = value
            case "desc": draft?.synopsis = value
            case "category": draft?.category = value
            default: break
            }
            activeElement = nil
            text = ""
        }

        guard elementName == "programme", let draft, !draft.title.isEmpty else { return }
        let identifier = "\(draft.stationID)|\(Int(draft.start.timeIntervalSince1970))|\(draft.title)"
        let program = EPGProgram(
            id: identifier,
            stationID: draft.stationID,
            title: draft.title,
            start: draft.start,
            end: draft.end,
            synopsis: draft.synopsis.isEmpty ? nil : draft.synopsis,
            category: draft.category.isEmpty ? nil : draft.category,
            imageURL: draft.imageURL
        )
        programsByStationID[draft.stationID, default: []].append(program)
        self.draft = nil
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        programsByStationID = programsByStationID.filter { documentStationIDs.contains($0.key) }
    }

    private static func parseDate(_ value: String) -> Date? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for format in ["yyyyMMddHHmmss Z", "yyyyMMddHHmm Z", "yyyyMMddHHmmssZ", "yyyyMMddHHmmZ"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) { return date }
        }
        return nil
    }
}
