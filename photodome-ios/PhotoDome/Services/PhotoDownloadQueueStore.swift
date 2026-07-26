import Foundation

actor PhotoDownloadQueueStore {
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
            .appendingPathComponent("PhotoDomeDownloads", isDirectory: true)
        fileURL = directory.appendingPathComponent("queue.json")
    }

    func load() throws -> [PhotoDownloadItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try decoder.decode(
            [PhotoDownloadItem].self,
            from: Data(contentsOf: fileURL)
        )
    }

    func save(_ items: [PhotoDownloadItem]) throws {
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
