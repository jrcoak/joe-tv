import AVKit
import SwiftUI
import UIKit

private enum PlayerChromeLayer: Equatable {
    case hidden
    case controls
    case quickSwitch
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
            PlayerSurface(player: session.player)
                .ignoresSafeArea()

            if session.playbackError == nil,
               session.isReady,
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
            if target == .playPause || target == .favorite || target == .guide {
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
        .onExitCommand(perform: handlePlayerBack)
        .onPlayPauseCommand(perform: togglePlayback)
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

    private var playerChrome: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 64)
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
                    .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                    .onKeyPress(.escape, phases: .down) { _ in
                        handleBack()
                        return .handled
                    }
                    .onMoveCommand(perform: handleControlMove)
                    .accessibilityIdentifier("player.control.favorite")
                }

                Button {
                    model.destination = .liveTV
                    model.dismissPlayback()
                } label: {
                    Label("Guide", systemImage: "rectangle.grid.1x2")
                }
                .buttonStyle(PlayerControlButtonStyle())
                .focused($focusedTarget, equals: .guide)
                .onExitCommand(perform: handleBack)
                .onKeyPress(.downArrow, phases: .down) { _ in handleDown() }
                .onKeyPress(.escape, phases: .down) { _ in
                    handleBack()
                    return .handled
                }
                .onMoveCommand(perform: handleControlMove)
                .accessibilityIdentifier("player.control.guide")

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
            showControls(restoring: false)
        case .controls:
            showQuickSwitch()
        case .quickSwitch:
            scheduleChromeHide(after: 10)
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
        guard direction == .down,
              Date() >= verticalInputLockedUntil else { return }
        showQuickSwitch()
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
            return .ignored
        case .quickSwitch:
            showControls(restoring: true)
            return .handled
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
        case .hidden:
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
                  session.playbackError == nil else { return }
            hideChrome()
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
