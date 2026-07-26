import Foundation

enum EventRole: String, Codable, Sendable {
    case host
    case guest
}

enum EventLifecycle: String, Codable, Sendable {
    case live
    case ended
    case expiring
}

struct EventSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    // Optional for Keychain snapshots saved before display names shipped.
    let hostDisplayName: String?
    let locationLabel: String?
    let state: EventLifecycle
    let memberCount: Int
    // Optional for backward-compatible decoding of M0–M2 Keychain snapshots.
    let readyPhotoCount: Int?
    let createdAt: String
    let endedAt: String?
    let expiresAt: String?
    let uploadsRestrictedAt: String?
    let memberID: String
    let role: EventRole
}

struct StoredEventAccess: Codable, Equatable, Identifiable, Sendable {
    var id: String { event.id }

    var event: EventSnapshot
    let capability: String
    var joinCode: String?
}

struct HostTransfer: Equatable, Sendable {
    let eventID: String
    let transferToken: String
    let joinCode: String?
    let expiresAt: String
}

struct EventMember: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let role: EventRole
    let joinedAt: String
    let isViewer: Bool
}

enum EventTimestampFormatter {
    static func localDateTime(
        _ value: String?,
        timeZone: TimeZone = .current
    ) -> String? {
        guard let value else { return nil }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        let date: Date?
        if let parsed = parser.date(from: value) {
            date = parsed
        } else {
            parser.formatOptions = [.withInternetDateTime]
            date = parser.date(from: value)
        }
        guard let date else { return nil }

        var style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened
        )
        style.timeZone = timeZone
        let timestamp = date.formatted(style)
        guard let abbreviation = timeZone.abbreviation(for: date) else {
            return timestamp
        }
        return "\(timestamp) \(abbreviation)"
    }
}
