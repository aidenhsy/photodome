import Foundation
import UIKit

@MainActor
final class BackgroundUploadManager: NSObject, ObservableObject {
    static let shared = BackgroundUploadManager()

    @Published private(set) var items: [UploadQueueItem] = []

    private let store = UploadQueueStore()
    private let preprocessor = ImagePreprocessor()
    private var api: APIClient?
    private var isConfigured = false
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let identifier = "com.younger7jp.photodome.media-upload"
        let configuration = URLSessionConfiguration.background(
            withIdentifier: identifier
        )
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
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
            let activeTaskIDs = Set(
                await session.allTasks.map(\.taskIdentifier)
            )
            for index in items.indices
            where items[index].state == .uploading
                && !(items[index].taskIdentifier.map(activeTaskIDs.contains)
                    ?? false)
            {
                items[index].state = .failed
                items[index].failureMessage =
                    "The transfer was interrupted. Tap retry."
                items[index].taskIdentifier = nil
            }
            try await persist()
        } catch {
            items = []
        }
    }

    func enqueue(
        data: Data,
        access: StoredEventAccess,
        capturedAt: Date? = nil,
        captureLocation: PhotoCaptureLocation? = nil,
        itemID: UUID = UUID()
    ) async throws {
        let prepared = try await preprocessor.prepare(
            data,
            capturedAt: capturedAt,
            captureLocation: captureLocation
        )
        try await enqueue(
            prepared: prepared,
            access: access,
            itemID: itemID
        )
    }

    func prepare(
        data: Data,
        capturedAt: Date?,
        captureLocation: PhotoCaptureLocation?
    ) async throws -> PreparedPhoto {
        try await preprocessor.prepare(
            data,
            capturedAt: capturedAt,
            captureLocation: captureLocation
        )
    }

    func enqueue(
        prepared: PreparedPhoto,
        access: StoredEventAccess,
        itemID: UUID = UUID()
    ) async throws {
        await configure()
        guard let api else {
            try? FileManager.default.removeItem(at: prepared.fileURL)
            throw APIClientError.unexpectedStatus(0)
        }

        do {
            let grant = try await api.reservePhoto(
                eventID: access.id,
                capability: access.capability,
                prepared: prepared
            )
            var item = UploadQueueItem(
                id: itemID,
                eventID: access.id,
                photoID: grant.photoID,
                uploadSessionURL: grant.uploadURL,
                localFileURL: prepared.fileURL,
                contentType: grant.contentType,
                byteSize: grant.byteSize,
                taskIdentifier: nil,
                state: .uploading,
                bytesSent: 0,
                retryCount: 0,
                failureMessage: nil
            )
            items.append(item)
            item.taskIdentifier = startTask(for: item)
            replace(item)
            try await persist()
        } catch {
            try? FileManager.default.removeItem(at: prepared.fileURL)
            throw error
        }
    }

    func retry(itemID: UUID) async {
        await configure()
        guard
            var item = items.first(where: { $0.id == itemID }),
            let api,
            FileManager.default.fileExists(atPath: item.localFileURL.path)
        else {
            return
        }

        do {
            let capability = try await capability(for: item.eventID)
            let grant = try await api.renewPhotoUpload(
                eventID: item.eventID,
                photoID: item.photoID,
                capability: capability
            )
            item.uploadSessionURL = grant.uploadURL
            item.state = .uploading
            item.bytesSent = 0
            item.retryCount += 1
            item.failureMessage = nil
            item.taskIdentifier = startTask(for: item)
            replace(item)
            try await persist()
        } catch {
            markFailed(itemID: itemID)
        }
    }

    func acknowledgeReady(photoIDs: Set<String>) async {
        let finished = items.filter { photoIDs.contains($0.photoID) }
        for item in finished {
            try? FileManager.default.removeItem(at: item.localFileURL)
        }
        items.removeAll { photoIDs.contains($0.photoID) }
        try? await persist()
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
            try? FileManager.default.removeItem(at: item.localFileURL)
        }
        items.removeAll { $0.eventID == eventID }
        try? await persist()
    }

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }

    private func startTask(for item: UploadQueueItem) -> Int {
        var request = URLRequest(url: item.uploadSessionURL)
        request.httpMethod = "PUT"
        request.setValue(item.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(
            String(item.byteSize),
            forHTTPHeaderField: "Content-Length"
        )
        request.setValue(
            "bytes 0-\(item.byteSize - 1)/\(item.byteSize)",
            forHTTPHeaderField: "Content-Range"
        )
        let task = session.uploadTask(
            with: request,
            fromFile: item.localFileURL
        )
        task.resume()
        return task.taskIdentifier
    }

    private func handleProgress(taskID: Int, bytesSent: Int64) async {
        guard
            var item = items.first(where: { $0.taskIdentifier == taskID })
        else {
            return
        }
        item.bytesSent = bytesSent
        replace(item)
        try? await persist()
    }

    private func handleCompletion(
        taskID: Int,
        statusCode: Int?,
        error: Error?
    ) async {
        guard
            var item = items.first(where: { $0.taskIdentifier == taskID })
        else {
            return
        }
        item.taskIdentifier = nil

        guard error == nil, let statusCode, (200..<300).contains(statusCode)
        else {
            item.state = .failed
            item.failureMessage =
                "Upload paused before it finished. Tap retry."
            replace(item)
            try? await persist()
            return
        }

        item.state = .verifying
        item.bytesSent = Int64(item.byteSize)
        replace(item)
        try? await persist()
        await verify(itemID: item.id)
    }

    private func verify(itemID: UUID) async {
        guard
            var item = items.first(where: { $0.id == itemID }),
            let api
        else {
            return
        }
        do {
            let capability = try await capability(for: item.eventID)
            try await api.completePhotoUpload(
                eventID: item.eventID,
                photoID: item.photoID,
                capability: capability
            )
            item.state = .processing
            item.failureMessage = nil
            replace(item)
            try await persist()
        } catch {
            item.state = .failed
            item.failureMessage =
                "Photo verification did not finish. Tap retry."
            replace(item)
            try? await persist()
        }
    }

    private func capability(for eventID: String) async throws -> String {
        let access = try await KeychainCapabilityStore().loadAll()
            .first { $0.id == eventID }
        guard let access else {
            throw APIClientError.unauthorized
        }
        return access.capability
    }

    private func markFailed(itemID: UUID) {
        guard var item = items.first(where: { $0.id == itemID }) else {
            return
        }
        item.state = .failed
        item.taskIdentifier = nil
        item.failureMessage = "Retry could not start. Check your connection."
        replace(item)
        Task { try? await persist() }
    }

    private func replace(_ item: UploadQueueItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            items.append(item)
            return
        }
        items[index] = item
    }

    private func persist() async throws {
        try await store.save(items)
    }
}

extension BackgroundUploadManager: URLSessionTaskDelegate, URLSessionDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        Task { @MainActor [weak self] in
            await self?.handleProgress(
                taskID: task.taskIdentifier,
                bytesSent: totalBytesSent
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode
        Task { @MainActor [weak self] in
            await self?.handleCompletion(
                taskID: task.taskIdentifier,
                statusCode: statusCode,
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
