import Foundation

protocol AlbumPhotoListing: Sendable {
    func listPhotos(
        eventID: String,
        capability: String,
        cursor: String?
    ) async throws -> AlbumPhotoPage
}

extension APIClient: AlbumPhotoListing {}

@MainActor
final class EventAlbumViewModel: ObservableObject {
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var readyPhotoCount: Int
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var presentedError: String?

    @Published private(set) var access: StoredEventAccess
    private let realtime = EventRealtimeClient()
    private let onEventSignal: @MainActor (EventRealtimeSignal) -> Void
    private let photoLibraryWriter = PhotoLibraryWriter()
    private var api: APIClient?
    private var photoListing: (any AlbumPhotoListing)?
    private let snapshotStore: any AlbumSnapshotStoring
    private var didBootstrap = false
    private var lastMediaURLRecoveryAt: Date?
    private var nextCursor: String?

    private static let mediaURLRecoveryCooldown: TimeInterval = 15

    init(
        access: StoredEventAccess,
        onEventSignal: @escaping @MainActor (EventRealtimeSignal) -> Void,
        api: (any AlbumPhotoListing)? = nil,
        snapshotStore: any AlbumSnapshotStoring = AlbumSnapshotStore.shared
    ) {
        self.access = access
        self.onEventSignal = onEventSignal
        photoListing = api
        self.snapshotStore = snapshotStore
        readyPhotoCount = access.event.readyPhotoCount ?? 0
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await restoreSnapshot()
        await BackgroundUploadManager.shared.configure()

        do {
            if api == nil {
                let identity = try await InstallationIdentityStore().identity()
                let client = APIClient(
                    baseURL: AppConfiguration.apiBaseURL,
                    installationIdentity: identity
                )
                api = client
                photoListing = client
            }
            realtime.connect(
                eventID: access.id,
                capability: access.capability
            ) { [weak self] signal in
                self?.receive(signal)
            }
            if photos.isEmpty {
                await refresh()
            } else {
                await refreshLoadedPages()
            }
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func refresh() async {
        guard let photoListing, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await photoListing.listPhotos(
                eventID: access.id,
                capability: access.capability,
                cursor: nil
            )
            applyFirstPage(page)
            await persistSnapshot()
            prefetchThumbnails(Array(photos.prefix(18)))
            if let api {
                EventLiveActivityManager.shared.sync(
                    access: access,
                    readyPhotoCount: page.readyPhotoCount,
                    api: api
                )
            }
            await BackgroundUploadManager.shared.acknowledgeReady(
                photoIDs: Set(photos.map(\.id))
            )
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func refreshMediaURLsIfNeeded(at now: Date = Date()) async {
        guard
            AlbumMediaURLRefreshPolicy.shouldRefresh(
                photos: photos,
                at: now
            )
        else {
            return
        }
        await refreshLoadedPages()
    }

    func recoverMediaURLAfterFailure(
        _ failedURL: URL,
        at now: Date = Date()
    ) async {
        guard
            photos.contains(where: {
                $0.thumbnailURL == failedURL || $0.displayURL == failedURL
            }),
            !isLoading
        else {
            return
        }
        if let lastMediaURLRecoveryAt,
            now.timeIntervalSince(lastMediaURLRecoveryAt)
                < Self.mediaURLRecoveryCooldown
        {
            return
        }
        lastMediaURLRecoveryAt = now
        await refreshLoadedPages()
    }

    func photoBecameVisible(_ photoID: String) async {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else {
            return
        }
        if index.isMultiple(of: 9) {
            let end = min(photos.count, index + 18)
            prefetchThumbnails(Array(photos[index..<end]))
        }
        if index >= photos.count - 12 {
            await loadMore()
        }
    }

    func addPhoto(
        data: Data,
        capturedAt: Date? = nil,
        captureLocation: PhotoCaptureLocation? = nil,
        saveToLibrary: Bool = false,
        uploadID: UUID = UUID()
    ) async -> Bool {
        do {
            if saveToLibrary {
                guard captureLocation != nil else {
                    throw ImagePreprocessorError.unreadable
                }
                let prepared =
                    try await BackgroundUploadManager.shared.prepare(
                        data: data,
                        capturedAt: capturedAt,
                        captureLocation: captureLocation
                    )
                do {
                    try await photoLibraryWriter.save(
                        fileURL: prepared.fileURL,
                        capturedAt: prepared.capturedAt
                    )
                    try await BackgroundUploadManager.shared.enqueue(
                        prepared: prepared,
                        access: access,
                        itemID: uploadID
                    )
                } catch {
                    try? FileManager.default.removeItem(
                        at: prepared.fileURL
                    )
                    throw error
                }
                return true
            }

            try await BackgroundUploadManager.shared.enqueue(
                data: data,
                access: access,
                capturedAt: capturedAt,
                captureLocation: captureLocation,
                itemID: uploadID
            )
            return true
        } catch {
            presentedError = error.photoDomeMessage
            return false
        }
    }

    func removePhoto(_ photoID: String) async {
        guard let api else { return }
        do {
            try await api.removePhoto(
                eventID: access.id,
                photoID: photoID,
                capability: access.capability
            )
            photos.removeAll { $0.id == photoID }
            readyPhotoCount = max(0, readyPhotoCount - 1)
            await EventMediaCache.removePhoto(
                eventID: access.id,
                photoID: photoID
            )
            await persistSnapshot()
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func updateAccess(_ access: StoredEventAccess) {
        self.access = access
        readyPhotoCount = access.event.readyPhotoCount ?? readyPhotoCount
    }

    func disconnect() {
        realtime.disconnect()
    }

    private func receive(_ signal: EventRealtimeSignal) {
        switch signal {
        case .photoReady:
            onEventSignal(signal)
            Task { await refresh() }
        case .photoRemoved(let photoID):
            onEventSignal(signal)
            photos.removeAll { $0.id == photoID }
            readyPhotoCount = max(0, readyPhotoCount - 1)
            PhotoDownloadManager.shared.removePhoto(
                eventID: access.id,
                photoID: photoID
            )
            Task {
                await EventMediaCache.removePhoto(
                    eventID: access.id,
                    photoID: photoID
                )
                await persistSnapshot()
            }
            Task { await refresh() }
        case .eventEnded, .uploadsRestricted, .memberJoined,
            .memberUpdated, .memberRemoved, .codeRotated, .eventExpired,
            .accessRevoked:
            onEventSignal(signal)
        }
    }

    private func restoreSnapshot() async {
        if access.event.state == .expiring
            || eventExpiresAt.map({ $0 <= Date() }) == true
        {
            await EventMediaCache.removeEvent(eventID: access.id)
            return
        }
        do {
            guard let snapshot = try await snapshotStore.load(eventID: access.id)
            else {
                return
            }
            photos = snapshot.photos
            nextCursor = snapshot.nextCursor
            readyPhotoCount = snapshot.readyPhotoCount
            prefetchThumbnails(Array(photos.prefix(18)))
        } catch {
            // A corrupt optional snapshot must never block the authenticated
            // network source of truth.
        }
    }

    private func applyFirstPage(_ page: AlbumPhotoPage) {
        if page.nextCursor == nil {
            photos = page.photos
        } else {
            let freshIDs = Set(page.photos.map(\.id))
            let retained = photos.filter { !freshIDs.contains($0.id) }
            photos = Array(
                (page.photos + retained).prefix(page.readyPhotoCount)
            )
        }
        nextCursor = page.nextCursor
        readyPhotoCount = page.readyPhotoCount
    }

    private func loadMore() async {
        guard
            let photoListing,
            let cursor = nextCursor,
            !isLoading,
            !isLoadingMore
        else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await photoListing.listPhotos(
                eventID: access.id,
                capability: access.capability,
                cursor: cursor
            )
            let known = Set(photos.map(\.id))
            let additions = page.photos.filter { !known.contains($0.id) }
            photos.append(contentsOf: additions)
            nextCursor = page.nextCursor
            readyPhotoCount = page.readyPhotoCount
            await persistSnapshot()
            prefetchThumbnails(Array(additions.prefix(18)))
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    private func refreshLoadedPages() async {
        guard let photoListing, !isLoading, !isLoadingMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let targetCount = max(photos.count, 50)
            var refreshed: [AlbumPhoto] = []
            var cursor: String?
            var page: AlbumPhotoPage
            repeat {
                page = try await photoListing.listPhotos(
                    eventID: access.id,
                    capability: access.capability,
                    cursor: cursor
                )
                refreshed.append(contentsOf: page.photos)
                cursor = page.nextCursor
            } while cursor != nil && refreshed.count < targetCount

            let refreshedIDs = Set(refreshed.map(\.id))
            let retained = photos.filter { !refreshedIDs.contains($0.id) }
            photos = Array(
                (refreshed + retained).prefix(page.readyPhotoCount)
            )
            nextCursor = cursor
            readyPhotoCount = page.readyPhotoCount
            await persistSnapshot()
            prefetchThumbnails(Array(photos.prefix(18)))
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    private func persistSnapshot() async {
        do {
            try await snapshotStore.save(
                AlbumSnapshot(
                    eventID: access.id,
                    photos: photos,
                    nextCursor: nextCursor,
                    readyPhotoCount: readyPhotoCount,
                    savedAt: Date()
                )
            )
        } catch {
            // The network-backed album remains usable if the optional warm
            // snapshot cannot be written.
        }
    }

    private func prefetchThumbnails(_ photos: [AlbumPhoto]) {
        EventImagePipeline.shared.prefetch(
            eventID: access.id,
            photos: photos.filter {
                AlbumMediaURLRefreshPolicy.isUsable($0.urlsExpireAt)
            },
            variant: .thumbnail,
            eventExpiresAt: eventExpiresAt
        )
    }

    private var eventExpiresAt: Date? {
        AlbumMediaURLRefreshPolicy.date(access.event.expiresAt)
    }
}
