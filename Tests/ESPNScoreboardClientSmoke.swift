import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private enum Reply {
    case http(Int, Data)
}

private final class ScoreboardWire: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [Reply] = []
    private var captured: [URLRequest] = []
    private var unexpected = false

    func reset() {
        lock.lock(); defer { lock.unlock() }
        replies = []; captured = []; unexpected = false
    }
    func enqueue(_ reply: Reply) {
        lock.lock(); defer { lock.unlock() }
        replies.append(reply)
    }
    func take(_ request: URLRequest) -> Reply {
        lock.lock(); defer { lock.unlock() }
        captured.append(request)
        guard request.url?.host == "site.api.espn.com",
              request.url?.path == "/apis/site/v2/sports/football/nfl/scoreboard",
              !replies.isEmpty else {
            unexpected = true
            return .http(500, Data())
        }
        return replies.removeFirst()
    }
    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return captured
    }
    func verifyDrained() {
        lock.lock(); defer { lock.unlock() }
        check(!unexpected && replies.isEmpty, "Unexpected request or unused scoreboard response")
    }
}

private final class ScoreboardProtocol: URLProtocol {
    static let wire = ScoreboardWire()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let reply = Self.wire.take(request)
        switch reply {
        case .http(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@main enum ESPNScoreboardClientSmoke {
    private static let empty = Data(#"{"events":[]}"#.utf8)
    private static let game = Data(#"""
    {
      "events": [{
        "id": "401872948",
        "name": "Atlanta Falcons at Green Bay Packers",
        "date": "2026-09-25T00:15Z",
        "status": {"type": {"state": "in", "completed": false, "shortDetail": "2nd · 1:00"}},
        "competitions": [{
          "date": "2026-09-25T00:15Z",
          "broadcasts": [{"names": ["Prime Video"]}],
          "competitors": [
            {"homeAway": "home", "score": "10", "team": {"id": "9", "displayName": "Green Bay Packers"}},
            {"homeAway": "away", "score": "7", "team": {"id": "1", "displayName": "Atlanta Falcons"}}
          ]
        }]
      }]
    }
    """#.utf8)

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScoreboardProtocol.self]
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    static func requestIsCurrentWeek(_ request: URLRequest) -> Bool {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return query.count == 1 && query[0].name == "limit" && query[0].value == "100"
            && request.value(forHTTPHeaderField: "Accept") == "application/json"
    }

    static func iso(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func main() async {
        await requestFailureEmptyThrottleRecovery()
        await easternWindowAndMidnightCacheBoundary()
        print("ESPN scoreboard client smoke passed")
    }

    static func requestFailureEmptyThrottleRecovery() async {
        let wire = ScoreboardProtocol.wire
        wire.reset()
        let session = session()
        defer { session.invalidateAndCancel() }
        let client = ESPNScoreboardClient(session: session)
        let kickoff = iso("2026-09-25T00:15:00Z")

        wire.enqueue(.http(400, Data(#"{"code":400,"message":"Failed to get events endpoint."}"#.utf8)))
        do {
            _ = try await client.loadNFLScoreboard(referenceDate: kickoff)
            fatalError("HTTP 400 scoreboard response was accepted")
        } catch ESPNScoreboardError.httpStatus(let status) {
            check(status == 400, "Wrong scoreboard HTTP error")
        } catch { fatalError("Wrong scoreboard failure: \(error)") }

        wire.enqueue(.http(200, empty))
        let emptyResult = try! await client.loadNFLScoreboard(referenceDate: kickoff.addingTimeInterval(1))
        check(emptyResult.isEmpty && wire.requests.count == 2,
              "A failed request poisoned retry or a healthy empty scoreboard")

        let throttled = try! await client.loadNFLScoreboard(referenceDate: kickoff.addingTimeInterval(10))
        check(throttled.isEmpty && wire.requests.count == 2,
              "Healthy empty scoreboard did not honor the 20-second cache throttle")

        wire.enqueue(.http(200, game))
        let recovered = try! await client.loadNFLScoreboard(referenceDate: kickoff.addingTimeInterval(22))
        check(recovered.count == 1 && recovered[0].eventID == "401872948"
              && recovered[0].startsAt == kickoff && recovered[0].status == "Live · 2nd · 1:00",
              "Scoreboard did not recover with the observed midnight-UTC game")
        check(wire.requests.count == 3 && wire.requests.allSatisfy(requestIsCurrentWeek),
              "Scoreboard request reintroduced dates or changed the bounded current-week query")
        wire.verifyDrained()
    }

    static func easternWindowAndMidnightCacheBoundary() async {
        let kickoff = iso("2026-09-25T00:15:00Z")
        let window = NFLScoreboardCalendar.window(containing: kickoff)
        check(window.identity == "20260924-20260930" && window.contains(kickoff),
              "Midnight UTC kickoff was not assigned to its Eastern NFL schedule day")
        check(window.start == iso("2026-09-24T04:00:00Z")
              && window.cutoff == iso("2026-09-30T04:00:00Z"),
              "Eastern through-Tuesday window bounds changed")

        let wire = ScoreboardProtocol.wire
        wire.reset()
        let session = session()
        defer { session.invalidateAndCancel() }
        let client = ESPNScoreboardClient(session: session)
        let beforeEasternMidnight = iso("2026-09-25T03:59:59Z")
        let afterEasternMidnight = iso("2026-09-25T04:00:01Z")
        wire.enqueue(.http(200, empty)); wire.enqueue(.http(200, game))
        _ = try! await client.loadNFLScoreboard(referenceDate: beforeEasternMidnight)
        let nextDay = try! await client.loadNFLScoreboard(referenceDate: afterEasternMidnight)
        check(nextDay.first?.eventID == "401872948" && wire.requests.count == 2,
              "A sub-20-second cache crossed the explicit Eastern date-window identity")
        check(wire.requests.allSatisfy(requestIsCurrentWeek), "Rollover request used an unsupported date range")
        wire.verifyDrained()
    }
}
