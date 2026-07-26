import Foundation

@MainActor
final class EventAlbumViewModel: ObservableObject {
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var readyPhotoCount: Int
    @Published private(set) var isLoading = false
    @Published var presentedError: String?

    @Published private(set) var access: StoredEventAccess
    private let realtime = EventRealtimeClient()
    private let onEventSignal: @MainActor (EventRealtimeSignal) -> Void
    private let photoLibraryWriter = PhotoLibraryWriter()
    private var api: APIClient?
    private var didBootstrap = false

    init(
        access: StoredEventAccess,
        onEventSignal: @escaping @MainActor (EventRealtimeSignal) -> Void
    ) {
        self.access = access
        self.onEventSignal = onEventSignal
        readyPhotoCount = access.event.readyPhotoCount ?? 0
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await BackgroundUploadManager.shared.configure()

        do {
            let identity = try await InstallationIdentityStore().identity()
            api = APIClient(
                baseURL: AppConfiguration.apiBaseURL,
                installationIdentity: identity
            )
            realtime.connect(
                eventID: access.id,
                capability: access.capability
            ) { [weak self] signal in
                self?.receive(signal)
            }
            await refresh()
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func refresh() async {
        guard let api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.listPhotos(
                eventID: access.id,
                capability: access.capability
            )
            photos = page.photos
            readyPhotoCount = page.readyPhotoCount
            EventLiveActivityManager.shared.sync(
                access: access,
                readyPhotoCount: page.readyPhotoCount,
                api: api
            )
            await BackgroundUploadManager.shared.acknowledgeReady(
                photoIDs: Set(photos.map(\.id))
            )
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func addPhoto(
        data: Data,
        capturedAt: Date? = nil,
        captureLocation: PhotoCaptureLocation? = nil,
        saveToLibrary: Bool = false
    ) async {
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
                        access: access
                    )
                } catch {
                    try? FileManager.default.removeItem(
                        at: prepared.fileURL
                    )
                    throw error
                }
                return
            }

            try await BackgroundUploadManager.shared.enqueue(
                data: data,
                access: access,
                capturedAt: capturedAt,
                captureLocation: captureLocation
            )
        } catch {
            presentedError = error.photoDomeMessage
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
            Task { await refresh() }
        case .eventEnded, .uploadsRestricted, .memberJoined,
            .memberUpdated, .memberRemoved, .codeRotated, .eventExpired,
            .accessRevoked:
            onEventSignal(signal)
        }
    }
}
