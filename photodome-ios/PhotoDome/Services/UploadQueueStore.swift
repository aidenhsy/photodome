import Foundation

actor UploadQueueStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryURL: URL? = nil) {
        let directory =
            directoryURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent("PhotoDomeUploads", isDirectory: true)
        fileURL = directory.appendingPathComponent("queue.json")
    }

    func load() throws -> [UploadQueueItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try decoder.decode(
            [UploadQueueItem].self,
            from: Data(contentsOf: fileURL)
        )
    }

    func save(_ items: [UploadQueueItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(items).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
