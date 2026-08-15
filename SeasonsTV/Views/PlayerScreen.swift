import AVKit
import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var session: PlaybackSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var failureActionFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: session.player)
                .ignoresSafeArea()

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
                        .foregroundStyle(.yellow)
                    Text("Playback unavailable")
                        .font(.title2.bold())
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
