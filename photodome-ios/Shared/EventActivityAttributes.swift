import ActivityKit
import Foundation

struct EventActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var photoCount: Int
        var eventHasEnded: Bool
    }

    var eventID: UUID
    var eventName: String

    var eventURL: URL {
        URL(string: "photodome://event/\(eventID.uuidString.lowercased())")!
    }

    var captureURL: URL {
        URL(
            string:
                "photodome://event/\(eventID.uuidString.lowercased())/capture"
        )!
    }
}
