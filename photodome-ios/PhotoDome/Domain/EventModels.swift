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

enum AttendeeManagementPolicy {
    static func canOpenList(viewerRole: EventRole) -> Bool {
        viewerRole == .host
    }

    static func canRemove(
        _ member: EventMember,
        viewerRole: EventRole
    ) -> Bool {
        viewerRole == .host && member.role == .guest
    }
}

enum EventTimestampFormatter {
    static func deletionCountdown(
        _ value: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let expiry = parse(value) else { return nil }

        let today = calendar.startOfDay(for: now)
        let expiryDay = calendar.startOfDay(for: expiry)
        guard
            let days = calendar.dateComponents(
                [.day],
                from: today,
                to: expiryDay
            ).day
        else {
            return nil
        }

        switch days {
        case ...0:
            return "Deletes today"
        case 1:
            return "Deletes tomorrow"
        default:
            return "Deletes in \(days) days"
        }
    }

    static func localDateTime(
        _ value: String?,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String? {
        guard let date = parse(value) else { return nil }

        var style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened
        )
        style.timeZone = timeZone
        let timestamp = date.formatted(style.locale(locale))
        let timeZoneName = localTimeZoneName(
            timeZone,
            locale: locale
        )
        return "\(timestamp) (\(timeZoneName))"
    }

    private static func localTimeZoneName(
        _ timeZone: TimeZone,
        locale: Locale
    ) -> String {
        guard
            let name = timeZone.localizedName(
                for: .generic,
                locale: locale
            )
        else {
            return String(localized: "local time", locale: locale)
        }

        let normalizedName =
            name
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .uppercased()
        let exposesNumericOffset =
            normalizedName.hasPrefix("GMT+") || normalizedName.hasPrefix("GMT-")
            || normalizedName.hasPrefix("UTC+") || normalizedName.hasPrefix("UTC-")

        return exposesNumericOffset
            ? String(localized: "local time", locale: locale)
            : name
    }

    private static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let parsed = parser.date(from: value) {
            return parsed
        }

        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
}
