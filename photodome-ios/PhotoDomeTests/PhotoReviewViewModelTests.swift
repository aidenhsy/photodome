import Foundation
import XCTest

@testable import PhotoDome

@MainActor
final class PhotoReviewViewModelTests: XCTestCase {
    func testDecisionAdvancesCardBeforeServerResponse() async {
        let first = photo(id: "first")
        let second = photo(id: "second")
        let api = PhotoReviewServingStub(
            page: page(photos: [first, second]),
            pausesSelection: true
        )
        let model = PhotoReviewViewModel(access: access, api: api)

        await model.refresh()
        let task = Task { await model.decide(.keep) }
        while await !api.hasPendingSelection {
            await Task.yield()
        }

        XCTAssertEqual(model.currentPhoto?.id, second.id)
        XCTAssertEqual(model.decidedPhotoCount, 1)
        XCTAssertEqual(model.keptPhotoCount, 1)

        await api.completeSelection()
        await task.value
    }

    func testFailedDecisionRestoresCardAndCounts() async {
        let first = photo(id: "first")
        let api = PhotoReviewServingStub(
            page: page(photos: [first]),
            selectionError: APIClientError.unexpectedStatus(500)
        )
        let model = PhotoReviewViewModel(access: access, api: api)

        await model.refresh()
        await model.decide(.keep)

        XCTAssertEqual(model.currentPhoto?.id, first.id)
        XCTAssertEqual(model.decidedPhotoCount, 0)
        XCTAssertEqual(model.keptPhotoCount, 0)
        XCTAssertNotNil(model.presentedError)
    }

    private var access: StoredEventAccess {
        StoredEventAccess(
            event: EventSnapshot(
                id: "event",
                name: "Dinner",
                hostDisplayName: "Host",
                locationLabel: nil,
                state: .ended,
                memberCount: 2,
                readyPhotoCount: 2,
                createdAt: "2099-01-01T00:00:00.000Z",
                endedAt: "2099-01-01T00:01:00.000Z",
                expiresAt: "2099-01-08T00:01:00.000Z",
                uploadsRestrictedAt: nil,
                memberID: "reviewer",
                role: .guest
            ),
            capability: "capability",
            joinCode: nil
        )
    }

    private func page(photos: [AlbumPhoto]) -> ReviewPhotoPage {
        ReviewPhotoPage(
            photos: photos,
            nextCursor: nil,
            readyPhotoCount: photos.count,
            decidedPhotoCount: 0,
            keptPhotoCount: 0
        )
    }

    private func photo(id: String) -> AlbumPhoto {
        AlbumPhoto(
            id: id,
            contributorMemberID: "contributor",
            width: 1_600,
            height: 1_200,
            capturedAt: nil,
            readyAt: "2099-01-01T00:01:00.000Z",
            displayURL: URL(
                string: "https://example.com/\(id)/display"
            )!,
            thumbnailURL: URL(
                string: "https://example.com/\(id)/thumbnail"
            )!,
            urlsExpireAt: "2099-01-01T00:10:00.000Z"
        )
    }
}

private actor PhotoReviewServingStub: PhotoReviewServing {
    let page: ReviewPhotoPage
    let pausesSelection: Bool
    let selectionError: Error?
    private var selectionContinuation: CheckedContinuation<Void, Never>?

    init(
        page: ReviewPhotoPage,
        pausesSelection: Bool = false,
        selectionError: Error? = nil
    ) {
        self.page = page
        self.pausesSelection = pausesSelection
        self.selectionError = selectionError
    }

    var hasPendingSelection: Bool {
        selectionContinuation != nil
    }

    func getReviewQueue(
        eventID: String,
        capability: String,
        cursor: String?
    ) -> ReviewPhotoPage {
        page
    }

    func setPhotoSelection(
        eventID: String,
        photoID: String,
        capability: String,
        decision: PhotoSelectionDecision
    ) async throws -> PhotoSelection {
        if pausesSelection {
            await withCheckedContinuation { continuation in
                selectionContinuation = continuation
            }
        }
        if let selectionError {
            throw selectionError
        }
        return PhotoSelection(
            photoID: photoID,
            decision: decision,
            decidedAt: "2099-01-01T00:02:00.000Z"
        )
    }

    func undoLatestSelection(
        eventID: String,
        capability: String
    ) -> PhotoSelection? {
        nil
    }

    func completeSelection() {
        selectionContinuation?.resume()
        selectionContinuation = nil
    }
}
