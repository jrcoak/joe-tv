import Foundation
import Security

enum MediaAPIConfigurationError: LocalizedError, Equatable {
    case missingBaseURL
    case missingReadToken

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Schedule data is unavailable because this build has no valid Personal Media API URL."
        case .missingReadToken:
            return "Schedule data is not configured for this build. Add the private MEDIA_READ_TOKEN and rebuild the app."
        }
    }
}

struct MediaAPIConfiguration: Sendable, Equatable {
    let baseURL: URL
    let readToken: String

    static func bundled(_ bundle: Bundle = .main) throws -> Self {
        try values(
            baseURLValue: bundle.object(forInfoDictionaryKey: "MediaAPIBaseURL"),
            readTokenValue: bundle.object(forInfoDictionaryKey: "MediaReadToken")
        )
    }

    static func values(baseURLValue: Any?, readTokenValue: Any?) throws -> Self {
        guard let rawBaseURL = baseURLValue as? String,
              !rawBaseURL.contains("$("),
              let baseURL = URL(string: rawBaseURL),
              baseURL.scheme != nil,
              baseURL.host != nil else {
            throw MediaAPIConfigurationError.missingBaseURL
        }

        guard let rawReadToken = readTokenValue as? String else {
            throw MediaAPIConfigurationError.missingReadToken
        }
        let readToken = rawReadToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard readToken.count >= 32,
              !readToken.contains("$("),
              !readToken.localizedCaseInsensitiveContains("placeholder") else {
            throw MediaAPIConfigurationError.missingReadToken
        }

        return Self(baseURL: baseURL, readToken: readToken)
    }
}

enum MediaAPIReadRoute: Sendable {
    case guideXMLTV
    case sportsSchedule
    case sportsEventDetail(SportsEventDetailIdentity)

    var path: String {
        switch self {
        case .guideXMLTV: return "/api/v1/guide/xmltv"
        case .sportsSchedule: return "/api/v1/sports/schedule"
        case .sportsEventDetail(let identity):
            return "/api/v1/sports/events/\(identity.sport)/\(identity.league)/\(identity.eventID)"
        }
    }

    var accept: String {
        switch self {
        case .guideXMLTV: return "application/xml"
        case .sportsSchedule, .sportsEventDetail: return "application/json"
        }
    }
}

enum MediaAPIRequestBuilder {
    static func makeRequest(
        configuration: MediaAPIConfiguration,
        route: MediaAPIReadRoute
    ) -> URLRequest {
        var request = URLRequest(url: configuration.baseURL.appending(path: route.path))
        request.httpMethod = "GET"
        if case .sportsEventDetail = route {
            // Event details can legitimately appear after an earlier 404 when the Mac
            // publisher finishes. The provider maintains its own ETag/disk cache, so a
            // URLSession negative-cache hit would only hide newly published metadata.
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        request.setValue("Bearer \(configuration.readToken)", forHTTPHeaderField: "Authorization")
        request.setValue(route.accept, forHTTPHeaderField: "Accept")
        return request
    }
}

enum LegacyScheduleCredentialCleanup {
    private static let completionKey = "media-api.legacy-paired-token-removed"
    private static let service = "com.seasonstv.personal-media-api.device-token"
    private static let account = "paired-device"

    static func run(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completionKey) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            defaults.set(true, forKey: completionKey)
        }
    }
}
