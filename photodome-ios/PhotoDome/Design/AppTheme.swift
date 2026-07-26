import SwiftUI

/// Compatibility facade for screens built before Design System 1.0.
///
/// New design-system work should use `PhotoDomeTokens` and shared components
/// directly. These aliases let the M0–M7 screens adopt the permanent semantic
/// palette without a risky all-at-once rewrite.
enum AppTheme {
    static let canvas = PhotoDomeTokens.Semantic.backgroundPrimary
    static let ink = PhotoDomeTokens.Semantic.textPrimary
    static let secondaryInk = PhotoDomeTokens.Semantic.textSecondary
    static let hairline = PhotoDomeTokens.Semantic.borderSubtle
    static let softFill = PhotoDomeTokens.Semantic.backgroundRaised

    static let pagePadding = PhotoDomeTokens.Space.x6
    static let cornerRadius = PhotoDomeTokens.Radius.default
    static let eyebrow = PhotoDomeTokens.TypeStyle.eyebrow
}

struct MonochromeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PhotoDomeTokens.TypeStyle.headline)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(
                PhotoDomeTokens.Semantic.actionPrimaryLabel
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: PhotoDomeTokens.Size.minimumTouchTarget)
            .padding(.horizontal, PhotoDomeTokens.Space.x4)
            .padding(.vertical, PhotoDomeTokens.Space.x2)
            .background(
                PhotoDomeTokens.Semantic.actionPrimaryBackground.opacity(
                    configuration.isPressed ? 0.72 : 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
            )
            .opacity(isEnabled ? 1 : 0.38)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PhotoDomeTokens.TypeStyle.headline)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(PhotoDomeTokens.Semantic.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PhotoDomeTokens.Size.minimumTouchTarget)
            .padding(.horizontal, PhotoDomeTokens.Space.x4)
            .padding(.vertical, PhotoDomeTokens.Space.x2)
            .background(
                RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
                .fill(
                    configuration.isPressed
                        ? PhotoDomeTokens.Semantic.backgroundRaised
                        : PhotoDomeTokens.Semantic.backgroundPrimary
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
                .stroke(PhotoDomeTokens.Semantic.borderSubtle)
            }
            .opacity(isEnabled ? 1 : 0.38)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PhotoDomeTokens.TypeStyle.headline)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PhotoDomeTokens.Size.minimumTouchTarget)
            .padding(.horizontal, PhotoDomeTokens.Space.x4)
            .padding(.vertical, PhotoDomeTokens.Space.x2)
            .background(
                PhotoDomeTokens.State.danger.opacity(
                    configuration.isPressed ? 0.72 : 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
            )
            .opacity(isEnabled ? 1 : 0.38)
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PhotoDomeTokens.TypeStyle.headline)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(PhotoDomeTokens.Semantic.textPrimary)
            .frame(minHeight: PhotoDomeTokens.Size.minimumTouchTarget)
            .padding(.horizontal, PhotoDomeTokens.Space.x4)
            .background(
                PhotoDomeTokens.Semantic.backgroundRaised.opacity(
                    configuration.isPressed ? 1 : 0
                ),
                in: RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
            )
            .opacity(isEnabled ? 1 : 0.38)
    }
}
