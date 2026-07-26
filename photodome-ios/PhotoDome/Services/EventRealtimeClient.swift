import Foundation
@preconcurrency import SocketIO

enum EventRealtimeSignal: Equatable {
    case photoReady(String)
    case photoRemoved(String)
    case eventEnded
    case uploadsRestricted
    case memberJoined(String)
    case memberUpdated(String)
    case memberRemoved(String)
    case codeRotated(String)
    case eventExpired
    case accessRevoked
}

@MainActor
final class EventRealtimeClient {
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    func connect(
        eventID: String,
        capability: String,
        onSignal: @escaping @MainActor (EventRealtimeSignal) -> Void
    ) {
        disconnect()
        let manager = SocketManager(
            socketURL: AppConfiguration.apiBaseURL,
            config: [.compress, .forceWebsockets(true), .log(false)]
        )
        let socket = manager.defaultSocket

        on(socket, event: "event.photo_ready", eventID: eventID) { payload in
            payload["photoId"] as? String
        } receive: {
            onSignal(.photoReady($0))
        }
        on(socket, event: "event.photo_removed", eventID: eventID) { payload in
            payload["photoId"] as? String
        } receive: {
            onSignal(.photoRemoved($0))
        }
        on(socket, event: "event.member_joined", eventID: eventID) { payload in
            payload["memberId"] as? String
        } receive: {
            onSignal(.memberJoined($0))
        }
        on(socket, event: "event.member_updated", eventID: eventID) { payload in
            payload["memberId"] as? String
        } receive: {
            onSignal(.memberUpdated($0))
        }
        on(socket, event: "event.member_removed", eventID: eventID) { payload in
            payload["memberId"] as? String
        } receive: {
            onSignal(.memberRemoved($0))
        }
        onSimple(socket, event: "event.ended", eventID: eventID) {
            onSignal(.eventEnded)
        }
        onSimple(
            socket,
            event: "event.uploads_restricted",
            eventID: eventID
        ) {
            onSignal(.uploadsRestricted)
        }
        on(socket, event: "event.code_rotated", eventID: eventID) { payload in
            payload["actorMemberId"] as? String
        } receive: {
            onSignal(.codeRotated($0))
        }
        onSimple(socket, event: "event.expired", eventID: eventID) {
            onSignal(.eventExpired)
        }
        socket.on(clientEvent: .disconnect) { data, _ in
            guard data.first as? String == "io server disconnect" else {
                return
            }
            Task { @MainActor in onSignal(.accessRevoked) }
        }

        socket.connect(
            withPayload: [
                "eventId": eventID,
                "capability": capability,
            ]
        )
        self.manager = manager
        self.socket = socket
    }

    func disconnect() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
    }

    private func on(
        _ socket: SocketIOClient,
        event: String,
        eventID: String,
        value: @escaping ([String: Any]) -> String?,
        receive: @escaping @MainActor (String) -> Void
    ) {
        socket.on(event) { data, _ in
            guard
                let payload = data.first as? [String: Any],
                payload["eventId"] as? String == eventID,
                let value = value(payload)
            else {
                return
            }
            Task { @MainActor in receive(value) }
        }
    }

    private func onSimple(
        _ socket: SocketIOClient,
        event: String,
        eventID: String,
        receive: @escaping @MainActor () -> Void
    ) {
        socket.on(event) { data, _ in
            guard
                let payload = data.first as? [String: Any],
                payload["eventId"] as? String == eventID
            else {
                return
            }
            Task { @MainActor in receive() }
        }
    }
}
