import Foundation

@MainActor
final class PhotoDownloadManager: NSObject, ObservableObject {
    static let shared = PhotoDownloadManager()
    static let sessionIdentifier =
        "com.younger7jp.photodome.media-download"

    @Published private(set) var items: [PhotoDownloadItem] = []

    private let store = PhotoDownloadQueueStore()
    private let writer = PhotoLibraryWriter()
    private var api: APIClient?
    private var isConfigured = false
    private var backgroundCompletionHandler: (() -> Void)?
    private let maximumConcurrentDownloads = 3

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: Self.sessionIdentifier
        )
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost =
            maximumConcurrentDownloads
        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    func configure() async {
        guard !isConfigured else { return }
        isConfigured = true
        do {
            let identity = try await InstallationIdentityStore().identity()
            api = APIClient(
                baseURL: AppConfiguration.apiBaseURL,
                installationIdentity: identity
            )
            items = try await store.load()
            let activeTaskIDs = Set(await session.allTasks.map(\.taskIdentifier))
            for index in items.indices
            where items[index].state == .downloading
                && !(items[index].taskIdentifier.map(activeTaskIDs.contains)
                    ?? false)
            {
                items[index].state = .failed
                items[index].taskIdentifier = nil
                items[index].failureMessage =
                    "The download was interrupted. Tap retry."
            }
            try await persist()
            await resumePendingSaves()
            startQueuedDownloads()
        } catch {
            items = []
        }
    }

    func start(
        mode: DownloadManifestMode,
        access: StoredEventAccess
    ) async throws {
        await configure()
        guard let api else {
            throw APIClientError.unexpectedStatus(0)
        }
        let manifest = try await loadManifest(
            api: api,
            eventID: access.id,
            capability: access.capability,
            mode: mode,
            photoID: nil
        )
        let knownPhotoIDs = Set(
            items.filter { $0.eventID == access.id }.map(\.photoID)
        )
        for photo in manifest where !knownPhotoIDs.contains(photo.id) {
            items.append(downloadItem(for: photo, eventID: access.id))
        }
        try await persist()
        startQueuedDownloads()
    }

    func start(
        photoID: String,
        access: StoredEventAccess,
        downloadAgain: Bool
    ) async throws {
        await configure()
        guard let api else {
            throw APIClientError.unexpectedStatus(0)
        }

        if !downloadAgain,
            let existing = items.first(where: {
                $0.eventID == access.id && $0.photoID == photoID
            })
        {
            if existing.state == .failed {
                await retry(itemID: existing.id)
            }
            return
        }

        let manifest = try await loadManifest(
            api: api,
            eventID: access.id,
            capability: access.capability,
            mode: .all,
            photoID: photoID
        )
        guard let photo = manifest.first else {
            throw APIClientError.invalidMedia
        }
        items.append(downloadItem(for: photo, eventID: access.id))
        try await persist()
        startQueuedDownloads()
    }

    func savedPhotoIDs(eventID: String) -> Set<String> {
        Set(
            items.lazy
                .filter { $0.eventID == eventID && $0.state == .saved }
                .map(\.photoID)
        )
    }

    func retry(itemID: UUID) async {
        await configure()
        guard
            var item = items.first(where: { $0.id == itemID }),
            let api
        else {
            return
        }
        if let localFileURL = item.localFileURL,
            FileManager.default.fileExists(atPath: localFileURL.path)
        {
            item.state = .saving
            item.failureMessage = nil
            replace(item)
            try? await persist()
            await saveToLibrary(itemID: item.id)
            return
        }

        do {
            let access = try await access(eventID: item.eventID)
            let manifest = try await loadManifest(
                api: api,
                eventID: item.eventID,
                capability: access.capability,
                mode: .all,
                photoID: item.photoID
            )
            guard
                let refreshed = manifest.first(where: {
                    $0.id == item.photoID
                })
            else {
                remove(itemID: item.id)
                try? await persist()
                return
            }
            item.sourceURL = refreshed.originalURL
            item.state = .queued
            item.bytesReceived = 0
            item.retryCount += 1
            item.failureMessage = nil
            replace(item)
            try await persist()
            startQueuedDownloads()
        } catch {
            markFailed(
                itemID: item.id,
                message: "Retry could not start. Check your access and connection."
            )
        }
    }

    func removePhoto(eventID: String, photoID: String) {
        let matching = items.filter {
            $0.eventID == eventID && $0.photoID == photoID
                && $0.state != .saved
        }
        for item in matching {
            if let taskIdentifier = item.taskIdentifier {
                Task {
                    for task in await session.allTasks
                    where task.taskIdentifier == taskIdentifier {
                        task.cancel()
                    }
                }
            }
            if let localFileURL = item.localFileURL {
                try? FileManager.default.removeItem(at: localFileURL)
            }
            remove(itemID: item.id)
        }
        Task { try? await persist() }
    }

    func removeEvent(eventID: String) async {
        await configure()
        let matching = items.filter { $0.eventID == eventID }
        let taskIdentifiers = Set(matching.compactMap(\.taskIdentifier))
        for task in await session.allTasks
        where taskIdentifiers.contains(task.taskIdentifier) {
            task.cancel()
        }
        for item in matching {
            if let localFileURL = item.localFileURL {
                try? FileManager.default.removeItem(at: localFileURL)
            }
        }
        items.removeAll { $0.eventID == eventID }
        try? await persist()
        startQueuedDownloads()
    }

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }

    private func loadManifest(
        api: APIClient,
        eventID: String,
        capability: String,
        mode: DownloadManifestMode,
        photoID: String?
    ) async throws -> [DownloadManifestPhoto] {
        var cursor: String?
        var photos: [DownloadManifestPhoto] = []
        repeat {
            let page = try await api.getDownloadManifest(
                eventID: eventID,
                capability: capability,
                mode: mode,
                cursor: cursor,
                photoID: photoID
            )
            photos.append(contentsOf: page.photos)
            cursor = page.nextCursor
        } while cursor != nil
        return photos
    }

    private func downloadItem(
        for photo: DownloadManifestPhoto,
        eventID: String
    ) -> PhotoDownloadItem {
        PhotoDownloadItem(
            id: UUID(),
            eventID: eventID,
            photoID: photo.id,
            sourceURL: photo.originalURL,
            capturedAt: photo.capturedAt,
            expectedByteSize: photo.byteSize,
            localFileURL: nil,
            taskIdentifier: nil,
            state: .queued,
            bytesReceived: 0,
            retryCount: 0,
            failureMessage: nil
        )
    }

    private func startQueuedDownloads() {
        let activeCount = items.filter { $0.state == .downloading }.count
        let capacity = max(0, maximumConcurrentDownloads - activeCount)
        guard capacity > 0 else { return }
        for item in items.filter({ $0.state == .queued }).prefix(capacity) {
            var item = item
            let task = session.downloadTask(with: item.sourceURL)
            item.taskIdentifier = task.taskIdentifier
            item.state = .downloading
            replace(item)
            task.resume()
        }
        Task { try? await persist() }
    }

    private func handleProgress(
        taskID: Int,
        totalBytesWritten: Int64
    ) async {
        guard
            var item = items.first(where: { $0.taskIdentifier == taskID })
        else {
            return
        }
        item.bytesReceived = totalBytesWritten
        replace(item)
        try? await persist()
    }

    private func handleDownloaded(
        taskID: Int,
        stagedURL: URL,
        statusCode: Int?
    ) async {
        guard
            var item = items.first(where: { $0.taskIdentifier == taskID })
        else {
            try? FileManager.default.removeItem(at: stagedURL)
            return
        }
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        guard let statusCode, (200..<300).contains(statusCode) else {
            markFailed(
                itemID: item.id,
                message: "The signed download expired. Tap retry."
            )
            startQueuedDownloads()
            return
        }
        do {
            let destination = try downloadFileURL(for: item)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(
                at: stagedURL,
                to: destination
            )
            item.localFileURL = destination
            item.taskIdentifier = nil
            item.bytesReceived = Int64(item.expectedByteSize)
            item.state = .saving
            item.failureMessage = nil
            replace(item)
            try await persist()
            await saveToLibrary(itemID: item.id)
        } catch {
            markFailed(
                itemID: item.id,
                message: "The downloaded photo could not be prepared."
            )
        }
        startQueuedDownloads()
    }

    private func handleDownloadStagingFailure(taskID: Int) {
        guard
            let itemID = items.first(where: {
                $0.taskIdentifier == taskID
            })?.id
        else {
            return
        }
        markFailed(
            itemID: itemID,
            message:
                "The downloaded photo could not be stored. Check available space and try again."
        )
        startQueuedDownloads()
    }

    private func saveToLibrary(itemID: UUID) async {
        guard
            var item = items.first(where: { $0.id == itemID }),
            let localFileURL = item.localFileURL
        else {
            return
        }
        do {
            try await writer.save(
                fileURL: localFileURL,
                capturedAt: item.capturedAt
            )
            try? FileManager.default.removeItem(at: localFileURL)
            item.localFileURL = nil
            item.state = .saved
            item.failureMessage = nil
            replace(item)
            try await persist()
        } catch {
            item.state = .failed
            item.failureMessage = error.localizedDescription
            replace(item)
            try? await persist()
        }
    }

    private func resumePendingSaves() async {
        for item in items where item.state == .saving {
            await saveToLibrary(itemID: item.id)
        }
    }

    private func handleCompletion(taskID: Int, error: Error?) async {
        guard
            let item = items.first(where: { $0.taskIdentifier == taskID }),
            error != nil
        else {
            return
        }
        markFailed(
            itemID: item.id,
            message: "Download paused before it finished. Tap retry."
        )
        startQueuedDownloads()
    }

    private func downloadFileURL(for item: PhotoDownloadItem) throws -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("PhotoDomeDownloads/files", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("\(item.id.uuidString).jpg")
    }

    nonisolated static func stageDownloadedFile(
        at sourceURL: URL,
        taskID: Int,
        directoryURL: URL? = nil
    ) throws -> URL {
        let directory =
            directoryURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(
                "PhotoDomeDownloads/incoming",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let stagedURL = directory.appendingPathComponent(
            "\(taskID)-\(UUID().uuidString).download"
        )
        try FileManager.default.moveItem(at: sourceURL, to: stagedURL)
        try FileManager.default.setAttributes(
            [
                .protectionKey:
                    FileProtectionType
                    .completeUntilFirstUserAuthentication
            ],
            ofItemAtPath: stagedURL.path
        )
        return stagedURL
    }

    private func access(eventID: String) async throws -> StoredEventAccess {
        guard
            let access = try await KeychainCapabilityStore().loadAll()
                .first(where: { $0.id == eventID })
        else {
            throw APIClientError.unauthorized
        }
        return access
    }

    private func markFailed(itemID: UUID, message: String) {
        guard var item = items.first(where: { $0.id == itemID }) else {
            return
        }
        item.state = .failed
        item.taskIdentifier = nil
        item.failureMessage = message
        replace(item)
        Task { try? await persist() }
    }

    private func replace(_ item: PhotoDownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            items.append(item)
            return
        }
        items[index] = item
    }

    private func remove(itemID: UUID) {
        items.removeAll { $0.id == itemID }
    }

    private func persist() async throws {
        try await store.save(items)
    }
}

extension PhotoDownloadManager:
    URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate
{
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor [weak self] in
            await self?.handleProgress(
                taskID: downloadTask.taskIdentifier,
                totalBytesWritten: totalBytesWritten
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let statusCode =
            (downloadTask.response as? HTTPURLResponse)?.statusCode
        do {
            // URLSession deletes `location` when this delegate method returns.
            // Move it synchronously before handing work to the main actor.
            let stagedURL = try Self.stageDownloadedFile(
                at: location,
                taskID: downloadTask.taskIdentifier
            )
            Task { @MainActor [weak self] in
                await self?.handleDownloaded(
                    taskID: downloadTask.taskIdentifier,
                    stagedURL: stagedURL,
                    statusCode: statusCode
                )
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.handleDownloadStagingFailure(
                    taskID: downloadTask.taskIdentifier
                )
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor [weak self] in
            await self?.handleCompletion(
                taskID: task.taskIdentifier,
                error: error
            )
        }
    }

    nonisolated func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        Task { @MainActor [weak self] in
            let completion = self?.backgroundCompletionHandler
            self?.backgroundCompletionHandler = nil
            completion?()
        }
    }
}
