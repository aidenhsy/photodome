import Foundation

protocol PhotoReviewServing: Sendable {
    func getReviewQueue(
        eventID: String,
        capability: String,
        cursor: String?
    ) async throws -> ReviewPhotoPage

    func setPhotoSelection(
        eventID: String,
        photoID: String,
        capability: String,
        decision: PhotoSelectionDecision
    ) async throws -> PhotoSelection

    func undoLatestSelection(
        eventID: String,
        capability: String
    ) async throws -> PhotoSelection?
}

extension APIClient: PhotoReviewServing {}

@MainActor
final class PhotoReviewViewModel: ObservableObject {
    @Published private(set) var photos: [AlbumPhoto] = []
    @Published private(set) var readyPhotoCount = 0
    @Published private(set) var decidedPhotoCount = 0
    @Published private(set) var keptPhotoCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var hasIncomingPhotos = false
    @Published var presentedError: String?

    let access: StoredEventAccess
    private var api: (any PhotoReviewServing)?
    private var nextCursor: String?
    private var didBootstrap = false
    private var lastMediaURLRecoveryAt: Date?
    private let realtime = EventRealtimeClient()
    private static let mediaURLRecoveryCooldown: TimeInterval = 15

    init(
        access: StoredEventAccess,
        api: (any PhotoReviewServing)? = nil
    ) {
        self.access = access
        self.api = api
    }

    var currentPhoto: AlbumPhoto? {
        photos.first
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        do {
            if api == nil {
                let identity = try await InstallationIdentityStore().identity()
                api = APIClient(
                    baseURL: AppConfiguration.apiBaseURL,
                    installationIdentity: identity
                )
            }
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

    func decide(_ decision: PhotoSelectionDecision) async {
        guard
            let api,
            let photo = currentPhoto,
            !isSubmitting
        else {
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        photos.removeFirst()
        decidedPhotoCount += 1
        if decision == .keep {
            keptPhotoCount += 1
        }
        prefetchUpcomingPhotos()

        do {
            _ = try await api.setPhotoSelection(
                eventID: access.id,
                photoID: photo.id,
                capability: access.capability,
                decision: decision
            )
            if photos.count <= 5 {
                await loadMore()
            }
        } catch {
            photos.insert(photo, at: 0)
            decidedPhotoCount = max(0, decidedPhotoCount - 1)
            if decision == .keep {
                keptPhotoCount = max(0, keptPhotoCount - 1)
            }
            presentedError = error.photoDomeMessage
        }
    }

    func undo() async {
        guard let api, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            guard
                try await api.undoLatestSelection(
                    eventID: access.id,
                    capability: access.capability
                ) != nil
            else {
                return
            }
            await refresh()
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func refresh() async {
        guard let api, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.getReviewQueue(
                eventID: access.id,
                capability: access.capability,
                cursor: nil
            )
            let savedPhotoIDs = PhotoDownloadManager.shared.savedPhotoIDs(
                eventID: access.id
            )
            photos = page.photos.filter {
                !savedPhotoIDs.contains($0.id)
                    && $0.contributorMemberID != access.event.memberID
            }
            nextCursor = page.nextCursor
            readyPhotoCount = page.readyPhotoCount
            decidedPhotoCount = page.decidedPhotoCount
            keptPhotoCount = page.keptPhotoCount
            hasIncomingPhotos = false
            if photos.count <= 5 {
                await loadMore()
            }
            prefetchUpcomingPhotos()
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    func disconnect() {
        realtime.disconnect()
    }

    func recoverMediaURLAfterFailure(
        _ failedURL: URL,
        at now: Date = Date()
    ) async {
        guard
            photos.contains(where: { $0.displayURL == failedURL }),
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
        await refresh()
    }

    private func loadMore() async {
        guard let api, let cursor = nextCursor else { return }
        do {
            let page = try await api.getReviewQueue(
                eventID: access.id,
                capability: access.capability,
                cursor: cursor
            )
            let known = Set(photos.map(\.id))
            let savedPhotoIDs = PhotoDownloadManager.shared.savedPhotoIDs(
                eventID: access.id
            )
            photos.append(
                contentsOf: page.photos.filter {
                    !known.contains($0.id)
                        && !savedPhotoIDs.contains($0.id)
                        && $0.contributorMemberID != access.event.memberID
                }
            )
            nextCursor = page.nextCursor
            readyPhotoCount = page.readyPhotoCount
            decidedPhotoCount = page.decidedPhotoCount
            keptPhotoCount = page.keptPhotoCount
            if photos.count <= 5, nextCursor != nil {
                await loadMore()
            }
            prefetchUpcomingPhotos()
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    private func receive(_ signal: EventRealtimeSignal) {
        switch signal {
        case .photoReady:
            hasIncomingPhotos = true
            Task { await refreshKeepingIncomingNotice() }
        case .photoRemoved(let photoID):
            photos.removeAll { $0.id == photoID }
            PhotoDownloadManager.shared.removePhoto(
                eventID: access.id,
                photoID: photoID
            )
            Task { await refresh() }
        case .eventEnded, .uploadsRestricted, .memberJoined,
            .memberUpdated, .memberRemoved, .codeRotated:
            break
        case .eventExpired, .accessRevoked:
            presentedError = APIClientError.unauthorized.localizedDescription
        }
    }

    private func refreshKeepingIncomingNotice() async {
        await refresh()
        hasIncomingPhotos = true
    }

    private func prefetchUpcomingPhotos() {
        EventImagePipeline.shared.prefetch(
            eventID: access.id,
            photos: Array(photos.prefix(4)).filter {
                AlbumMediaURLRefreshPolicy.isUsable($0.urlsExpireAt)
            },
            variant: .display,
            eventExpiresAt: AlbumMediaURLRefreshPolicy.date(
                access.event.expiresAt
            )
        )
    }
}
