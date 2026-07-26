import Foundation
import Photos

enum PhotoLibraryWriterError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Allow PhotoDome to add photos in Settings, then try again."
    }
}

actor PhotoLibraryWriter {
    func requestAddPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    func save(fileURL: URL, capturedAt: String?) async throws {
        guard await requestAddPermission() else {
            throw PhotoLibraryWriterError.permissionDenied
        }
        let creationDate = capturedAt.flatMap(Self.parseDate)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = creationDate
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(
                with: .photo,
                fileURL: fileURL,
                options: options
            )
        }
    }

    func save(data: Data, capturedAt: Date?) async throws {
        guard await requestAddPermission() else {
            throw PhotoLibraryWriterError.permissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = capturedAt
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
