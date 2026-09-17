import Foundation

// Deterministic host microbenchmark: XML decoding only, not network, UI or tvOS latency.
@main
enum GuideParserBenchmark {
    static func main() throws {
        let stationCount = 70
        let programsPerStation = 48
        let start = Date(timeIntervalSince1970: 1_789_603_200)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        let stationIDs = Set((0..<stationCount).map { "station-\($0)" })
        var xml = "<?xml version=\"1.0\"?><tv>"
        for station in 0..<stationCount {
            xml += "<channel id=\"station-\(station)\"><display-name>Fixture \(station)</display-name></channel>"
            for slot in 0..<programsPerStation {
                let from = formatter.string(from: start.addingTimeInterval(Double(slot) * 1_800))
                let to = formatter.string(from: start.addingTimeInterval(Double(slot + 1) * 1_800))
                xml += "<programme start=\"\(from)\" stop=\"\(to)\" channel=\"station-\(station)\"><title>Fixture Program \(slot)</title><desc>Deterministic guide sample.</desc></programme>"
            }
        }
        xml += "</tv>"
        let data = Data(xml.utf8)
        let end = start.addingTimeInterval(18 * 3_600)
        let clock = ContinuousClock()
        var samples: [Double] = []
        for iteration in 0..<6 {
            let began = clock.now
            let programs = try XMLTVParser.parse(data: data, from: start, to: end, allowedStationIDs: stationIDs)
            let elapsed = began.duration(to: clock.now)
            let count = programs.values.reduce(0) { $0 + $1.count }
            guard count == stationCount * 36 else { fatalError("Unexpected program count: \(count)") }
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            if iteration > 0 { samples.append(seconds * 1_000) }
        }
        let sorted = samples.sorted()
        print("stations=\(stationCount) input_programs=\(stationCount * programsPerStation) selected_programs=\(stationCount * 36) bytes=\(data.count)")
        print("warmup=1 samples_ms=\(samples.map { String(format: "%.2f", $0) }.joined(separator: ","))")
        print(String(format: "median_ms=%.2f min_ms=%.2f max_ms=%.2f", sorted[sorted.count / 2], sorted[0], sorted[sorted.count - 1]))
    }
}
