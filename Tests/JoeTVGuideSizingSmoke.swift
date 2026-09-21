import Foundation

@main enum JoeTVGuideSizingSmoke {
    private static var checks = 0

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }

    static func main() {
        let standard = JoeTVGuideMetrics(size: .standard)
        let large = JoeTVGuideMetrics(size: .large)

        check(standard.channelWidth == 250 && standard.rowHeight == 66
            && standard.rulerHeight == 38 && standard.pointsPerMinute == 8
            && standard.gridHeight == 555, "Standard geometry changed from the accepted guide")
        check(standard.channelLogoWidth == 72 && standard.channelLogoHeight == 45
            && standard.channelFontSize == 16 && standard.channelLineLimit == 1,
            "Standard channel presentation changed")
        check(standard.channelHeaderFontSize == 12 && standard.rulerFontSize == 12
            && standard.programFontSize == 14 && standard.programLineLimit == 1
            && standard.programTimeFontSize == 10 && standard.unavailableFontSize == 14
            && standard.minimumProgramWidth == 94, "Standard guide typography changed")

        let visibleLargeRows = (large.gridHeight - large.rulerHeight) / large.rowHeight
        check(visibleLargeRows >= 5.5 && visibleLargeRows < 6,
            "Large guide no longer presents roughly six readable rows")
        check(large.channelFontSize > standard.channelFontSize
            && large.programFontSize > standard.programFontSize
            && large.programTimeFontSize > standard.programTimeFontSize
            && large.rulerFontSize > standard.rulerFontSize,
            "Large guide typography is not larger than Standard")
        check(large.channelLineLimit == 2 && large.programLineLimit == 2,
            "Large guide does not preserve two-line channel and program titles")
        check(large.pointsPerMinute == standard.pointsPerMinute,
            "Guide size changed the shared timeline scale")

        print("Joe-TV guide sizing passed (\(checks) checks; Standard preservation and Large readability)")
    }
}
