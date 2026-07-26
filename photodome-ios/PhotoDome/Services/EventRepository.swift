import Foundation

actor EventRepository {
    private let api: APIClient
    private let store: any EventAccessStoring

    init(api: APIClient, store: any EventAccessStoring) {
        self.api = api
        self.store = store
    }

    func restore() async throws -> [StoredEventAccess] {
        let saved = try await store.loadAll()
        var restored: [StoredEventAccess] = []

        for var access in saved {
            do {
                access.event = try await api.getEvent(
                    eventID: access.id,
                    capability: access.capability
                )
                try await store.save(access)
                restored.append(access)
            } catch APIClientError.unauthorized {
                try await store.remove(eventID: access.id)
            } catch APIClientError.eventUnavailable {
                try await store.remove(eventID: access.id)
            } catch {
                // Network failures must not erase a recoverable capability.
                restored.append(access)
            }
        }

        return restored.sorted { $0.event.createdAt > $1.event.createdAt }
    }

    func create(name: String, displayName: String) async throws
        -> StoredEventAccess
    {
        let access = try await api.createEvent(
            name: name,
            displayName: displayName
        )
        try await store.save(access)
        return access
    }

    func join(code: String, displayName: String) async throws
        -> StoredEventAccess
    {
        let access = try await api.joinEvent(
            code: code,
            displayName: displayName
        )
        try await store.save(access)
        return access
    }

    func refresh(_ access: StoredEventAccess) async throws
        -> StoredEventAccess
    {
        var access = access
        access.event = try await api.getEvent(
            eventID: access.id,
            capability: access.capability
        )
        try await store.save(access)
        return access
    }

    func rotateJoinCode(_ access: StoredEventAccess) async throws
        -> StoredEventAccess
    {
        var access = access
        access.joinCode = try await api.rotateJoinCode(
            eventID: access.id,
            capability: access.capability
        )
        try await store.save(access)
        return access
    }

    func endEvent(_ access: StoredEventAccess) async throws
        -> StoredEventAccess
    {
        var access = access
        access.event = try await api.endEvent(
            eventID: access.id,
            capability: access.capability
        )
        try await store.save(access)
        return access
    }

    func restrictUploads(_ access: StoredEventAccess) async throws
        -> StoredEventAccess
    {
        var access = access
        access.event = try await api.restrictUploads(
            eventID: access.id,
            capability: access.capability
        )
        try await store.save(access)
        return access
    }

    func listMembers(_ access: StoredEventAccess) async throws
        -> [EventMember]
    {
        try await api.listMembers(
            eventID: access.id,
            capability: access.capability
        )
    }

    func updateDisplayName(
        _ displayName: String,
        for access: StoredEventAccess
    ) async throws -> StoredEventAccess {
        var access = access
        access.event = try await api.updateDisplayName(
            eventID: access.id,
            capability: access.capability,
            displayName: displayName
        )
        try await store.save(access)
        return access
    }

    func removeMember(
        _ memberID: String,
        from access: StoredEventAccess
    ) async throws {
        try await api.removeMember(
            eventID: access.id,
            memberID: memberID,
            capability: access.capability
        )
    }

    func clearJoinCode(_ access: StoredEventAccess) async throws
        -> StoredEventAccess
    {
        var access = access
        access.joinCode = nil
        try await store.save(access)
        return access
    }

    func forget(eventID: String) async throws {
        try await store.remove(eventID: eventID)
    }

    func createHostTransfer(_ access: StoredEventAccess) async throws
        -> HostTransfer
    {
        try await api.createHostTransfer(
            eventID: access.id,
            capability: access.capability,
            joinCode: access.joinCode
        )
    }

    func acceptHostTransfer(_ payload: InvitePayload) async throws
        -> StoredEventAccess
    {
        guard
            case .hostTransfer(let token, _, let joinCode) = payload
        else {
            throw APIClientError.invalidInvite
        }
        let access = try await api.exchangeHostTransfer(
            token: token,
            joinCode: joinCode
        )
        try await store.save(access)
        return access
    }

}
