import Foundation

struct PreparedPhoto: Sendable {
    let fileURL: URL
    let byteSize: Int
    let sha256: String
    let width: Int
    let height: Int
    let capturedAt: String?
    let orientation: Int
}

struct PhotoCaptureLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
}

struct PhotoUploadGrant: Sendable {
    let photoID: String
    let uploadURL: URL
    let contentType: String
    let byteSize: Int
}

struct AlbumPhoto: Identifiable, Equatable, Sendable {
    let id: String
    let contributorMemberID: String
    let width: Int
    let height: Int
    let capturedAt: String?
    let readyAt: String
    let displayURL: URL
    let thumbnailURL: URL
    let urlsExpireAt: String
}

struct AlbumPhotoPage: Equatable, Sendable {
    let photos: [AlbumPhoto]
    let readyPhotoCount: Int
}

enum PhotoSelectionDecision: String, Codable, Sendable {
    case keep
    case skip
}

struct PhotoSelection: Equatable, Sendable {
    let photoID: String
    let decision: PhotoSelectionDecision
    let decidedAt: String
}

struct ReviewPhotoPage: Equatable, Sendable {
    let photos: [AlbumPhoto]
    let nextCursor: String?
    let readyPhotoCount: Int
    let decidedPhotoCount: Int
    let keptPhotoCount: Int
}

enum DownloadManifestMode: String, Codable, Sendable {
    case all
    case kept
}

struct DownloadManifestPhoto: Identifiable, Equatable, Sendable {
    let id: String
    let contentType: String
    let byteSize: Int
    let capturedAt: String?
    let readyAt: String
    let originalURL: URL
    let urlExpiresAt: String
}

struct DownloadManifestPage: Equatable, Sendable {
    let photos: [DownloadManifestPhoto]
    let nextCursor: String?
    let totalPhotoCount: Int
}

enum PhotoDownloadState: String, Codable, Sendable {
    case queued
    case downloading
    case saving
    case saved
    case failed
}

struct PhotoDownloadItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let eventID: String
    let photoID: String
    var sourceURL: URL
    let capturedAt: String?
    let expectedByteSize: Int
    var localFileURL: URL?
    var taskIdentifier: Int?
    var state: PhotoDownloadState
    var bytesReceived: Int64
    var retryCount: Int
    var failureMessage: String?

    var progress: Double {
        guard expectedByteSize > 0 else { return 0 }
        return min(1, Double(bytesReceived) / Double(expectedByteSize))
    }
}

enum UploadQueueState: String, Codable, Sendable {
    case uploading
    case verifying
    case processing
    case failed
}

struct UploadQueueItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let eventID: String
    let photoID: String
    var uploadSessionURL: URL
    let localFileURL: URL
    let contentType: String
    let byteSize: Int
    var taskIdentifier: Int?
    var state: UploadQueueState
    var bytesSent: Int64
    var retryCount: Int
    var failureMessage: String?

    var progress: Double {
        guard byteSize > 0 else { return 0 }
        return min(1, Double(bytesSent) / Double(byteSize))
    }
}
