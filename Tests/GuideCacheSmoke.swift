import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_789_603_200)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance() { lock.lock(); defer { lock.unlock() }; value.addTimeInterval(300) }
}

private enum Reply {
    case http(Int, Data, String?)
    case transport
}

private final class Wire: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [Reply] = []
    private var captured: [URLRequest] = []
    private var unexpected = false
    func reset() { lock.lock(); defer { lock.unlock() }; replies = []; captured = []; unexpected = false }
    func enqueue(_ reply: Reply) { lock.lock(); defer { lock.unlock() }; replies.append(reply) }
    func take(_ request: URLRequest) -> Reply {
        lock.lock(); defer { lock.unlock() }
        captured.append(request)
        guard request.url?.host == "guide-cache.invalid", !replies.isEmpty else {
            unexpected = true
            return .transport
        }
        return replies.removeFirst()
    }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return captured }
    func verifyDrained() {
        lock.lock(); defer { lock.unlock() }
        check(!unexpected && replies.isEmpty, "Unexpected request or unused stub response")
    }
}

// Intercept every scheme/host, including mistakes: nothing falls through to a socket.
private final class StubProtocol: URLProtocol {
    static let wire = Wire()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        switch Self.wire.take(request) {
        case .transport:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case .http(let status, let body, let etag):
            let headers = etag.map { ["ETag": $0] }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

private enum Kind: CaseIterable {
    case guide, sports
    var prefix: String { self == .guide ? "epg.xmltv" : "sports.schedule" }
    var filename: String { self == .guide ? "seasonstv-guide.xmltv" : "seasonstv-sports-schedule.json" }
    var route: String { self == .guide ? "/api/v1/guide/xmltv" : "/api/v1/sports/schedule" }
    var accept: String { self == .guide ? "application/xml" : "application/json" }
    func body(_ title: String, empty: Bool = false, unmatched: Bool = false) -> Data {
        if self == .guide {
            if empty { return Data("<tv/>".utf8) }
            let station = unmatched ? "99999" : "20453"
            return Data("<tv><channel id=\"\(station)\"/><programme channel=\"\(station)\" start=\"20260917000000 +0000\" stop=\"20260917010000 +0000\"><title>\(title)</title></programme></tv>".utf8)
        }
        let events = empty ? "" : "{\"eventId\":\"1\",\"title\":\"\(title)\",\"startsAt\":\"2026-09-17T00:00:00Z\",\"broadcasts\":[]}"
        return Data("{\"provider\":\"ESPN\",\"generatedAt\":\"2026-09-16T12:00:00.123Z\",\"windowStart\":\"2026-09-16\",\"windowEnd\":\"2026-09-18\",\"events\":[\(events)]}".utf8)
    }
    var invalidBodies: [Data] {
        if self == .guide {
            return [Data(), Data("<tv>".utf8), Data("<html><tv/></html>".utf8)]
        }
        return [Data(), Data("{".utf8), Data("{\"events\":[]}".utf8),
                Data(String(decoding: body("bad"), as: UTF8.self).replacingOccurrences(of: "2026-09-16T12:00:00.123Z", with: "not-a-date").utf8),
                Data(String(decoding: body("bad"), as: UTF8.self).replacingOccurrences(of: "2026-09-17T00:00:00Z", with: "not-a-date").utf8)]
    }
}

private struct Loaded {
    let titles: [String]
    let fetchedAt: Date?
    let generatedAt: Date?
}

private final class Harness {
    let kind: Kind
    let clock = TestClock()
    let directory: URL
    let suite = "com.jrcoak.joetv.tests.guide-cache.\(UUID().uuidString)"
    let defaults: UserDefaults
    let session: URLSession
    let wire = StubProtocol.wire
    var cache: URL { directory.appending(path: kind.filename) }
    var old: Data { kind.body("Old") }
    var new: Data { kind.body("New") }
    var prior: Date { Date(timeIntervalSince1970: 1_789_602_600) }
    init(_ kind: Kind) throws {
        self.kind = kind
        directory = FileManager.default.temporaryDirectory.appending(path: "joe-tv-guide-cache-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        wire.reset()
    }
    func close() {
        wire.verifyDrained()
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suite)
        try! FileManager.default.removeItem(at: directory)
    }
    func provider(failWrite: Bool = false) -> XMLTVGuideProvider {
        let suite = suite
        let clock = clock
        return XMLTVGuideProvider(
            configuration: MediaAPIConfiguration(baseURL: URL(string: "https://guide-cache.invalid")!, readToken: String(repeating: "synthetic-test-token-", count: 2)),
            session: session, defaults: { UserDefaults(suiteName: suite)! }, cacheDirectory: directory,
            now: { clock.now() }, writeCache: { data, url in
                if failWrite { throw CocoaError(.fileWriteNoPermission) }
                try data.write(to: url, options: .atomic)
            }
        )
    }
    func seed(body: Data? = nil, success: Date? = nil, attempt: Date? = nil) throws {
        if let body { try body.write(to: cache, options: .atomic) }
        defaults.set("old-tag", forKey: kind.prefix + ".etag")
        if let success { defaults.set(success, forKey: kind.prefix + ".lastRefresh") }
        if let attempt { defaults.set(attempt, forKey: kind.prefix + ".lastAttempt") }
    }
    func load(_ provider: XMLTVGuideProvider) async throws -> Loaded {
        switch kind {
        case .guide:
            let channel = LiveChannel(id: "f94a1f7b-9cc9-4d60-abcb-1b83e4e0d163", name: "ABC - New York", logoURL: nil, playback: .drmPage(URL(string: "https://unused.invalid")!), genre: .news)
            let result = try await provider.loadGuide(for: [channel], from: Date(timeIntervalSince1970: 1_789_603_200), to: Date(timeIntervalSince1970: 1_789_689_600))
            check(result.mappings.map(\.stationID) == ["20453"], "Guide mapping changed")
            return Loaded(titles: result.window.programsByStationID.values.flatMap { $0.map(\.title) }, fetchedAt: result.window.fetchedAt, generatedAt: nil)
        case .sports:
            let result = try await provider.loadSportsSchedule()
            check(result.provider == "ESPN" && result.windowStart == "2026-09-16" && result.windowEnd == "2026-09-18", "Sports envelope changed")
            return Loaded(titles: result.events.map(\.title), fetchedAt: nil, generatedAt: result.generatedAt)
        }
    }
    func expect(_ provider: XMLTVGuideProvider, titles: [String], success: Date?) async throws {
        let result = try await load(provider)
        check(result.titles == titles, "\(kind): wrong decoded content \(result.titles)")
        if kind == .guide { check(result.fetchedAt == (success ?? .distantPast), "Fabricated or stale guide freshness") }
        else { check(result.generatedAt == ISO8601DateFormatter.fractional.date(from: "2026-09-16T12:00:00.123Z"), "Publisher generatedAt changed") }
    }
    func error(_ provider: XMLTVGuideProvider, _ expected: String) async {
        do { _ = try await load(provider); fatalError("Expected \(expected)") }
        catch {
            let actual: String
            switch error {
            case EPGServiceError.invalidGuide: actual = "guide-invalid"
            case EPGServiceError.invalidSportsSchedule: actual = "sports-invalid"
            case EPGServiceError.refreshThrottled: actual = "throttled"
            case EPGServiceError.authorizationInvalid: actual = "401"
            case EPGServiceError.guideNotPublished: actual = "404"
            case EPGServiceError.sportsScheduleNotPublished: actual = "404"
            case EPGServiceError.serviceNotConfigured: actual = "503"
            case EPGServiceError.serverStatus(let status): actual = String(status)
            case is URLError: actual = "transport"
            case is CocoaError: actual = "write"
            default: fatalError("Unexpected error type: \(error)")
            }
            check(actual == expected, "Expected \(expected), got \(actual)")
        }
    }
    var invalid: String { kind == .guide ? "guide-invalid" : "sports-invalid" }
    func state(body: Data?, etag: String?, success: Date?, attempt: Date?, requests: Int) {
        check((try? Data(contentsOf: cache)) == body, "\(kind): cache bytes changed")
        check(defaults.string(forKey: kind.prefix + ".etag") == etag, "\(kind): ETag changed")
        check(defaults.object(forKey: kind.prefix + ".lastRefresh") as? Date == success, "\(kind): success changed")
        check(defaults.object(forKey: kind.prefix + ".lastAttempt") as? Date == attempt, "\(kind): attempt changed")
        check(wire.requests.count == requests, "\(kind): unexpected request count")
    }
    func headers(_ validators: [String?]) {
        check(wire.requests.count == validators.count, "Request count differs from expected headers")
        for (request, validator) in zip(wire.requests, validators) {
            check(request.url?.host == "guide-cache.invalid" && request.url?.path == kind.route, "Wrong route")
            check(request.httpMethod == "GET" && request.value(forHTTPHeaderField: "Accept") == kind.accept, "Wrong method/Accept")
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + String(repeating: "synthetic-test-token-", count: 2), "Wrong synthetic authorization")
            check(request.value(forHTTPHeaderField: "If-None-Match") == validator, "Wrong conditional validator")
        }
    }
}

private extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

@main
enum GuideCacheSmoke {
    static func main() async throws {
        for kind in Kind.allCases { try await run(kind) }
        print("Guide cache lifecycle smoke passed: both publications, exact bytes/metadata/headers, isolated recreation and failures")
    }
    private static func run(_ kind: Kind) async throws {
        // Replacement, persisted revalidation, untagged replacement, and no stale validator.
        do {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, success: h.prior)
            var p = h.provider()
            h.wire.enqueue(.http(200, h.new, "new-tag"))
            try await h.expect(p, titles: ["New"], success: h.clock.now())
            h.state(body: h.new, etag: "new-tag", success: h.clock.now(), attempt: h.clock.now(), requests: 1)
            h.clock.advance(); p = h.provider()
            h.wire.enqueue(.http(304, Data(), nil))
            try await h.expect(p, titles: ["New"], success: h.clock.now())
            h.state(body: h.new, etag: "new-tag", success: h.clock.now(), attempt: h.clock.now(), requests: 2)
            h.clock.advance()
            h.wire.enqueue(.http(200, h.old, nil))
            try await h.expect(p, titles: ["Old"], success: h.clock.now())
            h.state(body: h.old, etag: nil, success: h.clock.now(), attempt: h.clock.now(), requests: 3)
            h.clock.advance(); p = h.provider()
            h.wire.enqueue(.http(200, h.new, ""))
            try await h.expect(p, titles: ["New"], success: h.clock.now())
            h.state(body: h.new, etag: nil, success: h.clock.now(), attempt: h.clock.now(), requests: 4)
            h.headers(["old-tag", "new-tag", "new-tag", nil])
        }
        // Empty publications and zero matching stations remain real accepted bodies.
        for body in [kind.body("", empty: true)] + (kind == .guide ? [kind.body("Unmatched", unmatched: true)] : []) {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, success: h.prior)
            h.wire.enqueue(.http(200, body, "empty-tag"))
            try await h.expect(h.provider(), titles: [], success: h.clock.now())
            try await h.expect(h.provider(), titles: [], success: h.clock.now())
            h.state(body: body, etag: "empty-tag", success: h.clock.now(), attempt: h.clock.now(), requests: 1)
            h.headers(["old-tag"])
        }
        // Invalid 200 must throw, preserve good bytes, and survive recreation/throttle.
        for bad in kind.invalidBodies {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, success: h.prior)
            let p = h.provider()
            h.wire.enqueue(.http(200, bad, "bad-tag"))
            await h.error(p, h.invalid)
            h.state(body: h.old, etag: "old-tag", success: h.prior, attempt: h.clock.now(), requests: 1)
            try await h.expect(p, titles: ["Old"], success: h.prior)
            try await h.expect(h.provider(), titles: ["Old"], success: h.prior)
            h.state(body: h.old, etag: "old-tag", success: h.prior, attempt: h.clock.now(), requests: 1)
            h.headers(["old-tag"])
        }
        // Missing/corrupt bodies: invalid 200 and unexpected 304 cannot bless an old tag.
        for cached: Data? in [nil, Data("corrupt".utf8)] {
            for status in [200, 304] {
                let h = try Harness(kind); defer { h.close() }
                try h.seed(body: cached)
                let p = h.provider()
                h.wire.enqueue(.http(status, Data(), "bad-tag"))
                await h.error(p, h.invalid)
                await h.error(h.provider(), "throttled")
                h.state(body: cached, etag: "old-tag", success: nil, attempt: h.clock.now(), requests: 1)
                h.clock.advance()
                h.wire.enqueue(.http(200, h.new, "recovered-tag"))
                try await h.expect(p, titles: ["New"], success: h.clock.now())
                h.state(body: h.new, etag: "recovered-tag", success: h.clock.now(), attempt: h.clock.now(), requests: 2)
                h.headers([nil, nil])
            }
            // Direct repair and transport failure without usable bytes.
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: cached)
            h.wire.enqueue(.transport)
            await h.error(h.provider(), "transport")
            h.state(body: cached, etag: "old-tag", success: nil, attempt: h.clock.now(), requests: 1)
            h.clock.advance()
            h.wire.enqueue(.http(200, h.new, "repair"))
            try await h.expect(h.provider(), titles: ["New"], success: h.clock.now())
            h.state(body: h.new, etag: "repair", success: h.clock.now(), attempt: h.clock.now(), requests: 2)
            h.headers([nil, nil])
        }
        // Throttle does not itself write success/attempt, including restored bad bytes.
        for cached: Data? in [kind.body("Old"), nil, Data("corrupt".utf8)] {
            let h = try Harness(kind); defer { h.close() }
            let attempted = h.clock.now()
            try h.seed(body: cached, success: h.prior, attempt: attempted)
            let p = h.provider()
            if cached == h.old { try await h.expect(p, titles: ["Old"], success: h.prior) }
            else { await h.error(p, "throttled") }
            h.state(body: cached, etag: "old-tag", success: h.prior, attempt: attempted, requests: 0)
            h.headers([])
        }
        // Offline/write fallback preserves bytes, success and publisher time after restart.
        for writeFailure in [false, true] {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, success: h.prior)
            h.wire.enqueue(writeFailure ? .http(200, h.new, "unwritten") : .transport)
            try await h.expect(h.provider(failWrite: writeFailure), titles: ["Old"], success: h.prior)
            try await h.expect(h.provider(), titles: ["Old"], success: h.prior)
            h.state(body: h.old, etag: "old-tag", success: h.prior, attempt: h.clock.now(), requests: 1)
            h.headers(["old-tag"])
        }
        do {
            let h = try Harness(kind); defer { h.close() }
            h.wire.enqueue(.http(200, h.new, "unwritten"))
            await h.error(h.provider(failWrite: true), "write")
            h.state(body: nil, etag: nil, success: nil, attempt: h.clock.now(), requests: 1)
            h.headers([nil])
        }
        for status in [401, 404, 503, 500] {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, success: h.prior)
            h.wire.enqueue(.http(status, h.new, "rejected"))
            await h.error(h.provider(), String(status))
            h.state(body: h.old, etag: "old-tag", success: h.prior, attempt: h.clock.now(), requests: 1)
            h.headers(["old-tag"])
        }
        // Legacy success is unknown until an accepted 304 or 200, never 'now' on reads.
        for status in [200, 304] {
            let h = try Harness(kind); defer { h.close() }
            try h.seed(body: h.old, attempt: h.clock.now())
            try await h.expect(h.provider(), titles: ["Old"], success: nil)
            h.state(body: h.old, etag: "old-tag", success: nil, attempt: h.clock.now(), requests: 0)
            h.clock.advance()
            h.wire.enqueue(.transport)
            try await h.expect(h.provider(), titles: ["Old"], success: nil)
            h.state(body: h.old, etag: "old-tag", success: nil, attempt: h.clock.now(), requests: 1)
            h.clock.advance()
            h.wire.enqueue(.http(status, h.old, "old-tag"))
            try await h.expect(h.provider(), titles: ["Old"], success: h.clock.now())
            h.state(body: h.old, etag: "old-tag", success: h.clock.now(), attempt: h.clock.now(), requests: 2)
            h.headers(["old-tag", "old-tag"])
        }
        print("\(kind): lifecycle matrix passed")
    }
}
