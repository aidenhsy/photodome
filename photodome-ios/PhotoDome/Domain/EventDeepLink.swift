import Foundation

enum EventDeepLink: Equatable, Hashable, Sendable {
    case event(eventID: String)
    case capture(eventID: String)

    private static let scheme = "photodome"
    private static let host = "event"

    var eventID: String {
        switch self {
        case .event(let eventID), .capture(let eventID):
            eventID
        }
    }

    var opensCamera: Bool {
        if case .capture = self {
            return true
        }
        return false
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.path = "/\(eventID)" + (opensCamera ? "/capture" : "")
        return components.url!
    }

    init?(url: URL) {
        guard
            url.scheme?.lowercased() == Self.scheme,
            url.host?.lowercased() == Self.host
        else {
            return nil
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard
            let eventID = parts.first,
            UUID(uuidString: eventID) != nil
        else {
            return nil
        }

        switch Array(parts.dropFirst()) {
        case []:
            self = .event(eventID: eventID)
        case ["capture"]:
            self = .capture(eventID: eventID)
        default:
            return nil
        }
    }
}
