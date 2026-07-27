import Foundation

struct AlbumSnapshot: Codable, Equatable, Sendable {
    let eventID: String
    let photos: [AlbumPhoto]
    let nextCursor: String?
    let readyPhotoCount: Int
    let savedAt: Date
}

protocol AlbumSnapshotStoring: Sendable {
    func load(eventID: String) async throws -> AlbumSnapshot?
    func save(_ snapshot: AlbumSnapshot) async throws
    func remove(eventID: String) async throws -> [String]
}

actor AlbumSnapshotStore: AlbumSnapshotStoring {
    static let shared = AlbumSnapshotStore()

    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryURL: URL? = nil) {
        self.directoryURL =
            directoryURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent(
                "PhotoDomeAlbumSnapshots",
                isDirectory: true
            )
        encoder.outputFormatting = [.sortedKeys]
    }

    func load(eventID: String) throws -> AlbumSnapshot? {
        let fileURL = fileURL(for: eventID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try decoder.decode(
            AlbumSnapshot.self,
            from: Data(contentsOf: fileURL)
        )
    }

    func save(_ snapshot: AlbumSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [
                .protectionKey:
                    FileProtectionType.completeUntilFirstUserAuthentication
            ]
        )
        try encoder.encode(snapshot).write(
            to: fileURL(for: snapshot.eventID),
            options: [
                .atomic,
                .completeFileProtectionUntilFirstUserAuthentication,
            ]
        )
    }

    @discardableResult
    func remove(eventID: String) throws -> [String] {
        let snapshot = try load(eventID: eventID)
        let fileURL = fileURL(for: eventID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        return snapshot?.photos.map(\.id) ?? []
    }

    private func fileURL(for eventID: String) -> URL {
        let safeName =
            Data(eventID.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return
            directoryURL
            .appendingPathComponent(safeName)
            .appendingPathExtension("json")
    }
}
