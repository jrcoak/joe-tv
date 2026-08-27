import Foundation

@main
enum ParserSmoke {
    static func main() {
        let baseURL = URL(string: "https://seasons4u.com")!
        let programStart = Date(timeIntervalSince1970: 1_700_000_000)
        let program = EPGProgram(
            id: "program-1",
            stationID: "station-1",
            title: "Fixture Program",
            start: programStart,
            end: programStart.addingTimeInterval(3_600),
            synopsis: nil,
            category: "Sports",
            imageURL: nil
        )
        guard program.contains(programStart),
              program.contains(programStart.addingTimeInterval(3_599)),
              !program.contains(program.end) else {
            fatalError("EPG program boundary behavior is incorrect")
        }
        let layout = EPGTimelineLayout(
            windowStart: programStart.addingTimeInterval(900),
            windowEnd: programStart.addingTimeInterval(2_700),
            pointsPerMinute: 6
        )
        guard let frame = layout.frame(for: program),
              frame.offset == 0,
              frame.width == 180,
              layout.width == 180 else {
            fatalError("EPG timeline clipping or absolute-time geometry is incorrect")
        }

        guard SportsCategoryOption.all.prefix(4).map(\.id) == ["football", "baseball", "hockey", "basketball"] else {
            fatalError("Default Sports category order changed")
        }

        let veryLocalChannels = VeryLocalClient(session: .shared).loadChannels()
        guard veryLocalChannels.count == 29,
              veryLocalChannels.first?.id == "verylocal:htv-national-desk",
              veryLocalChannels.allSatisfy({ $0.genre == .news }),
              veryLocalChannels.allSatisfy({ channel in
                  if case .veryLocal = channel.playback { return true }
                  return false
              }) else {
            fatalError("Very Local public station directory is incomplete or has unstable identities")
        }
        guard ChannelDirectory.brandAssetName(forPlaybackIdentity: "verylocal:wmur") == "VeryLocalLogo_WMUR",
              ChannelDirectory.brandAssetName(forPlaybackIdentity: "verylocal:wcvb") == "VeryLocalLogo_WCVB" else {
            fatalError("The priority Very Local stations are not using bundled high-resolution logos")
        }

        let mediaReadToken = String(repeating: "a", count: 32)
        guard let mediaConfiguration = try? MediaAPIConfiguration.values(
            baseURLValue: "https://personal-media-api.example",
            readTokenValue: mediaReadToken
        ),
              mediaConfiguration.baseURL.host == "personal-media-api.example",
              mediaConfiguration.readToken == mediaReadToken else {
            fatalError("Valid private media-read configuration was rejected")
        }
        let guideRequest = MediaAPIRequestBuilder.makeRequest(
            configuration: mediaConfiguration,
            route: .guideXMLTV
        )
        let sportsRequest = MediaAPIRequestBuilder.makeRequest(
            configuration: mediaConfiguration,
            route: .sportsSchedule
        )
        guard guideRequest.httpMethod == "GET",
              guideRequest.url?.path == "/api/v1/guide/xmltv",
              guideRequest.value(forHTTPHeaderField: "Authorization") == "Bearer \(mediaReadToken)",
              guideRequest.value(forHTTPHeaderField: "Accept") == "application/xml",
              sportsRequest.url?.path == "/api/v1/sports/schedule",
              sportsRequest.value(forHTTPHeaderField: "Accept") == "application/json" else {
            fatalError("MEDIA_READ_TOKEN was not scoped to the expected schedule GET requests")
        }
        do {
            _ = try MediaAPIConfiguration.values(
                baseURLValue: "https://personal-media-api.example",
                readTokenValue: "$(MEDIA_READ_TOKEN)"
            )
            fatalError("Placeholder MEDIA_READ_TOKEN should be rejected")
        } catch MediaAPIConfigurationError.missingReadToken {
            // Expected: unconfigured builds fail clearly at runtime.
        } catch {
            fatalError("Unexpected media-read configuration error: \(error)")
        }

        let sportsScheduleJSON = Data(#"""
        {
          "provider": "ESPN",
          "generatedAt": "2026-08-14T12:00:00.123+00:00",
          "windowStart": "2026-08-13",
          "windowEnd": "2026-08-22",
          "events": [
            {
              "eventId": "401772510",
              "title": "New York Giants at New England Patriots",
              "sport": "Football",
              "leagueId": "nfl",
              "league": "NFL",
              "startsAt": "2026-08-14T23:10:00Z",
              "endsAt": null,
              "status": "Scheduled",
              "venue": "Gillette Stadium",
              "country": "United States",
              "homeTeamId": "17",
              "homeTeam": "New England Patriots",
              "homeTeamLogoUrl": "https://media.example/patriots.png",
              "awayTeamId": "19",
              "awayTeam": "New York Giants",
              "awayTeamLogoUrl": "https://media.example/giants.png",
              "homeScore": null,
              "awayScore": null,
              "thumbnailUrl": "https://media.example/matchup.jpg",
              "sourceDate": "2026-08-14",
              "sourceTime": "23:10:00",
              "broadcasts": [
                {"channelId":"123","channel":"ESPN","country":"US","logoUrl":"https://media.example/espn.png"},
                {"channelId":"124","channel":"NFL Network","country":"US","logoUrl":null}
              ]
            }
          ]
        }
        """#.utf8)
        guard let sportsSchedule = try? SportsScheduleDecoder.decode(sportsScheduleJSON),
              sportsSchedule.events.first?.homeTeamLogoURL?.host == "media.example",
              sportsSchedule.events.first?.broadcastChannels == ["ESPN", "NFL Network"] else {
            fatalError("Sports schedule JSON or artwork metadata was not decoded")
        }
        let footballPlaybackItem = MediaItem(
            id: "s4u-football-1",
            title: "Giants @ Patriots",
            subtitle: "Live",
            imageURL: URL(string: "https://low-resolution.example/game.png"),
            categoryID: "football",
            playback: .hls(URL(string: "https://media.example/game/master.m3u8")!)
        )
        let enrichedSports = SportsScheduleEnricher.merge(
            sportsSchedule,
            into: [CatalogCategory(id: "football", title: "Football", symbol: "football.fill", items: [footballPlaybackItem])]
        )
        guard let enrichedFootball = enrichedSports.first?.items.first,
              enrichedFootball.id == footballPlaybackItem.id,
              enrichedFootball.isPlayable,
              enrichedFootball.imageURL?.path.hasSuffix("matchup.jpg") == true,
              enrichedFootball.sportsEvent?.league == "NFL" else {
            fatalError("Sports schedule metadata was not merged without changing playback identity")
        }

        let html = #"""
        <html><body>
          <div id="channels">
            <table><tbody>
              <tr>
                <td><img src="/Content/img/media/ESPN1.png"></td>
                <td>ESPN (Worldwide option)</td>
                <td><button ng-click="bkb.Watch(5001,'channel','home',false,{})">Watch</button></td>
              </tr>
              <tr>
                <td><img src="/Content/img/media/ESPN1.png"></td>
                <td>ESPN (DRM HD Channel) | International option</td>
                <td><a href="/PlayerDRMChannels/International/1ad12446-8e18-4e57-885e-ce0b17b6e6be">Watch (DRM)</a></td>
              </tr>
              <tr>
                <td>Dynamic template placeholder</td>
                <td><button ng-click="bkb.Watch(live.id,'channel','home',false,{})">Watch</button></td>
              </tr>
            </tbody></table>
          </div>
        </body></html>
        """#

        let categories = HTMLCatalogParser.parseCatalog(html, baseURL: baseURL)
        guard let channels = categories.first(where: { $0.id == "channels" }), channels.items.count == 2 else {
            fatalError("Expected two channel items, got \(categories.map { ($0.id, $0.items.count) })")
        }

        guard case .request(let request) = channels.items[0].playback,
              channels.items[0].title == "ESPN",
              channels.items[0].subtitle == "International access",
              request.endpoint == "/Player/Watch_BKB",
              request.controller == "bkb",
              request.arguments == ["5001", "channel", "home", "false", "{}"] else {
            fatalError("Standard watch invocation was not parsed")
        }

        guard let basketballPayload = try? PlaybackPayloadBuilder.makePayload(for: request),
              basketballPayload["id"] as? Int64 == 5001,
              basketballPayload["type"] as? String == "channel",
              basketballPayload["broadcast"] as? String == "home",
              basketballPayload["isDVR"] as? Bool == false,
              basketballPayload["player"] == nil,
              JSONSerialization.isValidJSONObject(basketballPayload) else {
            fatalError("Basketball playback payload does not match the site controller")
        }

        let hockeyRequest = PlaybackRequest(
            endpoint: "/Player/Watch_HKY",
            controller: "hky",
            arguments: ["-13031", "live", "HOME", "1", "false", "{}"]
        )
        guard let hockeyPayload = try? PlaybackPayloadBuilder.makePayload(for: hockeyRequest),
              hockeyPayload["mediaId"] as? Int64 == 1,
              hockeyPayload["isDVR"] as? Bool == false else {
            fatalError("Hockey playback payload does not match the site controller")
        }

        let footballRequest = PlaybackRequest(
            endpoint: "/Player/Watch",
            controller: "fbl",
            arguments: ["1", "N", "{}", "false", "true"]
        )
        guard let footballPayload = try? PlaybackPayloadBuilder.makePayload(for: footballRequest),
              footballPayload["code"] as? Int64 == 1,
              footballPayload["quality"] as? String == "9",
              footballPayload["alt"] as? Bool == true else {
            fatalError("Football playback payload does not match the site controller")
        }

        let baseballRequest = PlaybackRequest(
            endpoint: "/Player/Watch_BSB",
            controller: "bsb",
            arguments: ["45", "channel", "home", "0", "false", "{}"]
        )
        let epoch = Date(timeIntervalSince1970: 0)
        guard let baseballPayload = try? PlaybackPayloadBuilder.makePayload(for: baseballRequest, now: epoch),
              baseballPayload["gmd"] as? Int64 == 621_355_968_000_000_000,
              baseballPayload["dateCode"] == nil,
              baseballPayload["isG"] == nil else {
            fatalError("Timestamped playback payload does not match the site controller")
        }

        guard channels.items.contains(where: {
            if case .drmPage = $0.playback { return true }
            return false
        }) else {
            fatalError("DRM page link was not parsed")
        }

        let dynamicGamesPayload = Data(#"""
        [
          {
            "Id": 101,
            "Away": "Lions",
            "Home": "Bengals",
            "GameTime": "/Date(1786665600000)/",
            "IsLive": true,
            "LiveContent": [
              {"id": "01ce0b43-0401-4ab7-b8c3-c85860b8e4bd", "isdrm": true},
              {"id": 7001, "typ": 14, "descweb": "away-key"},
              {"id": 7002, "typ": 14, "descweb": "home-key"},
              {"id": 5001, "typ": 11, "isdrm": false}
            ]
          },
          {
            "Id": 102,
            "Away": "Broncos",
            "Home": "Falcons",
            "GameTimeText": "Friday 8/14/26 7:00 PM ET",
            "IsLive": false,
            "LiveContent": []
          },
          {
            "Id": 103,
            "Away": "Colts",
            "Home": "Patriots",
            "IsLive": true,
            "LiveContent": [
              {"id": 5002, "typ": 11, "isdrm": false}
            ]
          },
          {
            "Id": 104,
            "Away": "Packers",
            "Home": "Steelers",
            "Quarter": "F",
            "IsFinal": true,
            "IsLive": false,
            "LiveContent": []
          }
        ]
        """#.utf8)
        let dynamicGames = HTMLCatalogParser.parseDynamicGames(
            dynamicGamesPayload,
            categoryID: "football",
            controller: "fbl",
            baseURL: baseURL,
            directStreamTemplate: "https://media.example/[key]/master.m3u8?hmac=fixture"
        )
        let normalizedDynamicTime = dynamicGames.first?.subtitle?
            .replacingOccurrences(of: "\u{202F}", with: " ")
        guard dynamicGames.count == 4,
              dynamicGames[0].title == "Lions @ Bengals",
              normalizedDynamicTime?.contains("7:00 PM ET") == true,
              dynamicGames[1].title == "Broncos @ Falcons",
              dynamicGames[1].subtitle == "Friday 8/14/26 7:00 PM ET",
              !dynamicGames[1].isPlayable,
              dynamicGames[3].subtitle == "Final" else {
            fatalError("Dynamic football schedule was not parsed")
        }
        guard dynamicGames[0].hasMultiplePlaybackOptions,
              dynamicGames[0].playbackOptions.prefix(2).map(\.title) == ["Home Feed", "Away Feed"],
              dynamicGames[0].playbackOptions.contains(where: { option in
                  if case .drmPage(let url) = option.playback {
                      return url.lastPathComponent == "01ce0b43-0401-4ab7-b8c3-c85860b8e4bd"
                  }
                  return false
              }),
              case .hls(let homeFeedURL) = dynamicGames[0].playback,
              homeFeedURL.path.contains("aG9tZS1rZXk") else {
            fatalError("Dynamic football broadcast choices were not parsed")
        }
        guard case .request(let dynamicAlternate) = dynamicGames[2].playback,
              dynamicAlternate.endpoint == "/Player/Watch_BKB",
              dynamicAlternate.controller == "bkb",
              dynamicAlternate.arguments.first == "5002" else {
            fatalError("Dynamic alternate game stream was not parsed")
        }

        let templateHTML = #"hky.Watch(1,'live','HOME',1,false,{},null,null,'https://media.example/[key]/master.m3u8?hmac=fixture'.replace('[key]', p.b64u(live.descweb)))"#
        guard HTMLCatalogParser.footballDirectStreamTemplate(in: templateHTML) ==
                "https://media.example/[key]/master.m3u8?hmac=fixture" else {
            fatalError("Football direct-stream template was not discovered")
        }

        let officialBaseballPayload = Data(#"""
        {
          "games": [
            {
              "Id": 901,
              "Away_Name": "Yankees",
              "Home_Name": "Red Sox",
              "DateCode": 20260826,
              "IsLive": true,
              "MediaOptionsForPlayer": [
                {"feed": "AWAY", "mediaPlaybackId": 40, "isDVR": false},
                {"feed": "HOME", "mediaPlaybackId": 41, "isDVR": false}
              ]
            }
          ]
        }
        """#.utf8)
        let officialBaseball = HTMLCatalogParser.parseDynamicGames(
            officialBaseballPayload,
            categoryID: "baseball",
            controller: "bsb",
            baseURL: baseURL
        )
        guard officialBaseball.count == 1,
              officialBaseball[0].title == "Yankees @ Red Sox",
              officialBaseball[0].playbackOptions.map(\.title) == ["Home Feed", "Away Feed"],
              case .request(let homeBaseball) = officialBaseball[0].playback,
              homeBaseball.arguments == ["901", "live", "home", "41", "false", "20260826"],
              case .request(let awayBaseball) = officialBaseball[0].playbackOptions[1].playback,
              awayBaseball.arguments[2] == "away" else {
            fatalError("Baseball Home/Away broadcast choices were not parsed")
        }
        guard let googleBaseballPayload = try? PlaybackPayloadBuilder.makePayload(for: homeBaseball, now: epoch),
              googleBaseballPayload["id"] as? Int64 == 901,
              googleBaseballPayload["mediaId"] as? Int64 == 41,
              googleBaseballPayload["dateCode"] as? Int64 == 20_260_826,
              googleBaseballPayload["isG"] as? Bool == true,
              googleBaseballPayload["gmd"] as? Int64 == 621_355_968_000_000_000 else {
            fatalError("Baseball WatchG payload does not match the site controller")
        }

        let liveShapedBaseballPayload = Data(#"""
        {
          "games": [
            {
              "Id": 903,
              "Away_Name": "Cubs",
              "Home_Name": "Cardinals",
              "DateCode": 20260826,
              "IsLive": true,
              "Media": [
                null,
                {"feed": "AWAY", "mediaPlaybackId": 52},
                {"feed": "HOME", "mediaPlaybackId": 53}
              ],
              "MediaOptionsForPlayer": [null, "CHC", "STL"]
            }
          ]
        }
        """#.utf8)
        let liveShapedBaseball = HTMLCatalogParser.parseDynamicGames(
            liveShapedBaseballPayload,
            categoryID: "baseball",
            controller: "bsb",
            baseURL: baseURL
        )
        guard liveShapedBaseball.count == 1,
              liveShapedBaseball[0].playbackOptions.map(\.title) == ["Home Feed", "Away Feed"],
              case .request(let liveHomeBaseball) = liveShapedBaseball[0].playback,
              liveHomeBaseball.arguments == ["903", "live", "home", "53", "false", "20260826"] else {
            fatalError("Baseball media arrays with scalar labels and null placeholders were not parsed")
        }

        let twinsAthleticsPayload = Data(#"""
        {
          "games": [
            {
              "Id": 823988,
              "Away_Name": "Twins",
              "Home_Name": "Athletics",
              "DateCode": 20260826,
              "IsLive": true,
              "Media": {
                "0": {"feed": "HOME", "mediaPlaybackId": 61},
                "1": {"feed": "AWAY", "mediaPlaybackId": 62}
              },
              "MediaOptionsForPlayer": {"0": "ATH", "1": "MIN"}
            }
          ]
        }
        """#.utf8)
        let twinsAthletics = HTMLCatalogParser.parseDynamicGames(
            twinsAthleticsPayload,
            categoryID: "baseball",
            controller: "bsb",
            baseURL: baseURL
        )
        guard twinsAthletics.count == 1,
              twinsAthletics[0].title == "Twins @ Athletics",
              twinsAthletics[0].playbackOptions.map(\.title) == ["Home Feed", "Away Feed"],
              case .request(let athleticsHome) = twinsAthletics[0].playback,
              athleticsHome.arguments == ["823988", "live", "home", "61", "false", "20260826"],
              let athleticsPayload = try? PlaybackPayloadBuilder.makePayload(for: athleticsHome, now: epoch),
              athleticsPayload["dateCode"] as? Int64 == 20_260_826,
              athleticsPayload["isG"] as? Bool == true else {
            fatalError("Twins @ Athletics numeric-keyed Home/Away feeds were not parsed")
        }

        let splitBaseballPayload = Data(#"""
        {
          "games": [
            {
              "Id": 902,
              "Away_Name": "Cubs",
              "Home_Name": "Cardinals",
              "IsLive": true,
              "Media": [
                {"feed": "AWAY", "mediaPlaybackId": 50},
                {"feed": "HOME", "mediaPlaybackId": 51}
              ],
              "MediaOptionsForPlayer": [
                {"directUrl": "https://media.example/away/master.m3u8"},
                {"directUrl": "https://media.example/home/master.m3u8"}
              ]
            }
          ]
        }
        """#.utf8)
        let splitBaseball = HTMLCatalogParser.parseDynamicGames(
            splitBaseballPayload,
            categoryID: "baseball",
            controller: "bsb",
            baseURL: baseURL
        )
        guard splitBaseball.count == 1,
              splitBaseball[0].playbackOptions.map(\.title) == ["Home Feed", "Away Feed"],
              case .hls(let splitHomeURL) = splitBaseball[0].playback,
              splitHomeURL.absoluteString.contains("/home/") else {
            fatalError("Split baseball media and player options were not paired")
        }

        let baseballPartialHTML = #"""
        <div id="baseball">
          <table><tbody>
            <tr>
              <td><img src="https://media.example/baseball.png"></td>
              <td>Philadelphia Phillies vs. Minnesota Twins</td>
              <td>
                <a ng-click="hky.Watch(-11111113,'live','HOME',1,false,{},null,null,'https://media.example/baseball/master.m3u8?signature=temporary')">Backup</a>
              </td>
            </tr>
            <tr>
              <td>Cleveland Guardians vs. Detroit Tigers</td>
              <td><span>Game has ended.</span></td>
            </tr>
          </tbody></table>
        </div>
        """#
        let baseballCategories = HTMLCatalogParser.parseCatalog(baseballPartialHTML, baseURL: baseURL)
        guard let baseball = baseballCategories.first(where: { $0.id == "baseball" }),
              baseball.items.count == 1,
              baseball.items[0].title == "Philadelphia Phillies vs. Minnesota Twins",
              baseball.items[0].imageURL?.host == "media.example",
              baseball.items[0].isPlayable,
              case .hls(let baseballURL) = baseball.items[0].playback,
              baseballURL.path.hasSuffix("master.m3u8") else {
            fatalError("Lazy-loaded Baseball events were not parsed")
        }

        let scheduledBaseballPayload = Data(#"""
        {
          "games": [
            {
              "Id": 903,
              "Away_Name": "Cardinals",
              "Home_Name": "Cubs",
              "GameTimeText": "Bottom 5th",
              "IsLive": false,
              "MediaOptionsForPlayer": []
            }
          ]
        }
        """#.utf8)
        let scheduledBaseball = HTMLCatalogParser.parseDynamicGames(
            scheduledBaseballPayload,
            categoryID: "baseball",
            controller: "bsb",
            baseURL: baseURL
        )
        let supplementalBaseballHTML = #"""
        <div id="baseball"><table><tr>
          <td>St. Louis Cardinals vs. Chicago Cubs</td>
          <td><button ng-click="hky.Watch(-11111113,'live','HOME',1,false,{},null,null,'https://media.example/cubs/master.m3u8?signature=temporary')">Backup</button></td>
        </tr></table></div>
        """#
        let supplementalBaseball = HTMLCatalogParser.parseCatalog(supplementalBaseballHTML, baseURL: baseURL)
            .first(where: { $0.id == "baseball" })?.items ?? []
        let mergedBaseball = HTMLCatalogParser.mergingSupplementalPlayback(
            supplementalBaseball,
            into: scheduledBaseball
        )
        guard mergedBaseball.count == 1,
              mergedBaseball[0].title == "Cardinals @ Cubs",
              mergedBaseball[0].isPlayable,
              case .hls(let mergedBaseballURL) = mergedBaseball[0].playback,
              mergedBaseballURL.path.hasSuffix("master.m3u8") else {
            fatalError("Baseball backup feeds were not merged into the official schedule")
        }

        let commentOnlyRowHTML = #"""
        <div id="others"><table><tr>
          <td><!-- old provider marker --></td>
          <td><button ng-click="bkb.Watch(6001,'channel','home',false,{})">Watch</button></td>
        </tr></table></div>
        """#
        let commentOnlyCategories = HTMLCatalogParser.parseCatalog(commentOnlyRowHTML, baseURL: baseURL)
        guard commentOnlyCategories.allSatisfy({ $0.items.isEmpty }) else {
            fatalError("HTML comments must not become visible catalog titles")
        }

        let unresolvedTemplateHTML = #"""
        <div id="ncaaf"><table><tr>
          <td>{{game.Away_Name}}</td>
          <td><button ng-click="hky.Watch(-1,'live','HOME',1,false,{},null,null,'https://media.example/template/master.m3u8')">Watch</button></td>
        </tr></table></div>
        """#
        let unresolvedTemplateCategories = HTMLCatalogParser.parseCatalog(unresolvedTemplateHTML, baseURL: baseURL)
        guard unresolvedTemplateCategories.allSatisfy({ $0.items.isEmpty }) else {
            fatalError("Unresolved Angular titles must not become visible catalog items")
        }

        let drmChannelHTML = #"""
        <div class="pdrm-list__items" id="chanList">
          <a class="pdrm-chan" href="/PlayerDRMChannels/1ad12446-8e18-4e57-885e-ce0b17b6e6be" data-name="espn">
            <span class="pdrm-chan__logo"><img src="/Content/Img/media/ESPN.png" alt="ESPN"></span>
            <span class="pdrm-chan__name">ESPN</span>
            <span class="pdrm-chan__cta">Watch</span>
          </a>
          <a class="pdrm-chan" href="/PlayerDRMChannels/1ee7fbd0-c9e9-4dae-a586-240e5b3da34a" data-name="cnn">
            <span class="pdrm-chan__logo"><img src="https://media.example/cnn.png" alt="CNN"></span>
            <span class="pdrm-chan__name">CNN</span>
            <span class="pdrm-chan__cta">Watch</span>
          </a>
        </div>
        """#
        let liveChannels = HTMLCatalogParser.parseDRMChannels(drmChannelHTML, baseURL: baseURL)
        guard liveChannels.count == 2,
              liveChannels[0].name == "CNN",
              liveChannels[0].genre == .news,
              liveChannels[1].name == "ESPN",
              liveChannels[1].genre == .sports,
              case .drmPage(let espnPage) = liveChannels[1].playback,
              espnPage.host == "seasons4u.com" else {
            fatalError("DRM channel lineup was not parsed and grouped")
        }

        let legacyChannelHTML = #"""
        <div id="channels"><table><tbody>
          <tr>
            <td><img src="/Content/Img/media/fox-weather.png"></td>
            <td>Fox Weather</td>
            <td><button ng-click="hky.Watch(-13031,'live','HOME',1,false,{})">Watch</button></td>
          </tr>
          <tr>
            <td>Unmapped Channel</td>
            <td><button ng-click="bkb.Watch(9999,'channel','home',false,{})">Watch</button></td>
          </tr>
        </tbody></table></div>
        """#
        let legacyChannels = HTMLCatalogParser.parseLegacyChannels(legacyChannelHTML, baseURL: baseURL)
        guard legacyChannels.count == 2,
              let foxWeather = legacyChannels.first(where: { $0.id == "legacy:hky:live:-13031" }),
              case .request(let foxWeatherRequest) = foxWeather.playback,
              foxWeatherRequest.endpoint == "/Player/Watch_HKY" else {
            fatalError("Legacy channel playback identities were not parsed")
        }

        let curated = ChannelDirectory.curate(liveChannels + legacyChannels)
        guard curated.map(\.name) == ["CNN", "ESPN", "Fox Weather"],
              curated.map(\.id) == [
                "1ee7fbd0-c9e9-4dae-a586-240e5b3da34a",
                "1ad12446-8e18-4e57-885e-ce0b17b6e6be",
                "legacy:hky:live:-13031"
              ] else {
            fatalError("Curated channel filtering or canonical ordering is incorrect")
        }

        guard ChannelDirectory.channels.count == 66,
              Set(ChannelDirectory.channels.map(\.playbackIdentity)).count == 66,
              ChannelDirectory.channels.allSatisfy({ Int($0.stationID) != nil }),
              ChannelDirectory.channels.first(where: { $0.displayName == "CBS 60fps · New York" })?.stationID == "16689" else {
            fatalError("The curated 66-channel playback/XMLTV mapping is incomplete")
        }

        let xmltv = Data(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="20453"><display-name>WABCDT</display-name></channel>
          <channel id="99999"><display-name>ABC · New York</display-name></channel>
          <programme start="20260814110000 -0400" stop="20260814120000 -0400" channel="20453">
            <title>Morning News</title><desc>Local headlines.</desc><category>News</category>
          </programme>
          <programme start="20260814120000 -0400" stop="20260814130000 -0400" channel="20453">
            <title>Midday</title><icon src="https://media.example/midday.jpg" />
          </programme>
          <programme start="20260814120000 -0400" stop="20260814130000 -0400" channel="99999">
            <title>Display-name collision</title>
          </programme>
        </tv>
        """#.utf8)
        let xmlWindowStart = ISO8601DateFormatter().date(from: "2026-08-14T15:30:00Z")!
        let xmlWindowEnd = ISO8601DateFormatter().date(from: "2026-08-14T16:30:00Z")!
        guard let xmlPrograms = try? XMLTVParser.parse(
            data: xmltv,
            from: xmlWindowStart,
            to: xmlWindowEnd,
            allowedStationIDs: ["20453"]
        ),
              xmlPrograms.keys.sorted() == ["20453"],
              xmlPrograms["20453"]?.map(\.title) == ["Morning News", "Midday"],
              xmlPrograms["20453"]?.first?.synopsis == "Local headlines.",
              xmlPrograms["20453"]?.last?.imageURL?.host == "media.example" else {
            fatalError("XMLTV numeric station matching or time-window filtering is incorrect")
        }

        let streamPayload = Data(#"{"url":"https:\/\/media.example\/live\/master.m3u8?signature=temporary"}"#.utf8)
        guard HTMLCatalogParser.parseHLSURL(from: streamPayload)?.host == "media.example" else {
            fatalError("HLS URL was not parsed")
        }

        let drmHTML = #"""
        <script>
          var source = { hls: 'https://media.example/live/master.m3u8' };
          var drm = { fairplay: {
            certificateURL: '/PlayerDRMChannels/License__?id=temporary',
            headers: { 'Env': 'production', 'Channel-Id': 'temporary-channel' },
            getLicenseServerUrl: function(t) {
              var licenseServerUrl = t.replace("skd://", "https://");
              licenseServerUrl = "https://fairplay-proxy.example/" + licenseServerUrl;
              return licenseServerUrl;
            }
          }};
        </script>
        """#
        let pageURL = URL(string: "https://seasons4u.com/PlayerDRMChannels/International/example")!
        guard let drm = HTMLCatalogParser.parseDRMConfiguration(drmHTML, pageURL: pageURL, baseURL: baseURL),
              drm.certificateURL.host == "seasons4u.com",
              drm.headers["Env"] == "production",
              drm.licenseProxyPrefix == "https://fairplay-proxy.example/" else {
            fatalError("FairPlay configuration was not parsed")
        }

        print("Parser smoke test passed")
    }
}
