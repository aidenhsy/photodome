import ImageIO
import UIKit
import XCTest

@testable import PhotoDome

final class EventMediaCacheTests: XCTestCase {
    func testAlbumSnapshotRoundTripsLoadedPages() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumSnapshotStore(directoryURL: directory)
        let snapshot = AlbumSnapshot(
            eventID: "event",
            photos: [photo],
            nextCursor: "next-photo",
            readyPhotoCount: 2,
            savedAt: Date(timeIntervalSince1970: 100)
        )

        try await store.save(snapshot)
        let restored = try await store.load(eventID: "event")

        XCTAssertEqual(restored, snapshot)
        let removedIDs = try await store.remove(eventID: "event")
        XCTAssertEqual(removedIDs, [photo.id])
        let removedSnapshot = try await store.load(eventID: "event")
        XCTAssertNil(removedSnapshot)
    }

    func testLocalPreviewUsesBoundedImageIODecode() async throws {
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 2_048, height: 1_024)
        ).image { context in
            UIColor.systemBlue.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: 2_048, height: 1_024)
            )
        }
        let data = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))

        let thumbnail = await LocalImageThumbnailer.make(
            data: data,
            maximumPixelSize: 512
        )

        let cgImage = try XCTUnwrap(thumbnail?.cgImage)
        XCTAssertLessThanOrEqual(max(cgImage.width, cgImage.height), 512)
        XCTAssertGreaterThan(min(cgImage.width, cgImage.height), 0)
    }

    func testExpiredSignedURLCanOnlyUseWarmCache() throws {
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(
                from: "2099-01-01T00:05:01Z"
            )
        )

        XCTAssertFalse(
            AlbumMediaURLRefreshPolicy.isUsable(
                "2099-01-01T00:05:00.000Z",
                at: now
            )
        )
        XCTAssertTrue(
            AlbumMediaURLRefreshPolicy.isUsable(
                "2099-01-01T00:10:00.000Z",
                at: now
            )
        )
    }

    private var photo: AlbumPhoto {
        AlbumPhoto(
            id: "photo",
            contributorMemberID: "member",
            width: 2_048,
            height: 1_024,
            capturedAt: nil,
            readyAt: "2099-01-01T00:00:00.000Z",
            displayURL: URL(
                string: "https://example.com/display?signed"
            )!,
            thumbnailURL: URL(
                string: "https://example.com/thumb?signed"
            )!,
            urlsExpireAt: "2099-01-01T00:05:00.000Z"
        )
    }
}
