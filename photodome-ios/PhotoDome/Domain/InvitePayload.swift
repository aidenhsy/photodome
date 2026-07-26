import Foundation

enum InvitePayload: Equatable, Sendable {
    case join(code: String)
    case hostTransfer(token: String, eventID: String, joinCode: String?)

    static let localInviteBaseURL = URL(string: "https://photodome.invalid")!

    var url: URL {
        var components = URLComponents(
            url: Self.localInviteBaseURL,
            resolvingAgainstBaseURL: false
        )!

        switch self {
        case .join(let code):
            components.path = "/join"
            components.queryItems = [
                URLQueryItem(name: "code", value: code)
            ]
        case .hostTransfer(let token, let eventID, let joinCode):
            components.path = "/host-transfer"
            components.queryItems = [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "eventId", value: eventID),
                URLQueryItem(name: "joinCode", value: joinCode),
            ].filter { $0.value != nil }
        }

        return components.url!
    }

    init?(url: URL) {
        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            return nil
        }

        let values = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
                item in item.value.map { (item.name, $0) }
            }
        )

        switch components.path {
        case "/join":
            guard let code = values["code"], !code.isEmpty else { return nil }
            self = .join(code: code)
        case "/host-transfer":
            guard
                let token = values["token"],
                !token.isEmpty,
                let eventID = values["eventId"],
                !eventID.isEmpty
            else {
                return nil
            }
            self = .hostTransfer(
                token: token,
                eventID: eventID,
                joinCode: values["joinCode"]
            )
        default:
            return nil
        }
    }
}
