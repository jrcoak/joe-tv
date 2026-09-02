import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            SeasonTheme.background.ignoresSafeArea()

            switch model.screen {
            case .checkingSession:
                LaunchView()
            case .signedOut:
                LoginView()
            case .catalog:
                CatalogView()
            }

            if model.isWorking {
                WorkingOverlay(message: model.workingMessage)
            }
        }
        .alert(
            "Joe-TV",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(model.errorMessage ?? "") }
        )
        .fullScreenCover(item: $model.playbackSession) { session in
            PlayerScreen(session: session)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 24) {
            BrandMark(size: 104)
            ProgressView()
            Text("Checking your membership…")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LoginView: View {
    @EnvironmentObject private var model: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = true
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        HStack(spacing: 64) {
            VStack(spacing: 20) {
                BrandMark(size: 116)
                Text("Joe-TV")
                    .font(.headline.monospaced().weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(SeasonTheme.liveSignal)
            }
            .frame(width: 300)

            VStack(alignment: .leading, spacing: 22) {
                Text("Sign in")
                    .font(.system(size: 44, weight: .semibold))
                Text("Your password is used only to sign in and is never stored by Joe-TV.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextField("Email", text: $email, prompt: Text("you@domain.com"))
                    .textContentType(.username)
                    .focused($focusedField, equals: .email)
                    .accessibilityIdentifier("login.email")

                SecureField("Password", text: $password, prompt: Text("Password"))
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submit)
                    .accessibilityIdentifier("login.password")

                Toggle("Keep me signed in on this Apple TV", isOn: $rememberMe)

                Button(action: submit) {
                    Label("Sign in", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 66)
                .disabled(model.isWorking)
                .accessibilityIdentifier("login.submit")

            }
            .padding(44)
            .frame(width: 640)
            .background(SeasonTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24).stroke(SeasonTheme.keyline)
            }
        }
        .padding(.horizontal, 100)
        .onAppear { focusedField = .email }
    }

    private func submit() {
        focusedField = nil
        Task {
            let succeeded = await model.signIn(email: email, password: password, rememberMe: rememberMe)
            if succeeded { password = "" }
        }
    }
}

private struct CatalogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsSignOut = false
    @State private var showsSportsCategorySettings = false
    @State private var showsChannelSettings = false
    @State private var homeEntryFocusRequest = 0
    @State private var liveTVEntryFocusRequest = 0
    @State private var sportsEntryFocusRequest = 0
    @State private var espnPlusEntryFocusRequest = 0
    @FocusState private var focusedDestination: AppModel.Destination?
    @FocusState private var moreIsFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                destinationBar
                    .frame(width: geometry.size.width, alignment: .leading)
                    .clipped()

                Group {
                    switch model.destination {
                    case .home:
                        JoeTVHomeView(
                            entryFocusRequest: homeEntryFocusRequest,
                            onFocusNavigation: focusCurrentDestination
                        )
                    case .liveTV:
                        JoeTVGuideView(
                            entryFocusRequest: liveTVEntryFocusRequest,
                            onFocusNavigation: focusCurrentDestination
                        )
                    case .sports:
                        JoeTVSportsView(
                            entryFocusRequest: sportsEntryFocusRequest,
                            onFocusNavigation: focusCurrentDestination
                        )
                    case .espnPlus:
                        JoeTVESPNPlusView(
                            entryFocusRequest: espnPlusEntryFocusRequest,
                            onFocusNavigation: focusCurrentDestination
                        )
                    }
                }
                .frame(width: geometry.size.width, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .confirmationDialog(
            "Sign out of Joe-TV?",
            isPresented: $confirmsSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { model.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local Seasons4U session from this Apple TV.")
        }
        .sheet(isPresented: $showsSportsCategorySettings) {
            SportsCategorySettingsView()
        }
        .sheet(isPresented: $showsChannelSettings) {
            ChannelSettingsView()
        }
    }

    private var destinationBar: some View {
        HStack(spacing: 18) {
            BrandMark(size: 44)
                .accessibilityHidden(true)
            Text("Joe-TV")
                .font(.subheadline.monospaced().weight(.bold))
                .tracking(2.4)

            HStack(spacing: 8) {
                destinationButton("Home", symbol: "house.fill", destination: .home)
                destinationButton("Live TV", symbol: "rectangle.grid.1x2.fill", destination: .liveTV)
                if !model.isVeryLocalOnly {
                    destinationButton("Live Sports", symbol: "sportscourt.fill", destination: .sports)
                    destinationButton("ESPN+", symbol: "play.rectangle.fill", destination: .espnPlus)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()

            if model.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("Refreshing content")
            }

            Menu {
                Button {
                    Task { await model.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                if !model.isVeryLocalOnly {
                    Button {
                        Task {
                            await model.loadEPG(around: Date())
                            await model.loadSportsSchedule()
                        }
                    } label: {
                        Label("Refresh TV & Sports Data", systemImage: "calendar.badge.clock")
                    }
                    Button { showsSportsCategorySettings = true } label: {
                        Label("Sports Categories", systemImage: "slider.horizontal.3")
                    }
                }
                Button { showsChannelSettings = true } label: {
                    Label("Channels", systemImage: "tv.and.mediabox")
                }
                Button(role: model.isVeryLocalOnly ? nil : .destructive) {
                    if model.isVeryLocalOnly {
                        model.signOut()
                    } else {
                        confirmsSignOut = true
                    }
                } label: {
                    Label(
                        model.isVeryLocalOnly ? "Back to sign in" : "Sign out",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 38)
            }
            .buttonStyle(TopNavigationButtonStyle(isSelected: false))
            .focused($moreIsFocused)
            .onKeyPress(.leftArrow) {
                moreIsFocused = false
                focusedDestination = model.isVeryLocalOnly ? .liveTV : .espnPlus
                return .handled
            }
            .onKeyPress(.downArrow) {
                requestContentFocus(from: nil)
                return .handled
            }
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    moreIsFocused = false
                    focusedDestination = model.isVeryLocalOnly ? .liveTV : .espnPlus
                case .down:
                    requestContentFocus(from: nil)
                default:
                    break
                }
            }
            .accessibilityLabel("More")
            .accessibilityIdentifier("navigation.more")
        }
        .padding(.horizontal, SeasonTheme.horizontalInset)
        .padding(.vertical, 12)
        .background(SeasonTheme.background.opacity(0.94))
        .overlay(alignment: .bottom) { Rectangle().fill(SeasonTheme.keyline).frame(height: 1) }
    }

    private func destinationButton(
        _ title: String,
        symbol: String,
        destination: AppModel.Destination
    ) -> some View {
        Button {
            model.destination = destination
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(TopNavigationButtonStyle(isSelected: model.destination == destination))
        .focused($focusedDestination, equals: destination)
        .onKeyPress(.leftArrow) {
            focusNavigationItem(leftOf: destination)
            return destination == .home ? .ignored : .handled
        }
        .onKeyPress(.rightArrow) {
            focusNavigationItem(rightOf: destination)
            return .handled
        }
        .onKeyPress(.downArrow) {
            requestContentFocus(from: destination)
            return .handled
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                focusNavigationItem(leftOf: destination)
            case .right:
                focusNavigationItem(rightOf: destination)
            case .down:
                requestContentFocus(from: destination)
            default:
                break
            }
        }
        .accessibilityAddTraits(model.destination == destination ? .isSelected : [])
    }

    private func focusCurrentDestination() {
        moreIsFocused = false
        focusedDestination = model.destination
    }

    private func focusNavigationItem(leftOf destination: AppModel.Destination) {
        moreIsFocused = false
        switch destination {
        case .home:
            break
        case .liveTV:
            focusedDestination = .home
        case .sports:
            focusedDestination = .liveTV
        case .espnPlus:
            focusedDestination = .sports
        }
    }

    private func focusNavigationItem(rightOf destination: AppModel.Destination) {
        switch destination {
        case .home:
            moreIsFocused = false
            focusedDestination = .liveTV
        case .liveTV:
            if model.isVeryLocalOnly {
                focusedDestination = nil
                moreIsFocused = true
            } else {
                moreIsFocused = false
                focusedDestination = .sports
            }
        case .sports:
            moreIsFocused = false
            focusedDestination = .espnPlus
        case .espnPlus:
            focusedDestination = nil
            moreIsFocused = true
        }
    }

    private func requestContentFocus(from _: AppModel.Destination?) {
        switch model.destination {
        case .home:
            homeEntryFocusRequest += 1
        case .liveTV:
            liveTVEntryFocusRequest += 1
        case .sports:
            sportsEntryFocusRequest += 1
        case .espnPlus:
            espnPlusEntryFocusRequest += 1
        }
    }
}

private struct ChannelSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private struct ProviderSection: Identifiable {
        let id: String
        let title: String
        let channels: [LiveChannel]
    }

    private var sections: [ProviderSection] {
        LiveChannelSection.allCases.compactMap { section in
            let channels = model.availableLiveChannels.filter {
                ChannelDirectory.section(for: $0) == section
            }
            guard !channels.isEmpty else { return nil }
            return ProviderSection(id: section.id, title: section.rawValue, channels: channels)
        }
    }

    private var enabledCount: Int {
        model.availableLiveChannels.reduce(into: 0) { count, channel in
            if model.isChannelEnabled(channel.id) { count += 1 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Channels")
                        .font(.system(size: 42, weight: .semibold))
                    Text("Choose which channels appear in Live TV and which favorites appear on Home.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sections) { section in
                        Text(section.title.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        ForEach(section.channels) { channel in
                            let isEnabled = model.isChannelEnabled(channel.id)
                            let isFavorite = model.isChannelFavorite(channel.id)
                            HStack(spacing: 12) {
                                Button {
                                    model.setChannel(channel.id, enabled: !isEnabled)
                                } label: {
                                    HStack(spacing: 18) {
                                        ArtworkView(
                                            url: channel.logoURL,
                                            symbol: "tv",
                                            localAssetName: ChannelDirectory.brandAssetName(
                                                forPlaybackIdentity: channel.id
                                            ),
                                            outerPadding: 3,
                                            artworkPadding: 5
                                        )
                                        .frame(width: 96, height: 56)

                                        Text(channel.name)
                                            .font(.title3.weight(.medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isEnabled ? SeasonTheme.accent : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SportsSettingsRowButtonStyle())
                                .accessibilityLabel("\(channel.name), Live TV")
                                .accessibilityValue(isEnabled ? "Enabled" : "Disabled")
                                .accessibilityIdentifier("settings.channel.\(channel.id)")

                                Button {
                                    model.setChannelFavorite(channel.id, favorite: !isFavorite)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: isFavorite ? "star.fill" : "star")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(isFavorite ? SeasonTheme.focusVolt : .secondary)
                                        Text("Favorite")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .frame(width: 92)
                                }
                                .buttonStyle(SportsSettingsRowButtonStyle())
                                .accessibilityLabel("\(channel.name), Favorite")
                                .accessibilityValue(isFavorite ? "Yes" : "No")
                                .accessibilityIdentifier("settings.favorite.\(channel.id)")
                            }
                        }
                    }
                }
            }

            HStack {
                Text("\(enabledCount) enabled · \(model.favoriteChannelIDs.count) favorites")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Favorites") { model.clearFavoriteChannels() }
                    .buttonStyle(.bordered)
                    .disabled(model.favoriteChannelIDs.isEmpty)
                Button("Restore Defaults") { model.restoreDefaultChannels() }
                    .buttonStyle(.bordered)
                Button("Enable All") { model.enableAllChannels() }
                    .buttonStyle(.bordered)
                    .disabled(enabledCount == model.availableLiveChannels.count)
            }
        }
        .padding(50)
        .frame(width: 920, height: 820)
        .background(SeasonTheme.background)
    }
}

private struct SportsCategorySettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sports categories")
                        .font(.system(size: 42, weight: .semibold))
                    Text("Choose which sections appear in Sports.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(SportsCategoryOption.all) { category in
                        let isEnabled = model.isSportsCategoryEnabled(category.id)
                        Button {
                            model.setSportsCategory(category.id, enabled: !isEnabled)
                        } label: {
                            HStack(spacing: 18) {
                                Image(systemName: category.symbol)
                                    .frame(width: 34)
                                Text(category.title)
                                    .font(.title3.weight(.medium))
                                Spacer()
                                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isEnabled ? SeasonTheme.accent : .secondary)
                            }
                        }
                        .buttonStyle(SportsSettingsRowButtonStyle())
                        .accessibilityValue(isEnabled ? "Enabled" : "Disabled")
                    }
                }
            }

            HStack {
                Text("Default: Football, Baseball, Hockey, and Basketball")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restore Defaults") { model.restoreDefaultSportsCategories() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(50)
        .frame(width: 880, height: 790)
        .background(SeasonTheme.background)
    }
}

private struct LiveTVBrowseView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedScheduleChannelID: String?
    @FocusState private var focusedChannelID: String?
    @FocusState private var scheduleDisclosureFocused: Bool
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private struct ChannelSection: Identifiable {
        let id: String
        let title: String
        let channels: [LiveChannel]
    }

    private var filteredChannels: [LiveChannel] {
        guard !model.liveSearchQuery.isEmpty else { return model.liveChannels }
        return model.liveChannels.filter {
            $0.name.localizedCaseInsensitiveContains(model.liveSearchQuery)
        }
    }

    private var sections: [ChannelSection] {
        if !model.liveSearchQuery.isEmpty {
            return [ChannelSection(id: "results", title: "Search Results", channels: filteredChannels)]
        }
        let browseOrder: [ChannelGenre] = [.entertainment, .news, .sports, .lifestyle, .kids, .spanish]
        return browseOrder.compactMap { genre in
            let matches = model.liveChannels.filter { $0.genre == genre }
            guard !matches.isEmpty else { return nil }
            return ChannelSection(id: genre.id, title: genre.title, channels: matches)
        }
    }

    private var focusedChannel: LiveChannel? {
        if let focusedChannelID,
           let channel = model.liveChannels.first(where: { $0.id == focusedChannelID }) {
            return channel
        }
        if let stored = model.lastFocusedLiveID,
           stored.hasPrefix("channel:"),
           let channel = model.liveChannels.first(where: { "channel:\($0.id)" == stored }),
           filteredChannels.contains(where: { $0.id == channel.id }) {
            return channel
        }
        return sections.first?.channels.first
    }

    private var guideWindow: EPGGuideWindow? {
        switch model.epgState {
        case .loaded(let window): return window
        case .loading(let cached): return cached
        case .failed(_, let cached): return cached
        default: return nil
        }
    }

    private var guideErrorMessage: String? {
        guard case .failed(let message, _) = model.epgState else { return nil }
        return message
    }

    var body: some View {
        if model.liveChannels.isEmpty, let error = model.channelState.errorMessage {
            StatePanel(
                title: "Live TV unavailable",
                message: error,
                symbol: "wifi.exclamationmark",
                actionTitle: "Try again"
            ) { Task { await model.reload() } }
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 18) {
                    if let error = model.channelState.errorMessage {
                        InlineStatusBanner(message: "Showing the previous lineup. \(error)") {
                            Task { await model.reload() }
                        }
                    }

                    if let guideErrorMessage {
                        InlineStatusBanner(message: "Some programming details are unavailable. \(guideErrorMessage)") {
                            Task { await model.loadEPG(around: Date()) }
                        }
                    }

                    HStack(alignment: .top, spacing: 22) {
                        channelBrowser(at: context.date)
                            .frame(width: 560)

                        channelStage(at: context.date)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, SeasonTheme.horizontalInset)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
            .onAppear { restoreFocus() }
            .onChange(of: focusedChannelID) { _, channelID in
                guard let channelID else { return }
                model.lastFocusedLiveID = "channel:\(channelID)"
                if expandedScheduleChannelID != channelID {
                    expandedScheduleChannelID = nil
                }
            }
            .onChange(of: entryFocusRequest) { _, _ in restoreFocus() }
            .onChange(of: filteredChannels.map(\.id)) { _, ids in
                if let focusedChannelID, ids.contains(focusedChannelID) { return }
                self.focusedChannelID = ids.first
            }
            .onExitCommand {
                if expandedScheduleChannelID != nil {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        expandedScheduleChannelID = nil
                    }
                } else {
                    onFocusNavigation()
                }
            }
            .background(LiveTVPalette.background)
        }
    }

    private func channelBrowser(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Search channels", text: $model.liveSearchQuery)
                .font(.system(size: 19, weight: .regular))
                .onMoveCommand { direction in
                    if direction == .up { onFocusNavigation() }
                }
                .accessibilityIdentifier("browse.search")

            if model.liveChannels.isEmpty {
                StatePanel(
                    title: "No channels enabled",
                    message: "Enable channels from More, then Channels.",
                    symbol: "tv.slash",
                    actionTitle: nil,
                    action: {}
                )
            } else if filteredChannels.isEmpty {
                StatePanel(
                    title: "No channels found",
                    message: "Try a different channel name.",
                    symbol: "magnifyingglass",
                    actionTitle: "Clear Search"
                ) { model.liveSearchQuery = "" }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(sections) { section in
                                Section {
                                    ForEach(section.channels) { channel in
                                        Button {
                                            Task { await model.play(channel) }
                                        } label: {
                                            LiveChannelRow(
                                                channel: channel,
                                                program: nowPlaying(for: channel, at: date),
                                                date: date
                                            )
                                        }
                                        .buttonStyle(LiveChannelRowButtonStyle())
                                        .focused($focusedChannelID, equals: channel.id)
                                        .onMoveCommand { direction in
                                            if direction == .right,
                                               !upcomingPrograms(for: channel, at: date).isEmpty {
                                                scheduleDisclosureFocused = true
                                            }
                                        }
                                        .id(channel.id)
                                        .accessibilityLabel(channelAccessibilityLabel(channel, at: date))
                                        .accessibilityHint("Press to watch")
                                        .accessibilityIdentifier("browse.channel.\(channel.id)")
                                    }
                                } header: {
                                    Text(section.title.uppercased())
                                        .font(.system(size: 15, weight: .semibold))
                                        .tracking(1.2)
                                        .foregroundStyle(LiveTVPalette.mutedText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 14)
                                        .padding(.bottom, 7)
                                        .background(LiveTVPalette.panel)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: focusedChannelID) { _, channelID in
                        guard let channelID else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            proxy.scrollTo(channelID, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(LiveTVPalette.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(LiveTVPalette.divider) }
    }

    private func channelStage(at date: Date) -> some View {
        let channel = focusedChannel
        let current = channel.flatMap { nowPlaying(for: $0, at: date) }
        let next = channel.flatMap { nextProgram(for: $0, after: current, at: date) }
        let upcoming = channel.map { upcomingPrograms(for: $0, at: date) } ?? []
        let isScheduleExpanded = channel.map { expandedScheduleChannelID == $0.id } ?? false

        return ZStack(alignment: .bottomLeading) {
            ProgramBackdrop(
                imageURL: nil,
                fallbackLogoURL: channel?.logoURL,
                fallbackLogoAssetName: channel.flatMap {
                    ChannelDirectory.brandAssetName(forPlaybackIdentity: $0.id)
                },
                fallbackColor: heroColor(for: channel?.genre)
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            if let channel, isScheduleExpanded {
                scheduleDrawer(channel: channel, programs: upcoming)
                    .frame(width: 610)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 230)

                HStack(spacing: 10) {
                    Text("LIVE")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(LiveTVPalette.accent)

                    if let channel {
                        Text(channel.name.uppercased())
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(0.7)
                            .foregroundStyle(.white.opacity(0.76))
                    }
                }

                Text(current?.title ?? channel?.name ?? "Choose a channel")
                    .font(.system(size: 42, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let current {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(current.start.formatted(date: .omitted, time: .shortened))
                            Spacer()
                            Text(current.end.formatted(date: .omitted, time: .shortened))
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LiveTVPalette.mutedText)

                        LiveProgressBar(program: current, date: date)
                    }

                    if let synopsis = current.synopsis, !synopsis.isEmpty {
                        Text(synopsis)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .frame(maxWidth: 780, alignment: .leading)
                    }
                } else {
                    Text(channel?.genre.title ?? "Live television")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(LiveTVPalette.mutedText)
                }

                HStack(alignment: .center, spacing: 18) {
                    Label("Press Select to watch", systemImage: "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))

                    Spacer()

                    if let channel, let next, !upcoming.isEmpty {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                expandedScheduleChannelID = isScheduleExpanded ? nil : channel.id
                            }
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("UP NEXT  ·  \(next.start.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 13, weight: .semibold))
                                        .tracking(0.6)
                                        .foregroundStyle(LiveTVPalette.accent)
                                    Text(next.title)
                                        .font(.system(size: 17, weight: .medium))
                                        .lineLimit(1)
                                }

                                Image(systemName: isScheduleExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .buttonStyle(LiveScheduleDisclosureButtonStyle(isExpanded: isScheduleExpanded))
                        .focused($scheduleDisclosureFocused)
                        .onMoveCommand { direction in
                            if direction == .left {
                                scheduleDisclosureFocused = false
                                focusedChannelID = channel.id
                            }
                        }
                        .accessibilityLabel("Up next on \(channel.name)")
                        .accessibilityHint(isScheduleExpanded ? "Press to hide the schedule" : "Press to show the schedule")
                        .accessibilityIdentifier("browse.upNext")
                    }
                }
            }
            .padding(36)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(LiveTVPalette.divider) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: channel?.id)
    }

    private func scheduleDrawer(channel: LiveChannel, programs: [EPGProgram]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("UP NEXT")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(LiveTVPalette.accent)
                Spacer()
                Text(channel.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .padding(.bottom, 13)

            ForEach(Array(programs.prefix(5).enumerated()), id: \.element.id) { index, program in
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text(program.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(index == 0 ? LiveTVPalette.accent : LiveTVPalette.mutedText)
                        .frame(width: 92, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(program.title)
                            .font(.system(size: 18, weight: .medium))
                            .lineLimit(1)
                        if let category = program.category, !category.isEmpty {
                            Text(category)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(LiveTVPalette.mutedText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

                if index < min(programs.count, 5) - 1 {
                    Rectangle().fill(LiveTVPalette.divider).frame(height: 1)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.13)) }
        .shadow(color: .black.opacity(0.34), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Upcoming schedule for \(channel.name)")
    }

    private func restoreFocus() {
        if let stored = model.lastFocusedLiveID,
           stored.hasPrefix("channel:") {
            let id = String(stored.dropFirst("channel:".count))
            if filteredChannels.contains(where: { $0.id == id }) {
                focusedChannelID = id
                return
            }
        }
        focusedChannelID = sections.first?.channels.first?.id
    }

    private func nowPlaying(for channel: LiveChannel, at date: Date) -> EPGProgram? {
        guard let stationID = model.channelStationMappings[channel.id] else { return nil }
        return guideWindow?.programsByStationID[stationID]?.first(where: { $0.contains(date) })
    }

    private func nextProgram(for channel: LiveChannel, after current: EPGProgram?, at date: Date) -> EPGProgram? {
        guard let stationID = model.channelStationMappings[channel.id] else { return nil }
        let programs = guideWindow?.programsByStationID[stationID] ?? []
        if let current, let index = programs.firstIndex(of: current), programs.indices.contains(index + 1) {
            return programs[index + 1]
        }
        return programs.first(where: { $0.start >= date })
    }

    private func upcomingPrograms(for channel: LiveChannel, at date: Date) -> [EPGProgram] {
        guard let stationID = model.channelStationMappings[channel.id] else { return [] }
        return Array((guideWindow?.programsByStationID[stationID] ?? [])
            .filter { $0.start > date }
            .prefix(5))
    }

    private func channelAccessibilityLabel(_ channel: LiveChannel, at date: Date) -> String {
        if let program = nowPlaying(for: channel, at: date) {
            return "\(channel.name), now playing \(program.title)"
        }
        return "\(channel.name), \(channel.genre.title)"
    }

    private func heroColor(for genre: ChannelGenre?) -> Color {
        switch genre {
        case .sports: return Color(red: 0.12, green: 0.15, blue: 0.17)
        case .news: return Color(red: 0.08, green: 0.13, blue: 0.17)
        case .entertainment: return Color(red: 0.10, green: 0.13, blue: 0.15)
        case .lifestyle: return Color(red: 0.08, green: 0.14, blue: 0.14)
        case .kids: return Color(red: 0.13, green: 0.14, blue: 0.15)
        case .spanish: return Color(red: 0.13, green: 0.11, blue: 0.12)
        case nil: return LiveTVPalette.background
        }
    }
}

private enum LiveTVPalette {
    static let background = Color(red: 0.018, green: 0.027, blue: 0.034)
    static let panel = Color(red: 0.027, green: 0.039, blue: 0.049)
    static let row = Color(red: 0.038, green: 0.052, blue: 0.062)
    static let focusedRow = Color(red: 0.075, green: 0.088, blue: 0.096)
    static let divider = Color.white.opacity(0.09)
    static let mutedText = Color.white.opacity(0.48)
    static let accent = Color(red: 0.96, green: 0.66, blue: 0.08)
}

private struct LiveChannelRow: View {
    let channel: LiveChannel
    let program: EPGProgram?
    let date: Date

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(
                url: channel.logoURL,
                symbol: "tv.fill",
                localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id),
                outerPadding: 4,
                artworkPadding: 8
            )
            .frame(width: 112, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(channel.name)
                        .font(.system(size: 23, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LiveTVPalette.accent)
                }

                Text(program?.title ?? channel.genre.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(LiveTVPalette.mutedText)
                    .lineLimit(1)

                if let program {
                    LiveProgressBar(program: program, date: date)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
    }
}

private struct LiveChannelRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> RowButtonBody {
        RowButtonBody(configuration: configuration)
    }

    struct RowButtonBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .background(
                    isFocused ? LiveTVPalette.focusedRow : LiveTVPalette.row,
                    in: RoundedRectangle(cornerRadius: 3)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isFocused ? LiveTVPalette.accent : LiveTVPalette.divider, lineWidth: isFocused ? 2 : 1)
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(LiveTVPalette.accent)
                        .frame(width: isFocused ? 5 : 0)
                }
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .shadow(color: isFocused ? .black.opacity(0.24) : .clear, radius: 8, y: 4)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
        }
    }
}

private struct LiveScheduleDisclosureButtonStyle: ButtonStyle {
    let isExpanded: Bool

    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration, isExpanded: isExpanded)
    }

    struct Body: View {
        let configuration: Configuration
        let isExpanded: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    isFocused ? Color.white.opacity(0.14) : Color.black.opacity(isExpanded ? 0.62 : 0.34),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            isFocused ? Color.white.opacity(0.92) : (isExpanded ? LiveTVPalette.accent : Color.white.opacity(0.13)),
                            lineWidth: isFocused || isExpanded ? 2 : 1
                        )
                }
                .scaleEffect(configuration.isPressed ? 0.98 : (isFocused ? 1.035 : 1))
                .shadow(color: isFocused ? .black.opacity(0.32) : .clear, radius: 12, y: 7)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isFocused)
        }
    }
}

private struct LiveProgressBar: View {
    let program: EPGProgram
    let date: Date

    private var progress: Double {
        let duration = program.end.timeIntervalSince(program.start)
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(program.start) / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.16))
                Rectangle()
                    .fill(LiveTVPalette.accent)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

private struct ProgramBackdrop: View {
    let imageURL: URL?
    let fallbackLogoURL: URL?
    var fallbackLogoAssetName: String? = nil
    let fallbackColor: Color
    var fallbackSymbol = "tv.fill"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [fallbackColor.opacity(0.9), SeasonTheme.raisedSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ArtworkView(
                url: fallbackLogoURL,
                symbol: fallbackSymbol,
                localAssetName: fallbackLogoAssetName,
                outerPadding: 10,
                artworkPadding: 18
            )
            .frame(width: 430, height: 270)
            .opacity(0.88)
            .shadow(color: .black.opacity(0.35), radius: 28, y: 14)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
    }
}

private struct LiveTVGuideView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedProgram: ProgramSelection?
    @FocusState private var focusedID: String?

    private var genres: [ChannelGenre] {
        ChannelGenre.allCases.filter { genre in
            model.liveChannels.contains(where: { $0.genre == genre })
        }
    }

    private var channels: [LiveChannel] {
        model.liveChannels.filter { channel in
            (model.selectedChannelGenre == nil || channel.genre == model.selectedChannelGenre) &&
            (model.liveSearchQuery.isEmpty || channel.name.localizedCaseInsensitiveContains(model.liveSearchQuery))
        }
    }

    private var guideWindow: EPGGuideWindow? {
        switch model.epgState {
        case .loaded(let window): return window
        case .loading(let cached): return cached
        case .failed(_, let cached): return cached
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, SeasonTheme.horizontalInset)
                .padding(.top, 30)
                .padding(.bottom, 18)

            filters
                .padding(.horizontal, SeasonTheme.horizontalInset)
                .padding(.bottom, 18)

            if model.liveChannels.isEmpty, let error = model.channelState.errorMessage {
                StatePanel(
                    title: "Live TV unavailable",
                    message: error,
                    symbol: "wifi.exclamationmark",
                    actionTitle: "Try again"
                ) { Task { await model.reload() } }
            } else if channels.isEmpty {
                StatePanel(
                    title: "No channels found",
                    message: model.liveSearchQuery.isEmpty ? "No channels are available for this group." : "Try another name or clear the search.",
                    symbol: "tv.slash",
                    actionTitle: "Clear filters"
                ) {
                    model.liveSearchQuery = ""
                    model.selectedChannelGenre = nil
                }
            } else {
                if let error = model.channelState.errorMessage {
                    InlineStatusBanner(message: "The lineup could not be refreshed. Showing the previous channels. \(error)") {
                        Task { await model.reload() }
                    }
                    .padding(.horizontal, SeasonTheme.horizontalInset)
                }

                guideHeader
                    .padding(.horizontal, SeasonTheme.horizontalInset)

                GuideGrid(
                    channels: channels,
                    guideWindow: guideWindow,
                    mappings: model.channelStationMappings,
                    timeAnchor: $model.guideTimeAnchor,
                    focusedID: $focusedID,
                    selectProgram: { channel, program in
                        selectedProgram = ProgramSelection(channel: channel, program: program)
                    },
                    play: { channel in Task { await model.play(channel) } }
                )
                .refreshable { await model.reload() }
            }
        }
        .sheet(item: $selectedProgram) { selection in
            ProgramInfoView(selection: selection) {
                selectedProgram = nil
                Task { await model.play(selection.channel) }
            }
        }
        .onAppear { restoreInitialFocus() }
        .onChange(of: focusedID) { _, newValue in
            model.lastFocusedLiveID = newValue
            guard let newValue, newValue.hasPrefix("program:") else { return }
            let programID = String(newValue.dropFirst("program:".count))
            if let program = channels.lazy.flatMap({ programs(for: $0) }).first(where: { $0.id == programID }) {
                model.guideTimeAnchor = program.start
            }
        }
        .onChange(of: channels.map(\.id)) { _, _ in
            guard !focusIsValid else {
                return
            }
            focusedID = nil
            restoreInitialFocus()
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text("LIVE TV")
                    .font(.caption.monospaced().weight(.bold))
                    .tracking(3)
                    .foregroundStyle(SeasonTheme.accent)
                Text("Guide")
                    .font(.system(size: 52, weight: .semibold))
                Text("\(channels.count) of \(model.liveChannels.count) channels")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                moveGuide(byDays: -1)
            } label: {
                Label("Previous day", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(FocusPillButtonStyle(isSelected: false))

            Button {
                moveGuide(byDays: 1)
            } label: {
                Label("Next day", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(FocusPillButtonStyle(isSelected: false))

            Button {
                model.guideTimeAnchor = Date()
                focusedID = nil
                Task { await model.loadEPG(around: model.guideTimeAnchor) }
                restoreInitialFocus()
            } label: {
                Label("Jump to Now", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(FocusPillButtonStyle(isSelected: false))
        }
    }

    private var filters: some View {
        HStack(spacing: 14) {
            TextField("Search channels", text: $model.liveSearchQuery)
                .frame(width: 410)
                .accessibilityIdentifier("guide.search")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterButton("All", symbol: "square.grid.2x2.fill", genre: nil)
                    ForEach(genres) { genre in
                        filterButton(genre.title, symbol: genre.symbol, genre: genre)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func filterButton(_ title: String, symbol: String, genre: ChannelGenre?) -> some View {
        Button {
            model.selectedChannelGenre = genre
        } label: {
            Label(
                title,
                systemImage: model.selectedChannelGenre == genre ? "checkmark.circle.fill" : symbol
            )
        }
        .buttonStyle(FocusPillButtonStyle(isSelected: model.selectedChannelGenre == genre))
        .accessibilityAddTraits(model.selectedChannelGenre == genre ? .isSelected : [])
    }

    private var guideHeader: some View {
        HStack(spacing: 16) {
            Text("CHANNEL")
                .frame(width: GuideGrid.channelWidth, alignment: .leading)
            HStack {
                Text(model.guideTimeAnchor, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                Spacer()
                epgStatus
            }
            .frame(maxWidth: .infinity)
        }
        .font(.caption.monospaced().weight(.bold))
        .tracking(1.5)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 46)
    }

    @ViewBuilder private var epgStatus: some View {
        switch model.epgState {
        case .loading:
            Label("UPDATING GUIDE", systemImage: "arrow.clockwise")
        case .failed:
            Label("GUIDE UPDATED EARLIER", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        case .unavailable:
            Text("SCHEDULE DATA PENDING")
        case .loaded:
            Text("NOW & NEXT")
        }
    }

    private func programs(for channel: LiveChannel) -> [EPGProgram] {
        guard let stationID = model.channelStationMappings[channel.id] else { return [] }
        return guideWindow?.programsByStationID[stationID] ?? []
    }

    private func moveGuide(byDays days: Int) {
        model.guideTimeAnchor = Calendar.current.date(byAdding: .day, value: days, to: model.guideTimeAnchor) ?? model.guideTimeAnchor
        focusedID = nil
        Task { await model.loadEPG(around: model.guideTimeAnchor) }
    }

    private func restoreInitialFocus() {
        guard focusedID == nil, let channel = channels.first else { return }
        if let previous = model.lastFocusedLiveID,
           channels.contains(where: { candidate in
               previous == "channel:\(candidate.id)" || programs(for: candidate).contains(where: { previous == "program:\($0.id)" })
           }) {
            focusedID = previous
        } else if let current = programs(for: channel).first(where: { $0.contains(model.guideTimeAnchor) }) {
            focusedID = "program:\(current.id)"
        } else {
            focusedID = "channel:\(channel.id)"
        }
    }

    private var focusIsValid: Bool {
        guard let focusedID else { return false }
        return channels.contains { channel in
            focusedID == "channel:\(channel.id)" ||
            programs(for: channel).contains { focusedID == "program:\($0.id)" }
        }
    }
}

private struct GuideGrid: View {
    static let channelWidth: CGFloat = 310

    let channels: [LiveChannel]
    let guideWindow: EPGGuideWindow?
    let mappings: [String: String]
    @Binding var timeAnchor: Date
    @FocusState.Binding var focusedID: String?
    let selectProgram: (LiveChannel, EPGProgram) -> Void
    let play: (LiveChannel) -> Void

    private let pointsPerMinute: CGFloat = 6

    private var windowStart: Date {
        guideWindow?.start ?? timeAnchor
    }

    private var windowEnd: Date {
        guideWindow?.end ?? timeAnchor.addingTimeInterval(8 * 3_600)
    }

    private var timelineWidth: CGFloat {
        max(1_360, EPGTimelineLayout(
            windowStart: windowStart,
            windowEnd: windowEnd,
            pointsPerMinute: Double(pointsPerMinute)
        ).width)
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                LazyVStack(spacing: 12) {
                    ForEach(channels) { channel in
                        channelCell(channel)
                    }
                }
                .frame(width: Self.channelWidth)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(channels) { channel in
                            programRow(channel)
                        }
                    }
                    .frame(width: timelineWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, SeasonTheme.horizontalInset)
            .padding(.vertical, 14)
            .padding(.bottom, 64)
        }
    }

    private func programs(for channel: LiveChannel) -> [EPGProgram] {
        guard let stationID = mappings[channel.id] else { return [] }
        return guideWindow?.programsByStationID[stationID] ?? []
    }

    private func channelCell(_ channel: LiveChannel) -> some View {
        Button { play(channel) } label: {
            HStack(spacing: 16) {
                ArtworkView(
                    url: channel.logoURL,
                    symbol: "tv.fill",
                    localAssetName: ChannelDirectory.brandAssetName(forPlaybackIdentity: channel.id)
                )
                    .frame(width: 78, height: 54)
                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.name).font(.headline).lineLimit(1)
                    Text(channel.genre.title.uppercased())
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "play.fill")
            }
            .padding(.horizontal, 16)
            .frame(width: Self.channelWidth, height: 86)
            .background(SeasonTheme.surface, in: RoundedRectangle(cornerRadius: SeasonTheme.cardRadius))
            .overlay { RoundedRectangle(cornerRadius: SeasonTheme.cardRadius).stroke(SeasonTheme.keyline) }
        }
        .buttonStyle(.card)
        .focused($focusedID, equals: "channel:\(channel.id)")
        .accessibilityLabel("\(channel.name), \(channel.genre.title), play channel")
        .accessibilityIdentifier("guide.channel.\(channel.id)")
    }

    @ViewBuilder private func programRow(_ channel: LiveChannel) -> some View {
        let items = programs(for: channel)
        if items.isEmpty {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Schedule unavailable").font(.headline)
                    Text("Use the channel Play button to watch \(channel.name)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .frame(width: timelineWidth, height: 86, alignment: .leading)
            .background(SeasonTheme.surface, in: RoundedRectangle(cornerRadius: SeasonTheme.cardRadius))
            .accessibilityElement(children: .combine)
        } else {
            ZStack(alignment: .leading) {
                Rectangle().fill(SeasonTheme.surface.opacity(0.45)).frame(width: timelineWidth, height: 86)
                ForEach(items) { program in
                    let frame = EPGTimelineLayout(
                        windowStart: windowStart,
                        windowEnd: windowEnd,
                        pointsPerMinute: Double(pointsPerMinute)
                    ).frame(for: program)
                    Button {
                        timeAnchor = program.start
                        selectProgram(channel, program)
                    } label: {
                        ProgramCell(
                            program: program,
                            visibleWidth: frame?.width ?? 0
                        )
                    }
                    .buttonStyle(.card)
                    .focused($focusedID, equals: "program:\(program.id)")
                    .offset(x: frame?.offset ?? 0)
                    .accessibilityLabel("\(program.title), \(program.start.formatted(date: .omitted, time: .shortened)) to \(program.end.formatted(date: .omitted, time: .shortened))")
                }
            }
            .frame(width: timelineWidth, height: 86, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: SeasonTheme.cardRadius))
        }
    }
}

private struct ProgramCell: View {
    let program: EPGProgram
    let visibleWidth: Double

    private var width: CGFloat {
        max(90, visibleWidth - 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(program.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(program.start.formatted(date: .omitted, time: .shortened)) – \(program.end.formatted(date: .omitted, time: .shortened))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(width: width, height: 82, alignment: .leading)
        .background(program.contains(Date()) ? SeasonTheme.accent.opacity(0.18) : SeasonTheme.surface)
        .overlay { RoundedRectangle(cornerRadius: SeasonTheme.cardRadius).stroke(program.contains(Date()) ? SeasonTheme.accent.opacity(0.8) : SeasonTheme.keyline) }
        .clipShape(RoundedRectangle(cornerRadius: SeasonTheme.cardRadius))
    }
}

private struct ProgramSelection: Identifiable {
    let channel: LiveChannel
    let program: EPGProgram
    var id: String { program.id }
}

private struct ProgramInfoView: View {
    let selection: ProgramSelection
    let play: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(selection.channel.name.uppercased())
                .font(.caption.monospaced().weight(.bold))
                .tracking(2)
                .foregroundStyle(SeasonTheme.accent)
            Text(selection.program.title)
                .font(.system(size: 46, weight: .semibold))
            Text("\(selection.program.start.formatted(date: .abbreviated, time: .shortened)) – \(selection.program.end.formatted(date: .omitted, time: .shortened))")
                .font(.title3)
                .foregroundStyle(.secondary)
            if let synopsis = selection.program.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.title3)
                    .lineLimit(4)
                    .frame(maxWidth: 820, alignment: .leading)
            }
            HStack(spacing: 16) {
                Button(action: play) { Label("Watch channel", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(56)
        .frame(minWidth: 900, minHeight: 480, alignment: .leading)
        .background(SeasonTheme.background)
    }
}

private struct SportsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedCategoryID: String?
    @FocusState private var focusedItemID: String?
    @FocusState private var focusedActionID: String?
    @State private var showsOtherFeeds = false
    let entryFocusRequest: Int
    let onFocusNavigation: () -> Void

    private var focusedItem: MediaItem? {
        guard let category = model.selectedCategory else { return nil }
        if let focusedItemID,
           let item = category.items.first(where: { $0.id == focusedItemID }) {
            return item
        }
        if let restoredID = model.lastFocusedEventID,
           let item = category.items.first(where: { $0.id == restoredID }) {
            return item
        }
        return category.items.first
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - (SeasonTheme.horizontalInset * 2))
            let stageWidth = max(0, contentWidth - 560 - 22)

            VStack(spacing: 16) {
                categoryBar
                    .frame(width: contentWidth, alignment: .leading)

                if let error = model.eventState.errorMessage, !model.visibleSportsCategories.isEmpty {
                    InlineStatusBanner(message: "Events could not be refreshed. Showing the previous catalog. \(error)") {
                        Task { await model.reload() }
                    }
                    .frame(width: contentWidth)
                }

                if let error = model.sportsScheduleState.errorMessage {
                    InlineStatusBanner(message: "Sports details are unavailable. \(error)") {
                        Task { await model.loadSportsSchedule() }
                    }
                    .frame(width: contentWidth)
                }

                if let category = model.selectedCategory, !category.items.isEmpty {
                    HStack(alignment: .top, spacing: 22) {
                        eventBrowser(category)
                            .frame(width: 560)
                        eventStage(focusedItem)
                            .frame(width: stageWidth, alignment: .leading)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .clipped()
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
                } else if let category = model.selectedCategory {
                    StatePanel(
                        title: "No \(category.title) events",
                        message: "There are no events in the current sports schedule window.",
                        symbol: category.symbol,
                        actionTitle: "Refresh"
                    ) { Task { await model.reload() } }
                    .frame(width: contentWidth)
                } else if let error = model.eventState.errorMessage {
                    StatePanel(title: "Sports unavailable", message: error, symbol: "wifi.exclamationmark", actionTitle: "Try again") {
                        Task { await model.reload() }
                    }
                    .frame(width: contentWidth)
                } else if model.enabledSportsCategoryIDs.isEmpty {
                    StatePanel(title: "No categories enabled", message: "Open More, then Sports Categories to choose what appears here.", symbol: "slider.horizontal.3", actionTitle: nil) {}
                        .frame(width: contentWidth)
                } else {
                    StatePanel(title: "No events available", message: "Refresh to check for current sports and events.", symbol: "sportscourt", actionTitle: "Refresh") {
                        Task { await model.reload() }
                    }
                    .frame(width: contentWidth)
                }
            }
            .padding(.horizontal, SeasonTheme.horizontalInset)
            .padding(.top, 18)
            .padding(.bottom, 26)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .background(LiveTVPalette.background)
        .refreshable { await model.reload() }
        .onChange(of: focusedItemID) { _, itemID in
            if let itemID { model.lastFocusedEventID = itemID }
            showsOtherFeeds = false
        }
        .onChange(of: entryFocusRequest) { _, _ in
            focusSelectedCategory()
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.visibleSportsCategories) { category in
                    Button {
                        model.selectedCategoryID = category.id
                        focusedItemID = nil
                        focusedActionID = nil
                        showsOtherFeeds = false
                    } label: {
                        Label(
                            category.title,
                            systemImage: model.selectedCategoryID == category.id ? "checkmark.circle.fill" : category.symbol
                        )
                    }
                    .buttonStyle(FocusPillButtonStyle(isSelected: model.selectedCategoryID == category.id))
                    .focused($focusedCategoryID, equals: category.id)
                    .onMoveCommand { direction in
                        switch direction {
                        case .up: onFocusNavigation()
                        case .down: focusSelectedEvent()
                        default: break
                        }
                    }
                    .accessibilityAddTraits(model.selectedCategoryID == category.id ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func eventBrowser(_ category: CatalogCategory) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.title.uppercased())
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(0.8)
                Spacer()
                Text("\(category.items.count) EVENTS")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(LiveTVPalette.mutedText)
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(category.items) { item in
                            Button { activateEvent(item) } label: {
                                SportsEventRow(item: item)
                            }
                            .buttonStyle(LiveChannelRowButtonStyle())
                            .focused($focusedItemID, equals: item.id)
                            .id(item.id)
                            .onMoveCommand { direction in
                                switch direction {
                                case .up where category.items.first?.id == item.id:
                                    focusSelectedCategory()
                                case .right where item.sportsPlaybackAvailable(at: Date()):
                                    focusBestAction()
                                default:
                                    break
                                }
                            }
                            .accessibilityLabel(
                                "\(item.title), \(item.subtitle ?? "Live"), \(eventActionDescription(for: item))"
                            )
                            .accessibilityIdentifier("sports.item.\(item.id)")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: focusedItemID) { _, itemID in
                    guard let itemID else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        proxy.scrollTo(itemID, anchor: .center)
                    }
                }
            }
        }
        .padding(18)
        .background(LiveTVPalette.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(LiveTVPalette.divider) }
    }

    private func eventStage(_ item: MediaItem?) -> some View {
        let best = item.flatMap(bestOption)
        let baseballFeeds = item.map(baseballPrimaryOptions) ?? []
        let alternates = item.map {
            baseballFeeds.isEmpty ? otherOptions(for: $0) : otherBaseballOptions(for: $0, primary: baseballFeeds)
        } ?? []

        return ZStack(alignment: .bottomLeading) {
            SportsEventBackdrop(item: item)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.2), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: 220)

                Text(stageEyebrow(for: item))
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(LiveTVPalette.accent)

                Text(item?.title ?? "Choose an event")
                    .font(.system(size: 42, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let subtitle = item?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(LiveTVPalette.mutedText)
                }

                if let event = item?.sportsEvent, !event.broadcasts.isEmpty {
                    Label(
                        event.broadcastChannels.joined(separator: "  ·  "),
                        systemImage: "tv"
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LiveTVPalette.mutedText)
                    .lineLimit(1)
                }

                if let item, !baseballFeeds.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(baseballFeeds) { option in
                            Button { play(item, option: option) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "play.fill")
                                        .font(.title3.weight(.bold))
                                    Text(option.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(BroadcastPrimaryButtonStyle())
                            .focused($focusedActionID, equals: option.id)
                            .onMoveCommand { if $0 == .left { focusSelectedEvent() } }
                        }
                    }

                    alternateFeedPicker(item, options: alternates)
                } else if let item, let best {
                    Button { play(item, option: best) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "play.fill")
                                .font(.title3.weight(.bold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Play Best Feed")
                                    .font(.headline)
                                Text(best.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(BroadcastPrimaryButtonStyle())
                    .focused($focusedActionID, equals: "best")
                    .onMoveCommand { if $0 == .left { focusSelectedEvent() } }

                    alternateFeedPicker(item, options: alternates)
                } else if let item {
                    Label(unavailableActionTitle(for: item, at: Date()), systemImage: "clock")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(LiveTVPalette.mutedText)
                }
            }
            .padding(36)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(LiveTVPalette.divider) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: item?.id)
    }

    @ViewBuilder
    private func alternateFeedPicker(_ item: MediaItem, options: [MediaItem.PlaybackOption]) -> some View {
        if !options.isEmpty {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    showsOtherFeeds.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("More Feeds")
                            .font(.headline)
                        Text("\(options.count) additional broadcasts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: showsOtherFeeds ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(BroadcastDisclosureButtonStyle(isExpanded: showsOtherFeeds))
            .focused($focusedActionID, equals: "other-feeds")
            .onMoveCommand { if $0 == .left { focusSelectedEvent() } }

            if showsOtherFeeds {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(options) { option in
                            Button { play(item, option: option) } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(option.title).lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(BroadcastFeedButtonStyle())
                            .focused($focusedActionID, equals: option.id)
                            .onMoveCommand { if $0 == .left { focusSelectedEvent() } }
                        }
                    }
                }
                .frame(maxHeight: 205)
                .transition(.opacity)
            }
        }
    }

    private func bestOption(for item: MediaItem) -> MediaItem.PlaybackOption? {
        guard item.sportsPlaybackAvailable(at: Date()) else { return nil }
        let playable = item.playbackOptions.filter { option in
            if case .unavailable = option.playback { return false }
            return true
        }
        #if !targetEnvironment(simulator)
        if let fairPlayHD = playable.first(where: { option in
            if case .drmPage = option.playback { return true }
            return false
        }) {
            return fairPlayHD
        }
        #endif
        return playable.first
    }

    private func stageEyebrow(for item: MediaItem?) -> String {
        guard let item else { return "SPORTS & EVENTS" }
        if item.sportsPlaybackAvailable(at: Date()) { return "LIVE & ON DEMAND" }
        return item.sportsEvent?.league?.uppercased() ?? "UPCOMING"
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

    private func otherOptions(for item: MediaItem) -> [MediaItem.PlaybackOption] {
        guard let best = bestOption(for: item) else { return [] }
        return item.playbackOptions.filter { option in
            guard option.id != best.id else { return false }
            if case .unavailable = option.playback { return false }
            return true
        }
    }

    private func baseballPrimaryOptions(for item: MediaItem) -> [MediaItem.PlaybackOption] {
        guard item.categoryID == "baseball",
              item.sportsPlaybackAvailable(at: Date()) else { return [] }
        let playable = item.playbackOptions.filter(isPlayableOption)
        return playable.filter { option in
            let title = option.title.lowercased()
            guard !title.contains("dvr") else { return false }
            return title.hasPrefix("home feed")
                || title.hasPrefix("away feed")
                || title.hasPrefix("national feed")
        }
    }

    private func otherBaseballOptions(
        for item: MediaItem,
        primary: [MediaItem.PlaybackOption]
    ) -> [MediaItem.PlaybackOption] {
        let primaryIDs = Set(primary.map(\.id))
        return item.playbackOptions.filter { option in
            !primaryIDs.contains(option.id) && isPlayableOption(option)
        }
    }

    private func isPlayableOption(_ option: MediaItem.PlaybackOption) -> Bool {
        if case .unavailable = option.playback { return false }
        return true
    }

    private func eventActionDescription(for item: MediaItem) -> String {
        guard item.sportsPlaybackAvailable(at: Date()) else {
            return unavailableActionTitle(for: item, at: Date())
        }
        return baseballPrimaryOptions(for: item).count > 1
            ? "press to choose home or away feed"
            : "press to play"
    }

    private func activateEvent(_ item: MediaItem) {
        guard item.sportsPlaybackAvailable(at: Date()) else { return }
        let baseballFeeds = baseballPrimaryOptions(for: item)
        guard baseballFeeds.count > 1, let firstFeed = baseballFeeds.first else {
            playBest(item)
            return
        }
        focusedItemID = item.id
        DispatchQueue.main.async { focusedActionID = firstFeed.id }
    }

    private func playBest(_ item: MediaItem) {
        guard item.sportsPlaybackAvailable(at: Date()) else { return }
        guard let best = bestOption(for: item) else {
            Task { await model.play(item) }
            return
        }
        play(item, option: best)
    }

    private func play(_ item: MediaItem, option: MediaItem.PlaybackOption) {
        Task { await model.play(item, option: option) }
    }

    private func focusBestAction() {
        let actionID = focusedItem.flatMap { baseballPrimaryOptions(for: $0).first?.id } ?? "best"
        DispatchQueue.main.async { focusedActionID = actionID }
    }

    private func focusSelectedCategory() {
        focusedItemID = nil
        let categoryID = model.selectedCategoryID
        DispatchQueue.main.async {
            focusedCategoryID = categoryID
        }
    }

    private func focusSelectedEvent() {
        guard let category = model.selectedCategory else { return }
        let restoredID = model.lastFocusedEventID.flatMap { previous in
            category.items.contains(where: { $0.id == previous }) ? previous : nil
        }
        guard let itemID = restoredID ?? category.items.first?.id else { return }
        focusedCategoryID = nil
        DispatchQueue.main.async {
            focusedItemID = itemID
        }
    }

}

private struct SportsEventRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 14) {
            SportsEventThumbnail(item: item)
                .frame(width: 112, height: 70)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 22, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(item.subtitle ?? "Live")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(LiveTVPalette.mutedText)
                        .lineLimit(1)
                    Spacer()
                    if item.sportsPlaybackAvailable(at: Date()) && item.hasMultiplePlaybackOptions {
                        Text("\(item.playbackOptions.count) FEEDS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(LiveTVPalette.accent)
                    } else {
                        Image(systemName: item.sportsPlaybackAvailable(at: Date()) ? "play.fill" : "clock")
                            .foregroundStyle(item.sportsPlaybackAvailable(at: Date()) ? LiveTVPalette.accent : LiveTVPalette.mutedText)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
    }
}

private struct SportsEventThumbnail: View {
    let item: MediaItem

    var body: some View {
        if let event = item.sportsEvent,
           event.awayTeamLogoURL != nil || event.homeTeamLogoURL != nil {
            HStack(spacing: 7) {
                TeamLogoView(name: event.awayTeam, url: event.awayTeamLogoURL)
                TeamLogoView(name: event.homeTeam, url: event.homeTeamLogoURL)
            }
            .padding(8)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
        } else {
            ArtworkView(url: item.imageURL, symbol: "sportscourt.fill")
        }
    }
}

private struct SportsEventBackdrop: View {
    let item: MediaItem?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.17), Color(red: 0.035, green: 0.04, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let thumbnailURL = item?.sportsEvent?.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            } else if let event = item?.sportsEvent,
                      event.awayTeamLogoURL != nil || event.homeTeamLogoURL != nil {
                HStack(spacing: 56) {
                    TeamLogoView(name: event.awayTeam, url: event.awayTeamLogoURL)
                    Text("@")
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
                    TeamLogoView(name: event.homeTeam, url: event.homeTeamLogoURL)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 58)
                .padding(.vertical, 44)
            } else {
                ArtworkView(url: item?.imageURL, symbol: "sportscourt.fill")
                    .frame(width: 430, height: 270)
                    .opacity(0.88)
            }
        }
    }
}

private struct TeamLogoView: View {
    let name: String?
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Text(initials)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let words = (name ?? "Team").split(separator: " ")
        return String(words.suffix(2).compactMap(\.first)).uppercased()
    }
}

private struct BroadcastPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 26)
            .frame(height: 108)
            .background(isFocused ? Color.white : SeasonTheme.accent.opacity(0.92))
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isFocused ? 1.025 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.34 : 0.18), radius: isFocused ? 20 : 8, y: 8)
            .animation(.easeOut(duration: 0.14), value: isFocused)
    }
}

private struct SportsSettingsRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 22)
            .frame(height: 64)
            .background(isFocused ? Color.white : SeasonTheme.surface)
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(SeasonTheme.keyline) }
            .scaleEffect(isFocused ? 1.012 : 1)
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

private struct BroadcastDisclosureButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    let isExpanded: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .frame(height: 82)
            .background(isFocused ? Color.white : SeasonTheme.surface)
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isExpanded ? SeasonTheme.accent.opacity(0.75) : SeasonTheme.keyline, lineWidth: 1.5)
            }
            .scaleEffect(isFocused ? 1.018 : 1)
            .animation(.easeOut(duration: 0.14), value: isFocused)
    }
}

private struct BroadcastFeedButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .frame(height: 66)
            .background(isFocused ? Color.white : SeasonTheme.surface)
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(SeasonTheme.keyline) }
            .scaleEffect(isFocused ? 1.025 : 1)
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}
