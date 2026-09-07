import Foundation

enum HTMLCatalogParser {
    private struct SectionDefinition {
        let id: String
        let title: String
        let symbol: String
        let aliases: [String]
    }

    private static let sections: [SectionDefinition] = [
        .init(id: "football", title: "Football", symbol: "football.fill", aliases: ["football"]),
        .init(id: "soccer", title: "Soccer", symbol: "soccerball", aliases: ["st", "worldcup", "uefac", "mls"]),
        .init(id: "basketball", title: "Basketball", symbol: "basketball.fill", aliases: ["basketball", "marchmadness"]),
        .init(id: "hockey", title: "Hockey", symbol: "hockey.puck.fill", aliases: ["hockey"]),
        .init(id: "baseball", title: "Baseball", symbol: "baseball.fill", aliases: ["baseball"]),
        .init(id: "college", title: "College", symbol: "graduationcap.fill", aliases: ["ncaaf"]),
        .init(id: "channels", title: "Channels", symbol: "tv.fill", aliases: ["channels", "espnp"]),
        .init(id: "combat", title: "Combat", symbol: "figure.boxing", aliases: ["mma"]),
        .init(id: "racing", title: "Racing", symbol: "flag.checkered", aliases: ["f1"]),
        .init(id: "other", title: "More", symbol: "square.grid.2x2.fill", aliases: ["others"])
    ]

    static func isLoginPage(_ html: String, responseURL: URL?) -> Bool {
        if responseURL?.path.lowercased().contains("/account/login") == true { return true }
        return html.contains("name=\"Username\"") && html.contains("name=\"Password\"")
    }

    static func antiForgeryToken(in html: String) -> String? {
        firstCapture(
            in: html,
            pattern: #"name=["']__RequestVerificationToken["'][^>]*value=["']([^"']+)["']"#
        ).map(decodeEntities)
        ?? firstCapture(
            in: html,
            pattern: #"value=["']([^"']+)["'][^>]*name=["']__RequestVerificationToken["']"#
        ).map(decodeEntities)
    }

    static func parseCatalog(_ html: String, baseURL: URL) -> [CatalogCategory] {
        var grouped: [String: [MediaItem]] = [:]

        for section in sections {
            var items: [MediaItem] = []
            for alias in section.aliases {
                guard let fragment = fragment(forElementID: alias, in: html) else { continue }
                items.append(contentsOf: parseRows(fragment, categoryID: section.id, baseURL: baseURL))
            }
            grouped[section.id] = deduplicate(items)
        }

        // Some server variants move rows outside their traditional containers.
        let allKnownItems = Set(grouped.values.flatMap { $0 }.map(signature))
        let ungrouped = parseRows(html, categoryID: "other", baseURL: baseURL)
            .filter { !allKnownItems.contains(signature($0)) }
        grouped["other", default: []].append(contentsOf: ungrouped)
        grouped["other"] = deduplicate(grouped["other"] ?? [])

        let result = sections.compactMap { definition -> CatalogCategory? in
            let items = grouped[definition.id] ?? []
            guard !items.isEmpty else { return nil }
            return CatalogCategory(
                id: definition.id,
                title: definition.title,
                symbol: definition.symbol,
                items: items
            )
        }

        return result
    }

    static func parseDRMChannels(_ html: String, baseURL: URL) -> [LiveChannel] {
        let anchors = allCaptures(in: html, pattern: #"(?is)<a\b([^>]*)>(.*?)</a>"#)
        var seen = Set<String>()

        return anchors.compactMap { captures -> LiveChannel? in
            guard captures.count == 2 else { return nil }
            let attributes = captures[0]
            let body = captures[1]
            guard attributes.range(
                of: #"class=["'][^"']*\bpdrm-chan\b[^"']*["']"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil,
            let href = firstCapture(in: attributes, pattern: #"href=["']([^"']+)["']"#),
            let playbackURL = absoluteURL(decodeEntities(href), relativeTo: baseURL),
            isPlayableDRMPath(playbackURL.path),
            seen.insert(playbackURL.absoluteString).inserted else { return nil }

            let name = firstCapture(
                in: body,
                pattern: #"(?is)<span\b[^>]*class=["'][^"']*\bpdrm-chan__name\b[^"']*["'][^>]*>(.*?)</span>"#
            ).map(plainText)
            ?? firstCapture(in: body, pattern: #"(?is)<img\b[^>]*alt=["']([^"']+)["']"#).map(decodeEntities)
            ?? ""
            guard !name.isEmpty else { return nil }

            let logoURL = firstCapture(in: body, pattern: #"(?is)<img\b[^>]*src=["']([^"']+)["']"#)
                .flatMap { absoluteURL(decodeEntities($0), relativeTo: baseURL) }

            return LiveChannel(
                id: playbackURL.lastPathComponent,
                name: name,
                logoURL: logoURL,
                playback: .drmPage(playbackURL),
                genre: ChannelDirectory.genre(for: name)
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func parseLegacyChannels(_ html: String, baseURL: URL) -> [LiveChannel] {
        guard let category = parseCatalog(html, baseURL: baseURL).first(where: { $0.id == "channels" }) else {
            return []
        }

        var seen = Set<String>()
        return category.items.compactMap { item -> LiveChannel? in
            guard case .request(let request) = item.playback,
                  let rawID = request.arguments.first,
                  !rawID.isEmpty else { return nil }
            let type = request.arguments.indices.contains(1)
                ? request.arguments[1].lowercased()
                : "live"
            let identity = "legacy:\(request.controller):\(type):\(rawID)"
            guard seen.insert(identity).inserted else { return nil }
            return LiveChannel(
                id: identity,
                name: item.title,
                logoURL: item.imageURL,
                playback: .request(request),
                genre: ChannelDirectory.genre(for: item.title)
            )
        }
    }

    static func parseDynamicGames(
        _ data: Data,
        categoryID: String,
        controller: String,
        baseURL: URL,
        directStreamTemplate: String? = nil
    ) -> [MediaItem] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let games: [[String: Any]]
        if let array = object as? [[String: Any]] {
            games = array
        } else if let dictionary = object as? [String: Any],
                  let array = dynamicValue(in: dictionary, keys: ["games", "events"]) as? [[String: Any]] {
            games = array
        } else {
            return []
        }

        return games.enumerated().compactMap { index, game in
            let away = dynamicString(in: game, keys: ["away_name", "awayname", "awayteamname", "awayteam", "away"])
            let home = dynamicString(in: game, keys: ["home_name", "homename", "hometeamname", "hometeam", "home"])
            let descriptiveTitle = dynamicString(in: game, keys: ["description", "name", "title", "eventname"])
            let title: String
            if let away, let home, !away.isEmpty, !home.isEmpty {
                title = "\(away) @ \(home)"
            } else if let descriptiveTitle, !descriptiveTitle.isEmpty {
                title = descriptiveTitle
            } else {
                return nil
            }

            let rawID = dynamicString(in: game, keys: ["id", "gameid", "eventid", "code"])
                ?? "\(categoryID)-\(index)-\(title)"
            let providerEventDateCode = dynamicString(in: game, keys: ["datecode"])
            let subtitle = dynamicScheduleText(in: game)
            let imageString = dynamicString(
                in: game,
                keys: ["away_logo", "awaylogo", "awayimage", "imageurl", "image", "logo"]
            )
            let imageURL = imageString.flatMap { absoluteURL($0, relativeTo: baseURL) }

            let playbackOptions = dynamicPlaybackOptions(
                in: game,
                fallbackController: controller,
                baseURL: baseURL,
                directStreamTemplate: directStreamTemplate
            )

            return MediaItem(
                id: "dynamic|\(categoryID)|\(rawID)",
                title: title,
                subtitle: subtitle,
                imageURL: imageURL,
                categoryID: categoryID,
                playbackOptions: playbackOptions,
                providerEventDateCode: providerEventDateCode
            )
        }
    }

    static func parseESPNPlusEvents(_ data: Data, baseURL: URL) -> [MediaItem] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }

        let airings: [[String: Any]]
        if let dictionary = object as? [String: Any] {
            airings = dynamicArray(in: dictionary, keys: ["airings", "events", "games"])
                .compactMap { $0 as? [String: Any] }
        } else if let array = object as? [[String: Any]] {
            airings = array
        } else {
            return []
        }

        var seen = Set<String>()
        return airings.compactMap { game -> MediaItem? in
            guard let title = dynamicString(in: game, keys: ["name", "title"]),
                  let sourceValue = dynamicValue(in: game, keys: ["source"]),
                  let playbackID = dynamicString(
                    in: dynamicDictionary(sourceValue),
                    keys: ["playbackid", "playbackId"]
                  ),
                  !playbackID.isEmpty else { return nil }

            let network = dynamicValue(in: game, keys: ["network"])
                .map(dynamicDictionary)
                .flatMap { dynamicString(in: $0, keys: ["name", "title"]) }
                ?? "ESPN+"
            let competition = ["subcategory", "league", "sport"].lazy.compactMap { key in
                dynamicValue(in: game, keys: [key])
                    .map(dynamicDictionary)
                    .flatMap { dynamicString(in: $0, keys: ["name", "title"]) }
            }.first ?? "ESPN+"
            let imageURL = dynamicValue(in: game, keys: ["image"])
                .map(dynamicDictionary)
                .flatMap { dynamicString(in: $0, keys: ["url", "href"]) }
                .flatMap { absoluteURL($0, relativeTo: baseURL) }

            let metadata = espnPlusPlaybackMetadata(playbackID)
            let type = dynamicString(in: game, keys: ["type", "airingtype"])?.lowercased()
            let isReplay = type == "replay" || metadata.contentType == "vod"

            var components = URLComponents(url: baseURL.appending(path: "/PlayerDRMEP/Watch"), resolvingAgainstBaseURL: true)
            components?.queryItems = [URLQueryItem(name: "id", value: playbackID)]
            guard let pageURL = components?.url else { return nil }

            let stableID = metadata.mediaID ?? metadata.sourceID ?? playbackID
            guard seen.insert(stableID).inserted else { return nil }
            let subtitle = [competition, network, isReplay ? "Replay" : "Live"]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")

            return MediaItem(
                id: "espnplus|\(stableID)",
                title: title,
                subtitle: subtitle,
                imageURL: imageURL,
                categoryID: "espnplus",
                playback: .drmPage(pageURL)
            )
        }
        .sorted { left, right in
            let leftReplay = left.subtitle?.localizedCaseInsensitiveContains("Replay") == true
            let rightReplay = right.subtitle?.localizedCaseInsensitiveContains("Replay") == true
            if leftReplay != rightReplay { return !leftReplay }
            return left.title.localizedStandardCompare(right.title) == .orderedAscending
        }
    }

    static func footballDirectStreamTemplate(in html: String) -> String? {
        firstCapture(
            in: html,
            pattern: #"(https?://[^\"'<>]*\[key\][^\"'<>]*\.m3u8\?hmac=[^\"'<>]+)"#
        ).map(decodeEntities)
    }

    static func mergingDynamicItems(
        _ items: [MediaItem],
        categoryID: String,
        title: String,
        symbol: String,
        into categories: [CatalogCategory]
    ) -> [CatalogCategory] {
        var result = categories.filter { $0.id != categoryID }
        let category = CatalogCategory(
            id: categoryID,
            title: title,
            symbol: symbol,
            items: prioritizedEvents(deduplicate(items))
        )
        if let order = sections.firstIndex(where: { $0.id == categoryID }) {
            let insertion = result.firstIndex { existing in
                (sections.firstIndex(where: { $0.id == existing.id }) ?? sections.count) > order
            } ?? result.endIndex
            result.insert(category, at: insertion)
        } else {
            result.append(category)
        }

        return result
    }

    static func mergingSupplementalPlayback(
        _ supplementalItems: [MediaItem],
        into primaryItems: [MediaItem]
    ) -> [MediaItem] {
        primaryItems.map { primary in
            guard let supplemental = supplementalItems.first(where: {
                titlesDescribeSameEvent(primary.title, $0.title)
            }) else { return primary }

            let primaryPlayable = primary.playbackOptions.filter {
                if case .unavailable = $0.playback { return false }
                return true
            }
            let supplementalPlayable = supplemental.playbackOptions.filter {
                if case .unavailable = $0.playback { return false }
                return true
            }
            var seen = Set<String>()
            let merged = (primaryPlayable + supplementalPlayable).filter {
                seen.insert(playbackSignature($0.playback)).inserted
            }
            guard !merged.isEmpty else { return primary }
            var seenIDs = Set<String>()
            let uniquelyIdentified = merged.enumerated().map { index, option in
                let id = seenIDs.insert(option.id).inserted
                    ? option.id
                    : "merged-\(index)-\(option.id)"
                return MediaItem.PlaybackOption(id: id, title: option.title, playback: option.playback)
            }

            return MediaItem(
                id: primary.id,
                title: primary.title,
                subtitle: primary.subtitle,
                imageURL: primary.imageURL ?? supplemental.imageURL,
                categoryID: primary.categoryID,
                playbackOptions: uniquelyIdentified,
                providerEventDateCode: primary.providerEventDateCode
            )
        }
    }

    static func parseHLSURL(from payload: Data) -> URL? {
        guard var text = String(data: payload, encoding: .utf8) else { return nil }
        text = text.replacingOccurrences(of: "\\/", with: "/")
        let patterns = [
            #"https:\/\/[^\s"'<>]+?\.m3u8(?:\?[^\s"'<>]+)?"#,
            #"https://[^\s"'<>]+?\.m3u8(?:\?[^\s"'<>]+)?"#
        ]
        for pattern in patterns {
            if let match = firstCapture(in: text, pattern: "(" + pattern + ")"),
               let url = URL(string: decodeEntities(match)) {
                return url
            }
        }
        return nil
    }

    static func parseDRMConfiguration(_ html: String, pageURL: URL, baseURL: URL) -> DRMConfiguration? {
        guard let hlsString = firstCapture(in: html, pattern: #"hls\s*:\s*["']([^"']+\.m3u8[^"']*)["']"#),
              let hlsURL = absoluteURL(decodeEntities(hlsString), relativeTo: baseURL) else {
            return nil
        }

        let fairPlayBlock: String = {
            guard let range = firstRange(in: html, pattern: #"fairplay\s*:"#) else { return html }
            return String(html[range.lowerBound...].prefix(8_000))
        }()

        // ESPN pages contain both Widevine and FairPlay certificateURL fields. Restrict the
        // lookup to the FairPlay block so Apple TV never receives the Widevine certificate.
        guard let certificateString = firstCapture(
            in: fairPlayBlock,
            pattern: #"certificateURL\s*:\s*["']([^"']+)["']"#
        ),
              let certificateURL = absoluteURL(decodeEntities(certificateString), relativeTo: baseURL) else {
            return nil
        }

        var headers: [String: String] = [:]
        if let headerBlock = firstCapture(in: fairPlayBlock, pattern: #"headers\s*:\s*\{([^}]+)\}"#) {
            let headerPattern = #"["']([^"']+)["']\s*:\s*["']([^"']*)["']"#
            for captures in allCaptures(in: headerBlock, pattern: headerPattern) where captures.count == 2 {
                headers[decodeEntities(captures[0])] = decodeEntities(captures[1])
            }
        }

        var prefix: String?
        if pageURL.path.lowercased().contains("international") {
            prefix = firstCapture(
                in: fairPlayBlock,
                pattern: #"licenseServerUrl\s*=\s*["']([^"']+)["']\s*\+\s*licenseServerUrl"#
            ).map(decodeEntities)
        }

        let licenseURL = firstCapture(
            in: fairPlayBlock,
            pattern: #"(?:LA_URL|licenseServerURL|licenseServerUrl)\s*:\s*["']([^"']+)["']"#
        )
        .map(decodeEntities)
        .flatMap { absoluteURL($0, relativeTo: baseURL) }

        let contentIdentifierStrategy: DRMContentIdentifierStrategy = {
            if let dropCount = firstCapture(
                in: fairPlayBlock,
                pattern: #"(?is)replace\(\s*["']skd://["']\s*,\s*["']["']\s*\)\s*\.substring\(\s*(\d+)\s*\)"#
            ).flatMap(Int.init) {
                return .schemeStripped(dropFirst: dropCount)
            }
            if fairPlayBlock.range(
                of: #"replace\(\s*["']skd://["']\s*,\s*["']["']\s*\)"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                return .schemeStripped(dropFirst: 0)
            }
            return .fullSKDURL
        }()

        return DRMConfiguration(
            hlsURL: hlsURL,
            certificateURL: certificateURL,
            licenseProxyPrefix: prefix,
            headers: headers,
            licenseURL: licenseURL,
            contentIdentifierStrategy: contentIdentifierStrategy
        )
    }

    private static func parseRows(_ html: String, categoryID: String, baseURL: URL) -> [MediaItem] {
        allCaptures(in: html, pattern: #"(?is)<tr\b[^>]*>(.*?)</tr>"#).compactMap { captures in
            guard let row = captures.first else { return nil }
            let cells = allCaptures(in: row, pattern: #"(?is)<td\b[^>]*>(.*?)</td>"#)
                .compactMap(\.first)
                .map(plainText)
                .filter { !$0.isEmpty }

            var title = cells.first(where: { cell in
                let lower = cell.lowercased()
                return lower != "@" && !lower.hasPrefix("watch") && !lower.contains("available during")
            }) ?? plainText(row)
            let rawTitle = title
            title = cleanTitle(title)
            guard !title.isEmpty,
                  !title.contains("{{"),
                  !title.contains("}}"),
                  title.range(of: #"\b(?:game|live)\.\w+"#, options: [.regularExpression, .caseInsensitive]) == nil else {
                return nil
            }

            let imageURL = firstCapture(in: row, pattern: #"(?is)<img\b[^>]*src=["']([^"']+)["']"#)
                .flatMap { absoluteURL(decodeEntities($0), relativeTo: baseURL) }

            if let href = firstCapture(
                in: row,
                pattern: #"(?is)<a\b[^>]*href=["']([^"']*PlayerDRMChannels[^"']*)["'][^>]*>"#
            ), let pageURL = absoluteURL(decodeEntities(href), relativeTo: baseURL), isPlayableDRMPath(pageURL.path) {
                let id = "drm|\(categoryID)|\(pageURL.absoluteString)"
                return MediaItem(
                    id: id,
                    title: title,
                    subtitle: subtitle(from: rawTitle, drm: true),
                    imageURL: imageURL,
                    categoryID: categoryID,
                    playback: .drmPage(pageURL)
                )
            }

            let actionPattern = #"(?is)<(?:a|button)\b[^>]*ng-click\s*=\s*(?:"([^"]+\.Watch\([^"]+\))"|'([^']+\.Watch\([^']+\))')[^>]*>(.*?)</(?:a|button)>"#
            var actions: [(invocation: String, label: String)] = allCaptures(in: row, pattern: actionPattern)
                .compactMap { action in
                    guard let invocation = action.first else { return nil }
                    return (decodeEntities(invocation), action.count > 1 ? plainText(action.last ?? "") : "")
                }
            if actions.isEmpty {
                actions = allCaptures(
                    in: row,
                    pattern: #"(?is)ng-click\s*=\s*(?:"([^"]+\.Watch\([^"]+\))"|'([^']+\.Watch\([^']+\))')"#
                ).compactMap { action in
                    action.first.map { (decodeEntities($0), "") }
                }
            }

            let parsedActions: [(playback: MediaItem.Playback, controller: String, values: [String], label: String)] = actions.compactMap { action in
                guard let controllerName = firstCapture(
                    in: action.invocation,
                    pattern: #"([A-Za-z][A-Za-z0-9_]*)\.Watch\("#
                ), let arguments = firstCapture(in: action.invocation, pattern: #"\.Watch\((.*)\)"#) else { return nil }
                let values = splitArguments(arguments)
                guard let rawID = values.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                      isLiteralPlaybackID(rawID),
                      let controller = canonicalController(for: controllerName),
                      let endpoint = endpoint(for: controller) else { return nil }
                let decodedValues = values.map(unquote)
                let playback: MediaItem.Playback
                if let directURL = decodedValues.lazy.compactMap(directHLSURL).first {
                    playback = .hls(directURL)
                } else {
                    playback = .request(PlaybackRequest(
                        endpoint: endpoint,
                        controller: controller,
                        arguments: decodedValues
                    ))
                }
                return (playback, controller, decodedValues, action.label)
            }
            guard !parsedActions.isEmpty else { return nil }

            let feedLabels = parsedActions.map { action -> String in
                if action.values.indices.contains(2), !action.values[2].isEmpty { return action.values[2] }
                return cleanTitle(action.label)
            }
            let normalizedFeeds = feedLabels.map { $0.lowercased() }
            let canInferBaseballSides = categoryID == "baseball" &&
                parsedActions.count == 2 &&
                Set(normalizedFeeds.filter { !$0.isEmpty }).count == 2 &&
                normalizedFeeds.allSatisfy { !isNamedBroadcastRole($0) }

            var seenPlayback = Set<String>()
            let playbackOptions = parsedActions.enumerated().compactMap { index, action -> MediaItem.PlaybackOption? in
                guard seenPlayback.insert(playbackSignature(action.playback)).inserted else { return nil }
                let isDVR = (
                    action.values.indices.contains(4) &&
                        action.values[4].caseInsensitiveCompare("true") == .orderedSame
                ) || action.label.localizedCaseInsensitiveContains("DVR")
                let feed = feedLabels[index]
                let optionTitle: String
                if isNamedBroadcastRole(feed) {
                    optionTitle = broadcastTitle(feed, isDVR: isDVR)
                } else if canInferBaseballSides {
                    optionTitle = broadcastTitle(index == 0 ? "away" : "home", isDVR: isDVR)
                } else {
                    let label = cleanTitle(action.label)
                    if !label.isEmpty, label.caseInsensitiveCompare("Backup") != .orderedSame {
                        optionTitle = isDVR ? "\(label) · DVR" : label
                    } else if !feed.isEmpty {
                        optionTitle = broadcastTitle(feed, isDVR: isDVR)
                    } else {
                        optionTitle = isDVR ? "Watch · DVR" : "Watch"
                    }
                }
                return MediaItem.PlaybackOption(
                    id: "row-\(index)-\(action.controller)-\(playbackSignature(action.playback))",
                    title: optionTitle,
                    playback: action.playback
                )
            }
            guard !playbackOptions.isEmpty else { return nil }

            return MediaItem(
                id: "row|\(categoryID)|\(title)|\(playbackOptions[0].id)",
                title: title,
                subtitle: subtitle(from: rawTitle, drm: false),
                imageURL: imageURL,
                categoryID: categoryID,
                playbackOptions: playbackOptions.sorted {
                    broadcastPriority($0.title) < broadcastPriority($1.title)
                }
            )
        }
    }

    private static func isNamedBroadcastRole(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("home") || normalized.contains("away") || normalized.contains("national")
    }

    private static func canonicalController(for controller: String) -> String? {
        switch controller.lowercased() {
        case "p", "fbl": return "fbl"
        case "bkb", "bkbc": return "bkb"
        case "bsb", "bsbc": return "bsb"
        case "hky", "hkyc": return "hky"
        case "ncf", "ncaaf", "ncfc": return "ncf"
        case "xfl", "xflc": return "xfl"
        case "mm", "mmc": return "mm"
        case "mls", "mlsc": return "mls"
        case "oli", "olic": return "oli"
        default: return nil
        }
    }

    private static func endpoint(for controller: String) -> String? {
        switch controller {
        case "fbl": return "/Player/Watch"
        case "bkb": return "/Player/Watch_BKB"
        case "bsb": return "/Player/Watch_BSB"
        case "hky": return "/Player/Watch_HKY"
        case "ncf", "xfl": return "/Player/Watch_NCAAF"
        case "mm", "oli": return "/Player/Watch_OLI"
        case "mls": return "/Player/Watch_MLS"
        default: return nil
        }
    }

    private static func directHLSURL(_ value: String) -> URL? {
        guard value.range(of: #"^https?://[^\s]+\.m3u8(?:\?[^\s]+)?$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return URL(string: decodeEntities(value))
    }

    private static func isLiteralPlaybackID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
            (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            let decoded = unquote(trimmed)
            return !decoded.isEmpty &&
                decoded.range(of: #"[{}()$]"#, options: .regularExpression) == nil
        }
        return trimmed.range(of: #"^-?\d+$"#, options: .regularExpression) != nil
    }

    private static func fragment(forElementID id: String, in html: String) -> String? {
        guard let marker = firstRange(in: html, pattern: #"(?is)<(?:div|section)\b[^>]*\bid=["']"# + NSRegularExpression.escapedPattern(for: id) + #"["'][^>]*>"#) else {
            return nil
        }

        let tail = String(html[marker.lowerBound...])
        let searchableTail = String(tail.dropFirst())
        let nextMarkers = sections.flatMap(\.aliases)
            .filter { $0 != id }
            .compactMap { alias -> String.Index? in
                firstRange(
                    in: searchableTail,
                    pattern: #"(?is)<(?:div|section)\b[^>]*\bid=["']"# + NSRegularExpression.escapedPattern(for: alias) + #"["'][^>]*>"#
                )?.lowerBound
            }

        // A bounded slice is enough to isolate rows while staying tolerant of imperfect HTML.
        let maximumLength = 450_000
        let endOffset = nextMarkers.map { searchableTail.distance(from: searchableTail.startIndex, to: $0) + 1 }.min()
            ?? min(tail.count, maximumLength)
        return String(tail.prefix(min(endOffset, maximumLength)))
    }

    private static func isPlayableDRMPath(_ path: String) -> Bool {
        path.range(of: #"[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}"#, options: .regularExpression) != nil
    }

    private static func dynamicValue(in dictionary: [String: Any], keys: [String]) -> Any? {
        let normalized = dictionary.reduce(into: [String: Any]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        return keys.lazy.compactMap { normalized[$0.lowercased()] }.first
    }

    private static func dynamicArray(in dictionary: [String: Any], keys: [String]) -> [Any] {
        guard let value = dynamicValue(in: dictionary, keys: keys) else { return [] }
        if let array = value as? [Any] { return array }
        if let wrapped = value as? [String: Any] {
            if let array = dynamicValue(in: wrapped, keys: ["$values", "values", "items"]) as? [Any] {
                return array
            }
            let indexed = wrapped.compactMap { key, value -> (index: Int, value: Any)? in
                guard let index = Int(key) else { return nil }
                return (index, value)
            }
            if !indexed.isEmpty {
                return indexed.sorted { $0.index < $1.index }.map(\.value)
            }
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let array = object as? [Any] {
            return array
        }
        return []
    }

    private static func dynamicDictionary(_ value: Any) -> [String: Any] {
        if let dictionary = value as? [String: Any] { return dictionary }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            return dictionary
        }
        return [:]
    }

    private static func dynamicPlaybackOptions(
        in game: [String: Any],
        fallbackController: String,
        baseURL: URL,
        directStreamTemplate: String?
    ) -> [MediaItem.PlaybackOption] {
        let isProviderLive = dynamicBool(in: game, keys: ["islive", "live"]) == true
        let rawGameID = dynamicString(in: game, keys: ["id", "gameid", "eventid", "code"])
        let dateCode = dynamicString(in: game, keys: ["datecode"])
        let awayCode = dynamicString(in: game, keys: ["away", "awaycode", "awayabbr", "awayabbreviation"])
        let homeCode = dynamicString(in: game, keys: ["home", "homecode", "homeabbr", "homeabbreviation"])
        var options: [MediaItem.PlaybackOption] = []

        let media = dynamicArray(in: game, keys: ["media"])
        let playerOptions = dynamicArray(
            in: game,
            keys: ["mediaoptionsforplayer", "mediaoptions", "broadcasts"]
        )
        let liveContent = dynamicArray(in: game, keys: ["livecontent", "streams"])
        guard isProviderLive || !media.isEmpty || !playerOptions.isEmpty || !liveContent.isEmpty else {
            return [.init(id: "unavailable", title: "Unavailable", playback: .unavailable)]
        }
        let playbackType = dynamicString(
            in: game,
            keys: ["playbacktype", "streamtype"]
        ) ?? (isProviderLive ? "live" : "replay")
        let optionCount = max(media.count, playerOptions.count)
        if optionCount > 0, let rawGameID, let endpoint = endpoint(for: fallbackController) {
            for index in 0..<optionCount {
                let feedMetadata = index < media.count ? dynamicDictionary(media[index]) : [:]
                let playerOption = index < playerOptions.count ? dynamicDictionary(playerOptions[index]) : [:]
                guard let feed = dynamicString(
                    in: playerOption,
                    keys: ["feed", "broadcast", "name"]
                ) ?? dynamicString(
                    in: feedMetadata,
                    keys: ["feed", "broadcast", "name"]
                ), !isYouTubeMedia(playerOption),
                   !isYouTubeMedia(feedMetadata) else { continue }
                let normalizedFeed = feed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard normalizedFeed != "recap", normalizedFeed != "condensed" else { continue }
                let mediaState = dynamicString(in: playerOption, keys: ["mediastate", "state"])
                    ?? dynamicString(in: feedMetadata, keys: ["mediastate", "state"])
                if let mediaState, !mediaState.isEmpty,
                   mediaState.caseInsensitiveCompare("MEDIA_ON") != .orderedSame {
                    continue
                }
                let mediaID = dynamicString(
                    in: playerOption,
                    keys: ["mediaplaybackid", "mediaid", "playbackid", "id"]
                ) ?? dynamicString(
                    in: feedMetadata,
                    keys: ["mediaplaybackid", "mediaid", "playbackid", "id"]
                ) ?? "0"
                let isDVR = dynamicBool(in: playerOption, keys: ["isdvr", "dvr"])
                    ?? dynamicBool(in: feedMetadata, keys: ["isdvr", "dvr"])
                    ?? false
                let presentationFeed = broadcastRole(feed, awayCode: awayCode, homeCode: homeCode)
                let title = broadcastTitle(presentationFeed, isDVR: isDVR)
                let playback: MediaItem.Playback
                if let direct = dynamicString(
                    in: playerOption,
                    keys: ["directurl", "streamurl", "hlsurl", "url"]
                ).flatMap(directHLSURL) ?? dynamicString(
                    in: feedMetadata,
                    keys: ["directurl", "streamurl", "hlsurl", "url"]
                ).flatMap(directHLSURL) {
                    playback = .hls(direct)
                } else {
                    var arguments = [rawGameID, playbackType, feed.lowercased(), mediaID, String(isDVR)]
                    if fallbackController == "bsb", let dateCode {
                        arguments.append(dateCode)
                    } else {
                        arguments.append("{}")
                    }
                    playback = .request(PlaybackRequest(
                        endpoint: endpoint,
                        controller: fallbackController,
                        arguments: arguments
                    ))
                }
                options.append(.init(id: "media-\(index)-\(feed)-\(mediaID)", title: title, playback: playback))
            }
        }

        if !liveContent.isEmpty {
            var teamFeedIndex = 0
            var dvrTeamFeedIndex = 0
            for (index, value) in liveContent.enumerated() {
                let stream = dynamicDictionary(value)
                guard !stream.isEmpty else { continue }
                if dynamicBool(in: stream, keys: ["isdrm"]) == true,
                   let drmID = dynamicString(in: stream, keys: ["id", "channelid", "code"]),
                   let domesticURL = URL(string: "/PlayerDRMChannels/\(drmID)", relativeTo: baseURL)?.absoluteURL,
                   let internationalURL = URL(string: "/PlayerDRMChannels/International/\(drmID)", relativeTo: baseURL)?.absoluteURL {
                    options.append(.init(id: "drm-us-\(drmID)", title: "US Feed · DRM", playback: .drmPage(domesticURL)))
                    options.append(.init(id: "drm-intl-\(drmID)", title: "International Feed · DRM", playback: .drmPage(internationalURL)))
                    continue
                }

                guard let type = dynamicInt(in: stream, keys: ["typ", "type"]) else { continue }
                if type == 14 || type == 15 {
                    let explicitURL = dynamicString(
                        in: stream,
                        keys: ["directurl", "streamurl", "hlsurl", "url"]
                    ).flatMap(directHLSURL)
                    let templatedURL: URL? = {
                        guard let directStreamTemplate,
                              let key = dynamicString(in: stream, keys: ["descweb", "key", "streamkey"]) else { return nil }
                        var value = directStreamTemplate.replacingOccurrences(of: "[key]", with: base64URL(key))
                        if type == 15 {
                            value += value.contains("?") ? "&dvr=true" : "?dvr=true"
                        }
                        return URL(string: value)
                    }()
                    guard let url = explicitURL ?? templatedURL else { continue }
                    let fallback: String
                    if type == 14 {
                        fallback = teamFeedIndex.isMultiple(of: 2) ? "Away Feed" : "Home Feed"
                        teamFeedIndex += 1
                    } else {
                        fallback = dvrTeamFeedIndex.isMultiple(of: 2) ? "Away Feed · 5-min DVR" : "Home Feed · 5-min DVR"
                        dvrTeamFeedIndex += 1
                    }
                    let name = dynamicString(
                        in: stream,
                        keys: ["desc", "description", "label", "name", "title"]
                    ) ?? fallback
                    let title = type == 15 && !name.localizedCaseInsensitiveContains("DVR")
                        ? "\(name) · DVR"
                        : name
                    options.append(.init(id: "direct-\(index)-\(type)", title: title, playback: .hls(url)))
                    continue
                }

                guard [2, 11, 12].contains(type),
                      let streamID = dynamicString(in: stream, keys: ["id", "streamid", "code"]) else { continue }
                if type == 2 {
                    options.append(.init(
                        id: "standard-us-\(streamID)",
                        title: "US Feed",
                        playback: .request(PlaybackRequest(
                            endpoint: "/Player/Watch_BKB",
                            controller: "bkb",
                            arguments: [streamID, "channel", "", "0", "false", "{}"]
                        ))
                    ))
                    options.append(.init(
                        id: "standard-intl-\(streamID)",
                        title: "International Feed",
                        playback: .request(PlaybackRequest(
                            endpoint: "/Player/Watch_BKB",
                            controller: "bkb",
                            arguments: [streamID, "channel-int", "", "0", "false", "{}"]
                        ))
                    ))
                } else {
                    options.append(.init(
                        id: "alternate-\(streamID)-\(type)",
                        title: type == 12 ? "Alternate · 5-min DVR" : "Alternate Feed",
                        playback: .request(PlaybackRequest(
                            endpoint: "/Player/Watch_BKB",
                            controller: "bkb",
                            arguments: [streamID, "channel", "", "0", "false", "{}"]
                        ))
                    ))
                }
            }
        }

        if options.isEmpty, isProviderLive, let rawGameID, let endpoint = endpoint(for: fallbackController) {
            options.append(.init(
                id: "default",
                title: "Watch",
                playback: .request(PlaybackRequest(
                    endpoint: endpoint,
                    controller: fallbackController,
                    arguments: [rawGameID, "live"]
                ))
            ))
        }

        var seen = Set<String>()
        let unique = options.filter { seen.insert(playbackSignature($0.playback)).inserted }
        return unique.sorted { broadcastPriority($0.title) < broadcastPriority($1.title) }
    }

    private static func broadcastTitle(_ feed: String, isDVR: Bool) -> String {
        let normalized = feed.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: String
        switch normalized.lowercased() {
        case "home": base = "Home Feed"
        case "away": base = "Away Feed"
        case "national", "national feed": base = "National Feed"
        default: base = normalized.localizedCapitalized.contains("Feed") ? normalized.localizedCapitalized : "\(normalized.localizedCapitalized) Feed"
        }
        return isDVR ? "\(base) · DVR" : base
    }

    private static func broadcastRole(_ feed: String, awayCode: String?, homeCode: String?) -> String {
        let normalized = feed.trimmingCharacters(in: .whitespacesAndNewlines)
        if let awayCode,
           normalized.caseInsensitiveCompare(awayCode.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return "away"
        }
        if let homeCode,
           normalized.caseInsensitiveCompare(homeCode.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return "home"
        }
        return feed
    }

    private static func isYouTubeMedia(_ dictionary: [String: Any]) -> Bool {
        guard let value = dynamicValue(in: dictionary, keys: ["youtube"]), !(value is NSNull) else {
            return false
        }
        if let boolean = value as? Bool { return boolean }
        if let string = value as? String {
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private static func broadcastPriority(_ title: String) -> Int {
        let value = title.lowercased()
        if value.hasPrefix("home") { return value.contains("dvr") ? 1 : 0 }
        if value.hasPrefix("away") { return value.contains("dvr") ? 3 : 2 }
        if value.hasPrefix("national") { return 4 }
        if value.hasPrefix("us feed") { return 5 }
        if value.hasPrefix("international") { return 6 }
        if value.contains("alternate") { return 7 }
        if value.contains("drm") { return 9 }
        return 8
    }

    private static func base64URL(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func playbackSignature(_ playback: MediaItem.Playback) -> String {
        switch playback {
        case .drmPage(let url): return "drm|\(url.absoluteString)"
        case .hls(let url): return "hls|\(url.absoluteString)"
        case .request(let request): return "request|\(request.endpoint)|\(request.arguments.joined(separator: "|"))"
        case .unavailable: return "unavailable"
        }
    }

    private static func titlesDescribeSameEvent(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = competitors(in: lhs), let right = competitors(in: rhs) else {
            return normalizedTeamName(lhs) == normalizedTeamName(rhs)
        }
        return teamsMatch(left.0, right.0) && teamsMatch(left.1, right.1)
            || teamsMatch(left.0, right.1) && teamsMatch(left.1, right.0)
    }

    private static func competitors(in title: String) -> (String, String)? {
        let separated = title.replacingOccurrences(
            of: #"\s+(?:@|at|vs\.?|versus)\s+"#,
            with: "|",
            options: [.regularExpression, .caseInsensitive]
        )
        let parts = separated.split(separator: "|", maxSplits: 1).map { normalizedTeamName(String($0)) }
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return (parts[0], parts[1])
    }

    private static func normalizedTeamName(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func teamsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasSuffix(" " + rhs) || rhs.hasSuffix(" " + lhs)
    }

    private static func dynamicString(in dictionary: [String: Any], keys: [String]) -> String? {
        guard let value = dynamicValue(in: dictionary, keys: keys), !(value is NSNull) else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func dynamicBool(in dictionary: [String: Any], keys: [String]) -> Bool? {
        guard let value = dynamicValue(in: dictionary, keys: keys) else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            if string.caseInsensitiveCompare("true") == .orderedSame || string == "1" { return true }
            if string.caseInsensitiveCompare("false") == .orderedSame || string == "0" { return false }
        }
        return nil
    }

    private static func dynamicInt(in dictionary: [String: Any], keys: [String]) -> Int? {
        guard let value = dynamicValue(in: dictionary, keys: keys) else { return nil }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func dynamicScheduleText(in game: [String: Any]) -> String? {
        if dynamicBool(in: game, keys: ["isfinal", "final"]) == true {
            return "Final"
        }
        if let text = dynamicString(
            in: game,
            keys: ["datetext", "starttimetext", "gametimetext", "status", "quarter"]
        ), !text.isEmpty, text != "P" {
            return text.caseInsensitiveCompare("F") == .orderedSame ? "Final" : text
        }
        guard let value = dynamicValue(in: game, keys: ["date", "starttime", "gametime", "start"]) else {
            return dynamicBool(in: game, keys: ["islive", "live"]) == true ? "Live" : "Scheduled"
        }
        if let date = dynamicDate(value) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let eastern = TimeZone(identifier: "America/New_York")!
            formatter.timeZone = eastern
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            // Seasons4U serializes these wall-clock values using a fixed EST
            // offset. Remove the seasonal offset before formatting in Eastern
            // time so summer schedules match the website instead of drifting
            // one hour later in the native client.
            let providerDate = date.addingTimeInterval(-eastern.daylightSavingTimeOffset(for: date))
            return formatter.string(from: providerDate) + " ET"
        }
        return dynamicString(in: game, keys: ["date", "starttime", "gametime", "start"])
    }

    private static func dynamicDate(_ value: Any) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
        }
        guard let string = value as? String else { return nil }
        if let milliseconds = firstCapture(in: string, pattern: #"/Date\((-?\d+)"#).flatMap(Double.init) {
            return Date(timeIntervalSince1970: milliseconds / 1_000)
        }
        return ISO8601DateFormatter().date(from: string)
    }

    private static func dynamicDRMIdentifier(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            if dynamicBool(in: dictionary, keys: ["isdrm"]) == true,
               let identifier = dynamicString(in: dictionary, keys: ["id", "channelid", "code"]),
               identifier.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}$"#, options: .regularExpression) != nil {
                return identifier
            }
            for nested in dictionary.values {
                if let identifier = dynamicDRMIdentifier(in: nested) { return identifier }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let identifier = dynamicDRMIdentifier(in: nested) { return identifier }
            }
        }
        return nil
    }

    private static func espnPlusPlaybackMetadata(
        _ playbackID: String
    ) -> (mediaID: String?, sourceID: String?, contentType: String?) {
        guard let data = Data(base64Encoded: playbackID),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return (nil, nil, nil)
        }
        return (
            dynamicString(in: dictionary, keys: ["mediaid", "mediaId"]),
            dynamicString(in: dictionary, keys: ["sourceid", "sourceId"]),
            dynamicString(in: dictionary, keys: ["contenttype", "contentType"])?.lowercased()
        )
    }

    private static func cleanTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<!--|-->"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "(Worldwide option)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "(DRM HD Channel)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "| International option", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Watch (DRM)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Watch", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func subtitle(from title: String, drm: Bool) -> String? {
        if title.localizedCaseInsensitiveContains("International") ||
            title.localizedCaseInsensitiveContains("Worldwide") { return "International access" }
        if title.localizedCaseInsensitiveContains("US IP") { return "US network required" }
        return "Live"
    }

    private static func splitArguments(_ value: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var depth = 0
        for character in value {
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote { quote = nil }
                continue
            }
            if character == "'" || character == "\"" {
                quote = character
                current.append(character)
            } else if character == "{" || character == "[" || character == "(" {
                depth += 1
                current.append(character)
            } else if character == "}" || character == "]" || character == ")" {
                depth = max(0, depth - 1)
                current.append(character)
            } else if character == "," && depth == 0 {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { result.append(current.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return result
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") || trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) else {
            return decodeEntities(trimmed)
        }
        return decodeEntities(String(trimmed.dropFirst().dropLast()))
    }

    private static func deduplicate(_ items: [MediaItem]) -> [MediaItem] {
        var seen = Set<String>()
        return items.filter { seen.insert(signature($0)).inserted }
    }

    private static func prioritizedEvents(_ items: [MediaItem]) -> [MediaItem] {
        items.enumerated().sorted { left, right in
            let leftRank = eventPriority(left.element)
            let rightRank = eventPriority(right.element)
            return leftRank == rightRank ? left.offset < right.offset : leftRank < rightRank
        }.map(\.element)
    }

    private static func eventPriority(_ item: MediaItem) -> Int {
        let status = item.subtitle?.lowercased() ?? ""
        if status == "final" || status == "f" { return 4 }
        if status.contains("live") && item.isPlayable { return 0 }
        if item.isPlayable { return 1 }
        if status == "scheduled" || status.contains(" am") || status.contains(" pm") { return 2 }
        return 3
    }

    private static func signature(_ item: MediaItem) -> String {
        switch item.playback {
        case .drmPage(let url):
            return "drm|\(url.absoluteString)"
        case .hls(let url):
            return "hls|\(url.absoluteString)"
        case .request(let request):
            return "request|\(request.endpoint)|\(request.arguments.joined(separator: "|"))"
        case .unavailable:
            return "unavailable|\(item.id)"
        }
    }

    private static func plainText(_ html: String) -> String {
        decodeEntities(
            html
                .replacingOccurrences(of: #"(?is)<!--.*?-->"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"(?is)<script\b.*?</script>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"(?is)<style\b.*?</style>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func decodeEntities(_ value: String) -> String {
        var decoded = value
        let named = [
            "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&nbsp;": " "
        ]
        for (entity, replacement) in named {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        return decoded
    }

    private static func absoluteURL(_ value: String, relativeTo baseURL: URL) -> URL? {
        if value.hasPrefix("//") { return URL(string: "https:" + value) }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private static func firstCapture(in value: String, pattern: String) -> String? {
        allCaptures(in: value, pattern: pattern).first?.first
    }

    private static func allCaptures(in value: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                guard let swiftRange = Range(match.range(at: index), in: value) else { return nil }
                return String(value[swiftRange])
            }
        }
    }

    private static func firstRange(in value: String, pattern: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }
        return Range(match.range, in: value)
    }
}

enum SportsScheduleEnricher {
    static func merge(
        _ snapshot: SportsScheduleSnapshot,
        into playbackCategories: [CatalogCategory]
    ) -> [CatalogCategory] {
        var categories = playbackCategories

        let eventsByPlaybackAffinity = snapshot.events.sorted {
            let leftRank = playbackAffinityRank($0, relativeTo: snapshot.generatedAt)
            let rightRank = playbackAffinityRank($1, relativeTo: snapshot.generatedAt)
            if leftRank != rightRank { return leftRank < rightRank }
            if leftRank == 2 { return $0.startsAt > $1.startsAt }
            return $0.startsAt < $1.startsAt
        }

        for event in eventsByPlaybackAffinity {
            guard let categoryID = categoryID(for: event) else { continue }
            let categoryIndex: Int
            if let existing = categories.firstIndex(where: { $0.id == categoryID }) {
                categoryIndex = existing
            } else {
                categories.append(CatalogCategory(
                    id: categoryID,
                    title: categoryPresentation(for: categoryID).title,
                    symbol: categoryPresentation(for: categoryID).symbol,
                    items: []
                ))
                categoryIndex = categories.index(before: categories.endIndex)
            }

            if let itemIndex = categories[categoryIndex].items.firstIndex(where: {
                !$0.id.hasPrefix("schedule|") &&
                    $0.sportsEvent == nil &&
                    playbackItem($0, matches: event)
            }) {
                let playbackItem = categories[categoryIndex].items[itemIndex]
                categories[categoryIndex].items[itemIndex] = MediaItem(
                    id: playbackItem.id,
                    title: playbackItem.title,
                    subtitle: subtitle(for: event),
                    imageURL: event.thumbnailURL ?? playbackItem.imageURL,
                    categoryID: categoryID,
                    playbackOptions: playbackItem.playbackOptions,
                    sportsEvent: event,
                    providerEventDateCode: playbackItem.providerEventDateCode
                )
            } else {
                categories[categoryIndex].items.append(MediaItem(
                    id: "schedule|\(event.eventID)",
                    title: eventTitle(event),
                    subtitle: subtitle(for: event),
                    imageURL: event.thumbnailURL,
                    categoryID: categoryID,
                    playback: .unavailable,
                    sportsEvent: event
                ))
            }
        }

        return categories.map { category in
            var category = category
            category.items = category.items.enumerated().sorted { lhs, rhs in
                switch (lhs.element.sportsEvent, rhs.element.sportsEvent) {
                case let (left?, right?):
                    let leftRank = eventRank(left)
                    let rightRank = eventRank(right)
                    if leftRank != rightRank { return leftRank < rightRank }
                    if left.startsAt != right.startsAt { return left.startsAt < right.startsAt }
                    return lhs.offset < rhs.offset
                case (_?, nil): return false
                case (nil, _?): return true
                case (nil, nil): return lhs.offset < rhs.offset
                }
            }.map(\.element)
            return category
        }
    }

    private static func playbackAffinityRank(
        _ event: SportsScheduleEvent,
        relativeTo referenceDate: Date
    ) -> Int {
        let status = event.status?.lowercased() ?? ""
        if status.contains("progress") || status.contains("live") ||
            status.contains("half") || status.contains("period") {
            return 0
        }
        if event.startsAt >= referenceDate { return 1 }
        return 2
    }

    private static func playbackItem(_ item: MediaItem, matches event: SportsScheduleEvent) -> Bool {
        guard titlesDescribeSameEvent(item.title, eventTitle(event)) else { return false }
        guard let providerDateCode = providerDateCode(for: item) else { return true }
        return providerDateCode == dateCode(for: event.startsAt)
    }

    private static func providerDateCode(for item: MediaItem) -> String? {
        if let explicit = normalizedDateCode(item.providerEventDateCode) { return explicit }
        return item.playbackOptions.lazy.compactMap { option -> String? in
            guard case .request(let request) = option.playback,
                  request.controller.caseInsensitiveCompare("bsb") == .orderedSame,
                  request.arguments.indices.contains(5) else { return nil }
            return normalizedDateCode(request.arguments[5])
        }.first
    }

    private static func normalizedDateCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        return digits.count == 8 ? digits : nil
    }

    private static func dateCode(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func categoryID(for event: SportsScheduleEvent) -> String? {
        let value = [event.sport, event.league, event.leagueID]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if value.contains("football") || value.contains("nfl") || value.contains("ncaaf") { return "football" }
        if value.contains("baseball") || value.contains("mlb") { return "baseball" }
        if value.contains("hockey") || value.contains("nhl") { return "hockey" }
        if value.contains("basketball") || value.contains("nba") || value.contains("wnba") || value.contains("ncaab") { return "basketball" }
        if value.contains("soccer") || value.contains("mls") || value.contains("uefa") || value.contains("fifa") { return "soccer" }
        if value.contains("mma") || value.contains("ufc") || value.contains("boxing") { return "combat" }
        if value.contains("racing") || value.contains("formula 1") || value.contains("f1") { return "racing" }
        return nil
    }

    private static func categoryPresentation(for categoryID: String) -> (title: String, symbol: String) {
        switch categoryID {
        case "football": return ("Football", "football.fill")
        case "baseball": return ("Baseball", "baseball.fill")
        case "hockey": return ("Hockey", "hockey.puck.fill")
        case "basketball": return ("Basketball", "basketball.fill")
        case "soccer": return ("Soccer", "soccerball")
        case "combat": return ("Combat", "figure.boxing")
        case "racing": return ("Racing", "flag.checkered")
        default: return ("More", "square.grid.2x2.fill")
        }
    }

    private static func eventTitle(_ event: SportsScheduleEvent) -> String {
        if let away = event.awayTeam, let home = event.homeTeam, !away.isEmpty, !home.isEmpty {
            return "\(away) @ \(home)"
        }
        return event.title
    }

    private static func subtitle(for event: SportsScheduleEvent) -> String {
        let status = event.status?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let awayScore = event.awayScore, let homeScore = event.homeScore,
           let status, !status.isEmpty, status.lowercased() != "scheduled" {
            return "\(awayScore) – \(homeScore)  ·  \(status)"
        }
        if let status, !status.isEmpty, status.lowercased() != "scheduled" {
            return status
        }
        return event.startsAt.formatted(date: .abbreviated, time: .shortened)
    }

    private static func eventRank(_ event: SportsScheduleEvent) -> Int {
        let status = event.status?.lowercased() ?? ""
        if status.contains("progress") || status.contains("live") || status.contains("half") || status.contains("period") {
            return 0
        }
        if status.contains("final") || status.contains("complete") { return 2 }
        return 1
    }

    private static func titlesDescribeSameEvent(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = competitors(in: lhs), let right = competitors(in: rhs) else {
            return normalizedTeamName(lhs) == normalizedTeamName(rhs)
        }
        return teamsMatch(left.0, right.0) && teamsMatch(left.1, right.1)
            || teamsMatch(left.0, right.1) && teamsMatch(left.1, right.0)
    }

    private static func competitors(in title: String) -> (String, String)? {
        let separated = title.replacingOccurrences(
            of: #"\s+(?:@|at|vs\.?|versus)\s+"#,
            with: "|",
            options: [.regularExpression, .caseInsensitive]
        )
        let parts = separated.split(separator: "|", maxSplits: 1).map { normalizedTeamName(String($0)) }
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return (parts[0], parts[1])
    }

    private static func normalizedTeamName(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func teamsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasSuffix(" " + rhs) || rhs.hasSuffix(" " + lhs)
    }
}
