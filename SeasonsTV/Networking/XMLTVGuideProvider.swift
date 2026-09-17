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
    case invalidSportsEventDetail
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
        case .invalidSportsEventDetail:
            return "The sports event detail service returned data that could not be read."
        case .serverStatus(let status):
            return "The schedule service returned status \(status)."
        }
    }
}

actor XMLTVGuideProvider: EPGProviding, SportsScheduleProviding, SportsEventDetailProviding {
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
    private let cacheDirectory: URL
    private let now: @Sendable () -> Date
    private let writeCache: @Sendable (Data, URL) throws -> Void
    private var lastRefresh: Date?
    private var lastAttempt: Date?
    private var sportsLastRefresh: Date?
    private var sportsLastAttempt: Date?
    private var sportsDetailLastAttempts: [String: Date] = [:]
    private var sportsDetailMemoryCache: [String: SportsEventDetail] = [:]

    init(
        session: URLSession = .shared,
        bundle: Bundle = .main
    ) {
        // Resolve the process-wide store inside the actor initializer. Passing
        // UserDefaults as a default argument crosses an isolation boundary and
        // produces a Swift 6 sendability warning even though UserDefaults itself
        // provides synchronized access.
        let defaults = UserDefaults.standard
        self.now = { Date() }
        self.writeCache = { try $0.write(to: $1, options: .atomic) }
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
        self.cacheDirectory = cacheDirectory
        self.cacheURL = cacheDirectory.appending(path: "seasonstv-guide.xmltv")
        self.sportsCacheURL = cacheDirectory.appending(path: "seasonstv-sports-schedule.json")
    }

    // Fully supplied dependencies do not evaluate bundled configuration, standard
    // preferences or the user's cache location. Resolve defaults inside the actor.
    init(
        configuration: MediaAPIConfiguration,
        session: URLSession,
        defaults makeDefaults: () -> UserDefaults,
        cacheDirectory: URL,
        now: @escaping @Sendable () -> Date,
        writeCache: @escaping @Sendable (Data, URL) throws -> Void = {
            try $0.write(to: $1, options: .atomic)
        }
    ) {
        let defaults = makeDefaults()
        self.session = session
        self.defaults = defaults
        self.configuration = configuration
        self.configurationError = nil
        self.cacheDirectory = cacheDirectory
        self.cacheURL = cacheDirectory.appending(path: "seasonstv-guide.xmltv")
        self.sportsCacheURL = cacheDirectory.appending(path: "seasonstv-sports-schedule.json")
        self.now = now
        self.writeCache = writeCache
        self.lastRefresh = defaults.object(forKey: Self.lastRefreshKey) as? Date
        self.lastAttempt = defaults.object(forKey: Self.lastAttemptKey) as? Date
        self.sportsLastRefresh = defaults.object(forKey: Self.sportsLastRefreshKey) as? Date
        self.sportsLastAttempt = defaults.object(forKey: Self.sportsLastAttemptKey) as? Date
    }

    func loadGuide(
        for channels: [LiveChannel],
        from start: Date,
        to end: Date
    ) async throws -> (window: EPGGuideWindow, mappings: [ChannelStationMapping]) {
        let configuration = try requireConfiguration()
        let mappings = ChannelDirectory.explicitMappings(for: channels)
        let stationIDs = Set(mappings.map(\.stationID))
        let programs = try await currentGuidePrograms(
            configuration: configuration, from: start, to: end, stationIDs: stationIDs
        )
        return (
            EPGGuideWindow(
                start: start,
                end: end,
                programsByStationID: programs,
                fetchedAt: lastRefresh ?? .distantPast
            ),
            mappings
        )
    }

    func loadSportsSchedule() async throws -> SportsScheduleSnapshot {
        let configuration = try requireConfiguration()
        return try await currentSportsSchedule(configuration: configuration)
    }

    func loadSportsEventDetail(
        identity: SportsEventDetailIdentity
    ) async throws -> SportsEventDetail? {
        let configuration = try requireConfiguration()
        let cacheURL = sportsDetailCacheURL(identity: identity)
        let cachedData = try? Data(contentsOf: cacheURL)
        if let lastAttempt = sportsDetailLastAttempts[identity.cacheKey],
           Date().timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
            if let detail = sportsDetailMemoryCache[identity.cacheKey] { return detail }
            return try cachedData.map { try SportsEventDetailDecoder.decode($0, identity: identity) }
        }

        var request = MediaAPIRequestBuilder.makeRequest(
            configuration: configuration,
            route: .sportsEventDetail(identity)
        )
        let etagKey = sportsDetailETagKey(identity: identity)
        if let etag = defaults.string(forKey: etagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        sportsDetailLastAttempts[identity.cacheKey] = Date()

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EPGServiceError.invalidSportsEventDetail
            }
            switch httpResponse.statusCode {
            case 200:
                guard !data.isEmpty else { throw EPGServiceError.invalidSportsEventDetail }
                let detail = try SportsEventDetailDecoder.decode(data, identity: identity)
                try data.write(to: cacheURL, options: .atomic)
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    defaults.set(etag, forKey: etagKey)
                }
                sportsDetailMemoryCache[identity.cacheKey] = detail
                return detail
            case 304:
                guard let cachedData else { throw EPGServiceError.invalidSportsEventDetail }
                let detail = try SportsEventDetailDecoder.decode(cachedData, identity: identity)
                sportsDetailMemoryCache[identity.cacheKey] = detail
                return detail
            case 401:
                throw EPGServiceError.authorizationInvalid
            case 404:
                guard let cachedData else { return nil }
                let detail = try SportsEventDetailDecoder.decode(cachedData, identity: identity)
                sportsDetailMemoryCache[identity.cacheKey] = detail
                return detail
            case 503:
                throw EPGServiceError.serviceNotConfigured
            default:
                throw EPGServiceError.serverStatus(httpResponse.statusCode)
            }
        } catch {
            if error is EPGServiceError { throw error }
            guard let cachedData else { throw error }
            let detail = try SportsEventDetailDecoder.decode(cachedData, identity: identity)
            sportsDetailMemoryCache[identity.cacheKey] = detail
            return detail
        }
    }

    private func requireConfiguration() throws -> MediaAPIConfiguration {
        if let configuration { return configuration }
        throw EPGServiceError.configuration(configurationError ?? .missingReadToken)
    }

    private func currentGuidePrograms(
        configuration: MediaAPIConfiguration, from start: Date, to end: Date,
        stationIDs: Set<String>
    ) async throws -> [String: [EPGProgram]] {
        func validate(_ data: Data) throws -> [String: [EPGProgram]] {
            try XMLTVParser.parse(data: data, from: start, to: end, allowedStationIDs: stationIDs)
        }
        // Read and validate before using cached bytes or sending their validator.
        let cached = (try? Data(contentsOf: cacheURL)).flatMap { try? validate($0) }
        if let lastAttempt,
           now().timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
            guard let cached else { throw EPGServiceError.refreshThrottled }
            return cached
        }

        var request = MediaAPIRequestBuilder.makeRequest(
            configuration: configuration,
            route: .guideXMLTV
        )
        if cached != nil, let etag = defaults.string(forKey: Self.etagKey), !etag.isEmpty {
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
                let accepted = try validate(data)
                try writeCache(data, cacheURL)
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag"),
                   !etag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    defaults.set(etag, forKey: Self.etagKey)
                } else {
                    defaults.removeObject(forKey: Self.etagKey)
                }
                recordRefresh()
                return accepted
            case 304:
                guard let cached else { throw EPGServiceError.invalidGuide }
                recordRefresh()
                return cached
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
            if let cached { return cached }
            throw error
        }
    }

    private func currentSportsSchedule(configuration: MediaAPIConfiguration) async throws -> SportsScheduleSnapshot {
        func validate(_ data: Data) throws -> SportsScheduleSnapshot {
            do { return try SportsScheduleDecoder.decode(data) }
            catch { throw EPGServiceError.invalidSportsSchedule }
        }
        // Read and validate before using cached bytes or sending their validator.
        let cached = (try? Data(contentsOf: sportsCacheURL)).flatMap { try? validate($0) }
        if let sportsLastAttempt,
           now().timeIntervalSince(sportsLastAttempt) < Self.minimumRefreshInterval {
            guard let cached else { throw EPGServiceError.refreshThrottled }
            return cached
        }

        var request = MediaAPIRequestBuilder.makeRequest(
            configuration: configuration,
            route: .sportsSchedule
        )
        if cached != nil, let etag = defaults.string(forKey: Self.sportsETagKey), !etag.isEmpty {
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
                let accepted = try validate(data)
                try writeCache(data, sportsCacheURL)
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag"),
                   !etag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    defaults.set(etag, forKey: Self.sportsETagKey)
                } else {
                    defaults.removeObject(forKey: Self.sportsETagKey)
                }
                recordSportsRefresh()
                return accepted
            case 304:
                guard let cached else { throw EPGServiceError.invalidSportsSchedule }
                recordSportsRefresh()
                return cached
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
            if let cached { return cached }
            throw error
        }
    }

    private func recordRefresh() {
        let now = now()
        lastRefresh = now
        defaults.set(now, forKey: Self.lastRefreshKey)
    }

    private func recordAttempt() {
        let now = now()
        lastAttempt = now
        defaults.set(now, forKey: Self.lastAttemptKey)
    }

    private func recordSportsRefresh() {
        let now = now()
        sportsLastRefresh = now
        defaults.set(now, forKey: Self.sportsLastRefreshKey)
    }

    private func recordSportsAttempt() {
        let now = now()
        sportsLastAttempt = now
        defaults.set(now, forKey: Self.sportsLastAttemptKey)
    }

    private func sportsDetailCacheURL(identity: SportsEventDetailIdentity) -> URL {
        cacheDirectory.appending(
            path: "seasonstv-sports-detail-\(identity.sport)-\(identity.league)-\(identity.eventID).json"
        )
    }

    private func sportsDetailETagKey(identity: SportsEventDetailIdentity) -> String {
        "sports.detail.\(identity.sport).\(identity.league).\(identity.eventID).etag"
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

enum SportsEventDetailDecoder {
    static func decode(
        _ data: Data,
        identity: SportsEventDetailIdentity
    ) throws -> SportsEventDetail {
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
        let detail = try decoder.decode(SportsEventDetail.self, from: data)
        guard detail.provider == "ESPN",
              detail.eventID == identity.eventID,
              detail.sport == identity.sport,
              detail.league == identity.league else {
            throw EPGServiceError.invalidSportsEventDetail
        }
        return detail
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
        guard parser.parse(), delegate.hasTVRoot else { throw EPGServiceError.invalidGuide }
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
    private(set) var hasTVRoot = false
    private var sawRoot = false
    private enum ParsedTimestamp {
        case valid(Date)
        case invalid
    }
    // These values and formatters belong to one document, never shared requests.
    private var timestamps: [String: ParsedTimestamp] = [:]
    private lazy var dateFormatters: [DateFormatter] = {
        ["yyyyMMddHHmmss Z", "yyyyMMddHHmm Z", "yyyyMMddHHmmssZ", "yyyyMMddHHmmZ"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            return formatter
        }
    }()
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
        if !sawRoot {
            sawRoot = true
            hasTVRoot = elementName == "tv"
            if !hasTVRoot { parser.abortParsing(); return }
        }
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
                  let programmeStart = parseDate(rawStart),
                  let programmeEnd = parseDate(rawEnd),
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

    private func parseDate(_ value: String) -> Date? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = timestamps[normalized] {
            switch cached {
            case .valid(let date): return date
            case .invalid: return nil
            }
        }
        for formatter in dateFormatters {
            if let date = formatter.date(from: normalized) {
                timestamps[normalized] = .valid(date)
                return date
            }
        }
        timestamps[normalized] = .invalid
        return nil
    }
}
