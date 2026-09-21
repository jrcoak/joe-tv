import Foundation

@main enum JoeTVGuideSizingSmoke {
    private static var checks = 0

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }

    static func main() {
        let compact = JoeTVGuideMetrics(size: .compact)
        let standard = JoeTVGuideMetrics(size: .standard)

        check(compact.channelWidth == 250 && compact.rowHeight == 66
            && compact.rulerHeight == 38 && compact.pointsPerMinute == 8
            && compact.gridHeight == 555, "Compact geometry changed from the released guide")
        check(compact.channelLogoWidth == 72 && compact.channelLogoHeight == 45
            && compact.channelFontSize == 16 && compact.channelLineLimit == 1,
            "Compact channel presentation changed")
        check(compact.channelHeaderFontSize == 12 && compact.rulerFontSize == 12
            && compact.programFontSize == 14 && compact.programLineLimit == 1
            && compact.programTimeFontSize == 10 && compact.unavailableFontSize == 14
            && compact.minimumProgramWidth == 94, "Compact guide typography changed")

        let visibleStandardRows = (standard.gridHeight - standard.rulerHeight) / standard.rowHeight
        check(visibleStandardRows >= 5.5 && visibleStandardRows < 6,
            "Standard guide no longer presents roughly six readable rows")
        check(standard.channelWidth == 330 && standard.rowHeight == 94
            && standard.rulerHeight == 44 && standard.gridHeight == 600,
            "Standard guide geometry changed from native acceptance")
        check(standard.channelFontSize == 24 && standard.channelHeaderFontSize == 16
            && standard.rulerFontSize == 20 && standard.programFontSize == 24
            && standard.programTimeFontSize == 18 && standard.unavailableFontSize == 22,
            "Standard guide typography changed from native acceptance")
        check(standard.channelFontSize > compact.channelFontSize
            && standard.programFontSize > compact.programFontSize
            && standard.programTimeFontSize > compact.programTimeFontSize
            && standard.rulerFontSize > compact.rulerFontSize,
            "Standard guide typography is not larger than Compact")
        check(standard.channelLineLimit == 2 && standard.programLineLimit == 2,
            "Standard guide does not preserve two-line channel and program titles")
        check(standard.pointsPerMinute == compact.pointsPerMinute,
            "Guide size changed the shared timeline scale")

        print("Joe-TV guide sizing passed (\(checks) checks; Compact preservation and Standard readability)")
    }
}
