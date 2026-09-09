import Foundation

enum PlaybackPayloadBuilder {
    static func makePayload(for request: PlaybackRequest, now: Date = Date()) throws -> [String: Any] {
        guard !request.arguments.isEmpty else { throw SeasonsError.invalidResponse }

        let arguments = request.arguments
        let id = scalar(arguments[0])
        let type = string(arguments, at: 1, default: "live")

        switch request.controller {
        case "fbl":
            return [
                "code": id,
                "quality": "9",
                "type": type,
                "alt": scalar(arguments, at: 4, default: false)
            ]

        case "bkb":
            return [
                "id": id,
                "type": type,
                "broadcast": string(arguments, at: 2, default: "home"),
                "isDVR": scalar(arguments, at: 3, default: false),
                "isDRM": drmFlag(in: arguments, at: 4)
            ]

        case "hky":
            return [
                "id": id,
                "type": type,
                "broadcast": string(arguments, at: 2, default: "HOME"),
                "mediaId": scalar(arguments, at: 3, default: 0),
                "isDVR": scalar(arguments, at: 4, default: false)
            ]

        case "bsb":
            var payload: [String: Any] = [
                "id": id,
                "type": type,
                "broadcast": string(arguments, at: 2, default: "home"),
                "mediaId": scalar(arguments, at: 3, default: 0),
                "isDVR": scalar(arguments, at: 4, default: false),
                "gmd": dotNetTicks(for: now)
            ]
            let dateCode = string(arguments, at: 5, default: "")
            if dateCode.range(of: #"^\d{8}$"#, options: .regularExpression) != nil {
                payload["dateCode"] = scalar(dateCode)
                payload["isG"] = true
            }
            return payload

        case "ncf", "xfl":
            return [
                "id": id,
                "type": type,
                "broadcast": string(arguments, at: 2, default: "home"),
                "mediaId": scalar(arguments, at: 3, default: 0),
                "isDVR": scalar(arguments, at: 4, default: false),
                "gmd": dotNetTicks(for: now)
            ]

        case "mls":
            return [
                "id": id,
                "code": string(arguments, at: 1, default: ""),
                "type": string(arguments, at: 2, default: "live"),
                "broadcast": string(arguments, at: 3, default: "home"),
                "mediaId": scalar(arguments, at: 4, default: 0),
                "isDVR": scalar(arguments, at: 5, default: false),
                "gmd": dotNetTicks(for: now)
            ]

        case "oli", "mm":
            return [
                "id": id,
                "type": type,
                "broadcast": "home",
                "isDVR": scalar(arguments, at: 2, default: false)
            ]

        default:
            throw SeasonsError.invalidResponse
        }
    }

    private static func string(_ arguments: [String], at index: Int, default fallback: String) -> String {
        guard arguments.indices.contains(index) else { return fallback }
        let value = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value == "null" || value == "undefined" { return fallback }
        return value
    }

    private static func scalar(_ arguments: [String], at index: Int, default fallback: Any) -> Any {
        guard arguments.indices.contains(index) else { return fallback }
        return scalar(arguments[index])
    }

    private static func scalar(_ value: String) -> Any {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let integer = Int64(trimmed) { return integer }
        if trimmed.caseInsensitiveCompare("true") == .orderedSame { return true }
        if trimmed.caseInsensitiveCompare("false") == .orderedSame { return false }
        if trimmed == "null" || trimmed == "undefined" { return NSNull() }
        return trimmed
    }

    private static func drmFlag(in arguments: [String], at index: Int) -> Bool {
        guard arguments.indices.contains(index) else { return false }
        return arguments[index].range(
            of: #"IsDRM\s*[:=]\s*true"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func dotNetTicks(for date: Date) -> Int64 {
        let unixMilliseconds = Int64(date.timeIntervalSince1970 * 1_000)
        return unixMilliseconds * 10_000 + 621_355_968_000_000_000
    }
}

final class SeasonsClient {
    let baseURL = URL(string: "https://seasons4u.com")!
    private let cookieStorage: HTTPCookieStorage
    private let session: URLSession

    init(cookieStorage: HTTPCookieStorage = .shared) {
        self.cookieStorage = cookieStorage
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "Accept-Language": "en-US,en;q=0.9",
            "User-Agent": "Joe-TV/1.0 (AppleTV; tvOS)"
        ]
        self.session = URLSession(configuration: configuration)
    }

    func signIn(username: String, password: String, rememberMe: Bool) async throws {
        let loginURL = baseURL.appending(path: "/Account/Login")
        let (loginData, loginResponse) = try await session.data(from: loginURL)
        try validate(loginResponse)
        guard let loginHTML = String(data: loginData, encoding: .utf8),
              let token = HTMLCatalogParser.antiForgeryToken(in: loginHTML) else {
            throw SeasonsError.invalidResponse
        }

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = formData([
            "__RequestVerificationToken": token,
            "Username": username,
            "Password": password,
            "RememberMe": rememberMe ? "true" : "false"
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response)
        let html = String(data: data, encoding: .utf8) ?? ""
        let responseURL = (response as? HTTPURLResponse)?.url
        if HTMLCatalogParser.isLoginPage(html, responseURL: responseURL) {
            throw SeasonsError.invalidCredentials
        }
    }

    func loadCatalog() async throws -> [CatalogCategory] {
        let playerURL = baseURL.appending(path: "/Player")
        let (data, response) = try await session.data(from: playerURL)
        try validate(response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SeasonsError.invalidResponse
        }
        let responseURL = (response as? HTTPURLResponse)?.url
        if HTMLCatalogParser.isLoginPage(html, responseURL: responseURL) {
            throw SeasonsError.authenticationRequired
        }

        var categories = HTMLCatalogParser.parseCatalog(html, baseURL: baseURL)
        let footballStreamTemplate = HTMLCatalogParser.footballDirectStreamTemplate(in: html)
        let footballTask = Task {
            try? await self.loadCurrentFootballGames(directStreamTemplate: footballStreamTemplate)
        }
        let baseballTask = Task { try? await self.loadCurrentBaseballEvents() }
        let football = await footballTask.value
        let baseball = await baseballTask.value

        if let football, !football.isEmpty {
            categories = HTMLCatalogParser.mergingDynamicItems(
                football,
                categoryID: "football",
                title: "Football",
                symbol: "football.fill",
                into: categories
            )
        }
        if let baseball, !baseball.isEmpty {
            categories = HTMLCatalogParser.mergingDynamicItems(
                baseball,
                categoryID: "baseball",
                title: "Baseball",
                symbol: "baseball.fill",
                into: categories
            )
        }
        guard !categories.isEmpty else { throw SeasonsError.emptyCatalog }
        return categories
    }

    private func loadCurrentFootballGames(directStreamTemplate: String?) async throws -> [MediaItem] {
        let year = String(Calendar(identifier: .gregorian).component(.year, from: Date()))
        let weeksData = try await postJSON(path: "/Player/WeeksList", payload: ["year": year])
        let weeksObject = try JSONSerialization.jsonObject(with: weeksData)
        guard let weeks = weeksObject as? [[String: Any]], let week = weeks.first else { return [] }

        let normalized = week.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        guard let weekValue = normalized["week"],
              let responseYear = normalized["year"],
              let type = normalized["type"] else { return [] }

        let gamesData = try await postJSON(
            path: "/Player/GameList",
            payload: ["week": weekValue, "year": responseYear, "type": type]
        )
        return HTMLCatalogParser.parseDynamicGames(
            gamesData,
            categoryID: "football",
            controller: "fbl",
            baseURL: baseURL,
            directStreamTemplate: directStreamTemplate
        )
    }

    private func loadCurrentBaseballEvents() async throws -> [MediaItem] {
        let officialGames = (try? await postJSON(
            path: "/Player/GameList_BSB",
            payload: ["ticks": NSNull()]
        )).map {
            HTMLCatalogParser.parseDynamicGames(
                $0,
                categoryID: "baseball",
                controller: "bsb",
                baseURL: baseURL
            )
        } ?? []

        let supplementalGames = (try? await loadBaseballSupplementalEvents()) ?? []
        guard !officialGames.isEmpty else { return supplementalGames }
        return HTMLCatalogParser.mergingSupplementalPlayback(supplementalGames, into: officialGames)
    }

    private func loadBaseballSupplementalEvents() async throws -> [MediaItem] {
        let url = baseURL.appending(path: "/Player/BSBEventsPartial")
        let (data, response) = try await session.data(from: url)
        try validate(response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SeasonsError.invalidResponse
        }
        let responseURL = (response as? HTTPURLResponse)?.url
        if HTMLCatalogParser.isLoginPage(html, responseURL: responseURL) {
            throw SeasonsError.authenticationRequired
        }

        let wrappedHTML = #"<div id="baseball">"# + html + "</div>"
        return HTMLCatalogParser.parseCatalog(wrappedHTML, baseURL: baseURL)
            .first(where: { $0.id == "baseball" })?
            .items ?? []
    }

    func loadESPNPlusEvents(for date: Date, calendar: Calendar = .current) async throws -> [MediaItem] {
        let day = calendar.startOfDay(for: date)
        let ticks: Int64
        if calendar.isDateInToday(day) {
            ticks = 0
        } else {
            let unixMilliseconds = Int64(day.timeIntervalSince1970 * 1_000)
            ticks = unixMilliseconds * 10_000 + 621_355_968_000_000_000
        }
        let data = try await postJSON(
            path: "/Player/GameList_ESPNPlus",
            payload: ["ticks": ticks]
        )
        return HTMLCatalogParser.parseESPNPlusEvents(
            data,
            baseURL: baseURL,
            requestedDate: day,
            calendar: calendar
        )
    }

    private func postJSON(path: String, payload: [String: Any]) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SeasonsError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(baseURL.appending(path: "/Player").absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return data
    }

    func loadLiveChannels() async throws -> [LiveChannel] {
        async let drmResult = loadAuthenticatedHTML(path: "/PlayerDRMChannels")
        async let legacyResult = loadAuthenticatedHTML(path: "/Player")
        let (drmHTML, legacyHTML) = try await (drmResult, legacyResult)

        let discovered = HTMLCatalogParser.parseDRMChannels(drmHTML, baseURL: baseURL)
            + HTMLCatalogParser.parseLegacyChannels(legacyHTML, baseURL: baseURL)
        let channels = ChannelDirectory.curate(discovered)
        guard !channels.isEmpty else {
            throw SeasonsError.message("None of the configured Live TV channels are currently available for this account.")
        }
        return channels
    }

    private func loadAuthenticatedHTML(path: String) async throws -> String {
        let url = baseURL.appending(path: path)
        let (data, response) = try await session.data(from: url)
        try validate(response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SeasonsError.invalidResponse
        }
        let responseURL = (response as? HTTPURLResponse)?.url
        if HTMLCatalogParser.isLoginPage(html, responseURL: responseURL) {
            throw SeasonsError.authenticationRequired
        }
        return html
    }

    func resolveStream(_ playbackRequest: PlaybackRequest) async throws -> URL {
        guard let url = URL(string: playbackRequest.endpoint, relativeTo: baseURL)?.absoluteURL else {
            throw SeasonsError.invalidResponse
        }

        let payload = try PlaybackPayloadBuilder.makePayload(for: playbackRequest)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(baseURL.appending(path: "/Player").absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validatePlaybackResponse(response)
        if let responseURL = (response as? HTTPURLResponse)?.url,
           responseURL.path.lowercased().contains("/account/login") {
            throw SeasonsError.authenticationRequired
        }
        if let message = playbackErrorMessage(in: data) {
            throw SeasonsError.message(message)
        }
        guard let streamURL = HTMLCatalogParser.parseHLSURL(from: data) else {
            throw SeasonsError.streamUnavailable
        }
        return streamURL
    }

    func loadDRMConfiguration(from pageURL: URL) async throws -> DRMConfiguration {
        let (data, response) = try await session.data(from: pageURL)
        try validate(response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SeasonsError.invalidResponse
        }
        let responseURL = (response as? HTTPURLResponse)?.url
        if HTMLCatalogParser.isLoginPage(html, responseURL: responseURL) {
            throw SeasonsError.authenticationRequired
        }
        guard let configuration = HTMLCatalogParser.parseDRMConfiguration(
            html,
            pageURL: pageURL,
            baseURL: baseURL
        ) else {
            throw SeasonsError.fairPlayUnavailable
        }
        return configuration
    }

    func authenticatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return data
    }

    func clearLocalSession() {
        cookieStorage.cookies?.filter { cookie in
            cookie.domain.localizedCaseInsensitiveContains("seasons4u.com")
        }.forEach(cookieStorage.deleteCookie)
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw SeasonsError.invalidResponse
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw SeasonsError.authenticationRequired
        }
        guard (200..<400).contains(response.statusCode) else {
            throw SeasonsError.message("The server returned status \(response.statusCode).")
        }
    }

    private func validatePlaybackResponse(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw SeasonsError.invalidResponse
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw SeasonsError.authenticationRequired
        }
        guard (200..<400).contains(response.statusCode) else {
            if response.statusCode >= 500 {
                throw SeasonsError.message("Seasons4U could not prepare this stream. Refresh the catalog and try again.")
            }
            throw SeasonsError.message("The stream request was rejected (status \(response.statusCode)).")
        }
    }

    private func playbackErrorMessage(in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let normalized = text.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if normalized.hasPrefix("ERROR:") {
            let code = String(normalized.dropFirst("ERROR:".count))
            if code == "NoAccess" || code == "NoAccessAny" {
                return "Your Seasons4U package does not include this stream."
            }
            return "Seasons4U could not authorize this stream."
        }
        if normalized == "TempError" {
            return "This stream is not ready yet. Try again shortly."
        }
        if normalized.localizedCaseInsensitiveContains("blackout") {
            return "This stream is blacked out in your current location."
        }
        return nil
    }

    private func formData(_ values: [String: String]) -> Data? {
        values.map { key, value in
            "\(formEncode(key))=\(formEncode(value))"
        }
        .sorted()
        .joined(separator: "&")
        .data(using: .utf8)
    }

    private func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? value
    }
}
