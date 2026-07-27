import Foundation

@MainActor
final class EventAppViewModel: ObservableObject {
    @Published private(set) var events: [StoredEventAccess] = []
    @Published private(set) var archivedEventIDs: Set<String> = []
    @Published private(set) var membersByEvent: [String: [EventMember]] = [:]
    @Published private(set) var isLoading = true
    @Published var presentedError: String?

    private var repository: EventRepository?
    private var api: APIClient?
    private var didBootstrap = false
    private var bootstrapTask: Task<Void, Never>?
    private let archiveStore: EventArchiveStore

    init(archiveStore: EventArchiveStore = EventArchiveStore()) {
        self.archiveStore = archiveStore
        archivedEventIDs = archiveStore.load()
    }

    var activeEvents: [StoredEventAccess] {
        events.filter { !archivedEventIDs.contains($0.id) }
    }

    var archivedEvents: [StoredEventAccess] {
        events.filter { archivedEventIDs.contains($0.id) }
    }

    func bootstrap() async {
        if let bootstrapTask {
            await bootstrapTask.value
            return
        }
        guard !didBootstrap else { return }
        didBootstrap = true
        let task = Task { @MainActor in
            await performBootstrap()
        }
        bootstrapTask = task
        await task.value
        bootstrapTask = nil
    }

    private func performBootstrap() async {
        do {
            let identity = try await InstallationIdentityStore().identity()
            let api = APIClient(
                baseURL: AppConfiguration.apiBaseURL,
                installationIdentity: identity
            )
            let repository = EventRepository(
                api: api,
                store: KeychainCapabilityStore()
            )
            self.api = api
            self.repository = repository
            let restored = try await repository.restore()
            events = restored
            archiveStore.retain(eventIDs: Set(restored.map(\.id)))
            archivedEventIDs = archiveStore.load()
            syncLiveActivities()
            isLoading = false

            await BackgroundUploadManager.shared.configure()
            await PhotoDownloadManager.shared.configure()

            var available: [StoredEventAccess] = []
            for access in restored {
                do {
                    available.append(try await repository.refresh(access))
                } catch APIClientError.unauthorized {
                    await forget(eventID: access.id)
                } catch APIClientError.eventUnavailable {
                    await forget(eventID: access.id)
                } catch {
                    available.append(access)
                }
            }
            events = available
            archiveStore.retain(eventIDs: Set(available.map(\.id)))
            archivedEventIDs = archiveStore.load()
            syncLiveActivities()
        } catch {
            presentedError = error.photoDomeMessage
        }
        isLoading = false
    }

    func create(name: String, displayName: String) async -> String? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            presentedError = "Give the event a name first."
            return nil
        }

        do {
            let access = try await requireRepository().create(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: displayName
            )
            upsert(access)
            unarchive(eventID: access.id)
            return access.id
        } catch {
            presentedError = error.photoDomeMessage
            return nil
        }
    }

    @discardableResult
    func join(code: String, displayName: String) async -> Bool {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            presentedError = "Enter an event code first."
            return false
        }

        do {
            let access = try await requireRepository().join(
                code: code,
                displayName: displayName
            )
            upsert(access)
            unarchive(eventID: access.id)
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    @discardableResult
    func handle(_ payload: InvitePayload, displayName: String) async -> Bool {
        switch payload {
        case .join(let code):
            return await join(code: code, displayName: displayName)
        case .hostTransfer:
            do {
                let access = try await requireRepository()
                    .acceptHostTransfer(payload)
                upsert(access)
                unarchive(eventID: access.id)
                return true
            } catch {
                presentedError = error.photoDomeMessage
                return false
            }
        }
    }

    func refresh(eventID: String) async {
        guard let access = access(eventID: eventID) else { return }
        do {
            upsert(try await requireRepository().refresh(access))
        } catch APIClientError.unauthorized {
            await forget(eventID: eventID)
        } catch APIClientError.eventUnavailable {
            await forget(eventID: eventID)
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func rotateJoinCode(eventID: String) async -> Bool {
        guard let access = access(eventID: eventID) else { return false }
        do {
            upsert(try await requireRepository().rotateJoinCode(access))
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    func endEvent(eventID: String) async -> Bool {
        guard let access = access(eventID: eventID) else { return false }
        do {
            upsert(try await requireRepository().endEvent(access))
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    func restrictUploads(eventID: String) async -> Bool {
        guard let access = access(eventID: eventID) else { return false }
        do {
            upsert(try await requireRepository().restrictUploads(access))
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    func loadMembers(eventID: String) async {
        guard
            let access = access(eventID: eventID),
            access.event.role == .host
        else {
            return
        }
        do {
            membersByEvent[eventID] =
                try await requireRepository().listMembers(access)
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func updateDisplayName(_ displayName: String) async {
        let currentEvents = events
        var firstError: Error?

        for access in currentEvents {
            do {
                upsert(
                    try await requireRepository().updateDisplayName(
                        displayName,
                        for: access
                    )
                )
            } catch APIClientError.unauthorized {
                await forget(eventID: access.id)
            } catch APIClientError.eventUnavailable {
                await forget(eventID: access.id)
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError {
            presentedError = firstError.photoDomeMessage
        }
    }

    func removeMember(eventID: String, memberID: String) async -> Bool {
        guard let access = access(eventID: eventID) else { return false }
        do {
            try await requireRepository().removeMember(memberID, from: access)
            await loadMembers(eventID: eventID)
            await refresh(eventID: eventID)
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    func handleRealtime(
        _ signal: EventRealtimeSignal,
        eventID: String
    ) async {
        switch signal {
        case .photoReady, .photoRemoved:
            await refresh(eventID: eventID)
        case .eventEnded, .uploadsRestricted:
            await refresh(eventID: eventID)
        case .memberJoined, .memberUpdated, .memberRemoved:
            await refresh(eventID: eventID)
            await loadMembers(eventID: eventID)
        case .codeRotated(let actorMemberID):
            guard let access = access(eventID: eventID) else { return }
            if actorMemberID == access.event.memberID {
                return
            }
            do {
                upsert(try await requireRepository().clearJoinCode(access))
            } catch {
                presentedError = error.photoDomeMessage
            }
        case .eventExpired, .accessRevoked:
            await forget(eventID: eventID)
        }
    }

    func createHostTransfer(eventID: String) async -> HostTransfer? {
        guard let access = access(eventID: eventID) else { return nil }
        do {
            return try await requireRepository().createHostTransfer(access)
        } catch {
            presentedError = error.photoDomeMessage
            return nil
        }
    }

    func access(eventID: String) -> StoredEventAccess? {
        events.first { $0.id == eventID }
    }

    func archive(eventID: String) {
        guard events.contains(where: { $0.id == eventID }) else {
            return
        }
        archiveStore.archive(eventID: eventID)
        archivedEventIDs.insert(eventID)
    }

    func unarchive(eventID: String) {
        archiveStore.unarchive(eventID: eventID)
        archivedEventIDs.remove(eventID)
    }

    private func requireRepository() throws -> EventRepository {
        guard let repository else {
            throw APIClientError.unexpectedStatus(0)
        }
        return repository
    }

    private func upsert(_ access: StoredEventAccess) {
        events.removeAll { $0.id == access.id }
        events.append(access)
        events.sort { $0.event.createdAt > $1.event.createdAt }
        syncLiveActivities()
    }

    private func forget(eventID: String) async {
        await BackgroundUploadManager.shared.removeEvent(eventID: eventID)
        await PhotoDownloadManager.shared.removeEvent(eventID: eventID)
        await EventMediaCache.removeEvent(eventID: eventID)
        do {
            try await requireRepository().forget(eventID: eventID)
        } catch {
            presentedError = error.photoDomeMessage
        }
        events.removeAll { $0.id == eventID }
        unarchive(eventID: eventID)
        membersByEvent[eventID] = nil
        syncLiveActivities()
    }

    private func syncLiveActivities() {
        EventLiveActivityManager.shared.reconcile(events)
        guard let api else { return }
        for access in events where access.event.state == .live {
            EventLiveActivityManager.shared.sync(
                access: access,
                readyPhotoCount: access.event.readyPhotoCount ?? 0,
                api: api
            )
        }
    }
}
