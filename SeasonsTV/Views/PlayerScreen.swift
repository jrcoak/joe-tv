import AVKit
import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var session: PlaybackSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var failureActionFocused: Bool
    @State private var chromeVisible = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: session.player)
                .ignoresSafeArea()

            if session.playbackError == nil, session.isReady, chromeVisible {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Circle()
                                .fill(SeasonTheme.liveSignal)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
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

                    VStack(alignment: .leading, spacing: 9) {
                        Text("LIVE NOW")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(SeasonTheme.liveSignal)
                        Text(session.title)
                            .font(.system(size: 30, weight: .regular, design: .serif))
                            .foregroundStyle(SeasonTheme.paper)
                        HStack(spacing: 10) {
                            Rectangle().fill(SeasonTheme.paper.opacity(0.24)).frame(height: 3)
                            Circle().fill(SeasonTheme.liveSignal).frame(width: 9, height: 9)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(SeasonTheme.paper)
                        }
                    }
                    .padding(.horizontal, 64)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .allowsHitTesting(false)
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

            if let playbackError = session.playbackError {
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
                    Button("Return to Browse") {
                        session.player.pause()
                        dismiss()
                    }
                    .buttonStyle(FocusPillButtonStyle(isSelected: true))
                    .focused($failureActionFocused)
                }
                .padding(42)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        }
        .onAppear {
            session.player.play()
            failureActionFocused = session.playbackError != nil
            chromeVisible = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.3)) { chromeVisible = false }
            }
        }
        .onDisappear { session.player.pause() }
        .onChange(of: session.playbackError) { _, error in
            failureActionFocused = error != nil
        }
        .onExitCommand {
            session.player.pause()
            dismiss()
        }
    }
}
