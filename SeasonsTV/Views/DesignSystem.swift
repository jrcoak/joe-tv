import SwiftUI
import UIKit

enum SeasonTheme {
    static let background = Color(red: 0.018, green: 0.02, blue: 0.024)
    static let surface = Color.white.opacity(0.065)
    static let raisedSurface = Color.white.opacity(0.10)
    static let keyline = Color.white.opacity(0.13)
    static let accent = Color(red: 0.86, green: 0.64, blue: 0.28)
    static let warm = Color(red: 0.93, green: 0.39, blue: 0.20)
    static let horizontalInset: CGFloat = 72
    static let controlRadius: CGFloat = 16
    static let cardRadius: CGFloat = 18
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
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    isFocused
                        ? Color.white
                        : isSelected ? SeasonTheme.accent.opacity(0.24) : SeasonTheme.surface,
                    in: Capsule()
                )
                .overlay {
                    Capsule().stroke(
                        isFocused ? Color.white : isSelected ? SeasonTheme.accent : SeasonTheme.keyline,
                        lineWidth: isSelected ? 2 : 1
                    )
                }
                .scaleEffect(configuration.isPressed ? 0.97 : isFocused ? 1.04 : 1)
                .shadow(color: isFocused ? .black.opacity(0.34) : .clear, radius: 14, y: 7)
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
                .foregroundStyle(isFocused || isSelected ? Color.white : Color.white.opacity(0.62))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isFocused ? Color.white.opacity(0.13) : .clear)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(SeasonTheme.accent)
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
            Text(title).font(.title2.bold())
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
                .foregroundStyle(SeasonTheme.accent)
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
                    .fill(SeasonTheme.accent.opacity(0.58 + Double(index) * 0.12))
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
                        .foregroundStyle(SeasonTheme.accent)
                        .offset(x: size * 0.01)
                }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
