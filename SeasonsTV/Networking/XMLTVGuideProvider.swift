import Foundation
import Security

enum EPGServiceError: LocalizedError {
    case notPaired
    case invalidPairingCode
    case pairingRejected
    case authorizationExpired
    case guideNotPublished
    case invalidGuide
    case sportsScheduleNotPublished
    case invalidSportsSchedule
    case credentialStorage(Int32)
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notPaired:
            return "Connect guide data to see current and upcoming programs."
        case .invalidPairingCode:
            return "Enter the six-digit code from the Personal Media API dashboard."
        case .pairingRejected:
            return "That pairing code is invalid or has expired. Generate a new code and try again."
        case .authorizationExpired:
            return "The guide connection was revoked. Connect this Apple TV again."
        case .guideNotPublished:
            return "Guide data has not been published yet. Try again later."
        case .invalidGuide:
            return "The guide service returned XMLTV data that could not be read."
        case .sportsScheduleNotPublished:
            return "Sports schedule data has not been published yet. Try again later."
        case .invalidSportsSchedule:
            return "The sports schedule service returned data that could not be read."
        case .credentialStorage(let status):
            return "This build could not save the guide credential in Keychain (status \(status)). Reinstall a signed build and pair again."
        case .serverStatus(let status):
            return "The guide service returned status \(status)."
        }
    }
}

final class EPGDeviceTokenStore: @unchecked Sendable {
    private let service = "com.seasonstv.personal-media-api.device-token"
    private let account = "paired-device"
    private let lock = NSLock()
    private var memoryToken: String?

    func read() -> String? {
        lock.lock()
        let cachedToken = memoryToken
        lock.unlock()
        if let cachedToken { return cachedToken }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        lock.lock()
        memoryToken = token
        lock.unlock()
        return token
    }

    func save(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw EPGServiceError.credentialStorage(errSecParam)
        }
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertion = identity
            attributes.forEach { insertion[$0.key] = $0.value }
            let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard insertionStatus == errSecSuccess else {
                throw EPGServiceError.credentialStorage(insertionStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw EPGServiceError.credentialStorage(updateStatus)
        }
        lock.lock()
        memoryToken = token
        lock.unlock()
    }

    func delete() {
        lock.lock()
        memoryToken = nil
        lock.unlock()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

actor XMLTVGuideProvider: EPGProviding, EPGPairingProviding, SportsScheduleProviding {
    private struct PairingRequest: Encodable {
        let code: String
        let deviceName: String
    }

    private struct PairingResponse: Decodable {
        let token: String
        let deviceName: String
    }

    private static let serviceBaseURL = URL(string: "https://personal-media-api.vercel.app")!
    private static let minimumRefreshInterval: TimeInterval = 5 * 60
    private static let etagKey = "epg.xmltv.etag"
    private static let lastRefreshKey = "epg.xmltv.lastRefresh"
    private static let lastAttemptKey = "epg.xmltv.lastAttempt"
    private static let sportsETagKey = "sports.schedule.etag"
    private static let sportsLastRefreshKey = "sports.schedule.lastRefresh"
    private static let sportsLastAttemptKey = "sports.schedule.lastAttempt"

    nonisolated var isPaired: Bool { tokenStore.read() != nil }

    private nonisolated let tokenStore: EPGDeviceTokenStore
    private let session: URLSession
    private let defaults: UserDefaults
    private let cacheURL: URL
    private let sportsCacheURL: URL
    private var lastRefresh: Date?
    private var lastAttempt: Date?
    private var sportsLastRefresh: Date?
    private var sportsLastAttempt: Date?

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        tokenStore: EPGDeviceTokenStore = EPGDeviceTokenStore()
    ) {
        self.session = session
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.lastRefresh = defaults.object(forKey: Self.lastRefreshKey) as? Date
        self.lastAttempt = defaults.object(forKey: Self.lastAttemptKey) as? Date
        self.sportsLastRefresh = defaults.object(forKey: Self.sportsLastRefreshKey) as? Date
        self.sportsLastAttempt = defaults.object(forKey: Self.sportsLastAttemptKey) as? Date
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.cacheURL = cacheDirectory.appending(path: "seasonstv-guide.xmltv")
        self.sportsCacheURL = cacheDirectory.appending(path: "seasonstv-sports-schedule.json")
    }

    func pair(code: String, deviceName: String) async throws {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.range(of: #"^\d{6}$"#, options: .regularExpression) != nil else {
            throw EPGServiceError.invalidPairingCode
        }

        let url = Self.serviceBaseURL.appending(path: "/api/v1/pairing/exchange")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            PairingRequest(code: normalizedCode, deviceName: deviceName)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EPGServiceError.pairingRejected
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if [400, 401, 404, 409, 410].contains(httpResponse.statusCode) {
                throw EPGServiceError.pairingRejected
            }
            throw EPGServiceError.serverStatus(httpResponse.statusCode)
        }
        guard let result = try? JSONDecoder().decode(PairingResponse.self, from: data),
              !result.token.isEmpty else {
            throw EPGServiceError.pairingRejected
        }
        try tokenStore.save(result.token)
        lastRefresh = nil
        lastAttempt = nil
        sportsLastRefresh = nil
        sportsLastAttempt = nil
    }

    nonisolated func disconnect() {
        tokenStore.delete()
    }

    func loadGuide(
        for channels: [LiveChannel],
        from start: Date,
        to end: Date
    ) async throws -> (window: EPGGuideWindow, mappings: [ChannelStationMapping]) {
        guard let token = tokenStore.read() else { throw EPGServiceError.notPaired }
        let mappings = ChannelDirectory.explicitMappings(for: channels)
        let stationIDs = Set(mappings.map(\.stationID))
        let data = try await currentGuideData(token: token)
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
        guard let token = tokenStore.read() else { throw EPGServiceError.notPaired }
        let data = try await currentSportsScheduleData(token: token)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(SportsScheduleSnapshot.self, from: data)
        } catch {
            throw EPGServiceError.invalidSportsSchedule
        }
    }

    private func currentGuideData(token: String) async throws -> Data {
        let cachedData = try? Data(contentsOf: cacheURL)
        if let lastAttempt,
           Date().timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
            guard let cachedData else { throw EPGServiceError.invalidGuide }
            return cachedData
        }

        let url = Self.serviceBaseURL.appending(path: "/api/v1/guide/xmltv")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        if let etag = defaults.string(forKey: Self.etagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        recordAttempt()

        do {
            for attempt in 0..<2 {
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
                if attempt == 0 {
                    try await Task.sleep(for: .milliseconds(750))
                    continue
                }
                throw EPGServiceError.authorizationExpired
            case 404:
                throw EPGServiceError.guideNotPublished
            default:
                throw EPGServiceError.serverStatus(httpResponse.statusCode)
            }
            }
            throw EPGServiceError.authorizationExpired
        } catch {
            if error is EPGServiceError { throw error }
            if let cachedData { return cachedData }
            throw error
        }
    }

    private func currentSportsScheduleData(token: String) async throws -> Data {
        let cachedData = try? Data(contentsOf: sportsCacheURL)
        if let sportsLastAttempt,
           Date().timeIntervalSince(sportsLastAttempt) < Self.minimumRefreshInterval {
            guard let cachedData else { throw EPGServiceError.invalidSportsSchedule }
            return cachedData
        }

        let url = Self.serviceBaseURL.appending(path: "/api/v1/sports/schedule")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag = defaults.string(forKey: Self.sportsETagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        recordSportsAttempt()

        do {
            for attempt in 0..<2 {
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
                    recordSportsRefresh()
                    return data
                case 304:
                    guard let cachedData else { throw EPGServiceError.invalidSportsSchedule }
                    recordSportsRefresh()
                    return cachedData
                case 401:
                    if attempt == 0 {
                        try await Task.sleep(for: .milliseconds(750))
                        continue
                    }
                    throw EPGServiceError.authorizationExpired
                case 404:
                    throw EPGServiceError.sportsScheduleNotPublished
                default:
                    throw EPGServiceError.serverStatus(httpResponse.statusCode)
                }
            }
            throw EPGServiceError.authorizationExpired
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
