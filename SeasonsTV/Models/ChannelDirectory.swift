import Foundation

struct CuratedChannelDefinition: Equatable {
    let displayName: String
    let playbackIdentity: String
    let stationID: String
    let callSign: String
}

enum ChannelDirectory {
    static let channels: [CuratedChannelDefinition] = [
        .init(displayName: "ABC · New York", playbackIdentity: "f94a1f7b-9cc9-4d60-abcb-1b83e4e0d163", stationID: "20453", callSign: "WABCDT"),
        .init(displayName: "ACC Network", playbackIdentity: "736220c2-0584-49f2-8301-dafc41b60c50", stationID: "111871", callSign: "ACC"),
        .init(displayName: "AMC", playbackIdentity: "63a1d590-ba28-45be-9ac3-d4f3a96f285d", stationID: "59337", callSign: "AMCHD"),
        .init(displayName: "AXS TV", playbackIdentity: "9fe38ff1-a391-437d-8929-e7901357579b", stationID: "28506", callSign: "AXSTV"),
        .init(displayName: "BBC America", playbackIdentity: "da2cf322-ef6c-4a01-bbb6-c88043357b3d", stationID: "64492", callSign: "BBCAHD"),
        .init(displayName: "BBC World News", playbackIdentity: "1ed7043d-97d1-4dc6-b329-1c7b6cbf0e21", stationID: "101449", callSign: "BBCWDEH"),
        .init(displayName: "Bloomberg", playbackIdentity: "2aa0449d-8342-467c-9d0f-a7ed7d985a85", stationID: "71799", callSign: "BLOOMHD"),
        .init(displayName: "Bravo", playbackIdentity: "46ea053f-7831-4b28-bfcc-7fc296515024", stationID: "58625", callSign: "BRAVOHD"),
        .init(displayName: "BTN", playbackIdentity: "3513b40b-edf0-4305-9e58-cc3f94d5af26", stationID: "56783", callSign: "BIGTEN"),
        .init(displayName: "Cartoon Network", playbackIdentity: "2951664b-313c-4c0b-b400-b58d7296fa82", stationID: "60048", callSign: "TOONHD"),
        .init(displayName: "CNBC", playbackIdentity: "1d1c473c-9d8d-4b56-a7be-4fe19f05e33e", stationID: "58780", callSign: "CNBCHD"),
        .init(displayName: "CNN", playbackIdentity: "1ee7fbd0-c9e9-4dae-a586-240e5b3da34a", stationID: "58646", callSign: "CNNHD"),
        .init(displayName: "Comedy Central", playbackIdentity: "e0d7e8fd-c995-4f4d-a7d1-1509028dfbc3", stationID: "62420", callSign: "CCHD"),
        .init(displayName: "Discovery Channel", playbackIdentity: "35985f70-44fe-4b4c-857f-2670ec74bc3c", stationID: "56905", callSign: "DSCHD"),
        .init(displayName: "E!", playbackIdentity: "c54ae4fb-b1a6-4cbb-a22a-4ffaab4cc332", stationID: "61812", callSign: "EHD"),
        .init(displayName: "ESPN", playbackIdentity: "1ad12446-8e18-4e57-885e-ce0b17b6e6be", stationID: "32645", callSign: "ESPNHD"),
        .init(displayName: "ESPN News", playbackIdentity: "8f506ece-9d83-4292-a3d9-e507feb06ac2", stationID: "16485", callSign: "ESPNEWS"),
        .init(displayName: "ESPN2", playbackIdentity: "e5f0e8cc-12da-48a9-aa98-ebd7a8a7e477", stationID: "45507", callSign: "ESPN2HD"),
        .init(displayName: "ESPNU", playbackIdentity: "eefc0d5d-25d5-4422-b545-b7c31e7ce9bf", stationID: "60696", callSign: "ESPNUHD"),
        .init(displayName: "Food Network", playbackIdentity: "db5c3856-12a4-4978-9788-1c794be5fd87", stationID: "50747", callSign: "FOODHD"),
        .init(displayName: "FOX · New York", playbackIdentity: "afd29b14-3269-4bac-bef9-f5315df86e8d", stationID: "20360", callSign: "WNYWDT"),
        .init(displayName: "Fox Business", playbackIdentity: "11885abc-cf83-4c42-9362-aa95fee1a1a1", stationID: "58718", callSign: "FBNHD"),
        .init(displayName: "Fox News", playbackIdentity: "eba5c11a-7a50-415a-bbd6-3ddb8f328e8f", stationID: "60179", callSign: "FNCHD"),
        .init(displayName: "Freeform", playbackIdentity: "202d30c6-76b7-4581-b078-9b6f49b9deb6", stationID: "10093", callSign: "FREEFRM"),
        .init(displayName: "FS1", playbackIdentity: "ecdd7b1b-976c-4f07-b70e-4e1e8ee42daa", stationID: "82547", callSign: "FS1HD"),
        .init(displayName: "FX", playbackIdentity: "e148a440-889a-4efa-aee2-b1bf06b7ad1e", stationID: "58574", callSign: "FXHD"),
        .init(displayName: "Golf Channel", playbackIdentity: "dc585211-cd6c-4f0b-aaa9-ac6dcbf1c998", stationID: "61854", callSign: "GOLFHD"),
        .init(displayName: "Hallmark", playbackIdentity: "1fc0b596-d783-4f0f-84c0-9de7b412e8eb", stationID: "66268", callSign: "HALLHD"),
        .init(displayName: "HGTV", playbackIdentity: "5b4aad51-84c2-4c5d-9fe1-6f84fc736efa", stationID: "14902", callSign: "HGTV"),
        .init(displayName: "Investigation Discovery", playbackIdentity: "3414f755-16f3-4e3e-affe-0b579c5067ec", stationID: "65342", callSign: "IDHD"),
        .init(displayName: "Lifetime", playbackIdentity: "b5c96a02-4a84-40b6-b6d4-72088002b2aa", stationID: "60150", callSign: "LIFEHD"),
        .init(displayName: "Lifetime Movie Network", playbackIdentity: "899bb811-0ed0-4106-9032-1dc583ef2d81", stationID: "55887", callSign: "LMNHD"),
        .init(displayName: "MLB Network", playbackIdentity: "afecb1b2-7c7c-4b87-a1ac-4632a10420e3", stationID: "62081", callSign: "MLBHD"),
        .init(displayName: "MLB Strike Zone", playbackIdentity: "a560126f-4e8e-4c94-a69d-608a1ac45c58", stationID: "75220", callSign: "MLBSZHD"),
        .init(displayName: "MSNBC", playbackIdentity: "009f9cd8-3a7a-487c-b9c1-f13b8d3adc3c", stationID: "64241", callSign: "MSNOWHD"),
        .init(displayName: "MTV", playbackIdentity: "90544673-e787-4078-b482-46897553e254", stationID: "60964", callSign: "MTVHD"),
        .init(displayName: "NBA TV", playbackIdentity: "846a3549-4d83-4b35-b399-759e72f5dff2", stationID: "45526", callSign: "NBATVHD"),
        .init(displayName: "NBC · Los Angeles", playbackIdentity: "15530ed4-5f86-4eec-842c-3b48e1f10195", stationID: "19568", callSign: "KNBCDT"),
        .init(displayName: "NBC · Boston", playbackIdentity: "155765d4-5f86-4eec-842c-3b48e1f10195", stationID: "91446", callSign: "WBTSCD"),
        .init(displayName: "NBC · New York", playbackIdentity: "6321f4e7-7529-46af-ab0c-1b151c2fe61d", stationID: "20459", callSign: "WNBCDT"),
        .init(displayName: "NFL Network", playbackIdentity: "029726c2-a92a-447d-a256-964259ce95ca", stationID: "45399", callSign: "NFLHD"),
        .init(displayName: "NHL Network", playbackIdentity: "e01bb24e-a2ff-4f42-afdf-807fcb52343d", stationID: "58690", callSign: "NHLHD"),
        .init(displayName: "Oxygen", playbackIdentity: "17359ab9-e4c5-4516-8743-8d6789ed665f", stationID: "70522", callSign: "OXYGNHD"),
        .init(displayName: "Paramount Network", playbackIdentity: "892d80b7-e4ce-4850-a155-a791988ae913", stationID: "59186", callSign: "PARHD"),
        .init(displayName: "NFL RedZone", playbackIdentity: "89b2ae46-d203-4198-b483-95b69bbb5cfb", stationID: "65025", callSign: "NFLNRZD"),
        .init(displayName: "REELZ", playbackIdentity: "32af2a92-67fb-44fc-a710-e013907fe84a", stationID: "68385", callSign: "REELZHD"),
        .init(displayName: "SEC Network", playbackIdentity: "20496edb-4217-4fb7-90cb-21b3389672f9", stationID: "89714", callSign: "SECH"),
        .init(displayName: "Showtime", playbackIdentity: "17093ef0-3435-469d-a572-2b7c08d4c3f8", stationID: "21868", callSign: "PARSHOH"),
        .init(displayName: "Syfy", playbackIdentity: "67c904f3-7f82-4e26-8629-2664afdd2dca", stationID: "58623", callSign: "SYFYHD"),
        .init(displayName: "TBS", playbackIdentity: "428c625c-ea2b-4ad5-9d61-3fe672ea7668", stationID: "58515", callSign: "TBSHD"),
        .init(displayName: "TCM", playbackIdentity: "d2730af3-6b72-4ec3-bc70-b4439cdb15e9", stationID: "64312", callSign: "TCMHD"),
        .init(displayName: "Tennis Channel", playbackIdentity: "1cf50ba8-3956-4ed4-9640-fb6b369a1453", stationID: "33395", callSign: "TENNIS"),
        .init(displayName: "TLC", playbackIdentity: "390630dd-c302-47f5-8c25-f51259993504", stationID: "57391", callSign: "TLCHD"),
        .init(displayName: "TNT", playbackIdentity: "102fa8ba-72dd-4e15-8784-8916729e8d5e", stationID: "42642", callSign: "TNTHD"),
        .init(displayName: "truTV", playbackIdentity: "b5e0f0dc-199c-40fc-b2f1-154597b54b7f", stationID: "64490", callSign: "TRUTVHD"),
        .init(displayName: "UNIVERSO", playbackIdentity: "6eb90a9b-2da1-4469-bd63-9801c8df705b", stationID: "91588", callSign: "UNVSOHD"),
        .init(displayName: "USA", playbackIdentity: "67ed0315-e3d4-4f8f-bbc5-442d4a2305cc", stationID: "58452", callSign: "USAHD"),
        .init(displayName: "Willow Extra", playbackIdentity: "8b47644d-0ba3-4d36-a501-b2959ae9dd7d", stationID: "100316", callSign: "WILLOW2"),
        .init(displayName: "Fox Soccer Plus", playbackIdentity: "legacy:bkb:channel:605", stationID: "66879", callSign: "FSP"),
        .init(displayName: "CBS · New York", playbackIdentity: "legacy:bkb:channel:5012", stationID: "16689", callSign: "WCBSDT"),
        .init(displayName: "CBS 60fps · New York", playbackIdentity: "legacy:bkb:channel:802", stationID: "16689", callSign: "WCBSDT"),
        .init(displayName: "CBS Sports Network", playbackIdentity: "legacy:bkb:channel:804", stationID: "59250", callSign: "CBSSNHD"),
        .init(displayName: "PBS · State College", playbackIdentity: "legacy:bkb:channel:5037", stationID: "45799", callSign: "WPSUDT"),
        .init(displayName: "Fox Deportes", playbackIdentity: "legacy:bkb:channel:604", stationID: "72189", callSign: "FXDEPHD"),
        .init(displayName: "Fox Weather", playbackIdentity: "legacy:hky:live:-13031", stationID: "93141", callSign: "FOXWX"),
        .init(displayName: "The Weather Channel", playbackIdentity: "legacy:hky:live:-13032", stationID: "58812", callSign: "WEATHHD")
    ]

    private static let byPlaybackIdentity = Dictionary(
        uniqueKeysWithValues: channels.map { ($0.playbackIdentity, $0) }
    )

    static func definition(forPlaybackIdentity identity: String) -> CuratedChannelDefinition? {
        byPlaybackIdentity[identity]
    }

    static func brandAssetName(forPlaybackIdentity identity: String) -> String? {
        guard let definition = byPlaybackIdentity[identity] else { return nil }
        return "ChannelLogo_\(definition.stationID)"
    }

    static func curate(_ discovered: [LiveChannel]) -> [LiveChannel] {
        let available = Dictionary(discovered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return channels.compactMap { definition in
            guard let channel = available[definition.playbackIdentity] else { return nil }
            return LiveChannel(
                id: definition.playbackIdentity,
                name: definition.displayName,
                logoURL: channel.logoURL,
                playback: channel.playback,
                genre: genre(for: definition.displayName)
            )
        }
    }

    static func explicitMappings(for channels: [LiveChannel]) -> [ChannelStationMapping] {
        channels.compactMap { channel in
            guard let definition = byPlaybackIdentity[channel.id] else { return nil }
            return ChannelStationMapping(
                channelID: channel.id,
                stationID: definition.stationID,
                provenance: .explicit
            )
        }
    }

    static func genre(for name: String) -> ChannelGenre {
        let value = name.lowercased()
        if containsAny(value, ["deportes", "universo"]) { return .spanish }
        if containsAny(value, [
            "espn", "fs1", "acc network", "btn", "golf", "mlb", "nba", "nfl", "nhl",
            "redzone", "sec network", "sports", "tennis", "willow", "soccer"
        ]) { return .sports }
        if containsAny(value, [
            "news", "cnn", "cnbc", "msnbc", "bloomberg", "fox business", "fox weather",
            "weather channel", "bbc world"
        ]) { return .news }
        if containsAny(value, ["cartoon"]) { return .kids }
        if containsAny(value, [
            "discovery", "food", "hgtv", "tlc", "hallmark", "lifetime", "investigation"
        ]) { return .lifestyle }
        return .entertainment
    }

    private static func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains(where: value.contains)
    }
}
