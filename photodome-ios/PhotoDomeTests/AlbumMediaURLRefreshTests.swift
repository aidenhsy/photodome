import Foundation
import XCTest

@testable import PhotoDome

@MainActor
final class AlbumMediaURLRefreshTests: XCTestCase {
    func testRefreshPolicyRefreshesBeforeEarliestSignedURLExpires() throws {
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2099-01-01T00:04:31Z")
        )
        let photos = [
            photo(
                id: "later",
                urlVersion: "old",
                expiresAt: "2099-01-01T00:06:00.000Z"
            ),
            photo(
                id: "earlier",
                urlVersion: "old",
                expiresAt: "2099-01-01T00:05:00.000Z"
            ),
        ]

        XCTAssertTrue(
            AlbumMediaURLRefreshPolicy.shouldRefresh(
                photos: photos,
                at: now
            )
        )
    }

    func testForegroundRefreshReplacesExpiringPhotoURLs() async throws {
        let oldPhoto = photo(
            id: "photo",
            urlVersion: "old",
            expiresAt: "2099-01-01T00:05:00.000Z"
        )
        let freshPhoto = photo(
            id: "photo",
            urlVersion: "fresh",
            expiresAt: "2099-01-01T00:10:00.000Z"
        )
        let api = AlbumPhotoListingStub(
            pages: [
                page(oldPhoto),
                page(freshPhoto),
            ]
        )
        let model = EventAlbumViewModel(
            access: access,
            onEventSignal: { _ in },
            api: api,
            snapshotStore: AlbumSnapshotMemoryStore()
        )

        await model.refresh()
        let nearExpiry = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2099-01-01T00:04:31Z")
        )
        await model.refreshMediaURLsIfNeeded(at: nearExpiry)

        let requestCount = await api.requestCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(model.photos.first?.thumbnailURL, freshPhoto.thumbnailURL)
    }

    func testOneFailedCurrentURLRefreshesAndStaleFailuresDoNotRefetch() async {
        let oldPhoto = photo(
            id: "photo",
            urlVersion: "old",
            expiresAt: "2099-01-01T00:05:00.000Z"
        )
        let freshPhoto = photo(
            id: "photo",
            urlVersion: "fresh",
            expiresAt: "2099-01-01T00:10:00.000Z"
        )
        let api = AlbumPhotoListingStub(
            pages: [
                page(oldPhoto),
                page(freshPhoto),
            ]
        )
        let model = EventAlbumViewModel(
            access: access,
            onEventSignal: { _ in },
            api: api,
            snapshotStore: AlbumSnapshotMemoryStore()
        )

        await model.refresh()
        await model.recoverMediaURLAfterFailure(oldPhoto.thumbnailURL)
        await model.recoverMediaURLAfterFailure(oldPhoto.thumbnailURL)

        let requestCount = await api.requestCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(model.photos.first?.thumbnailURL, freshPhoto.thumbnailURL)
    }

    func testNearEndVisibilityLoadsAndMergesTheNextCursorPage() async {
        let first = photo(
            id: "first",
            urlVersion: "one",
            expiresAt: "2099-01-01T00:05:00.000Z"
        )
        let second = photo(
            id: "second",
            urlVersion: "two",
            expiresAt: "2099-01-01T00:05:00.000Z"
        )
        let api = CursorAlbumPhotoListingStub(
            pages: [
                nil: AlbumPhotoPage(
                    photos: [first],
                    nextCursor: first.id,
                    readyPhotoCount: 2
                ),
                first.id: AlbumPhotoPage(
                    photos: [second],
                    nextCursor: nil,
                    readyPhotoCount: 2
                ),
            ]
        )
        let snapshotStore = AlbumSnapshotMemoryStore()
        let model = EventAlbumViewModel(
            access: access,
            onEventSignal: { _ in },
            api: api,
            snapshotStore: snapshotStore
        )

        await model.refresh()
        await model.photoBecameVisible(first.id)

        XCTAssertEqual(model.photos.map(\.id), [first.id, second.id])
        let cursors = await api.requestedCursors
        XCTAssertEqual(cursors.count, 2)
        XCTAssertNil(cursors[0])
        XCTAssertEqual(cursors[1], first.id)
        let snapshot = await snapshotStore.load(eventID: access.id)
        XCTAssertEqual(snapshot?.photos.map(\.id), [first.id, second.id])
    }

    func testStableCacheKeyIgnoresRotatingSignedURL() {
        let old = photo(
            id: "photo",
            urlVersion: "old-signature",
            expiresAt: "2099-01-01T00:05:00.000Z"
        )
        let fresh = photo(
            id: "photo",
            urlVersion: "fresh-signature",
            expiresAt: "2099-01-01T00:10:00.000Z"
        )

        let oldKey = EventImageCacheKey.make(
            eventID: access.id,
            photoID: old.id,
            variant: .thumbnail
        )
        let freshKey = EventImageCacheKey.make(
            eventID: access.id,
            photoID: fresh.id,
            variant: .thumbnail
        )
        let displayKey = EventImageCacheKey.make(
            eventID: access.id,
            photoID: fresh.id,
            variant: .display
        )

        XCTAssertEqual(oldKey, freshKey)
        XCTAssertNotEqual(oldKey, displayKey)
        XCTAssertFalse(oldKey.contains("signature"))
    }

    private var access: StoredEventAccess {
        StoredEventAccess(
            event: EventSnapshot(
                id: "event",
                name: "Dinner",
                hostDisplayName: "Host",
                locationLabel: nil,
                state: .ended,
                memberCount: 1,
                readyPhotoCount: 1,
                createdAt: "2099-01-01T00:00:00.000Z",
                endedAt: "2099-01-01T00:01:00.000Z",
                expiresAt: "2099-01-08T00:01:00.000Z",
                uploadsRestrictedAt: nil,
                memberID: "member",
                role: .host
            ),
            capability: "capability",
            joinCode: nil
        )
    }

    private func page(_ photo: AlbumPhoto) -> AlbumPhotoPage {
        AlbumPhotoPage(
            photos: [photo],
            nextCursor: nil,
            readyPhotoCount: 1
        )
    }

    private func photo(
        id: String,
        urlVersion: String,
        expiresAt: String
    ) -> AlbumPhoto {
        AlbumPhoto(
            id: id,
            contributorMemberID: "member",
            width: 1_000,
            height: 1_000,
            capturedAt: nil,
            readyAt: "2099-01-01T00:01:00.000Z",
            displayURL: URL(
                string: "https://example.com/\(id)/display?\(urlVersion)"
            )!,
            thumbnailURL: URL(
                string: "https://example.com/\(id)/thumb?\(urlVersion)"
            )!,
            urlsExpireAt: expiresAt
        )
    }
}

private actor AlbumPhotoListingStub: AlbumPhotoListing {
    private let pages: [AlbumPhotoPage]
    private var index = 0

    init(pages: [AlbumPhotoPage]) {
        self.pages = pages
    }

    var requestCount: Int { index }

    func listPhotos(
        eventID: String,
        capability: String,
        cursor: String?
    ) async throws -> AlbumPhotoPage {
        let page = pages[min(index, pages.count - 1)]
        index += 1
        return page
    }
}

private actor CursorAlbumPhotoListingStub: AlbumPhotoListing {
    private let pages: [String?: AlbumPhotoPage]
    private(set) var requestedCursors: [String?] = []

    init(pages: [String?: AlbumPhotoPage]) {
        self.pages = pages
    }

    func listPhotos(
        eventID: String,
        capability: String,
        cursor: String?
    ) async throws -> AlbumPhotoPage {
        requestedCursors.append(cursor)
        return pages[cursor]!
    }
}

private actor AlbumSnapshotMemoryStore: AlbumSnapshotStoring {
    private var snapshots: [String: AlbumSnapshot] = [:]

    func load(eventID: String) -> AlbumSnapshot? {
        snapshots[eventID]
    }

    func save(_ snapshot: AlbumSnapshot) {
        snapshots[snapshot.eventID] = snapshot
    }

    func remove(eventID: String) -> [String] {
        snapshots.removeValue(forKey: eventID)?.photos.map(\.id) ?? []
    }
}
