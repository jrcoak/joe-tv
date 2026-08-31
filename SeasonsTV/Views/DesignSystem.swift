import SwiftUI
import UIKit

enum SeasonTheme {
    /// JOE-TV's warm, editorial palette. Volt is reserved for remote focus.
    static let background = Color(red: 0.031, green: 0.039, blue: 0.051) // #080A0D
    static let paper = Color(red: 0.957, green: 0.949, blue: 0.929) // #F4F2ED
    static let liveSignal = Color(red: 1.0, green: 0.357, blue: 0.208) // #FF5B35
    static let focusVolt = Color(red: 0.839, green: 1.0, blue: 0.294) // #D6FF4B
    static let surface = Color(red: 0.066, green: 0.082, blue: 0.102)
    static let raisedSurface = Color(red: 0.086, green: 0.106, blue: 0.129)
    static let keyline = paper.opacity(0.14)
    static let secondaryText = paper.opacity(0.58)
    static let accent = liveSignal
    static let warm = liveSignal
    static let horizontalInset: CGFloat = 72
    static let controlRadius: CGFloat = 10
    static let cardRadius: CGFloat = 12
    static let focusLineWidth: CGFloat = 4
    static let focusAnimation = Animation.easeOut(duration: 0.16)
}

struct FocusPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        FocusPillBody(configuration: configuration, isSelected: isSelected)
    }

    struct FocusPillBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(SeasonTheme.paper)
                .padding(.horizontal, 20)
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
                .scaleEffect(configuration.isPressed ? 0.97 : isFocused ? 1.04 : 1)
                .shadow(color: isFocused ? SeasonTheme.focusVolt.opacity(0.16) : .clear, radius: 18)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
        }
    }
}

struct TopNavigationButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TopNavigationBody(configuration: configuration, isSelected: isSelected)
    }

    struct TopNavigationBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.system(size: 21, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isFocused || isSelected ? SeasonTheme.paper : SeasonTheme.secondaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isFocused ? SeasonTheme.raisedSurface : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? SeasonTheme.focusVolt : .clear, lineWidth: SeasonTheme.focusLineWidth)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(SeasonTheme.paper)
                        .frame(width: isSelected ? 28 : 0, height: 3)
                        .offset(y: 5)
                }
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isSelected)
        }
    }
}

struct ArtworkView: View {
    let url: URL?
    let symbol: String
    var localAssetName: String? = nil
    var outerPadding: CGFloat = 14
    var artworkPadding: CGFloat = 12

    var body: some View {
        ZStack {
            Color.white.opacity(0.055)
            ZStack {
                Color(red: 0.93, green: 0.93, blue: 0.94)
                Group {
                    if let localAssetName, UIImage(named: localAssetName) != nil {
                        Image(localAssetName)
                            .resizable()
                            .scaledToFit()
                    } else if let url {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .empty:
                                fallback.opacity(0.42)
                            case .failure:
                                fallback
                            @unknown default:
                                fallback
                            }
                        }
                    } else {
                        fallback
                    }
                }
                .padding(artworkPadding)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(outerPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image(systemName: symbol)
            .font(.system(size: 38))
            .foregroundStyle(.gray)
    }
}

struct StatePanel: View {
    let title: String
    let message: String
    let symbol: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(SeasonTheme.accent)
            Text(title).font(.title2.bold()).foregroundStyle(SeasonTheme.paper)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InlineStatusBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundStyle(SeasonTheme.liveSignal)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(SeasonTheme.surface, in: RoundedRectangle(cornerRadius: SeasonTheme.controlRadius))
    }
}

struct WorkingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            HStack(spacing: 18) {
                ProgressView()
                Text(message).font(.headline)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SeasonTheme.controlRadius))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(SeasonTheme.raisedSurface)
            RoundedRectangle(cornerRadius: size * 0.22)
                .stroke(SeasonTheme.keyline)

            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == 0 ? SeasonTheme.liveSignal : SeasonTheme.paper.opacity(0.30 + Double(index) * 0.12))
                    .frame(width: size * 0.15, height: size * 0.31)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(SeasonTheme.background)
                .frame(width: size * 0.35, height: size * 0.27)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: size * 0.12, weight: .bold))
                        .foregroundStyle(SeasonTheme.liveSignal)
                        .offset(x: size * 0.01)
                }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
