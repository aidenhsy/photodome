import SwiftUI

enum PhotoDomeLifecycleTone {
    case live
    case neutral
    case warning
    case danger
}

/// Shared status treatment for event lifecycle and upload-admission state.
struct PhotoDomeLifecyclePill: View {
    let title: String
    let tone: PhotoDomeLifecycleTone

    var body: some View {
        HStack(spacing: PhotoDomeTokens.Space.x2) {
            if tone == .live {
                Circle()
                    .fill(foreground)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            Text(title.uppercased())
                .font(PhotoDomeTokens.TypeStyle.eyebrow)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, PhotoDomeTokens.Space.x3)
        .frame(minHeight: 30)
        .background(background, in: Capsule())
        .overlay {
            Capsule()
                .stroke(border)
        }
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .live:
            PhotoDomeTokens.Semantic.actionPrimaryLabel
        case .neutral:
            PhotoDomeTokens.Semantic.textPrimary
        case .warning:
            PhotoDomeTokens.State.warning
        case .danger:
            PhotoDomeTokens.State.danger
        }
    }

    private var background: Color {
        switch tone {
        case .live:
            PhotoDomeTokens.Semantic.actionPrimaryBackground
        case .neutral, .warning, .danger:
            PhotoDomeTokens.Semantic.backgroundRaised
        }
    }

    private var border: Color {
        switch tone {
        case .live:
            PhotoDomeTokens.Semantic.actionPrimaryBackground
        case .neutral:
            PhotoDomeTokens.Semantic.borderSubtle
        case .warning:
            PhotoDomeTokens.State.warning.opacity(0.4)
        case .danger:
            PhotoDomeTokens.State.danger.opacity(0.4)
        }
    }
}

enum PhotoDomeStatusTone {
    case information
    case success
    case warning
    case danger
}

/// Inline system feedback that repeats color meaning with a symbol and copy.
struct PhotoDomeStatusMessage: View {
    let title: String
    let detail: String?
    let tone: PhotoDomeStatusTone

    init(
        _ title: String,
        detail: String? = nil,
        tone: PhotoDomeStatusTone = .information
    ) {
        self.title = title
        self.detail = detail
        self.tone = tone
    }

    var body: some View {
        HStack(alignment: .top, spacing: PhotoDomeTokens.Space.x3) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(
                    width: PhotoDomeTokens.Size.minimumTouchTarget,
                    height: PhotoDomeTokens.Size.minimumTouchTarget
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x1) {
                Text(title)
                    .font(PhotoDomeTokens.TypeStyle.headline)
                if let detail {
                    Text(detail)
                        .font(PhotoDomeTokens.TypeStyle.subheadline)
                        .foregroundStyle(
                            PhotoDomeTokens.Semantic.textSecondary
                        )
                }
            }
            .padding(.vertical, PhotoDomeTokens.Space.x2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhotoDomeTokens.Space.x3)
        .background(
            PhotoDomeTokens.Semantic.backgroundRaised,
            in: RoundedRectangle(
                cornerRadius: PhotoDomeTokens.Radius.default,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch tone {
        case .information: PhotoDomeTokens.State.information
        case .success: PhotoDomeTokens.State.success
        case .warning: PhotoDomeTokens.State.warning
        case .danger: PhotoDomeTokens.State.danger
        }
    }

    private var symbol: String {
        switch tone {
        case .information: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .danger: "exclamationmark.circle"
        }
    }
}

/// Standard empty state for event, album, review, and download surfaces.
struct PhotoDomeEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x3) {
            Image(systemName: systemImage)
                .font(.title2.weight(.medium))
                .accessibilityHidden(true)

            Text(title)
                .font(PhotoDomeTokens.TypeStyle.title)

            Text(message)
                .font(PhotoDomeTokens.TypeStyle.body)
                .foregroundStyle(
                    PhotoDomeTokens.Semantic.textSecondary
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PhotoDomeTokens.Space.x4)
        .background(
            PhotoDomeTokens.Semantic.backgroundRaised,
            in: RoundedRectangle(
                cornerRadius: PhotoDomeTokens.Radius.feature,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }
}
