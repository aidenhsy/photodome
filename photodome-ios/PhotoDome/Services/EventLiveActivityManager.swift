@preconcurrency import ActivityKit
import Foundation

@MainActor
final class EventLiveActivityManager {
    static let shared = EventLiveActivityManager()

    private var activities: [String: Activity<EventActivityAttributes>] = [:]
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    private init() {
        for activity in Activity<EventActivityAttributes>.activities {
            activities[activity.attributes.eventID.uuidString.lowercased()] =
                activity
        }
    }

    func reconcile(_ accesses: [StoredEventAccess]) {
        let liveIDs = Set(
            accesses
                .filter { $0.event.state == .live }
                .map { $0.id.lowercased() }
        )
        for eventID in activities.keys where !liveIDs.contains(eventID) {
            end(eventID: eventID)
        }
    }

    func sync(
        access: StoredEventAccess,
        readyPhotoCount: Int,
        api: APIClient
    ) {
        guard access.event.state == .live else {
            end(eventID: access.id)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        guard let eventID = UUID(uuidString: access.id) else {
            return
        }

        let state = EventActivityAttributes.ContentState(
            photoCount: readyPhotoCount,
            eventHasEnded: false
        )
        let key = access.id.lowercased()

        if let activity = activities[key] {
            observePushTokens(
                activity,
                access: access,
                api: api
            )
            Task {
                await activity.update(
                    ActivityContent(state: state, staleDate: nil)
                )
            }
            return
        }

        do {
            let activity = try Activity.request(
                attributes: EventActivityAttributes(
                    eventID: eventID,
                    eventName: access.event.name
                ),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: .token
            )
            activities[key] = activity
            observePushTokens(activity, access: access, api: api)
        } catch {
            // Live Activities are optional. The event camera and album remain
            // fully available when the user or system declines the request.
        }
    }

    private func observePushTokens(
        _ activity: Activity<EventActivityAttributes>,
        access: StoredEventAccess,
        api: APIClient
    ) {
        guard tokenTasks[activity.id] == nil else { return }
        tokenTasks[activity.id] = Task {
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled else { return }
                let token = tokenData.map {
                    String(format: "%02x", $0)
                }.joined()
                try? await api.registerLiveActivityToken(
                    eventID: access.id,
                    capability: access.capability,
                    pushToken: token
                )
            }
        }
    }

    private func end(eventID: String) {
        let key = eventID.lowercased()
        guard let activity = activities.removeValue(forKey: key) else {
            return
        }
        tokenTasks.removeValue(forKey: activity.id)?.cancel()
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
