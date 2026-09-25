import Foundation

@main
private enum FootballPlaybackRefreshSmoke {
    private static var checks = 0

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }

    private static func expect(
        _ expected: FootballPlaybackRefreshError,
        _ message: String,
        operation: () throws -> Void
    ) {
        checks += 1
        do {
            try operation()
            fatalError(message)
        } catch let error as FootballPlaybackRefreshError {
            if error != expected { fatalError("\(message): got \(error)") }
        } catch {
            fatalError("\(message): got unexpected \(error)")
        }
    }

    private static func parsedFootball(
        id: Int = 42,
        streams: String,
        signature: String
    ) -> MediaItem {
        let data = Data("""
        [
          {
            "Id": \(id),
            "Away": "Owls",
            "Home": "Bears",
            "IsLive": true,
            "LiveContent": [\(streams)]
          }
        ]
        """.utf8)
        guard let item = HTMLCatalogParser.parseDynamicGames(
            data,
            categoryID: "football",
            controller: "fbl",
            baseURL: URL(string: "https://seasons4u.com")!,
            directStreamTemplate: "https://media.example/[key]/master.m3u8?hmac=\(signature)"
        ).first else {
            fatalError("Football fixture did not parse")
        }
        return item
    }

    private static func option(
        titled title: String,
        in item: MediaItem
    ) -> MediaItem.PlaybackOption {
        guard let option = item.playbackOptions.first(where: { $0.title == title }) else {
            fatalError("Missing \(title) in fixture")
        }
        return option
    }

    private static func item(
        id: String = "dynamic|football|42",
        options: [MediaItem.PlaybackOption]
    ) -> MediaItem {
        MediaItem(
            id: id,
            title: "Owls @ Bears",
            subtitle: "Live",
            imageURL: nil,
            categoryID: "football",
            playbackOptions: options
        )
    }

    static func main() throws {
        let playerRequest = FootballPlaybackRefresh.playerMetadataRequest(
            baseURL: URL(string: "https://seasons4u.com")!
        )
        check(playerRequest.url?.absoluteString == "https://seasons4u.com/Player", "Refresh requested the wrong page")
        check(playerRequest.httpMethod == "GET", "Refresh Player request was not GET")
        check(
            playerRequest.cachePolicy == .reloadIgnoringLocalCacheData,
            "Refresh Player request allowed a cached signed template"
        )

        let old = parsedFootball(
            streams: """
            {"typ":14,"desc":"Away Feed","descweb":"away-old"},
            {"typ":14,"desc":"Home Feed","descweb":"home-old"},
            {"typ":15,"desc":"Away Feed · DVR","descweb":"away-dvr-old"},
            {"typ":15,"desc":"Home Feed · DVR","descweb":"home-dvr-old"}
            """,
            signature: "old"
        )
        let fresh = parsedFootball(
            streams: """
            {"typ":15,"desc":"Home Feed · DVR","descweb":"home-dvr-fresh"},
            {"typ":14,"desc":"Home Feed","descweb":"home-fresh"},
            {"typ":15,"desc":"Away Feed · DVR","descweb":"away-dvr-fresh"},
            {"typ":14,"desc":"Away Feed","descweb":"away-fresh"}
            """,
            signature: "fresh"
        )

        for title in ["Home Feed", "Away Feed", "Home Feed · DVR", "Away Feed · DVR"] {
            let selected = option(titled: title, in: old)
            check(
                FootballPlaybackRefresh.requiresRefresh(item: old, option: selected),
                "Dynamic direct football \(title) did not require refresh"
            )
            let refreshed = try FootballPlaybackRefresh.refreshedOption(
                for: old,
                selectedOption: selected,
                in: [fresh]
            )
            check(refreshed.title == title, "Refresh changed semantic feed \(title)")
            guard case .hls(let url) = refreshed.playback else {
                fatalError("Refreshed \(title) was not direct HLS")
            }
            check(url.query?.contains("hmac=fresh") == true, "Refresh retained old signature for \(title)")
            check(!url.absoluteString.contains("-old"), "Refresh retained old stream key for \(title)")
            check(
                url.query?.contains("dvr=true") == selected.isStartOver,
                "Refresh changed DVR identity for \(title)"
            )
        }

        let selectedHome = option(titled: "Home Feed", in: old)
        let sameTitleDifferentEvent = parsedFootball(
            id: 99,
            streams: #"{"typ":14,"desc":"Home Feed","descweb":"other-home"}"#,
            signature: "fresh"
        )
        expect(.eventUnavailable, "Refresh borrowed a feed from another event") {
            _ = try FootballPlaybackRefresh.refreshedOption(
                for: old,
                selectedOption: selectedHome,
                in: [sameTitleDifferentEvent]
            )
        }

        let awayOnly = parsedFootball(
            streams: #"{"typ":14,"desc":"Away Feed","descweb":"away-only"}"#,
            signature: "fresh"
        )
        expect(.optionUnavailable, "Refresh borrowed a different feed from the same event") {
            _ = try FootballPlaybackRefresh.refreshedOption(
                for: old,
                selectedOption: selectedHome,
                in: [awayOnly]
            )
        }

        let duplicateHome = item(options: [
            .init(id: "home-a", title: "Home Feed", playback: .hls(URL(string: "https://a.example/live.m3u8")!)),
            .init(id: "home-b", title: "Home Feed", playback: .hls(URL(string: "https://b.example/live.m3u8")!))
        ])
        expect(.ambiguousOption, "Refresh silently chose between duplicate semantic feeds") {
            _ = try FootballPlaybackRefresh.refreshedOption(
                for: old,
                selectedOption: selectedHome,
                in: [duplicateHome]
            )
        }

        let international = MediaItem.PlaybackOption(
            id: "international",
            title: "International Feed · DRM",
            playback: .drmPage(URL(string: "https://example.com/international")!)
        )
        let national = MediaItem.PlaybackOption(
            id: "national",
            title: "National Feed",
            playback: .hls(URL(string: "https://example.com/national.m3u8")!)
        )
        check(
            FootballPlaybackOptionIdentity(international) != FootballPlaybackOptionIdentity(national),
            "International and national feeds shared an identity"
        )

        let currentRequest = MediaItem.PlaybackOption(
            id: "request",
            title: "Home Feed",
            playback: .request(PlaybackRequest(
                endpoint: "/Player/Watch_FBL",
                controller: "fbl",
                arguments: ["42", "live", "home", "7", "false", "{}"]
            ))
        )
        check(
            !FootballPlaybackRefresh.requiresRefresh(item: old, option: currentRequest),
            "Resolved football request was unnecessarily refreshed"
        )
        check(
            !FootballPlaybackRefresh.requiresRefresh(
                item: item(id: "static|football|42", options: [selectedHome]),
                option: selectedHome
            ),
            "Non-dynamic HLS item was unnecessarily refreshed"
        )

        let refreshedRequest = try FootballPlaybackRefresh.refreshedOption(
            for: old,
            selectedOption: selectedHome,
            in: [item(options: [currentRequest])]
        )
        guard case .request(let request) = refreshedRequest.playback else {
            fatalError("Same semantic feed could not move to current request metadata")
        }
        check(request.arguments[2] == "home", "Refreshed request changed the selected feed")
        check(request.arguments[4] == "false", "Refreshed request changed live/DVR mode")

        let scheduleEvent = SportsScheduleEvent(
            eventID: "espn-42",
            title: "Owls at Bears",
            sport: "Football",
            leagueID: "nfl",
            league: "NFL",
            startsAt: Date(timeIntervalSince1970: 1_800_000_000),
            endsAt: Date(timeIntervalSince1970: 1_800_014_400),
            status: "Scheduled",
            venue: nil,
            country: nil,
            homeTeamID: nil,
            homeTeam: "Bears",
            homeTeamLogoURL: nil,
            awayTeamID: nil,
            awayTeam: "Owls",
            awayTeamLogoURL: nil,
            homeScore: nil,
            awayScore: nil,
            thumbnailURL: nil,
            sourceDate: nil,
            sourceTime: nil,
            broadcasts: []
        )
        let enriched = SportsScheduleEnricher.merge(
            SportsScheduleSnapshot(
                provider: "fixture",
                generatedAt: Date(timeIntervalSince1970: 1_799_990_000),
                windowStart: "20270115",
                windowEnd: "20270116",
                events: [scheduleEvent]
            ),
            into: [CatalogCategory(id: "football", title: "Football", symbol: "football.fill", items: [old])]
        )
        let consolidated = SportsEventGuidePolicy.consolidatedItems(categories: enriched, espnPlusItems: [])
        guard let sportsCard = consolidated.first(where: { $0.sportsEvent?.eventID == scheduleEvent.eventID }) else {
            fatalError("Dynamic football fixture did not reach consolidated Sports")
        }
        check(sportsCard.id == old.id, "Sports consolidation replaced the stable dynamic football ID")
        check(
            FootballPlaybackRefresh.requiresRefresh(item: sportsCard, option: option(titled: "Home Feed", in: sportsCard)),
            "Consolidated Sports football card bypassed selection refresh"
        )

        let fantasyCard = MediaItem(
            id: sportsCard.id,
            title: scheduleEvent.title,
            subtitle: scheduleEvent.status,
            imageURL: sportsCard.imageURL,
            categoryID: "nfl",
            playbackOptions: sportsCard.playbackOptions,
            sportsEvent: scheduleEvent,
            providerEventDateCode: sportsCard.providerEventDateCode
        )
        check(fantasyCard.id == old.id, "Fantasy projection replaced the stable dynamic football ID")
        check(
            FootballPlaybackRefresh.requiresRefresh(item: fantasyCard, option: option(titled: "Home Feed", in: fantasyCard)),
            "Fantasy football card bypassed selection refresh"
        )

        print("Football playback refresh smoke passed (\(checks) checks)")
    }
}
