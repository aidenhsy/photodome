import XCTest

@testable import PhotoDome

final class AlbumUploadGridPolicyTests: XCTestCase {
    func testNewestPendingUploadsAppearBeforeOlderPendingUploads() throws {
        let oldest = try makeItem(id: UUID(), photoID: "oldest")
        let newest = try makeItem(id: UUID(), photoID: "newest")

        let visible = AlbumUploadGridPolicy.visibleQueueItems(
            eventID: "event",
            readyPhotoIDs: [],
            allItems: [oldest, newest]
        )

        XCTAssertEqual(visible.map(\.photoID), ["newest", "oldest"])
    }

    func testReadyServerPhotoReplacesMatchingOptimisticCell() throws {
        let item = try makeItem(id: UUID(), photoID: "ready-photo")

        let visible = AlbumUploadGridPolicy.visibleQueueItems(
            eventID: "event",
            readyPhotoIDs: ["ready-photo"],
            allItems: [item]
        )

        XCTAssertTrue(visible.isEmpty)
    }

    func testQueueIdentityReplacesPreparingPlaceholderWithoutDuplicate()
        throws
    {
        let handedOffID = UUID()
        let stillPreparingID = UUID()
        let queued = try makeItem(id: handedOffID, photoID: "reserved")

        let visible = AlbumUploadGridPolicy.visiblePreparingIDs(
            [handedOffID, stillPreparingID],
            eventQueueItems: [queued]
        )

        XCTAssertEqual(visible, [stillPreparingID])
    }

    func testOtherEventQueueItemsAreExcluded() throws {
        let other = try makeItem(
            id: UUID(),
            eventID: "other-event",
            photoID: "other"
        )

        let visible = AlbumUploadGridPolicy.visibleQueueItems(
            eventID: "event",
            readyPhotoIDs: [],
            allItems: [other]
        )

        XCTAssertTrue(visible.isEmpty)
    }

    func testAllActivePipelineStatesUseOneUploadingPresentation() {
        let activeStates: [UploadQueueState?] = [
            nil,
            .uploading,
            .verifying,
            .processing,
        ]

        for state in activeStates {
            let presentation = AlbumUploadPresentation(state: state)
            XCTAssertEqual(presentation, .uploading)
            XCTAssertEqual(presentation.label, "Uploading")
            XCTAssertEqual(presentation.icon, "arrow.up")
        }
    }

    func testFailedPipelineStateKeepsRetryPresentation() {
        let presentation = AlbumUploadPresentation(state: .failed)

        XCTAssertEqual(presentation, .failed)
        XCTAssertEqual(presentation.label, "Tap to retry")
        XCTAssertEqual(presentation.icon, "exclamationmark.circle")
    }

    private func makeItem(
        id: UUID,
        eventID: String = "event",
        photoID: String
    ) throws -> UploadQueueItem {
        UploadQueueItem(
            id: id,
            eventID: eventID,
            photoID: photoID,
            uploadSessionURL: try XCTUnwrap(
                URL(string: "https://storage.example/upload")
            ),
            localFileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"),
            contentType: "image/jpeg",
            byteSize: 100,
            taskIdentifier: nil,
            state: .uploading,
            bytesSent: 0,
            retryCount: 0,
            failureMessage: nil
        )
    }
}
