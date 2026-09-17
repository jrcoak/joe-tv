import Foundation

// Pure production-policy tests. No AppModel/provider/session/defaults construction.
@main
enum GuideMergeSmoke {
    typealias Policy = EPGGuideMergePolicy
    static let start = Date(timeIntervalSince1970: 1_789_603_200)
    static let end = start.addingTimeInterval(3_600)
    static let oldTime = start.addingTimeInterval(-600)
    static let freshTime = start.addingTimeInterval(60)

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    static func program(_ id: String, _ station: String, from: TimeInterval = 0, to: TimeInterval = 1_800) -> EPGProgram {
        EPGProgram(id: id, stationID: station, title: "Title \(id)", start: start.addingTimeInterval(from),
                   end: start.addingTimeInterval(to), synopsis: "Description", category: "News", imageURL: nil)
    }
    static func window(_ rows: [String: [EPGProgram]], fetchedAt: Date = oldTime,
                       from: Date = start, to: Date = end) -> EPGGuideWindow {
        EPGGuideWindow(start: from, end: to, programsByStationID: rows, fetchedAt: fetchedAt)
    }
    static func success(_ channels: Set<String>, _ window: EPGGuideWindow, _ mappings: [(String, String)]) -> Policy.Source {
        .init(channelIDs: channels, outcome: .loaded(window: window, mappings: mappings.map {
            ChannelStationMapping(channelID: $0.0, stationID: $0.1, provenance: .provider)
        }))
    }
    static func failure(_ channels: Set<String>, _ message: String = "Fixture failure") -> Policy.Source {
        .init(channelIDs: channels, outcome: .failed(message: message))
    }
    static func merged(_ sources: [Policy.Source], cached: EPGGuideWindow? = nil,
                       mappings: [String: String] = [:], from: Date = start, to: Date = end) -> Policy.Merge {
        Policy.merge(sources: sources, cached: cached, cachedMappings: mappings, from: from, to: to)
    }
    static func loaded(_ result: Policy.Merge) -> EPGGuideWindow {
        guard case .loaded(let window) = result.state else { fatalError("Expected loaded guide") }
        return window
    }
    static func failed(_ result: Policy.Merge, message: String = "Fixture failure") -> EPGGuideWindow? {
        guard case .failed(let actual, let window) = result.state else { fatalError("Expected failed guide") }
        check(actual == message, "Changed safe error surface")
        return window
    }

    static func main() {
        let a = program("old-a", "a"), b = program("old-b", "b")
        let newA = program("new-a", "a"), newB = program("new-b", "b")
        let firstA = success(["channel-a"], window(["a": [a]]), [("channel-a", "a")])
        let firstB = success(["channel-b"], window(["b": [b]]), [("channel-b", "b")])
        let initial = merged([firstA, firstB])
        let knownGood = loaded(initial)
        check(knownGood == window(["a": [a], "b": [b]]), "Two-source seed lost programs or provenance")
        check(initial.mappings == ["channel-a": "a", "channel-b": "b"], "Seed mappings lost")

        // Reproduce the original loadedResults-only merge: one success discards b.
        let legacyLoadedResults = [window(["a": [newA]], fetchedAt: freshTime)]
        let legacyRows = legacyLoadedResults.reduce(into: [String: [EPGProgram]]()) { result, window in
            result.merge(window.programsByStationID) { $0 + $1 }
        }
        check(legacyRows["b"] == nil, "Fixture no longer demonstrates original partial loss")

        let refreshedA = success(["channel-a"], window(["a": [newA]], fetchedAt: freshTime), [("channel-a", "a")])
        let refreshedB = success(["channel-b"], window(["b": [newB]], fetchedAt: freshTime), [("channel-b", "b")])
        let partial = merged([refreshedA, failure(["channel-b"])], cached: knownGood, mappings: initial.mappings)
        check(failed(partial) == window(["a": [newA], "b": [b]]), "Partial refresh failed to retain b / old age")
        check(partial.mappings == initial.mappings, "Failed source mapping lost")
        let opposite = merged([failure(["channel-a"]), refreshedB], cached: knownGood, mappings: initial.mappings)
        check(failed(opposite) == window(["a": [a], "b": [newB]]), "Opposite-source failure lost a")
        check(opposite.mappings == initial.mappings, "Opposite-source mapping lost")

        // Aggregate timestamp remains conservatively old through repeated partials.
        let reversedPartial = merged([refreshedB, failure(["channel-a"])], cached: failed(partial), mappings: partial.mappings)
        check(failed(reversedPartial) == window(["a": [newA], "b": [newB]]), "Repeated partial lost state or fabricated freshness")
        let recovered = merged([refreshedA, refreshedB], cached: failed(reversedPartial), mappings: reversedPartial.mappings)
        check(loaded(recovered) == window(["a": [newA], "b": [newB]], fetchedAt: freshTime), "Full recovery did not replace aggregate age")

        // Success is authoritative even with no programs or no mappings.
        for emptyMappings in [[("channel-a", "a")], []] {
            let empty = success(["channel-a"], window([:], fetchedAt: freshTime), emptyMappings)
            let result = merged([empty, failure(["channel-b"])], cached: knownGood, mappings: initial.mappings)
            check(failed(result)?.programsByStationID["a", default: []].isEmpty == true, "Successful empty resurrected a")
            check(failed(result)?.programsByStationID["b"] == [b], "Successful empty lost failed b")
            check(result.mappings["channel-a"] == emptyMappings.first?.1 && result.mappings["channel-b"] == "b", "Authoritative mapping removal lost")
        }
        let emptyAll = merged([success(["channel-a"], window([:], fetchedAt: freshTime), []),
                               success(["channel-b"], window([:], fetchedAt: freshTime.addingTimeInterval(30)), [])],
                              cached: knownGood, mappings: initial.mappings)
        check(loaded(emptyAll) == window([:], fetchedAt: freshTime) && emptyAll.mappings.isEmpty, "All-empty success not authoritative")

        // Remapped successes drop obsolete stations and unrelated returned mappings.
        let changedA = program("changed-a", "new-station-a")
        let changedB = program("changed-b", "new-station-b")
        let remapped = merged([
            success(["channel-a"], window(["new-station-a": [changedA], "a": [a], "intruder": [program("x", "intruder")]], fetchedAt: freshTime),
                    [("channel-a", "new-station-a"), ("removed-channel", "intruder")]),
            success(["channel-b"], window(["new-station-b": [changedB]], fetchedAt: freshTime.addingTimeInterval(-10)), [("channel-b", "new-station-b")])
        ], cached: knownGood, mappings: initial.mappings)
        check(loaded(remapped) == window(["new-station-a": [changedA], "new-station-b": [changedB]], fetchedAt: freshTime.addingTimeInterval(-10)), "Remapped success leaked obsolete/unrelated rows")
        check(remapped.mappings == ["channel-a": "new-station-a", "channel-b": "new-station-b"], "Remapped channels incorrect")

        // Both failures retain only requested mapped rows overlapping both windows.
        let crossing = program("crossing", "a", from: -300, to: 300)
        let late = program("late", "a", from: 2_400, to: 4_000)
        let expired = program("expired", "a", from: -600, to: 0)
        let future = program("future", "a", from: 3_600, to: 4_000)
        let badStation = program("wrong-bucket", "z")
        let unusableRange = program("reversed", "a", from: 1_200, to: 600)
        let wideCache = window(["a": [late, future, crossing, expired, badStation, unusableRange], "b": [b], "removed": [program("removed", "removed")]],
                               from: start.addingTimeInterval(-3_600), to: end.addingTimeInterval(3_600))
        let filtered = merged([failure(["channel-a"]), failure(["channel-b"])], cached: wideCache,
                              mappings: initial.mappings.merging(["gone": "removed"]) { $1 })
        check(failed(filtered) == window(["a": [crossing, late], "b": [b]]), "All-failure did not filter time, station or removed channels")
        check(filtered.mappings == initial.mappings, "Removed channel mapping survived")
        check(failed(filtered)?.programsByStationID["a"]?.first?.start == crossing.start &&
              failed(filtered)?.programsByStationID["a"]?.last?.end == late.end, "Merge invented clipped program times")
        let shifted = merged([failure(["channel-a"])], cached: wideCache, mappings: initial.mappings,
                             from: start.addingTimeInterval(1_800), to: end)
        check(failed(shifted) == window(["a": [late]], from: start.addingTimeInterval(1_800)), "Requested viewport filtering failed")
        let narrowCache = window(["a": [a, future]], to: start.addingTimeInterval(600))
        let narrow = merged([failure(["channel-a"])], cached: narrowCache, mappings: initial.mappings)
        check(failed(narrow) == window(["a": [a]]), "Cache coverage admitted an outside program")

        // A known long program proves its own coverage beyond the old viewport.
        // Empty/expired stations cannot carry mappings into that disjoint viewport.
        let longRunning = program("long", "a", from: 0, to: 7_200)
        let shortViewport = window(["a": [longRunning], "b": [b]], to: start.addingTimeInterval(600))
        let laterStart = start.addingTimeInterval(3_600), laterEnd = start.addingTimeInterval(5_400)
        let bridge = merged([failure(["channel-a", "channel-b"])], cached: shortViewport,
                            mappings: initial.mappings, from: laterStart, to: laterEnd)
        check(failed(bridge) == window(["a": [longRunning]], from: laterStart, to: laterEnd), "Known cross-viewport program was lost or altered")
        check(bridge.mappings == ["channel-a": "a"], "Expired station mapping crossed disjoint viewports")
        let emptyDisjoint = merged([failure(["channel-a"])], cached: window([:], to: start.addingTimeInterval(600)),
                                   mappings: initial.mappings, from: laterStart, to: laterEnd)
        check(failed(emptyDisjoint) == nil && emptyDisjoint.mappings.isEmpty, "Mapping-only disjoint cache invented coverage")
        let expiredDisjoint = merged([failure(["channel-b"])], cached: shortViewport, mappings: initial.mappings,
                                     from: laterStart, to: laterEnd)
        check(failed(expiredDisjoint) == nil && expiredDisjoint.mappings.isEmpty, "Expired-only disjoint cache invented coverage")

        // No usable cache, missing mappings and disjoint windows cannot invent data.
        for candidate in [Optional<EPGGuideWindow>.none, window(["a": [a]], from: end, to: end.addingTimeInterval(600))] {
            let result = merged([failure(["channel-a"])], cached: candidate, mappings: initial.mappings)
            check(failed(result) == nil && result.mappings.isEmpty, "No overlapping cache must stay nil")
        }
        let unowned = merged([failure(["channel-a"])], cached: knownGood)
        check(failed(unowned) == nil && unowned.mappings.isEmpty, "Unmapped cached rows resurrected")
        let coldPartial = merged([refreshedA, failure(["channel-b"])])
        check(failed(coldPartial) == window(["a": [newA]], fetchedAt: freshTime), "Cold partial lost success or invented prior data")
        let mapOnly = merged([failure(["channel-a"])], cached: window([:]), mappings: initial.mappings)
        check(failed(mapOnly) == window(["a": []]) && mapOnly.mappings == ["channel-a": "a"], "Prior empty mapping lost or marked fresh")
        let unknownAge = merged([refreshedA, failure(["channel-b"])], cached: window(["b": [b]], fetchedAt: .distantPast), mappings: initial.mappings)
        check(failed(unknownAge)?.fetchedAt == .distantPast, "Unknown age was made fresh")

        // Provider absence is a visible failure with the same retention rules.
        let unavailable = Policy.Source(channelIDs: ["channel-b"], outcome: .unavailable)
        let absent = merged([refreshedA, unavailable], cached: knownGood, mappings: initial.mappings)
        check(failed(absent, message: "Programming details are unavailable.") == window(["a": [newA], "b": [b]]), "Missing provider silently accepted or lost cache")
        let coldAbsent = merged([unavailable])
        check(failed(coldAbsent, message: "Programming details are unavailable.") == nil && coldAbsent.mappings.isEmpty, "Cold missing provider invented content")
        let noChannels = merged([.init(channelIDs: [], outcome: .unavailable)], cached: knownGood, mappings: initial.mappings)
        check(noChannels.state == .unavailable && noChannels.mappings.isEmpty, "Empty requested groups retained data")
        let noSources = merged([], cached: knownGood, mappings: initial.mappings)
        check(noSources.state == .unavailable && noSources.mappings.isEmpty, "No sources retained data")

        // Shared station: successful claims own its body, including mapping removal.
        let shared = program("old-shared", "shared")
        let sharedCache = window(["shared": [shared]])
        let sharedMappings = ["channel-a": "shared", "channel-b": "shared"]
        for rows in [[], [program("new-shared", "shared")]] {
            let result = merged([success(["channel-a"], window(["shared": rows], fetchedAt: freshTime), [("channel-a", "shared")]),
                                 failure(["channel-b"])], cached: sharedCache, mappings: sharedMappings)
            check(failed(result)?.programsByStationID["shared"] == rows && result.mappings == sharedMappings, "Shared-station stale rows resurrected")
            check(failed(result)?.fetchedAt == oldTime, "Retained shared mapping became fresh")
        }
        let remappedShared = merged([success(["channel-a"], window(["new-station-a": [changedA]], fetchedAt: freshTime), [("channel-a", "new-station-a")]),
                                     failure(["channel-b"])], cached: sharedCache, mappings: sharedMappings)
        check(failed(remappedShared)?.programsByStationID["shared"] == nil && remappedShared.mappings["channel-b"] == "shared", "Obsolete shared rows resurrected after remap")
        let emptyShared = merged([success(["channel-a"], window([:], fetchedAt: freshTime), []), failure(["channel-b"])], cached: sharedCache, mappings: sharedMappings)
        check(failed(emptyShared)?.programsByStationID.isEmpty == true && emptyShared.mappings == ["channel-b": "shared"], "Empty shared claim resurrected old contribution")

        // Shared successful stations are deduplicated and deterministically sorted.
        let earlier = program("earlier", "shared", from: -20, to: 100)
        let tieA = program("tie-a", "shared"), tieZ = program("tie-z", "shared")
        let sharedA = success(["channel-a"], window(["shared": [tieZ, earlier, tieA]], fetchedAt: freshTime), [("channel-a", "shared")])
        let sharedB = success(["channel-b"], window(["shared": [tieA]], fetchedAt: oldTime), [("channel-b", "shared")])
        let ordered = merged([sharedA, sharedB])
        check(loaded(ordered) == window(["shared": [earlier, tieA, tieZ]]), "Shared mapping duplicated programs or unstable sort")
        let reordered = merged([sharedB, sharedA])
        check(reordered.state == ordered.state && reordered.mappings == ordered.mappings, "Independent source order changed nonconflicting result")
        let reversedSources = merged([failure(["channel-b"]), refreshedA], cached: knownGood, mappings: initial.mappings)
        check(reversedSources.state == partial.state && reversedSources.mappings == partial.mappings, "Partial result depends on completion order")
        print("Guide merge smoke passed: loss reproduction, partial retention, authoritative empty, remapping, filtering, provenance, recovery and absence")
    }
}
