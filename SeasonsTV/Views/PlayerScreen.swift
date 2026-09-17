import AVKit
import SwiftUI
import UIKit

private enum PlayerChromeLayer: Equatable {
    case hidden
    case controls
    case quickSwitch
    case fantasyDrawer
}

private enum FantasyDrawerTab: String, CaseIterable, Hashable {
    case matchup = "Matchup"
    case league = "League"

    var symbol: String {
        switch self {
        case .matchup: return "person.2.fill"
        case .league: return "list.number"
        }
    }
}

private final class PlayerChromeModel: ObservableObject {
    @Published var layer: PlayerChromeLayer = .hidden
    private var backLockedUntil = Date.distantPast
    var hideTask: Task<Void, Never>?

    func acquireBack() -> Bool {
        guard Date() >= backLockedUntil else { return false }
        backLockedUntil = Date().addingTimeInterval(0.45)
        return true
    }
}

struct PlayerScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var chrome = PlayerChromeModel()

    var body: some View {
        Group {
            if let session = model.playbackSession {
                PlayerSessionView(session: session, chrome: chrome)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}

private struct PlayerSessionView: View {
    private enum FocusTarget: Hashable {
        case playPause
        case favorite
        case guide
        case captions
        case fantasyScorebug
        case quickSwitchTrigger
        case quickSwitch(String)
    }

    @ObservedObject var session: PlaybackSession
    @ObservedObject var chrome: PlayerChromeModel
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var failureActionFocused: Bool
    @FocusState private var playerFocused: Bool
    @FocusState private var focusedTarget: FocusTarget?
    @State private var passiveChromeVisible = true
    @State private var isPaused = false
    @State private var lastControlFocus: FocusTarget = .playPause
    @State private var channelSurfTargetID: String?
    @State private var channelSurfMessage: String?
    @State private var channelSurfMessageTask: Task<Void, Never>?
    @State private var pageCommandPosition = 0
    @State private var verticalInputLockedUntil = Date.distantPast
    @State private var captionsPresented = false
    @State private var playbackDismissScheduled = false

    private var quickSwitchEntries: [QuickSwitchRailEntry] { model.quickSwitchEntries }
    private var currentGuideProgram: EPGProgram? {
        guard let target = model.activePlaybackTarget else { return nil }
        return model.guideProgram(for: target)
    }
    private var nextGuideProgram: EPGProgram? {
        guard let target = model.activePlaybackTarget else { return nil }
        return model.nextGuideProgram(for: target)
    }
    private var remoteControlHint: String {
        if model.playbackPresentation == .fantasyZone {
            return "Matchup · Details   Down · Quick Switch   Hold Select · Last Stream"
        }
        if session.isLivePlayback, model.lastPlaybackTarget != nil {
            return "Down · Quick Switch   Hold Select · Last Stream"
        }
        return session.isLivePlayback
            ? "Down · Quick Switch"
            : "Down · Quick Switch   Left/Right · 10 seconds"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            playbackSurface

            if model.playbackPresentation == .fantasyZone,
               session.isReady,
               session.playbackError == nil {
                if chrome.layer == .fantasyDrawer {
                    FantasyPlaybackDrawer {
                        closeFantasyDrawer()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if chrome.layer != .controls {
                    fantasyScorebug
                }
            }

            if session.playbackError == nil,
               session.isReady,
               chrome.layer != .fantasyDrawer,
               passiveChromeVisible || chrome.layer != .hidden {
                playerChrome
                    .transition(.opacity)
            }

            if !session.isReady && session.playbackError == nil {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Preparing \(session.title)…")
                        .font(.headline)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 22)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityElement(children: .combine)
            }

            if session.isReady,
               session.playbackError == nil,
               chrome.layer == .hidden,
               let channelSurfMessage {
                HStack(spacing: 13) {
                    if channelSurfTargetID != nil {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(SeasonTheme.liveSignal)
                    }
                    Text(channelSurfMessage)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                }
                .foregroundStyle(SeasonTheme.paper)
                .padding(.horizontal, 22)
                .frame(minHeight: 58)
                .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline) }
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            }

            if let playbackError = session.playbackError {
                failureView(playbackError)
            }
        }
        .interactiveDismissDisabled(true)
        .focusable(session.playbackError == nil && chrome.layer == .hidden)
        .focused($playerFocused)
        .onAppear {
            session.player.play()
            playerFocused = true
            passiveChromeVisible = true
            scheduleChromeHide(after: 4)
        }
        .onDisappear {
            chrome.hideTask?.cancel()
            channelSurfMessageTask?.cancel()
        }
        .onChange(of: session.id) { _, _ in
            session.player.play()
            isPaused = false
            captionsPresented = false
            passiveChromeVisible = true
            scheduleChromeHide(after: chrome.layer == .hidden ? 4 : 10)
        }
        .onChange(of: model.activePlaybackTarget?.id) { previous, current in
            guard previous != nil,
                  current != nil,
                  current != previous,
                  model.playbackSwitchMessage == nil else { return }
            clearChannelSurfStatus()
            hideChrome()
        }
        .onChange(of: session.playbackError) { _, error in
            failureActionFocused = error != nil
        }
        .onChange(of: focusedTarget) { previous, target in
            guard let target else { return }
            if target == .quickSwitchTrigger {
                showQuickSwitch()
                return
            }
            if target == .playPause || target == .favorite || target == .guide || target == .captions {
                lastControlFocus = target
                if case .quickSwitch = previous {
                    showControls(restoring: true)
                    return
                }
            }
            scheduleChromeHide(after: 10)
        }
        .onChange(of: model.switchingPlaybackTargetID) { previous, current in
            guard previous != nil, current == nil else { return }
            if let message = model.playbackSwitchMessage,
               channelSurfTargetID != nil {
                channelSurfTargetID = nil
                channelSurfMessage = message
                scheduleChannelSurfMessageHide()
            } else if model.playbackSwitchMessage == nil {
                clearChannelSurfStatus()
                hideChrome()
            }
        }
        .onChange(of: quickSwitchEntries.map(\.id)) { _, identifiers in
            guard case .quickSwitch(let focusedID) = focusedTarget,
                  !identifiers.contains(focusedID) else { return }
            focusFirstQuickSwitchEntry()
        }
        .onChange(of: captionsPresented) { _, isPresented in
            if isPresented {
                chrome.hideTask?.cancel()
            } else if chrome.layer != .hidden {
                scheduleChromeHide(after: 10)
            }
        }
        .confirmationDialog(
            "Subtitles & Captions",
            isPresented: $captionsPresented,
            titleVisibility: .visible
        ) {
            if session.subtitleOptions.isEmpty {
                Button("No captions available") {}
                    .disabled(true)
            } else {
                Button(session.selectedSubtitleOptionID == nil ? "Off  ✓" : "Off") {
                    session.selectSubtitle(nil)
                }
                ForEach(session.subtitleOptions) { option in
                    Button(session.selectedSubtitleOptionID == option.id ? "\(option.title)  ✓" : option.title) {
                        session.selectSubtitle(option.id)
                    }
                }
            }
        } message: {
            Text("Choose a caption track for this stream.")
        }
        .onExitCommand(perform: handlePlayerBack)
        .onPlayPauseCommand(perform: togglePlayback)
        .task(id: session.id) {
            guard model.playbackPresentation == .fantasyZone else { return }
            while !Task.isCancelled {
                await model.refreshFantasyZone()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    return
                }
            }
        }
        .pageCommand(value: $pageCommandPosition, in: -10_000...10_000, step: 1)
        .onChange(of: pageCommandPosition) { previous, current in
            guard previous != current else { return }
            _ = requestChannelChange(by: current > previous ? 1 : -1)
        }
        .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
        .onKeyPress(.upArrow, phases: .down) { _ in handleUp() }
        .onKeyPress(.escape, phases: .down) { _ in
            guard chrome.layer == .hidden, playerFocused else { return .ignored }
            handleBack()
            return .handled
        }
        .onMoveCommand(perform: handlePlayerMove)
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.6)
                .exclusively(before: TapGesture())
                .onEnded { result in
                    guard session.playbackError == nil,
                          chrome.layer == .hidden else { return }
                    switch result {
                    case .first(let completed):
                        if completed { returnToLastStream() }
                    case .second:
                        showControls(restoring: false)
                    }
                }
        )
    }

    @ViewBuilder
    private var playbackSurface: some View {
        PlayerSurface(player: session.player)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var fantasyScorebug: some View {
        VStack {
            HStack {
                Spacer()
                FantasyScorebugContent()
            }
            Spacer()
        }
        .padding(.top, 42)
        .padding(.horizontal, 56)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: chrome.layer)
    }

    private var playerChrome: some View {
        VStack(spacing: 0) {
            if model.playbackPresentation == .fantasyZone,
               chrome.layer == .controls {
                HStack {
                    Spacer()
                    Button(action: showFantasyDrawer) {
                        FantasyScorebugContent()
                    }
                    .buttonStyle(FantasyScorebugButtonStyle())
                    .focused($focusedTarget, equals: .fantasyScorebug)
                    .onKeyPress(.downArrow) {
                        focusedTarget = lastControlFocus
                        return .handled
                    }
                    .onMoveCommand { direction in
                        guard direction == .down else { return }
                        focusedTarget = lastControlFocus
                    }
                    .accessibilityLabel("Open fantasy matchup")
                    .accessibilityHint("Shows your matchup, lineups, and league scores")
                }
                .padding(.horizontal, 56)
                .padding(.top, 42)
                .focusSection()
            } else if model.playbackPresentation != .fantasyZone {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        if session.isLivePlayback {
                            Circle()
                                .fill(SeasonTheme.liveSignal)
                                .frame(width: 8, height: 8)
                        }
                        Text(session.isLivePlayback ? "LIVE" : "PLAYBACK")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                        Text(session.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(SeasonTheme.paper)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.black.opacity(0.74))
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(SeasonTheme.keyline) }
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .padding(.horizontal, 56)
                .padding(.top, 42)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 13) {
                playerIdentity

                if chrome.layer != .hidden {
                    playerControls
                        .opacity(chrome.layer == .quickSwitch ? 0.62 : 1)
                }

                if chrome.layer == .quickSwitch {
                    quickSwitchRail
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.leading, 64)
            .padding(.trailing, 64)
            .padding(.top, 70)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: chrome.layer)
    }

    private var playerIdentity: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(model.activePlaybackTarget?.sourceLabel ?? "LIVE NOW")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(SeasonTheme.liveSignal)
            Text(currentGuideProgram?.title ?? session.title)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(SeasonTheme.paper)
                .lineLimit(1)

            if let program = currentGuideProgram {
                HStack(spacing: 12) {
                    Text(program.start.formatted(date: .omitted, time: .shortened))
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(SeasonTheme.paper.opacity(0.24))
                            Capsule()
                                .fill(SeasonTheme.liveSignal)
                                .frame(width: geometry.size.width * guideProgress(for: program))
                        }
                    }
                    .frame(height: 3)
                    Text(program.end.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(SeasonTheme.paper)

                HStack(spacing: 12) {
                    Text(session.title)
                    if let nextGuideProgram {
                        Text("Next · \(nextGuideProgram.title)")
                            .foregroundStyle(SeasonTheme.secondaryText)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            } else {
                HStack(spacing: 10) {
                    Rectangle().fill(SeasonTheme.paper.opacity(0.24)).frame(height: 3)
                    if session.isLivePlayback {
                        Circle().fill(SeasonTheme.liveSignal).frame(width: 9, height: 9)
                    }
                    Text(session.isLivePlayback ? "LIVE EDGE" : "ON DEMAND")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(SeasonTheme.paper)
                }
            }
        }
    }

    private func guideProgress(for program: EPGProgram, at date: Date = Date()) -> CGFloat {
        let duration = program.end.timeIntervalSince(program.start)
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, date.timeIntervalSince(program.start) / duration)))
    }

    private var playerControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Button(action: togglePlayback) {
                    Label(isPaused ? "Play" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(PlayerControlButtonStyle())
                .focused($focusedTarget, equals: .playPause)
                .onExitCommand(perform: handleBack)
                .onKeyPress(.upArrow) { handleControlUp() }
                .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                .onKeyPress(.escape, phases: .down) { _ in
                    handleBack()
                    return .handled
                }
                .onMoveCommand(perform: handleControlMove)
                .accessibilityIdentifier("player.control.playPause")

                if let channelID = model.activeLiveChannelID {
                    Button {
                        model.setChannelFavorite(
                            channelID,
                            favorite: !model.isChannelFavorite(channelID)
                        )
                    } label: {
                        Label(
                            model.isChannelFavorite(channelID) ? "Favorited" : "Favorite",
                            systemImage: model.isChannelFavorite(channelID) ? "star.fill" : "star"
                        )
                    }
                    .buttonStyle(PlayerControlButtonStyle())
                    .focused($focusedTarget, equals: .favorite)
                    .onExitCommand(perform: handleBack)
                    .onKeyPress(.upArrow) { handleControlUp() }
                    .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                    .onKeyPress(.escape, phases: .down) { _ in
                        handleBack()
                        return .handled
                    }
                    .onMoveCommand(perform: handleControlMove)
                    .accessibilityIdentifier("player.control.favorite")
                }

                Button {
                    if model.playbackPresentation == .fantasyZone {
                        showFantasyDrawer()
                    } else {
                        model.destination = .liveTV
                        model.dismissPlayback()
                    }
                } label: {
                    Label(
                        model.playbackPresentation == .fantasyZone ? "Matchup" : "Guide",
                        systemImage: model.playbackPresentation == .fantasyZone
                            ? "trophy.fill"
                            : "rectangle.grid.1x2"
                    )
                }
                .buttonStyle(PlayerControlButtonStyle())
                .focused($focusedTarget, equals: .guide)
                .onExitCommand(perform: handleBack)
                .onKeyPress(.upArrow) { handleControlUp() }
                .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                .onKeyPress(.escape, phases: .down) { _ in
                    handleBack()
                    return .handled
                }
                .onMoveCommand(perform: handleControlMove)
                .accessibilityIdentifier("player.control.guide")

                if !session.subtitleOptions.isEmpty {
                    Button {
                        session.refreshSubtitleOptions()
                        captionsPresented = true
                    } label: {
                        Label(
                            session.selectedSubtitleTitle ?? "Captions",
                            systemImage: "captions.bubble"
                        )
                    }
                    .buttonStyle(PlayerControlButtonStyle())
                    .focused($focusedTarget, equals: .captions)
                    .onExitCommand(perform: handleBack)
                    .onKeyPress(.upArrow) { handleControlUp() }
                    .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                    .onKeyPress(.escape, phases: .down) { _ in
                        handleBack()
                        return .handled
                    }
                    .onMoveCommand(perform: handleControlMove)
                    .accessibilityLabel("Subtitles and captions")
                    .accessibilityValue(session.selectedSubtitleTitle ?? "Off")
                    .accessibilityIdentifier("player.control.captions")
                }

                Spacer()

                Text(remoteControlHint)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            .frame(height: 72)

            Button(action: showQuickSwitch) {
                Text("Open Quick Switch")
                    .font(.system(size: 1))
                    .foregroundStyle(Color.black)
                    .frame(width: 720, height: 18)
                    .background(Color.black)
            }
            .buttonStyle(.plain)
            .focused($focusedTarget, equals: .quickSwitchTrigger)
            .onExitCommand(perform: handleBack)
            .onKeyPress(.escape, phases: .down) { _ in
                handleBack()
                return .handled
            }
            .accessibilityLabel("Open Quick Switch")
        }
        .focusSection()
    }

    private var quickSwitchRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message = model.playbackSwitchMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SeasonTheme.liveSignal)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SeasonTheme.paper)
                        .lineLimit(1)
                    Spacer()
                    Button("Dismiss") { model.clearPlaybackSwitchMessage() }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(SeasonTheme.keyline) }
            }

            if quickSwitchEntries.isEmpty {
                Text("Choose favorite channels in Settings to make quick switching available.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .frame(height: 116)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 20) {
                            quickSwitchGroup(
                                title: "RECENT",
                                entries: quickSwitchEntries.filter { $0.section == .recent }
                            )
                            quickSwitchGroup(
                                title: "FAVORITES",
                                entries: quickSwitchEntries.filter { $0.section == .favorite }
                            )
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 7)
                    }
                    .onChange(of: focusedTarget) { _, target in
                        guard case .quickSwitch(let id) = target else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .frame(height: 158)
                .focusSection()
            }
        }
    }

    @ViewBuilder
    private func quickSwitchGroup(
        title: String,
        entries: [QuickSwitchRailEntry]
    ) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(SeasonTheme.paper.opacity(0.62))

                HStack(spacing: 12) {
                    ForEach(entries) { entry in
                        Button {
                            Task { await model.switchPlayback(to: entry.target) }
                        } label: {
                            QuickSwitchCard(
                                target: entry.target,
                                nowPlaying: model.quickSwitchNowPlayingTitle(for: entry.target),
                                nextProgram: model.quickSwitchNextProgramTitle(for: entry.target),
                                isSwitching: model.switchingPlaybackTargetID == entry.target.id
                            )
                        }
                        .buttonStyle(QuickSwitchButtonStyle())
                        .focused($focusedTarget, equals: .quickSwitch(entry.target.id))
                        .onExitCommand(perform: handleBack)
                        .onKeyPress(.upArrow, phases: .down) { _ in handleUp() }
                        .onKeyPress(.escape, phases: .down) { _ in
                            handleBack()
                            return .handled
                        }
                        .onMoveCommand(perform: handleQuickSwitchMove)
                        .disabled(model.switchingPlaybackTargetID != nil)
                        .id(entry.target.id)
                        .accessibilityIdentifier("player.quickSwitch.\(entry.target.id)")
                    }
                }
            }
        }
    }

    private func failureView(_ playbackError: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(SeasonTheme.liveSignal)
            Text("Playback unavailable")
                .font(.system(size: 42, weight: .regular, design: .serif))
                .foregroundStyle(SeasonTheme.paper)
            Text(playbackError)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)
            Button("Return to Browse") { model.dismissPlayback() }
                .buttonStyle(FocusPillButtonStyle(isSelected: true))
                .focused($failureActionFocused)
        }
        .padding(42)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func togglePlayback() {
        guard session.playbackError == nil else { return }
        if isPaused {
            session.player.play()
        } else {
            session.player.pause()
        }
        isPaused.toggle()
        passiveChromeVisible = true
        scheduleChromeHide(after: chrome.layer == .hidden ? 3 : 10)
    }

    private func handleDown() -> KeyPress.Result {
        guard Date() >= verticalInputLockedUntil else { return .handled }
        switch chrome.layer {
        case .hidden:
            if model.directionalChannelSurfingEnabled,
               requestChannelChange(by: 1) {
                return .handled
            }
            if quickSwitchEntries.isEmpty {
                showControls(restoring: false)
            } else {
                showQuickSwitch()
            }
        case .controls:
            showQuickSwitch()
        case .quickSwitch:
            scheduleChromeHide(after: 10)
        case .fantasyDrawer:
            break
        }
        return .handled
    }

    private func handlePlayerMove(_ direction: MoveCommandDirection) {
        guard chrome.layer == .hidden else { return }
        switch direction {
        case .down:
            _ = handleDown()
        case .up:
            _ = handleUp()
        case .left:
            _ = handleHorizontalSeek(by: -10)
        case .right:
            _ = handleHorizontalSeek(by: 10)
        @unknown default:
            break
        }
    }

    private func handleControlMove(_ direction: MoveCommandDirection) {
        guard Date() >= verticalInputLockedUntil else { return }
        switch direction {
        case .up where model.playbackPresentation == .fantasyZone:
            focusedTarget = .fantasyScorebug
            scheduleChromeHide(after: 10)
        case .down:
            showQuickSwitch()
        case .left, .right:
            let targets = controlFocusTargets
            guard !targets.isEmpty else { return }

            let currentIndex = focusedTarget.flatMap { targets.firstIndex(of: $0) }
                ?? targets.firstIndex(of: lastControlFocus)
                ?? 0
            let offset = direction == .left ? -1 : 1
            let nextIndex = min(max(currentIndex + offset, 0), targets.count - 1)
            let nextTarget = targets[nextIndex]
            focusedTarget = nextTarget
            lastControlFocus = nextTarget
            scheduleChromeHide(after: 10)
        default:
            break
        }
    }

    private var controlFocusTargets: [FocusTarget] {
        var targets: [FocusTarget] = [.playPause]
        if model.activeLiveChannelID != nil {
            targets.append(.favorite)
        }
        targets.append(.guide)
        if !session.subtitleOptions.isEmpty {
            targets.append(.captions)
        }
        return targets
    }

    private func handleControlUp() -> KeyPress.Result {
        guard model.playbackPresentation == .fantasyZone else { return .ignored }
        guard Date() >= verticalInputLockedUntil else { return .handled }
        focusedTarget = .fantasyScorebug
        scheduleChromeHide(after: 10)
        return .handled
    }

    private func handleQuickSwitchMove(_ direction: MoveCommandDirection) {
        guard direction == .up,
              Date() >= verticalInputLockedUntil else { return }
        showControls(restoring: true)
    }

    private func handleUp() -> KeyPress.Result {
        guard Date() >= verticalInputLockedUntil else { return .handled }
        switch chrome.layer {
        case .hidden:
            if model.directionalChannelSurfingEnabled,
               requestChannelChange(by: -1) {
                return .handled
            }
            showControls(restoring: false)
            return .handled
        case .controls:
            if model.playbackPresentation == .fantasyZone {
                focusedTarget = .fantasyScorebug
                scheduleChromeHide(after: 10)
                return .handled
            }
            return .ignored
        case .quickSwitch:
            showControls(restoring: true)
            return .handled
        case .fantasyDrawer:
            return .ignored
        }
    }

    private func handleHorizontalSeek(by offset: Double) -> KeyPress.Result {
        guard chrome.layer == .hidden else {
            scheduleChromeHide(after: 10)
            return .ignored
        }
        guard session.seek(by: offset) else { return .handled }
        passiveChromeVisible = true
        channelSurfMessageTask?.cancel()
        channelSurfTargetID = nil
        channelSurfMessage = offset < 0 ? "Back 10 seconds" : "Forward 10 seconds"
        scheduleChannelSurfMessageHide()
        scheduleChromeHide(after: 3)
        return .handled
    }

    private func returnToLastStream() {
        guard session.isLivePlayback,
              channelSurfTargetID == nil,
              model.switchingPlaybackTargetID == nil else { return }
        guard let target = model.lastPlaybackTarget else {
            channelSurfMessage = "No previous stream yet"
            scheduleChannelSurfMessageHide()
            return
        }

        channelSurfMessageTask?.cancel()
        channelSurfTargetID = target.id
        channelSurfMessage = "Returning to \(target.title)…"
        Task {
            await model.switchToLastPlayback()
            if model.switchingPlaybackTargetID == nil,
               channelSurfTargetID != nil {
                if let message = model.playbackSwitchMessage {
                    channelSurfTargetID = nil
                    channelSurfMessage = message
                    scheduleChannelSurfMessageHide()
                } else {
                    clearChannelSurfStatus()
                }
            }
        }
    }

    private func requestChannelChange(by offset: Int) -> Bool {
        guard channelSurfTargetID == nil,
              model.switchingPlaybackTargetID == nil,
              let target = model.adjacentLiveChannel(by: offset) else { return false }
        channelSurfMessageTask?.cancel()
        channelSurfTargetID = target.id
        channelSurfMessage = "Switching to \(target.name)…"
        Task {
            await model.changeLiveChannel(by: offset)
            if model.switchingPlaybackTargetID == nil,
               channelSurfTargetID != nil {
                if let message = model.playbackSwitchMessage {
                    channelSurfTargetID = nil
                    channelSurfMessage = message
                    scheduleChannelSurfMessageHide()
                } else {
                    clearChannelSurfStatus()
                }
            }
        }
        return true
    }

    private func handleBack() {
        let acquired = chrome.acquireBack()
        guard acquired else { return }
        switch chrome.layer {
        case .quickSwitch:
            showControls(restoring: true)
        case .controls:
            hideChrome()
        case .fantasyDrawer:
            closeFantasyDrawer()
        case .hidden:
            dismissPlaybackAfterBackPress()
        }
    }

    private func dismissPlaybackAfterBackPress() {
        guard !playbackDismissScheduled else { return }
        playbackDismissScheduled = true
        model.beginPlaybackBackDismissal()
        chrome.hideTask?.cancel()
        playerFocused = false

        // Keep this view in the hierarchy until tvOS finishes dispatching the
        // current Menu/Back event. Removing it synchronously lets that same
        // event fall through to the browse screen (and, on device, the system).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            model.dismissPlayback()
        }
    }

    private func handlePlayerBack() {
        guard chrome.layer == .hidden, playerFocused else { return }
        handleBack()
    }

    private func showControls(restoring: Bool) {
        if chrome.layer != .controls {
            lockVerticalInputBriefly()
        }
        passiveChromeVisible = true
        chrome.layer = .controls
        playerFocused = false
        DispatchQueue.main.async {
            focusedTarget = restoring ? lastControlFocus : .playPause
        }
        scheduleChromeHide(after: 10)
    }

    private func showQuickSwitch() {
        guard !quickSwitchEntries.isEmpty else {
            scheduleChromeHide(after: 10)
            return
        }
        if chrome.layer != .quickSwitch {
            lockVerticalInputBriefly()
        }
        passiveChromeVisible = true
        chrome.layer = .quickSwitch
        playerFocused = false
        focusFirstQuickSwitchEntry()
        scheduleChromeHide(after: 10)
    }

    private func showFantasyDrawer() {
        guard model.playbackPresentation == .fantasyZone else { return }
        chrome.hideTask?.cancel()
        passiveChromeVisible = true
        chrome.layer = .fantasyDrawer
        playerFocused = false
        focusedTarget = nil
    }

    private func closeFantasyDrawer() {
        passiveChromeVisible = true
        chrome.layer = .controls
        playerFocused = false
        DispatchQueue.main.async {
            focusedTarget = .fantasyScorebug
        }
        scheduleChromeHide(after: 10)
    }

    private func focusFirstQuickSwitchEntry() {
        guard let first = quickSwitchEntries.first else { return }
        DispatchQueue.main.async {
            focusedTarget = .quickSwitch(first.target.id)
        }
    }

    private func lockVerticalInputBriefly() {
        verticalInputLockedUntil = Date().addingTimeInterval(0.18)
    }

    private func hideChrome() {
        chrome.hideTask?.cancel()
        chrome.layer = .hidden
        passiveChromeVisible = false
        focusedTarget = nil
        DispatchQueue.main.async { playerFocused = true }
    }

    private func clearChannelSurfStatus() {
        channelSurfMessageTask?.cancel()
        channelSurfTargetID = nil
        channelSurfMessage = nil
    }

    private func scheduleChannelSurfMessageHide() {
        channelSurfMessageTask?.cancel()
        channelSurfMessageTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            clearChannelSurfStatus()
        }
    }

    private func scheduleChromeHide(after seconds: Double) {
        chrome.hideTask?.cancel()
        chrome.hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled,
                  model.switchingPlaybackTargetID == nil,
                  session.playbackError == nil,
                  chrome.layer != .fantasyDrawer else { return }
            hideChrome()
        }
    }
}

private struct FantasyScorebugContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                    Text("FANTASY MATCHUP")
                    if let week = model.fantasyMatchup?.week {
                        Text("· WEEK \(week)")
                    }
                    Spacer(minLength: 8)
                    if FantasyPlaybackState.hasLiveStarter(
                        matchup: model.fantasyMatchup,
                        events: model.fantasyNFLScoreboard,
                        at: context.date
                    ) {
                        Circle()
                            .fill(SeasonTheme.liveSignal)
                            .frame(width: 7, height: 7)
                        Text("LIVE")
                            .foregroundStyle(SeasonTheme.liveSignal)
                    }
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(SeasonTheme.paper.opacity(0.72))

                if let matchup = model.fantasyMatchup {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        scorebugTeam(
                            model.fantasyUserTeam?.name ?? "Your team",
                            score: matchup.userPoints,
                            alignment: .leading
                        )
                        Text("VS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(SeasonTheme.secondaryText)
                        scorebugTeam(
                            model.fantasyOpponentTeam?.name ?? "Opponent",
                            score: matchup.opponentPoints,
                            alignment: .trailing
                        )
                    }

                    Text(FantasyPlaybackState.summary(
                        matchup: matchup,
                        events: model.fantasyNFLScoreboard,
                        at: context.date
                    ))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(SeasonTheme.secondaryText)
                    .lineLimit(1)
                } else {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Loading your matchup…")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(height: 50)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(width: 430, alignment: .leading)
            .frame(minHeight: 112, alignment: .leading)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(SeasonTheme.keyline) }
            .shadow(color: .black.opacity(0.34), radius: 22, y: 10)
        }
    }

    private func scorebugTeam(
        _ name: String,
        score: Double?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SeasonTheme.paper.opacity(0.76))
                .lineLimit(1)
            Text(FantasyPlaybackState.score(score))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SeasonTheme.paper)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct FantasyScorebugButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FantasyScorebugButtonBody(configuration: configuration)
    }

    private struct FantasyScorebugButtonBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? SeasonTheme.focusVolt : .clear, lineWidth: SeasonTheme.focusLineWidth)
                }
                .scaleEffect(configuration.isPressed ? 0.98 : isFocused ? 1.025 : 1)
                .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.18) : .clear, radius: 24)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
        }
    }
}

private struct FantasyPlaybackDrawer: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedID: String?
    @State private var selectedTab: FantasyDrawerTab = .matchup
    @State private var selectedMatchupID: String?
    let close: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                drawerHeader
                tabBar
                Group {
                    switch selectedTab {
                    case .matchup:
                        lineupView
                    case .league:
                        leagueView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Text("MENU · CLOSE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            .padding(.horizontal, 34)
            .padding(.top, 42)
            .padding(.bottom, 28)
            .frame(width: 720)
            .background(.ultraThinMaterial)
            .background(Color(red: 0.075, green: 0.083, blue: 0.095).opacity(0.93))
            .overlay(alignment: .leading) {
                Rectangle().fill(SeasonTheme.paper.opacity(0.18)).frame(width: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 38, x: -18)
        }
        .ignoresSafeArea()
        .onAppear {
            selectedMatchupID = currentMatchup?.id
            DispatchQueue.main.async { focusedID = "tab:\(selectedTab.rawValue)" }
        }
        .onExitCommand(perform: close)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedTab)
    }

    private var drawerHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                    Text("FANTASY ZONE")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(SeasonTheme.liveSignal)
                Text(model.fantasyLeague?.name ?? "Your league")
                    .font(.system(size: 29, weight: .regular, design: .serif))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(1)
            }
            Spacer()
            if let week = model.fantasyMatchup?.week {
                Text("WEEK \(week)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(FantasyDrawerTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.symbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FantasyDrawerTabButtonStyle(isSelected: selectedTab == tab))
                .focused($focusedID, equals: "tab:\(tab.rawValue)")
                .onMoveCommand { direction in
                    moveTabFocus(from: tab, direction: direction)
                }
            }
        }
    }

    private func moveTabFocus(from tab: FantasyDrawerTab, direction: MoveCommandDirection) {
        let tabs = FantasyDrawerTab.allCases
        guard let index = tabs.firstIndex(of: tab) else { return }

        switch direction {
        case .left where index > tabs.startIndex:
            focusedID = "tab:\(tabs[tabs.index(before: index)].rawValue)"
        case .right where index < tabs.index(before: tabs.endIndex):
            focusedID = "tab:\(tabs[tabs.index(after: index)].rawValue)"
        default:
            break
        }
    }

    @ViewBuilder
    private var lineupView: some View {
        if let matchup = selectedMatchup {
            let left = matchup.participants.first
            let right = matchup.participants.dropFirst().first
            let rowCount = max(left?.starters.count ?? 0, right?.starters.count ?? 0)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    lineupTeamHeader(left, alignment: .leading)
                    lineupTeamHeader(right, alignment: .trailing)
                }
                Rectangle().fill(SeasonTheme.keyline).frame(height: 1)
                if rowCount == 0 {
                    FantasyDrawerEmptyState(message: "Lineup details are loading…")
                } else {
                    ForEach(0..<rowCount, id: \.self) { index in
                        HStack(spacing: 16) {
                            FantasyLineupPlayerCell(player: player(at: index, in: left), alignment: .leading)
                            FantasyLineupPlayerCell(player: player(at: index, in: right), alignment: .trailing)
                        }
                    }
                }
            }
        } else {
            FantasyDrawerEmptyState(message: "Lineup details are loading…")
        }
    }

    private var leagueView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(SeasonTheme.secondaryText)
            ForEach(orderedLeagueMatchups) { matchup in
                FantasyLeagueMatchupRow(
                    matchup: matchup,
                    league: model.fantasyLeague,
                    currentRosterID: model.fantasyMatchup?.userRosterID
                )
                .background(
                    Color.white.opacity(selectedMatchupID == matchup.id ? 0.065 : 0.035),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(SeasonTheme.keyline)
                }
            }
        }
    }

    private var currentMatchup: FantasyLeagueMatchup? {
        guard let snapshot = model.fantasyMatchup else { return nil }
        return snapshot.leagueMatchups.first {
            $0.participants.contains(where: { $0.rosterID == snapshot.userRosterID })
        }
    }

    private var selectedMatchup: FantasyLeagueMatchup? {
        guard let snapshot = model.fantasyMatchup else { return nil }
        if let selectedMatchupID,
           let selected = snapshot.leagueMatchups.first(where: { $0.id == selectedMatchupID }) {
            return selected
        }
        if let currentMatchup { return currentMatchup }
        var participants = [
            FantasyMatchupParticipant(
                rosterID: snapshot.userRosterID,
                points: snapshot.userPoints,
                starters: snapshot.userStarters
            )
        ]
        if let opponentRosterID = snapshot.opponentRosterID {
            participants.append(
                FantasyMatchupParticipant(
                    rosterID: opponentRosterID,
                    points: snapshot.opponentPoints ?? 0,
                    starters: snapshot.opponentStarters
                )
            )
        }
        return FantasyLeagueMatchup(
            id: "current",
            matchupID: snapshot.matchupID,
            participants: participants
        )
    }

    private var orderedLeagueMatchups: [FantasyLeagueMatchup] {
        guard let userRosterID = model.fantasyMatchup?.userRosterID else {
            return model.fantasyMatchup?.leagueMatchups ?? []
        }
        return (model.fantasyMatchup?.leagueMatchups ?? []).sorted { left, right in
            let leftIsUser = left.participants.contains { $0.rosterID == userRosterID }
            let rightIsUser = right.participants.contains { $0.rosterID == userRosterID }
            if leftIsUser != rightIsUser { return leftIsUser }
            return left.id < right.id
        }
    }

    private func lineupTeamHeader(
        _ participant: FantasyMatchupParticipant?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(model.fantasyLeague?.team(forRosterID: participant?.rosterID)?.name ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SeasonTheme.paper)
                .lineLimit(1)
            Text(FantasyPlaybackState.score(participant?.points))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(SeasonTheme.paper)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func player(
        at index: Int,
        in participant: FantasyMatchupParticipant?
    ) -> FantasyPlayerWeek? {
        guard let starters = participant?.starters, index < starters.count else { return nil }
        return starters[index]
    }
}

private struct FantasyDrawerTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        FantasyDrawerTabButtonBody(configuration: configuration, isSelected: isSelected)
    }

    private struct FantasyDrawerTabButtonBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SeasonTheme.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    isSelected ? SeasonTheme.paper.opacity(0.13) : SeasonTheme.surface,
                    in: Capsule()
                )
                .overlay {
                    Capsule().stroke(
                        isFocused ? SeasonTheme.focusVolt : isSelected ? SeasonTheme.paper.opacity(0.72) : SeasonTheme.keyline,
                        lineWidth: isFocused ? SeasonTheme.focusLineWidth : isSelected ? 2 : 1
                    )
                }
                .scaleEffect(configuration.isPressed ? 0.97 : isFocused ? 1.025 : 1)
                .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.16) : .clear, radius: 18)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
        }
    }
}

private struct FantasyLineupPlayerCell: View {
    let player: FantasyPlayerWeek?
    let alignment: HorizontalAlignment

    var body: some View {
        HStack(spacing: 9) {
            if alignment == .trailing { score }
            VStack(alignment: alignment, spacing: 2) {
                Text(player?.name ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(1)
                Text([player?.position, player?.nflTeam].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(SeasonTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            if alignment == .leading { score }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private var score: some View {
        Text(player.map { FantasyPlaybackState.score($0.points) } ?? "")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(SeasonTheme.paper)
            .monospacedDigit()
            .frame(width: 58, alignment: alignment == .leading ? .trailing : .leading)
    }
}

private struct FantasyLeagueMatchupRow: View {
    let matchup: FantasyLeagueMatchup
    let league: FantasyLeagueProfile?
    let currentRosterID: Int?

    var body: some View {
        let left = matchup.participants.first
        let right = matchup.participants.dropFirst().first
        HStack(spacing: 12) {
            leagueTeam(left, alignment: .leading)
            Text("VS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(SeasonTheme.secondaryText)
            leagueTeam(right, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
    }

    private func leagueTeam(
        _ participant: FantasyMatchupParticipant?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            HStack(spacing: 6) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(league?.team(forRosterID: participant?.rosterID)?.name ?? "—")
                    .lineLimit(1)
                if participant?.rosterID == currentRosterID {
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(SeasonTheme.liveSignal)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            Text(FantasyPlaybackState.score(participant?.points))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(SeasonTheme.paper)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct FantasyDrawerEmptyState: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SeasonTheme.secondaryText)
        }
        .padding(.top, 18)
    }
}

private enum FantasyPlayerGameState: Equatable {
    case live
    case upcoming
    case final
    case unknown
}

private enum FantasyPlaybackState {
    static func score(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(2))) ?? "—"
    }

    static func hasLiveStarter(
        matchup: FantasyMatchupSnapshot?,
        events: [SportsScheduleEvent],
        at date: Date
    ) -> Bool {
        guard let matchup else { return false }
        return (matchup.userStarters + matchup.opponentStarters).contains {
            gameState(for: $0, events: events, at: date) == .live
        }
    }

    static func summary(
        matchup: FantasyMatchupSnapshot,
        events: [SportsScheduleEvent],
        at date: Date
    ) -> String {
        let participants = [
            FantasyMatchupParticipant(
                rosterID: matchup.userRosterID,
                points: matchup.userPoints,
                starters: matchup.userStarters
            ),
            matchup.opponentRosterID.map {
                FantasyMatchupParticipant(
                    rosterID: $0,
                    points: matchup.opponentPoints ?? 0,
                    starters: matchup.opponentStarters
                )
            }
        ].compactMap { $0 }
        return summary(
            participants: participants,
            currentRosterID: matchup.userRosterID,
            events: events,
            at: date
        )
    }

    static func summary(
        participants: [FantasyMatchupParticipant],
        currentRosterID: Int?,
        events: [SportsScheduleEvent],
        at date: Date
    ) -> String {
        guard !participants.isEmpty else { return "MATCHUP UPDATING" }
        let ordered = participants.sorted { left, _ in left.rosterID == currentRosterID }
        let you = ordered.first(where: { $0.rosterID == currentRosterID }) ?? ordered[0]
        let opponent = ordered.first(where: { $0.rosterID != you.rosterID })
        let yourLeft = unfinishedCount(you.starters, events: events, at: date)
        let opponentLeft = unfinishedCount(opponent?.starters ?? [], events: events, at: date)
        let resolvedCount = (you.starters + (opponent?.starters ?? [])).filter {
            gameState(for: $0, events: events, at: date) != .unknown
        }.count

        if resolvedCount == 0 {
            guard let opponent else { return "OPPONENT PENDING" }
            let difference = you.points - opponent.points
            if abs(difference) < 0.005 { return "MATCHUP TIED" }
            return difference > 0
                ? "LEADING BY \(score(abs(difference)))"
                : "TRAILING BY \(score(abs(difference)))"
        }
        if yourLeft == 0, opponentLeft == 0 { return "MATCHUP FINAL" }
        if opponentLeft == 0 { return "\(yourLeft) LEFT · OPP FINAL" }
        if yourLeft == 0 { return "YOU FINAL · OPP \(opponentLeft) LEFT" }
        return "\(yourLeft) LEFT · OPP \(opponentLeft) LEFT"
    }

    static func gameState(
        for player: FantasyPlayerWeek,
        events: [SportsScheduleEvent],
        at date: Date
    ) -> FantasyPlayerGameState {
        guard let code = normalizedTeamCode(player.nflTeam),
              let event = events.first(where: { eventContainsTeam($0, code: code) }) else {
            return .unknown
        }
        let status = event.status?.lowercased() ?? ""
        if ["final", "postponed", "canceled", "cancelled"].contains(where: status.contains) {
            return .final
        }
        if ["live", "halftime", "quarter", "overtime", "end of"].contains(where: status.contains) {
            return .live
        }
        if event.startsAt > date { return .upcoming }
        if event.homeScore != nil || event.awayScore != nil { return .live }
        return .upcoming
    }

    private static func unfinishedCount(
        _ players: [FantasyPlayerWeek],
        events: [SportsScheduleEvent],
        at date: Date
    ) -> Int {
        players.filter {
            let state = gameState(for: $0, events: events, at: date)
            return state == .live || state == .upcoming
        }.count
    }

    private static func eventContainsTeam(_ event: SportsScheduleEvent, code: String) -> Bool {
        let home = normalizedTeamCode(teamCode(from: event.homeTeamLogoURL))
        let away = normalizedTeamCode(teamCode(from: event.awayTeamLogoURL))
        return home == code || away == code
    }

    private static func teamCode(from url: URL?) -> String? {
        url?.deletingPathExtension().lastPathComponent
    }

    private static func normalizedTeamCode(_ value: String?) -> String? {
        guard let value else { return nil }
        switch value.uppercased() {
        case "WAS": return "WSH"
        case "JAC": return "JAX"
        default: return value.uppercased()
        }
    }
}

private struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerSurfaceView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    static func dismantleUIView(_ view: PlayerSurfaceView, coordinator: Void) {
        view.playerLayer.player = nil
    }
}

private final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            preconditionFailure("PlayerSurfaceView must use AVPlayerLayer")
        }
        return playerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }
}

private struct QuickSwitchCard: View {
    let target: PlaybackTarget
    let nowPlaying: String?
    let nextProgram: String?
    let isSwitching: Bool

    var body: some View {
        HStack(spacing: 13) {
            ArtworkView(
                url: target.imageURL,
                symbol: target.channelID == nil ? "sportscourt.fill" : "tv.fill",
                localAssetName: target.channelID.flatMap {
                    ChannelDirectory.brandAssetName(forPlaybackIdentity: $0)
                },
                outerPadding: 5,
                artworkPadding: 7
            )
            .frame(width: 86, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(SeasonTheme.liveSignal)
                        .frame(width: 6, height: 6)
                    Text(target.sourceLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(SeasonTheme.liveSignal)
                }
                Text(target.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SeasonTheme.paper)
                    .lineLimit(1)
                Text(nowPlaying ?? target.detail ?? "Live stream")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeasonTheme.paper.opacity(0.78))
                    .lineLimit(1)
                if let nextProgram {
                    Text("Next · \(nextProgram)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(SeasonTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSwitching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 310, height: 112)
        .contentShape(Rectangle())
    }
}

private struct PlayerControlButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isFocused ? Color.black : SeasonTheme.paper)
            .padding(.horizontal, 18)
            .frame(minWidth: 132, minHeight: 64)
            .background(isFocused ? SeasonTheme.focusVolt : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isFocused ? SeasonTheme.focusVolt : SeasonTheme.keyline, lineWidth: isFocused ? 4 : 1)
                    .padding(isFocused ? -4 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : isFocused ? 1.025 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
    }
}

private struct QuickSwitchButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isFocused
                    ? SeasonTheme.focusVolt.opacity(0.09)
                    : Color(red: 0.055, green: 0.065, blue: 0.08).opacity(0.94)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isFocused ? SeasonTheme.focusVolt : SeasonTheme.keyline, lineWidth: isFocused ? 4 : 1)
                    .padding(isFocused ? -4 : 0)
            }
            .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.18) : .clear, radius: 18)
            .scaleEffect(configuration.isPressed ? 0.98 : isFocused ? 1.018 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
    }
}
