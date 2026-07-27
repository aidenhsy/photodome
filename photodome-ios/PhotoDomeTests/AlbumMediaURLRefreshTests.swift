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
            api: api
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
            api: api
        )

        await model.refresh()
        await model.recoverMediaURLAfterFailure(oldPhoto.thumbnailURL)
        await model.recoverMediaURLAfterFailure(oldPhoto.thumbnailURL)

        let requestCount = await api.requestCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(model.photos.first?.thumbnailURL, freshPhoto.thumbnailURL)
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
        AlbumPhotoPage(photos: [photo], readyPhotoCount: 1)
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
        capability: String
    ) async throws -> AlbumPhotoPage {
        let page = pages[min(index, pages.count - 1)]
        index += 1
        return page
    }
}
