import SwiftUI

// MARK: - Home

struct JoeTVHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var lastFocusedFavoriteID: String?
    @FocusState private var focusedID: String?
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private var guideWindow: EPGGuideWindow? { model.epgState.usableWindow }
    private let heroTitleWidth: CGFloat = 720
    private let heroDescriptionWidth: CGFloat = 600

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            GeometryReader { geometry in
                let channel = featuredChannel(at: context.date)

                ZStack(alignment: .bottomLeading) {
                    JoeTVHeroBackdrop(event: nil, channel: channel)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.02),
                            Color.black.opacity(0.36),
                            SeasonTheme.background.opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 100)
                        heroCopy(channel: channel, at: context.date)
                        Spacer(minLength: 30)
                        nowAndNext(at: context.date)
                    }
                    .padding(.horizontal, SeasonTheme.horizontalInset)
                    .padding(.bottom, 38)
                }
            }
        }
        .background(SeasonTheme.background)
        .onAppear { restoreFocus() }
        .onChange(of: entryFocusRequest) { _, _ in restoreFocus() }
        .onChange(of: focusedID) { _, identifier in
            guard let identifier, identifier.hasPrefix("channel:") else { return }
            lastFocusedFavoriteID = String(identifier.dropFirst("channel:".count))
        }
        .onExitCommand { onFocusNavigation() }
    }

    @ViewBuilder
    private func heroCopy(channel: LiveChannel?, at date: Date) -> some View {
        if let channel {
            let program = nowPlaying(on: channel, at: date)
            VStack(alignment: .leading, spacing: 15) {
                JoeTVLiveEyebrow(text: channel.name)
                Text(program?.title ?? channel.name)
                    .font(.system(size: 68, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(width: heroTitleWidth, alignment: .leading)

                if let synopsis = program?.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.system(size: 20))
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .lineLimit(2)
                        .frame(width: heroDescriptionWidth, alignment: .leading)
                }

                HStack(spacing: 14) {
                    Button { Task { await model.play(channel) } } label: {
                        Label("Watch live", systemImage: "play.fill")
                    }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                    .focused($focusedID, equals: "hero-watch")
                    .onKeyPress(.upArrow) {
                        onFocusNavigation()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        focusFavoriteRail()
                        return .handled
                    }
                    .onMoveCommand(perform: handleHeroMove)

                    Button { model.destination = .liveTV } label: {
                        Label("Open guide", systemImage: "rectangle.grid.1x2")
                    }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: false))
                    .focused($focusedID, equals: "hero-guide")
                    .onKeyPress(.upArrow) {
                        onFocusNavigation()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        focusFavoriteRail()
                        return .handled
                    }
                    .onMoveCommand(perform: handleHeroMove)
                }
                .padding(.top, 4)
            }
            // Make the whole hero band a focus destination above the horizontal rail.
            // Without this guide, tvOS can briefly choose the full-width navigation bar
            // before the explicit Favorites → hero redirect takes effect.
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("LIVE TELEVISION, ALIVE")
                    .font(.caption.monospaced().weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(SeasonTheme.liveSignal)
                Text("Your night starts here.")
                    .font(.system(size: 68, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                Button { model.destination = .liveTV } label: {
                    Label("Open guide", systemImage: "rectangle.grid.1x2")
                }
                .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                .focused($focusedID, equals: "hero-guide")
                .onKeyPress(.upArrow) {
                    onFocusNavigation()
                    return .handled
                }
                .onMoveCommand(perform: handleHeroMove)
            }
        }
    }

    private func nowAndNext(at date: Date) -> some View {
        let favoriteChannels = model.favoriteLiveChannels
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("FAVORITES")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(SeasonTheme.paper)
                Text("Live channels")
                    .font(.system(size: 15))
                    .foregroundStyle(SeasonTheme.secondaryText)
                Spacer()
                Text(date, format: .dateTime.hour().minute())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }

            if favoriteChannels.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(SeasonTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No favorite channels yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SeasonTheme.paper)
                        Text("Choose favorites in Settings → Channels.")
                            .font(.system(size: 13))
                            .foregroundStyle(SeasonTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 128)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.42))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(favoriteChannels) { channel in
                            Button { Task { await model.play(channel) } } label: {
                                JoeTVNowCard(
                                    channel: channel,
                                    program: nowPlaying(on: channel, at: date),
                                    next: nextProgram(on: channel, at: date),
                                    date: date
                                )
                            }
                            .buttonStyle(JoeTVCardButtonStyle())
                            .focused($focusedID, equals: "channel:\(channel.id)")
                            .onKeyPress(.upArrow) {
                                focusPrimaryHero()
                                return .handled
                            }
                            .onMoveCommand { direction in
                                if direction == .up { focusPrimaryHero() }
                            }
                        }
                    }
                    // Focused tvOS cards scale beyond their nominal frame. Keep a focus-safe
                    // gutter inside the scroll content so the first and last outlines are not clipped.
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func featuredChannel(at date: Date) -> LiveChannel? {
        let favorites = model.favoriteLiveChannels
        if let lastFocusedFavoriteID,
           let focusedFavorite = favorites.first(where: { $0.id == lastFocusedFavoriteID }) {
            return focusedFavorite
        }
        return favorites.first
            ?? model.liveChannels.first(where: { nowPlaying(on: $0, at: date) != nil })
            ?? model.liveChannels.first
    }

    private func nowPlaying(on channel: LiveChannel, at date: Date) -> EPGProgram? {
        guard let station = model.channelStationMappings[channel.id] else { return nil }
        return guideWindow?.programsByStationID[station]?.first(where: { $0.contains(date) })
    }

    private func nextProgram(on channel: LiveChannel, at date: Date) -> EPGProgram? {
        guard let station = model.channelStationMappings[channel.id] else { return nil }
        return guideWindow?.programsByStationID[station]?.first(where: { $0.start > date })
    }

    private func handleHeroMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            onFocusNavigation()
        case .down:
            focusFavoriteRail()
        default:
            break
        }
    }

    private func focusPrimaryHero() {
        focusedID = !model.liveChannels.isEmpty
            ? "hero-watch"
            : "hero-guide"
    }

    private func focusFavoriteRail() {
        let favorites = model.favoriteLiveChannels
        guard !favorites.isEmpty else { return }
        let targetID = lastFocusedFavoriteID.flatMap { previousID in
            favorites.contains(where: { $0.id == previousID }) ? previousID : nil
        } ?? favorites[0].id
        focusedID = "channel:\(targetID)"
    }

    private func restoreFocus() {
        DispatchQueue.main.async {
            focusPrimaryHero()
        }
    }
}

// MARK: - Live guide

struct JoeTVGuideView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: GuideFilter = .all
    @State private var selectedChannelID: String?
    @State private var selectedProgramID: String?
    @State private var programActions: JoeTVProgramSelection?
    @FocusState private var focusedID: String?
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private enum GuideFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case sports = "Sports"
        case news = "News"
        case local = "Local"
        var id: String { rawValue }
    }

    private var guideWindow: EPGGuideWindow? { model.epgState.usableWindow }

    private var channels: [LiveChannel] {
        model.liveChannels.filter { channel in
            switch filter {
            case .all: return true
            case .sports: return channel.genre == .sports
            case .news: return channel.genre == .news
            case .local: return channel.id.hasPrefix("verylocal:")
            }
        }
    }

    private var selectedChannel: LiveChannel? {
        if let selectedChannelID, let channel = channels.first(where: { $0.id == selectedChannelID }) {
            return channel
        }
        return channels.first
    }

    private var selectedProgram: EPGProgram? {
        guard let selectedChannel else { return nil }
        let programs = programs(for: selectedChannel)
        if let selectedProgramID, let program = programs.first(where: { $0.id == selectedProgramID }) {
            return program
        }
        return programs.first(where: { $0.contains(Date()) }) ?? programs.first
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 10) {
                selectionHeader(at: context.date)
                    .frame(height: 190)

                HStack(spacing: 10) {
                    ForEach(GuideFilter.allCases) { option in
                        Button {
                            filter = option
                            resetSelection()
                        } label: {
                            Text(option.rawValue)
                        }
                        .buttonStyle(FocusPillButtonStyle(isSelected: filter == option))
                    }

                    Spacer()
                    epgStatus
                }

                if channels.isEmpty {
                    StatePanel(
                        title: "No channels in this view",
                        message: "Choose another guide filter or enable channels in Settings.",
                        symbol: "tv.slash",
                        actionTitle: "Show all"
                    ) {
                        filter = .all
                        resetSelection()
                    }
                } else {
                    JoeTVGuideGrid(
                        channels: channels,
                        guideWindow: guideWindow,
                        mappings: model.channelStationMappings,
                        anchor: model.guideTimeAnchor,
                        focusedID: $focusedID,
                        selectionChanged: updateSelection,
                        programPressed: { channel, program in
                            updateSelection(channel, program)
                            programActions = JoeTVProgramSelection(channel: channel, program: program)
                        },
                        channelPressed: { channel in
                            Task { await model.play(channel) }
                        }
                    )
                }
            }
            .padding(.horizontal, SeasonTheme.horizontalInset)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .background(SeasonTheme.background)
        .sheet(item: $programActions) { selection in
            JoeTVProgramActionsView(selection: selection) {
                programActions = nil
                Task { await model.play(selection.channel) }
            }
        }
        .onAppear { restoreFocus() }
        .onChange(of: entryFocusRequest) { _, _ in restoreFocus() }
        .onChange(of: focusedID) { _, identifier in
            guard let identifier else { return }
            if let match = guideSelection(for: identifier) {
                updateSelection(match.channel, match.program)
            }
        }
        .onExitCommand { onFocusNavigation() }
    }

    private func selectionHeader(at date: Date) -> some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("LIVE TV")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(SeasonTheme.liveSignal)
                    if let channel = selectedChannel {
                        Text(channel.name.uppercased())
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(SeasonTheme.secondaryText)
                    }
                }

                Text(selectedProgram?.title ?? selectedChannel?.name ?? "Live guide")
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(1)

                if let program = selectedProgram {
                    Text("\(program.start.formatted(date: .omitted, time: .shortened))–\(program.end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(SeasonTheme.secondaryText)
                    Text(program.synopsis?.isEmpty == false ? program.synopsis! : "Live programming on \(selectedChannel?.name ?? "this channel").")
                        .font(.system(size: 16))
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .lineLimit(2)
                        .frame(maxWidth: 760, alignment: .leading)
                } else {
                    Text("Choose a channel or program below. Moving focus previews; Select opens the program.")
                        .font(.system(size: 16))
                        .foregroundStyle(SeasonTheme.secondaryText)
                }

                if let channel = selectedChannel {
                    Button { Task { await model.play(channel) } } label: {
                        Label("Watch live", systemImage: "play.fill")
                    }
                    .buttonStyle(JoeTVCompactButtonStyle(isPrimary: true))
                    .focused($focusedID, equals: "watch-live")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            JoeTVProgramPreview(channel: selectedChannel, program: selectedProgram)
                .frame(width: 380, height: 188)
        }
    }

    @ViewBuilder private var epgStatus: some View {
        switch model.epgState {
        case .loading:
            Label("Updating guide", systemImage: "arrow.clockwise")
                .foregroundStyle(SeasonTheme.secondaryText)
        case .failed(let message, _):
            Label("Guide partially available", systemImage: "exclamationmark.triangle")
                .foregroundStyle(SeasonTheme.secondaryText)
                .help(message)
        case .unavailable:
            Text("Schedule data pending").foregroundStyle(SeasonTheme.secondaryText)
        case .loaded:
            Text("Now · \(Date().formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(SeasonTheme.secondaryText)
        }
    }

    private func programs(for channel: LiveChannel) -> [EPGProgram] {
        guard let station = model.channelStationMappings[channel.id] else { return [] }
        return guideWindow?.programsByStationID[station] ?? []
    }

    private func updateSelection(_ channel: LiveChannel, _ program: EPGProgram?) {
        selectedChannelID = channel.id
        selectedProgramID = program?.id
        model.lastFocusedLiveID = program.map { "program:\($0.id)" } ?? "channel:\(channel.id)"
    }

    private func resetSelection() {
        selectedChannelID = channels.first?.id
        selectedProgramID = nil
        focusedID = nil
    }

    private func restoreFocus() {
        if let previous = model.lastFocusedLiveID,
           let match = guideSelection(for: previous) {
            updateSelection(match.channel, match.program)
            DispatchQueue.main.async { focusedID = previous }
            return
        }
        resetSelection()
        if let channel = channels.first {
            let program = programs(for: channel).first(where: { $0.contains(Date()) }) ?? programs(for: channel).first
            let identifier = program.map { "program:\($0.id)" } ?? "channel:\(channel.id)"
            updateSelection(channel, program)
            DispatchQueue.main.async { focusedID = identifier }
        }
    }

    private func guideSelection(for identifier: String) -> (channel: LiveChannel, program: EPGProgram?)? {
        if identifier.hasPrefix("channel:") {
            let channelID = String(identifier.dropFirst("channel:".count))
            return channels.first(where: { $0.id == channelID }).map { ($0, nil) }
        }
        if identifier.hasPrefix("program:") {
            let programID = String(identifier.dropFirst("program:".count))
            for channel in channels {
                if let program = programs(for: channel).first(where: { $0.id == programID }) {
                    return (channel, program)
                }
            }
        }
        return nil
    }
}

private struct JoeTVGuideGrid: View {
    let channels: [LiveChannel]
    let guideWindow: EPGGuideWindow?
    let mappings: [String: String]
    let anchor: Date
    @FocusState.Binding var focusedID: String?
    let selectionChanged: (LiveChannel, EPGProgram?) -> Void
    let programPressed: (LiveChannel, EPGProgram) -> Void
    let channelPressed: (LiveChannel) -> Void

    private let channelWidth: CGFloat = 250
    private let rowHeight: CGFloat = 66
    private let rulerHeight: CGFloat = 38
    private let pointsPerMinute: CGFloat = 8

    private var windowStart: Date {
        let reference = max(anchor, guideWindow?.start ?? anchor)
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: reference)
        return calendar.date(byAdding: .minute, value: -(minute % 30), to: reference) ?? reference
    }

    private var windowEnd: Date { windowStart.addingTimeInterval(3 * 3_600) }
    private var timelineWidth: CGFloat { CGFloat(windowEnd.timeIntervalSince(windowStart) / 60) * pointsPerMinute }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text("CHANNELS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .frame(width: channelWidth, height: rulerHeight, alignment: .leading)

                    ForEach(channels) { channel in
                        Button { channelPressed(channel) } label: {
                            HStack(spacing: 12) {
                                ArtworkView(
                                    url: channel.logoURL,
                                    symbol: "tv",
                                    localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id),
                                    outerPadding: 2,
                                    artworkPadding: 5
                                )
                                .frame(width: 72, height: 45)
                                Text(channel.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(SeasonTheme.paper)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .frame(width: channelWidth, height: rowHeight, alignment: .leading)
                            .background(SeasonTheme.surface)
                            .overlay(alignment: .bottom) { Rectangle().fill(SeasonTheme.keyline).frame(height: 1) }
                        }
                        .buttonStyle(JoeTVGuideButtonStyle())
                        .focused($focusedID, equals: "channel:\(channel.id)")
                        .onChange(of: focusedID) { _, newValue in
                            if newValue == "channel:\(channel.id)" { selectionChanged(channel, nil) }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        timeRuler
                        ForEach(channels) { channel in
                            programRow(channel)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        nowLine
                    }
                }
            }
        }
        .frame(maxHeight: 555)
        .overlay { Rectangle().stroke(SeasonTheme.keyline, lineWidth: 1) }
        .clipped()
    }

    private var timeRuler: some View {
        ZStack(alignment: .leading) {
            SeasonTheme.background
            ForEach(0..<7, id: \.self) { tick in
                let date = windowStart.addingTimeInterval(Double(tick) * 30 * 60)
                Text(date, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .offset(x: CGFloat(tick) * 30 * pointsPerMinute + 8)
            }
        }
        .frame(width: timelineWidth, height: rulerHeight)
    }

    private func programRow(_ channel: LiveChannel) -> some View {
        let visiblePrograms = programs(for: channel).filter { $0.end > windowStart && $0.start < windowEnd }
        return ZStack(alignment: .leading) {
            SeasonTheme.surface.opacity(0.72)
            if visiblePrograms.isEmpty {
                Text("Schedule unavailable")
                    .font(.system(size: 14))
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .padding(.leading, 18)
            } else {
                ForEach(visiblePrograms) { program in
                    let start = max(program.start, windowStart)
                    let end = min(program.end, windowEnd)
                    let x = CGFloat(start.timeIntervalSince(windowStart) / 60) * pointsPerMinute
                    let width = max(94, CGFloat(end.timeIntervalSince(start) / 60) * pointsPerMinute - 4)
                    Button { programPressed(channel, program) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(program.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(program.start, format: .dateTime.hour().minute())
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(SeasonTheme.secondaryText)
                        }
                        .padding(.horizontal, 11)
                        .frame(width: width, height: rowHeight - 4, alignment: .leading)
                        .background(program.contains(Date()) ? SeasonTheme.liveSignal.opacity(0.13) : SeasonTheme.raisedSurface)
                        .overlay { Rectangle().stroke(SeasonTheme.keyline, lineWidth: 1) }
                    }
                    .buttonStyle(JoeTVGuideButtonStyle())
                    .focused($focusedID, equals: "program:\(program.id)")
                    .offset(x: x)
                }
            }
        }
        .frame(width: timelineWidth, height: rowHeight, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(SeasonTheme.keyline).frame(height: 1) }
    }

    @ViewBuilder private var nowLine: some View {
        let now = Date()
        if now >= windowStart && now <= windowEnd {
            let x = CGFloat(now.timeIntervalSince(windowStart) / 60) * pointsPerMinute
            VStack(spacing: 0) {
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(SeasonTheme.liveSignal)
                Rectangle().fill(SeasonTheme.liveSignal).frame(width: 2)
            }
            .frame(height: rulerHeight + CGFloat(channels.count) * rowHeight, alignment: .top)
            .offset(x: x - 1)
            .allowsHitTesting(false)
        }
    }

    private func programs(for channel: LiveChannel) -> [EPGProgram] {
        guard let station = mappings[channel.id] else { return [] }
        return guideWindow?.programsByStationID[station] ?? []
    }
}

// MARK: - Sports today

struct JoeTVSportsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedItemID: String?
    @State private var broadcastItem: MediaItem?
    @FocusState private var focusedID: String?
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private var items: [MediaItem] {
        var seen = Set<String>()
        return model.visibleSportsCategories
            .flatMap(\.items)
            .filter { !$0.isGenericSportsChannelShortcut }
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.sportsEvent?.startsAt ?? .distantFuture) < ($1.sportsEvent?.startsAt ?? .distantFuture) }
    }

    private var selectedItem: MediaItem? {
        if let selectedItemID, let item = items.first(where: { $0.id == selectedItemID }) { return item }
        return featuredItem(at: Date())
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 10) {
                sportsHeader(at: context.date)

                if let scheduleError = model.sportsScheduleState.errorMessage {
                    InlineStatusBanner(message: "Some schedule details are unavailable. \(scheduleError)") {
                        Task { await model.loadSportsSchedule() }
                    }
                }

                if let feature = selectedItem ?? featuredItem(at: context.date) {
                    HStack(alignment: .top, spacing: 16) {
                        featuredCard(feature, at: context.date)
                            .frame(maxWidth: .infinity)
                            .frame(height: 430)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("LIVE NOW")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(SeasonTheme.liveSignal)

                            let live = liveItems(at: context.date)
                            if live.isEmpty {
                                JoeTVQuietPanel(
                                    title: "No games are live right now",
                                    subtitle: "The next available events are below."
                                )
                            } else {
                                ScrollView(.vertical, showsIndicators: false) {
                                    LazyVStack(spacing: 6) {
                                        ForEach(live) { item in
                                            Button { activate(item) } label: {
                                                JoeTVScoreCard(item: item, date: context.date)
                                            }
                                            .buttonStyle(JoeTVCardButtonStyle())
                                            .focused($focusedID, equals: "live:\(item.id)")
                                            .onChange(of: focusedID) { _, newValue in
                                                if newValue == "live:\(item.id)" {
                                                    selectedItemID = item.id
                                                    model.focusSportsEvent(item.sportsEvent)
                                                }
                                            }
                                        }
                                    }
                                }
                                .focusSection()
                            }
                        }
                        .frame(width: 520, height: 430, alignment: .topLeading)
                        .clipped()
                    }
                    .frame(height: 430)
                    .focusSection()
                } else {
                    StatePanel(
                        title: "No sports available",
                        message: "Refresh to check for today's games and events.",
                        symbol: "sportscourt",
                        actionTitle: "Refresh"
                    ) { Task { await model.reload() } }
                }

                if !scheduleRailItems(at: context.date).isEmpty {
                    laterStrip(at: context.date)
                }
            }
            .padding(.horizontal, SeasonTheme.horizontalInset)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(SeasonTheme.background)
        .sheet(item: $broadcastItem) { item in
            JoeTVBroadcastSelector(item: item) { option in
                broadcastItem = nil
                Task { await model.play(item, option: option) }
            }
        }
        .onAppear {
            restoreFocus()
            model.prefetchSportsEventDetails(for: items)
            openDebugBaseballSelectorIfRequested()
        }
        .onChange(of: items.map(\.id)) { _, _ in openDebugBaseballSelectorIfRequested() }
        .onChange(of: entryFocusRequest) { _, _ in restoreFocus() }
        .onExitCommand { onFocusNavigation() }
    }

    private func sportsHeader(at date: Date) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SPORTS")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(SeasonTheme.liveSignal)
                Text("Today")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 14))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            Spacer()
            Text("\(liveItems(at: date).count) live  ·  \(scheduleRailItems(at: date).count) upcoming")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(SeasonTheme.secondaryText)
        }
    }

    private func featuredCard(_ item: MediaItem, at date: Date) -> some View {
        let detail = model.sportsEventDetail(for: item)
        return GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                JoeTVSportsBackdrop(item: item, detail: detail)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.28), Color.black.opacity(0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    JoeTVEventEyebrow(item: item, date: date)
                    Text(item.title)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(SeasonTheme.paper)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    if let event = item.sportsEvent {
                        JoeTVScoreLine(event: event, compact: false)
                    }
                    Text(detail?.status?.detail ?? item.subtitle ?? eventStatus(item, at: date))
                        .font(.system(size: 14))
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .lineLimit(1)
                    if let headline = detail?.headline,
                       !headline.isEmpty,
                       headline.caseInsensitiveCompare(item.title) != .orderedSame {
                        Text(headline)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SeasonTheme.paper.opacity(0.92))
                            .lineLimit(1)
                    }
                    if let description = detail?.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(SeasonTheme.secondaryText)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        if item.sportsPlaybackAvailable(at: date) && item.shouldPresentSportsPlaybackSelector {
                            Button { broadcastItem = item } label: {
                                Label("Choose stream", systemImage: "dot.radiowaves.left.and.right")
                            }
                            .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                            .focused($focusedID, equals: "feature-watch")
                        } else if item.sportsPlaybackAvailable(at: date) {
                            Button { playBest(item) } label: {
                                Label(playActionTitle(for: item, at: date), systemImage: "play.fill")
                            }
                            .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                            .focused($focusedID, equals: "feature-watch")
                        } else {
                            Label(unavailableActionTitle(for: item, at: date), systemImage: "clock")
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .tracking(0.7)
                                .foregroundStyle(SeasonTheme.secondaryText)
                        }
                    }
                }
                .padding(24)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .bottomLeading
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: SeasonTheme.cardRadius))
        .overlay { RoundedRectangle(cornerRadius: SeasonTheme.cardRadius).stroke(SeasonTheme.keyline) }
    }

    private func laterStrip(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scheduleRailTitle(at: date))
                .font(.system(size: 13, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(SeasonTheme.paper)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(scheduleRailItems(at: date).prefix(12).enumerated()), id: \.element.id) { index, item in
                        Button { activate(item) } label: {
                            JoeTVLaterCard(item: item, date: date)
                        }
                        .buttonStyle(JoeTVCardButtonStyle())
                        .focused($focusedID, equals: "later:\(item.id)")
                        .onChange(of: focusedID) { _, newValue in
                            if newValue == "later:\(item.id)" {
                                selectedItemID = item.id
                                model.focusSportsEvent(item.sportsEvent)
                            }
                        }
                        .onMoveCommand { direction in
                            guard direction == .up else { return }
                            focusLiveItem(aboveRailIndex: index, at: date)
                        }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    private func liveItems(at date: Date) -> [MediaItem] {
        items.filter { $0.sportsPhase(at: date) == .live }
    }

    private func laterTodayItems(at date: Date) -> [MediaItem] {
        items.filter {
            $0.sportsPhase(at: date) == .upcoming &&
                ($0.sportsEvent.map { Calendar.current.isDate($0.startsAt, inSameDayAs: date) } ?? true)
        }
    }

    private func tomorrowItems(at date: Date) -> [MediaItem] {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) else { return [] }
        return items.filter {
            $0.sportsPhase(at: date) == .upcoming &&
                ($0.sportsEvent.map { Calendar.current.isDate($0.startsAt, inSameDayAs: tomorrow) } ?? false)
        }
    }

    private func scheduleRailItems(at date: Date) -> [MediaItem] {
        let today = laterTodayItems(at: date)
        if !today.isEmpty { return today }
        let tomorrow = tomorrowItems(at: date)
        if !tomorrow.isEmpty { return tomorrow }
        return items.filter { $0.sportsPhase(at: date) == .upcoming }
    }

    private func scheduleRailTitle(at date: Date) -> String {
        if !laterTodayItems(at: date).isEmpty { return "LATER TODAY" }
        if !tomorrowItems(at: date).isEmpty { return "TOMORROW" }
        return "UP NEXT"
    }

    private func featuredItem(at date: Date) -> MediaItem? {
        liveItems(at: date).first(where: { $0.sportsPlaybackAvailable(at: date) })
            ?? liveItems(at: date).first
            ?? scheduleRailItems(at: date).first
    }

    private func eventStatus(_ item: MediaItem, at date: Date) -> String {
        switch item.sportsPhase(at: date) {
        case .live: return "Live now"
        case .replay: return "Replay available"
        case .completed: return "Final"
        case .upcoming: break
        }
        if let start = item.sportsEvent?.startsAt {
            return start.formatted(date: .abbreviated, time: .shortened)
        }
        return "Sports event"
    }

    private func activate(_ item: MediaItem) {
        selectedItemID = item.id
        guard item.sportsPlaybackAvailable(at: Date()) else { return }
        if item.shouldPresentSportsPlaybackSelector {
            broadcastItem = item
        } else if item.isPlayable {
            playBest(item)
        }
    }

    private func playBest(_ item: MediaItem) {
        guard item.sportsPlaybackAvailable(at: Date()) else { return }
        Task { await model.play(item, option: item.bestPlayableOption) }
    }

    private func playActionTitle(for item: MediaItem, at date: Date) -> String {
        item.sportsPhase(at: date) == .replay ? "Play replay" : "Watch live"
    }

    private func unavailableActionTitle(for item: MediaItem, at date: Date) -> String {
        switch item.sportsPhase(at: date) {
        case .completed, .replay:
            return "GAME COMPLETE"
        case .live:
            return "GAME UNDERWAY"
        case .upcoming:
            guard let gameTime = item.sportsEvent?.startsAt else { return "UPCOMING" }
            if let coverageTime = item.sportsCoverageStartsAt, date < coverageTime {
                return "COVERAGE BEGINS · \(coverageTime.formatted(date: .omitted, time: .shortened))"
            }
            return "GAME TIME · \(gameTime.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func focusLiveItem(aboveRailIndex index: Int, at date: Date) {
        let live = liveItems(at: date)
        if let target = live.indices.contains(index) ? live[index] : live.first {
            selectedItemID = target.id
            model.focusSportsEvent(target.sportsEvent)
            focusedID = "live:\(target.id)"
        } else if featuredItem(at: date)?.sportsPlaybackAvailable(at: date) == true {
            focusedID = "feature-watch"
        }
    }

    private func restoreFocus() {
        let feature = featuredItem(at: Date())
        selectedItemID = feature?.id
        DispatchQueue.main.async {
            if feature?.sportsPlaybackAvailable(at: Date()) == true {
                focusedID = "feature-watch"
            } else if let live = liveItems(at: Date()).first {
                focusedID = "live:\(live.id)"
            } else if let upcoming = scheduleRailItems(at: Date()).first {
                focusedID = "later:\(upcoming.id)"
            }
        }
    }

    private func openDebugBaseballSelectorIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["JOE_TV_DEBUG_OPEN_BASEBALL_SELECTOR"] == "1",
              broadcastItem == nil else { return }
        let liveBaseball = items.filter {
            $0.categoryID == "baseball" && $0.sportsPhase(at: Date()) == .live
        }
        let baseball = liveBaseball.first(where: {
            let groupIDs = Set($0.sportsBroadcastGroups.map(\.id))
            return groupIDs.contains("home") && groupIDs.contains("away")
        }) ?? liveBaseball.first(where: { $0.sportsPlaybackAvailable(at: Date()) })
        guard let baseball else { return }
        selectedItemID = baseball.id
        broadcastItem = baseball
        #endif
    }
}

// MARK: - ESPN+ calendar

struct JoeTVESPNPlusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var scope: Scope = .usOpen
    @State private var showsDatePicker = false
    @FocusState private var focusedID: String?
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private enum Scope: String {
        case usOpen = "US Open"
        case all = "All Events"
    }

    private var usOpenItems: [MediaItem] {
        model.espnPlusItems.filter { item in
            item.title.localizedCaseInsensitiveContains("US Open") ||
                (item.subtitle?.localizedCaseInsensitiveContains("US Open") == true)
        }
    }

    private var isShowingUSOpen: Bool {
        scope == .usOpen && !usOpenItems.isEmpty
    }

    private var displayedItems: [MediaItem] {
        isShowingUSOpen ? usOpenItems : model.espnPlusItems
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(model.espnPlusDate)
    }

    private var liveCount: Int {
        displayedItems.filter { $0.sportsPhase(at: Date()) == .live }.count
    }

    private var replayCount: Int {
        displayedItems.filter { $0.sportsPhase(at: Date()) == .replay }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            dateControls

            if let error = model.espnPlusState.errorMessage {
                InlineStatusBanner(message: "ESPN+ could not be refreshed. \(error)") {
                    Task { await model.loadESPNPlus(for: model.espnPlusDate) }
                }
            }

            content
        }
        .padding(.horizontal, SeasonTheme.horizontalInset)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(SeasonTheme.background)
        .sheet(isPresented: $showsDatePicker) {
            JoeTVESPNPlusDatePicker(selectedDate: model.espnPlusDate) { date in
                showsDatePicker = false
                Task { await model.loadESPNPlus(for: date) }
            }
        }
        .onAppear {
            restoreFocus()
            if model.espnPlusState == .idle {
                Task { await model.loadESPNPlus() }
            }
        }
        .onChange(of: entryFocusRequest) { _, _ in restoreFocus() }
        .onExitCommand { onFocusNavigation() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ESPN+")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(SeasonTheme.liveSignal)
                Text(isToday ? "Today" : model.espnPlusDate.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                Text(model.espnPlusDate, format: .dateTime.month(.wide).day().year())
                    .font(.system(size: 15))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            Spacer()
            if !displayedItems.isEmpty {
                Text("\(liveCount) live  ·  \(replayCount) replay")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
        }
    }

    private var dateControls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.moveESPNPlusDate(by: -1) }
            } label: {
                Label("Previous day", systemImage: "chevron.left")
            }
            .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
            .focused($focusedID, equals: "previous-day")
            .onKeyPress(.upArrow) {
                onFocusNavigation()
                return .handled
            }

            Button {
                showsDatePicker = true
            } label: {
                Label(
                    model.espnPlusDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                    systemImage: "calendar"
                )
            }
            .buttonStyle(JoeTVCompactButtonStyle(isPrimary: true))
            .focused($focusedID, equals: "choose-date")
            .onKeyPress(.upArrow) {
                onFocusNavigation()
                return .handled
            }

            Button {
                Task { await model.moveESPNPlusDate(by: 1) }
            } label: {
                Label("Next day", systemImage: "chevron.right")
            }
            .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
            .focused($focusedID, equals: "next-day")
            .onKeyPress(.upArrow) {
                onFocusNavigation()
                return .handled
            }

            if !isToday {
                Button("Today") {
                    Task { await model.loadESPNPlus(for: Date()) }
                }
                .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
                .focused($focusedID, equals: "today")
                .onKeyPress(.upArrow) {
                    onFocusNavigation()
                    return .handled
                }
            }

            Spacer()

            if !usOpenItems.isEmpty {
                Button("US Open") { scope = .usOpen }
                    .buttonStyle(FocusPillButtonStyle(isSelected: isShowingUSOpen))
                    .focused($focusedID, equals: "scope-us-open")
                Button("All Events") { scope = .all }
                    .buttonStyle(FocusPillButtonStyle(isSelected: !isShowingUSOpen))
                    .focused($focusedID, equals: "scope-all")
            }
        }
        .focusSection()
    }

    @ViewBuilder
    private var content: some View {
        switch model.espnPlusState {
        case .idle, .loading:
            VStack(spacing: 18) {
                ProgressView()
                Text("Loading ESPN+ for \(model.espnPlusDate.formatted(date: .abbreviated, time: .omitted))…")
                    .font(.title3)
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed where model.espnPlusItems.isEmpty:
            StatePanel(
                title: "ESPN+ unavailable",
                message: model.espnPlusState.errorMessage ?? "Joe-TV could not load this date.",
                symbol: "wifi.exclamationmark",
                actionTitle: "Try again"
            ) { Task { await model.loadESPNPlus(for: model.espnPlusDate) } }
        case .loaded, .failed:
            if displayedItems.isEmpty {
                StatePanel(
                    title: "Nothing scheduled",
                    message: "Seasons4U has not published any ESPN+ events for this date.",
                    symbol: "calendar.badge.clock",
                    actionTitle: isToday ? "Refresh" : "Return to Today"
                ) {
                    Task {
                        await model.loadESPNPlus(for: isToday ? model.espnPlusDate : Date())
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                        spacing: 16
                    ) {
                        ForEach(displayedItems) { item in
                            Button {
                                Task { await model.play(item) }
                            } label: {
                                JoeTVESPNPlusCard(item: item)
                            }
                            .buttonStyle(JoeTVCardButtonStyle())
                            .focused($focusedID, equals: "event:\(item.id)")
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 7)
                }
                .focusSection()
            }
        }
    }

    private func restoreFocus() {
        DispatchQueue.main.async { focusedID = "previous-day" }
    }
}

private struct JoeTVESPNPlusCard: View {
    let item: MediaItem

    private var phase: SportsEventPhase {
        item.sportsPhase(at: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JoeTVSportsBackdrop(item: item)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.3), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(phase == .replay ? "REPLAY" : "LIVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(phase == .replay ? SeasonTheme.paper.opacity(0.72) : SeasonTheme.liveSignal)
                Text(item.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(item.subtitle ?? "ESPN+")
                    .font(.system(size: 12))
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(height: 188)
        .background(SeasonTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
    }
}

private struct JoeTVESPNPlusDatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date
    @State private var displayedMonth: Date
    let apply: (Date) -> Void
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    init(selectedDate: Date, apply: @escaping (Date) -> Void) {
        _draftDate = State(initialValue: selectedDate)
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        _displayedMonth = State(initialValue: Calendar.current.date(from: components) ?? selectedDate)
        self.apply = apply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Choose an ESPN+ date")
                .font(.system(size: 42, weight: .regular, design: .serif))
                .foregroundStyle(SeasonTheme.paper)
            Text("Joe-TV will replace the current list with the live and replay catalog for that day.")
                .font(.title3)
                .foregroundStyle(SeasonTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Label("Previous month", systemImage: "chevron.left")
                }
                .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))

                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Label("Next month", systemImage: "chevron.right")
                }
                .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendar.shortStandaloneWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 26)
                }

                ForEach(Array(monthSlots.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            draftDate = date
                        } label: {
                            Text(date.formatted(.dateTime.day()))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(FocusPillButtonStyle(
                            isSelected: calendar.isDate(date, inSameDayAs: draftDate)
                        ))
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }

            HStack(spacing: 14) {
                Button("Show this date") { apply(draftDate) }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                Button("Cancel") { dismiss() }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: false))
            }
        }
        .padding(48)
        .frame(width: 920, height: 720, alignment: .topLeading)
        .background(SeasonTheme.background)
    }

    private var monthSlots: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth)
              ) else { return [] }
        let leadingBlanks = max(0, calendar.component(.weekday, from: firstDay) - 1)
        return Array(repeating: nil, count: leadingBlanks) + dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }.map(Optional.some)
    }

    private func moveMonth(by offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = month
    }
}

// MARK: - Layers and reusable components

private struct JoeTVProgramSelection: Identifiable {
    let channel: LiveChannel
    let program: EPGProgram
    var id: String { program.id }
}

private struct JoeTVProgramActionsView: View {
    let selection: JoeTVProgramSelection
    let watch: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(SeasonTheme.keyline)
                .frame(width: 54, height: 5)
                .frame(maxWidth: .infinity)
            Text(selection.channel.name.uppercased())
                .font(.caption.monospaced().weight(.bold))
                .tracking(1.8)
                .foregroundStyle(SeasonTheme.liveSignal)
            Text(selection.program.title)
                .font(.system(size: 46, weight: .regular, design: .serif))
                .foregroundStyle(SeasonTheme.paper)
            Text("\(selection.program.start.formatted(date: .abbreviated, time: .shortened))–\(selection.program.end.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(SeasonTheme.secondaryText)
            if let synopsis = selection.program.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.title3)
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .lineLimit(4)
            }
            HStack(spacing: 14) {
                Button(action: watch) { Label("Watch channel", systemImage: "play.fill") }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: true))
                    .focused($focused)
                Button("Close") { dismiss() }
                    .buttonStyle(JoeTVActionButtonStyle(isPrimary: false))
            }
        }
        .padding(48)
        .frame(width: 960, height: 530, alignment: .leading)
        .background(SeasonTheme.background)
        .onAppear { focused = true }
    }
}

private struct JoeTVBroadcastGroup: Identifiable {
    let id: String
    let title: String
    let options: [MediaItem.PlaybackOption]

    var hasMultipleModes: Bool {
        options.contains(where: \.isStartOver) && options.contains(where: { !$0.isStartOver })
    }
}

private struct JoeTVBroadcastSelector: View {
    let item: MediaItem
    let choose: (MediaItem.PlaybackOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedID: String?
    @State private var selectedGroupID: String?

    private var groups: [JoeTVBroadcastGroup] { item.sportsBroadcastGroups }

    private var selectedGroup: JoeTVBroadcastGroup? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(SeasonTheme.keyline)
                .frame(width: 54, height: 5)
                .frame(maxWidth: .infinity)
            Text("BROADCAST")
                .font(.caption.monospaced().weight(.bold))
                .tracking(1.8)
                .foregroundStyle(SeasonTheme.liveSignal)
            Text(selectedGroup == nil ? "Choose your broadcast." : "How do you want to watch?")
                .font(.system(size: 42, weight: .regular, design: .serif))
                .foregroundStyle(SeasonTheme.paper)
            Text(selectorSubtitle)
                .foregroundStyle(SeasonTheme.secondaryText)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if let selectedGroup {
                        ForEach(selectedGroup.options) { option in
                            Button { choose(option) } label: {
                                HStack(spacing: 18) {
                                    Image(systemName: option.isStartOver ? "backward.end.fill" : "play.fill")
                                        .frame(width: 42)
                                        .foregroundStyle(SeasonTheme.liveSignal)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playbackModeTitle(option))
                                            .font(.system(size: 24, weight: .semibold))
                                            .lineLimit(1)
                                        Text(option.isStartOver ? "Begin at the opening whistle" : playbackModeSubtitle)
                                            .font(.system(size: 16))
                                            .foregroundStyle(SeasonTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(SeasonTheme.secondaryText)
                                }
                                .padding(.horizontal, 22)
                                .frame(height: 108)
                            }
                            .buttonStyle(JoeTVRowButtonStyle())
                            .focused($focusedID, equals: "mode:\(option.id)")
                        }
                    } else {
                        ForEach(groups) { group in
                            Button { select(group) } label: {
                                HStack(spacing: 18) {
                                    Text(groupEyebrow(group))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(SeasonTheme.liveSignal)
                                        .frame(width: 120, alignment: .leading)
                                    Text(group.title)
                                        .font(.title3.weight(.semibold))
                                    Spacer()
                                    if group.hasMultipleModes {
                                        Text("LIVE / START OVER")
                                            .font(.caption.monospaced().weight(.semibold))
                                            .foregroundStyle(SeasonTheme.secondaryText)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(SeasonTheme.secondaryText)
                                }
                                .padding(.horizontal, 22)
                                .frame(height: 82)
                            }
                            .buttonStyle(JoeTVRowButtonStyle())
                            .focused($focusedID, equals: "feed:\(group.id)")
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                if selectedGroup != nil, groups.count > 1 {
                    Button("Back") {
                        selectedGroupID = nil
                        DispatchQueue.main.async { focusedID = groups.first.map { "feed:\($0.id)" } }
                    }
                    .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
                }
                Button("Cancel") { dismiss() }
                    .buttonStyle(JoeTVCompactButtonStyle(isPrimary: false))
            }
        }
        .padding(46)
        .frame(width: 980, height: 690, alignment: .leading)
        .background(SeasonTheme.background)
        .onAppear {
            if groups.count == 1, groups[0].hasMultipleModes {
                selectedGroupID = groups[0].id
                focusedID = groups[0].options.first.map { "mode:\($0.id)" }
            } else {
                focusedID = groups.first.map { "feed:\($0.id)" }
            }
        }
    }

    private var selectorSubtitle: String {
        if let selectedGroup {
            return "\(selectedGroup.title) has both the live point and a DVR start-over feed."
        }
        return groups.count > 1
            ? "Pick Home or Away first. If that feed offers DVR, Joe-TV will ask where to begin."
            : "Choose the available feed for this event."
    }

    private var playbackModeSubtitle: String {
        item.sportsPhase(at: Date()) == .replay ? "Play the published replay" : "Join the game at its current point"
    }

    private func select(_ group: JoeTVBroadcastGroup) {
        if group.hasMultipleModes {
            selectedGroupID = group.id
            DispatchQueue.main.async { focusedID = group.options.first.map { "mode:\($0.id)" } }
        } else if let option = group.options.first {
            choose(option)
        }
    }

    private func playbackModeTitle(_ option: MediaItem.PlaybackOption) -> String {
        if option.isStartOver { return "Start From Beginning" }
        return item.sportsPhase(at: Date()) == .replay ? "Play Replay" : "Watch Live"
    }

    private func groupEyebrow(_ group: JoeTVBroadcastGroup) -> String {
        switch group.id {
        case "home": return "HOME"
        case "away": return "AWAY"
        case "national": return "NATIONAL"
        default: return "STREAM"
        }
    }
}

private struct JoeTVLiveEyebrow: View {
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(SeasonTheme.liveSignal).frame(width: 8, height: 8)
            Text("LIVE · \(text.uppercased())")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(SeasonTheme.paper.opacity(0.76))
        }
    }
}

private struct JoeTVEventEyebrow: View {
    let item: MediaItem
    let date: Date

    var body: some View {
        let phase = item.sportsPhase(at: date)
        HStack(spacing: 9) {
            Circle()
                .fill(phase == .live ? SeasonTheme.liveSignal : SeasonTheme.paper.opacity(0.62))
                .frame(width: 8, height: 8)
            Text("\(phase.eyebrow) · \((item.sportsEvent?.league ?? item.categoryID).uppercased())")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(SeasonTheme.paper.opacity(0.76))
        }
    }
}

private struct JoeTVScoreLine: View {
    let event: SportsScheduleEvent
    let compact: Bool

    var body: some View {
        if event.awayScore != nil || event.homeScore != nil {
            HStack(spacing: compact ? 10 : 16) {
                Text(event.awayTeam ?? "Away")
                Text(event.awayScore.map(String.init) ?? "–").fontWeight(.bold)
                Rectangle().fill(SeasonTheme.keyline).frame(width: 1, height: 22)
                Text(event.homeTeam ?? "Home")
                Text(event.homeScore.map(String.init) ?? "–").fontWeight(.bold)
            }
            .font(.system(size: compact ? 15 : 22, weight: .medium, design: .rounded))
            .foregroundStyle(SeasonTheme.paper)
        }
    }
}

private struct JoeTVHeroBackdrop: View {
    let event: MediaItem?
    let channel: LiveChannel?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.11, blue: 0.14), SeasonTheme.background],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            if let event {
                JoeTVSportsBackdrop(item: event)
            } else if let channel {
                JoeTVProgramPreview(channel: channel, program: nil)
                    .scaleEffect(1.45)
                    .opacity(0.72)
            }
        }
        .clipped()
    }
}

private struct JoeTVSportsBackdrop: View {
    let item: MediaItem
    var detail: SportsEventDetail? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.15), SeasonTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let url = detail?.heroImage?.url ?? item.sportsEvent?.thumbnailURL ?? item.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            } else if let event = item.sportsEvent {
                HStack(spacing: 68) {
                    JoeTVTeamLogo(name: event.awayTeam, url: event.awayTeamLogoURL)
                    Text("@")
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .foregroundStyle(SeasonTheme.secondaryText)
                    JoeTVTeamLogo(name: event.homeTeam, url: event.homeTeamLogoURL)
                }
                .padding(70)
            }
        }
    }
}

private struct JoeTVTeamLogo: View {
    let name: String?
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Text(initials)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
        }
        .frame(width: 180, height: 150)
        .padding(18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
    }

    private var initials: String {
        String((name ?? "Team").split(separator: " ").suffix(2).compactMap(\.first)).uppercased()
    }
}

private struct JoeTVProgramPreview: View {
    let channel: LiveChannel?
    let program: EPGProgram?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SeasonTheme.raisedSurface, Color.black.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let imageURL = program?.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else if let channel {
                        ArtworkView(
                            url: channel.logoURL,
                            symbol: "tv.fill",
                            localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id),
                            outerPadding: 12,
                            artworkPadding: 22
                        )
                        .frame(width: 270, height: 150)
                    }
                }
            } else if let channel {
                ArtworkView(
                    url: channel.logoURL,
                    symbol: "tv.fill",
                    localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id),
                    outerPadding: 12,
                    artworkPadding: 22
                )
                .frame(width: 270, height: 150)
            }
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(SeasonTheme.liveSignal).frame(width: 7, height: 7)
                    Text("LIVE PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
        .accessibilityHidden(true)
    }
}

private struct JoeTVNowCard: View {
    let channel: LiveChannel
    let program: EPGProgram?
    let next: EPGProgram?
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                ArtworkView(
                    url: channel.logoURL,
                    symbol: "tv",
                    localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id),
                    outerPadding: 2,
                    artworkPadding: 5
                )
                .frame(width: 74, height: 42)
                Text(channel.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
            }
            Text(program?.title ?? "Live programming")
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
            if let program {
                JoeTVProgramProgress(program: program, date: date)
            }
            Text(next.map { "Next · \($0.title)" } ?? channel.genre.title)
                .font(.system(size: 12))
                .foregroundStyle(SeasonTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 300, height: 128, alignment: .leading)
        .background(Color.black.opacity(0.62))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct JoeTVScoreCard: View {
    let item: MediaItem
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.sportsEvent?.league?.uppercased() ?? item.categoryID.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(SeasonTheme.liveSignal)
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(SeasonTheme.liveSignal)
            }
            Text(item.title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
            if let event = item.sportsEvent,
               event.awayScore != nil || event.homeScore != nil {
                JoeTVScoreLine(event: event, compact: true)
            } else {
                Text(item.subtitle ?? "In progress")
                    .font(.system(size: 12))
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(SeasonTheme.raisedSurface)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct JoeTVLaterCard: View {
    let item: MediaItem
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(SeasonTheme.liveSignal)
            Text(item.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SeasonTheme.paper)
                .lineLimit(2)
            Text(item.sportsEvent?.league ?? item.categoryID.capitalized)
                .font(.system(size: 12))
                .foregroundStyle(SeasonTheme.secondaryText)
        }
        .padding(15)
        .frame(width: 310, height: 92, alignment: .leading)
        .background(SeasonTheme.surface)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusText: String {
        switch item.sportsPhase(at: date) {
        case .live: return "LIVE"
        case .replay: return "REPLAY AVAILABLE"
        case .completed: return "FINAL"
        case .upcoming:
            return item.sportsEvent?.startsAt.formatted(date: .omitted, time: .shortened) ?? "UPCOMING"
        }
    }
}

private struct JoeTVQuietPanel: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline).foregroundStyle(SeasonTheme.paper)
            Text(subtitle).font(.callout).foregroundStyle(SeasonTheme.secondaryText)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(SeasonTheme.surface)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
    }
}

private struct JoeTVProgramProgress: View {
    let program: EPGProgram
    let date: Date
    var body: some View {
        GeometryReader { geometry in
            let duration = max(program.end.timeIntervalSince(program.start), 1)
            let progress = min(max(date.timeIntervalSince(program.start) / duration, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(SeasonTheme.paper.opacity(0.16))
                Rectangle().fill(SeasonTheme.liveSignal).frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

// MARK: - Focus styles

private struct JoeTVActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    func makeBody(configuration: Configuration) -> some View {
        JoeTVFocusBody(configuration: configuration, isPrimary: isPrimary, compact: false)
    }
}

private struct JoeTVCompactButtonStyle: ButtonStyle {
    let isPrimary: Bool
    func makeBody(configuration: Configuration) -> some View {
        JoeTVFocusBody(configuration: configuration, isPrimary: isPrimary, compact: true)
    }
}

private struct JoeTVFocusBody: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool
    let compact: Bool
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: compact ? 15 : 18, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.black : SeasonTheme.paper)
            .padding(.horizontal, compact ? 18 : 24)
            .frame(minHeight: compact ? 52 : 64)
            .background(isPrimary ? SeasonTheme.paper : SeasonTheme.raisedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? SeasonTheme.focusVolt : SeasonTheme.keyline, lineWidth: isFocused ? 4 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : isFocused ? 1.025 : 1)
            .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.18) : .clear, radius: 18)
            .animation(reduceMotion ? nil : SeasonTheme.focusAnimation, value: isFocused)
    }
}

private struct JoeTVCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? SeasonTheme.focusVolt : .clear, lineWidth: SeasonTheme.focusLineWidth)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : isFocused ? 1.025 : 1)
            .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.18) : .clear, radius: 18)
            .animation(reduceMotion ? nil : SeasonTheme.focusAnimation, value: isFocused)
    }
}

private struct JoeTVGuideButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Rectangle().stroke(
                    isFocused ? SeasonTheme.focusVolt : .clear,
                    lineWidth: SeasonTheme.focusLineWidth
                )
            }
            .zIndex(isFocused ? 2 : 0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(SeasonTheme.focusAnimation, value: isFocused)
    }
}

private struct JoeTVRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SeasonTheme.paper)
            .background(SeasonTheme.raisedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? SeasonTheme.focusVolt : SeasonTheme.keyline, lineWidth: isFocused ? 4 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.99 : isFocused ? 1.012 : 1)
            .animation(SeasonTheme.focusAnimation, value: isFocused)
    }
}

// MARK: - Model conveniences

private extension EPGLoadState {
    var usableWindow: EPGGuideWindow? {
        switch self {
        case .loaded(let window): return window
        case .loading(let cached), .failed(_, let cached): return cached
        case .unavailable: return nil
        }
    }
}

private extension MediaItem {
    var playableOptions: [PlaybackOption] {
        playbackOptions.filter { option in
            if case .unavailable = option.playback { return false }
            return true
        }
    }

    var bestPlayableOption: PlaybackOption? {
        let playable = playableOptions
        #if !targetEnvironment(simulator)
        if let fairPlay = playable.first(where: { option in
            if case .drmPage = option.playback { return true }
            return false
        }) { return fairPlay }
        #endif
        return playable.first
    }

    var shouldPresentSportsPlaybackSelector: Bool {
        (categoryID == "baseball" && isPlayable) || playableOptions.count > 1
    }

    var sportsBroadcastGroups: [JoeTVBroadcastGroup] {
        var optionsByKey: [String: [PlaybackOption]] = [:]
        var encounteredKeys: [String] = []
        for option in playableOptions {
            let key = option.broadcastKey
            if optionsByKey[key] == nil { encounteredKeys.append(key) }
            optionsByKey[key, default: []].append(option)
        }

        let preferredOrder = ["home", "away", "national", "us", "international", "spanish", "radio", "alternate"]
        let orderedKeys = encounteredKeys.sorted { left, right in
            let leftRank = preferredOrder.firstIndex(of: left) ?? preferredOrder.count
            let rightRank = preferredOrder.firstIndex(of: right) ?? preferredOrder.count
            if leftRank != rightRank { return leftRank < rightRank }
            return encounteredKeys.firstIndex(of: left)! < encounteredKeys.firstIndex(of: right)!
        }

        return orderedKeys.compactMap { key in
            guard let options = optionsByKey[key], !options.isEmpty else { return nil }
            return JoeTVBroadcastGroup(
                id: key,
                title: broadcastGroupTitle(key: key, fallback: options[0].title),
                options: options.sorted {
                    if $0.isStartOver != $1.isStartOver { return !$0.isStartOver }
                    return $0.title < $1.title
                }
            )
        }
    }

    private func broadcastGroupTitle(key: String, fallback: String) -> String {
        switch key {
        case "home": return sportsEvent?.homeTeam.map { "\($0) · Home" } ?? "Home Feed"
        case "away": return sportsEvent?.awayTeam.map { "\($0) · Away" } ?? "Away Feed"
        case "national": return "National broadcast"
        case "us": return "U.S. broadcast"
        case "international": return "International broadcast"
        case "spanish": return "Spanish broadcast"
        case "radio": return "Radio broadcast"
        case "alternate": return "Alternate broadcast"
        default: return fallback
        }
    }
}

private extension SportsEventPhase {
    var eyebrow: String {
        switch self {
        case .live: return "LIVE"
        case .upcoming: return "UP NEXT"
        case .replay: return "REPLAY"
        case .completed: return "FINAL"
        }
    }
}
