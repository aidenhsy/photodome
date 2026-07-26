import ActivityKit
import SwiftUI
import WidgetKit

struct EventLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activityEyebrow(context.state))
                            .font(.caption2.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(context.attributes.eventName)
                            .font(.title2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 8)

                    Image(
                        systemName: context.state.eventHasEnded
                            ? "photo.on.rectangle.angled"
                            : "camera.fill"
                    )
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.black, in: Circle())
                    .accessibilityHidden(true)
                }

                Link(destination: activityDestination(context)) {
                    HStack(spacing: 8) {
                        Image(systemName: activityActionSymbol(context.state))
                            .accessibilityHidden(true)
                        Text(activityActionTitle(context.state))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(activityAccessibilityLabel(context))
            }
            .foregroundStyle(.black)
            .fontDesign(.rounded)
            .padding(16)
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(.black)
            .widgetURL(activityDestination(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "camera.aperture")
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.eventName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.photoCount)")
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: activityDestination(context)) {
                        Label(
                            activityActionTitle(context.state),
                            systemImage: activityActionSymbol(context.state)
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(.black)
                        .background(.white, in: Capsule())
                    }
                    .accessibilityLabel(activityAccessibilityLabel(context))
                }
            } compactLeading: {
                Image(systemName: "camera.aperture")
                    .accessibilityHidden(true)
            } compactTrailing: {
                HStack(spacing: 3) {
                    Text("\(context.state.photoCount)")
                        .monospacedDigit()
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
            } minimal: {
                Image(systemName: "camera.aperture")
                    .accessibilityLabel("PhotoDome event")
            }
            .keylineTint(.white)
            .widgetURL(activityDestination(context))
        }
    }

    private func activityEyebrow(
        _ state: EventActivityAttributes.ContentState
    ) -> String {
        state.eventHasEnded
            ? "\(photoCountLabel(state.photoCount)) · ENDED"
            : "LIVE EVENT · \(photoCountLabel(state.photoCount))"
    }

    private func photoCountLabel(_ photoCount: Int) -> String {
        "\(photoCount) \(photoCount == 1 ? "PHOTO" : "PHOTOS")"
    }

    private func activityActionTitle(
        _ state: EventActivityAttributes.ContentState
    ) -> String {
        state.eventHasEnded ? "View event" : "Take a photo"
    }

    private func activityActionSymbol(
        _ state: EventActivityAttributes.ContentState
    ) -> String {
        state.eventHasEnded ? "photo.on.rectangle.angled" : "camera.fill"
    }

    private func activityDestination(
        _ context: ActivityViewContext<EventActivityAttributes>
    ) -> URL {
        context.state.eventHasEnded
            ? context.attributes.eventURL
            : context.attributes.captureURL
    }

    private func activityAccessibilityLabel(
        _ context: ActivityViewContext<EventActivityAttributes>
    ) -> String {
        context.state.eventHasEnded
            ? "View \(context.attributes.eventName)"
            : "Take a photo for \(context.attributes.eventName)"
    }
}
