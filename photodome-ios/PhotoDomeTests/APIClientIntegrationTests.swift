import Foundation
import UIKit
import XCTest

@testable import PhotoDome

final class APIClientIntegrationTests: XCTestCase {
    func testGeneratedClientCallsLocalAPI() async throws {
        guard
            ProcessInfo.processInfo.environment[
                "PHOTODOME_API_INTEGRATION"
            ] == "1"
        else {
            throw XCTSkip("Set PHOTODOME_API_INTEGRATION=1 to run.")
        }

        let client = APIClient(
            baseURL: try XCTUnwrap(URL(string: "http://127.0.0.1:3000"))
        )
        try await client.checkHealth()
    }

    func testTwoIndependentClientsCreateJoinAndTransferHost() async throws {
        guard
            ProcessInfo.processInfo.environment[
                "PHOTODOME_API_INTEGRATION"
            ] == "1"
        else {
            throw XCTSkip("Set PHOTODOME_API_INTEGRATION=1 to run.")
        }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:3000"))
        let hostClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let guestClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )

        let host = try await hostClient.createEvent(
            name: "Two-device integration \(UUID().uuidString.prefix(6))",
            displayName: "Integration Host"
        )
        let joinCode = try XCTUnwrap(host.joinCode)
        let guest = try await guestClient.joinEvent(
            code: joinCode,
            displayName: "Integration Guest"
        )

        XCTAssertEqual(host.id, guest.id)
        XCTAssertEqual(host.event.hostDisplayName, "Integration Host")
        XCTAssertEqual(host.event.role, .host)
        XCTAssertEqual(guest.event.role, .guest)

        let hostSnapshot = try await hostClient.getEvent(
            eventID: host.id,
            capability: host.capability
        )
        let guestSnapshot = try await guestClient.getEvent(
            eventID: guest.id,
            capability: guest.capability
        )
        XCTAssertEqual(hostSnapshot.memberCount, 2)
        XCTAssertEqual(guestSnapshot.memberCount, 2)

        try await guestClient.registerLiveActivityToken(
            eventID: guest.id,
            capability: guest.capability,
            pushToken: "00112233aabbccdd"
        )

        let rotatedCode = try await hostClient.rotateJoinCode(
            eventID: host.id,
            capability: host.capability
        )
        XCTAssertNotEqual(rotatedCode, joinCode)
        _ = try await guestClient.getEvent(
            eventID: guest.id,
            capability: guest.capability
        )

        let transfer = try await hostClient.createHostTransfer(
            eventID: host.id,
            capability: host.capability,
            joinCode: rotatedCode
        )
        let newHost = try await guestClient.exchangeHostTransfer(
            token: transfer.transferToken,
            joinCode: transfer.joinCode
        )
        XCTAssertEqual(newHost.event.role, .host)
        XCTAssertEqual(newHost.id, host.id)

        do {
            _ = try await hostClient.getEvent(
                eventID: host.id,
                capability: host.capability
            )
            XCTFail("The transferred host capability should be invalid.")
        } catch APIClientError.unauthorized {
            // Expected: transfer rotates authority immediately.
        }
    }

    func testGuestPhotoAppearsInHostAlbum() async throws {
        guard
            ProcessInfo.processInfo.environment[
                "PHOTODOME_API_INTEGRATION"
            ] == "1"
        else {
            throw XCTSkip("Set PHOTODOME_API_INTEGRATION=1 to run.")
        }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:3000"))
        let hostClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let guestClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let host = try await hostClient.createEvent(
            name: "Media integration \(UUID().uuidString.prefix(6))",
            displayName: "Media Host"
        )
        let guest = try await guestClient.joinEvent(
            code: try XCTUnwrap(host.joinCode),
            displayName: "Media Guest"
        )
        let sourceData = await MainActor.run {
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: 640, height: 480)
            )
            return renderer.jpegData(withCompressionQuality: 0.9) { context in
                UIColor.black.setFill()
                context.fill(
                    CGRect(x: 0, y: 0, width: 640, height: 480)
                )
            }
        }
        let prepared = try await ImagePreprocessor().prepare(sourceData)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }
        let grant = try await guestClient.reservePhoto(
            eventID: guest.id,
            capability: guest.capability,
            prepared: prepared
        )

        var uploadRequest = URLRequest(url: grant.uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue(
            grant.contentType,
            forHTTPHeaderField: "Content-Type"
        )
        uploadRequest.setValue(
            String(grant.byteSize),
            forHTTPHeaderField: "Content-Length"
        )
        uploadRequest.setValue(
            "bytes 0-\(grant.byteSize - 1)/\(grant.byteSize)",
            forHTTPHeaderField: "Content-Range"
        )
        let (_, uploadResponse) = try await URLSession.shared.upload(
            for: uploadRequest,
            fromFile: prepared.fileURL
        )
        XCTAssertTrue(
            (200..<300).contains(
                try XCTUnwrap(
                    (uploadResponse as? HTTPURLResponse)?.statusCode
                )
            )
        )

        try await guestClient.completePhotoUpload(
            eventID: guest.id,
            photoID: grant.photoID,
            capability: guest.capability
        )
        var photos: [AlbumPhoto] = []
        for _ in 0..<20 where photos.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
            photos = try await hostClient.listPhotos(
                eventID: host.id,
                capability: host.capability
            ).photos
        }
        XCTAssertEqual(photos.map(\.id), [grant.photoID])

        try await hostClient.removePhoto(
            eventID: host.id,
            photoID: grant.photoID,
            capability: host.capability
        )
        let moderated = try await hostClient.listPhotos(
            eventID: host.id,
            capability: host.capability
        )
        XCTAssertTrue(moderated.photos.isEmpty)
        XCTAssertEqual(moderated.readyPhotoCount, 0)
    }

    func testHostLifecycleAndGrandfatheredUploadContract() async throws {
        guard
            ProcessInfo.processInfo.environment[
                "PHOTODOME_API_INTEGRATION"
            ] == "1"
        else {
            throw XCTSkip("Set PHOTODOME_API_INTEGRATION=1 to run.")
        }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:3000"))
        let hostClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let guestClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let host = try await hostClient.createEvent(
            name: "M4 integration \(UUID().uuidString.prefix(6))",
            displayName: "Lifecycle Host"
        )
        let guest = try await guestClient.joinEvent(
            code: try XCTUnwrap(host.joinCode),
            displayName: "Lifecycle Guest"
        )

        let ended = try await hostClient.endEvent(
            eventID: host.id,
            capability: host.capability
        )
        XCTAssertEqual(ended.state, .ended)
        XCTAssertNotNil(ended.endedAt)
        XCTAssertNotNil(ended.expiresAt)

        let sourceData = await MainActor.run {
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: 100, height: 100)
            )
            return renderer.jpegData(withCompressionQuality: 0.9) { context in
                UIColor.black.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }
        }
        let prepared = try await ImagePreprocessor().prepare(sourceData)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }
        let admitted = try await guestClient.reservePhoto(
            eventID: guest.id,
            capability: guest.capability,
            prepared: prepared
        )

        let restricted = try await hostClient.restrictUploads(
            eventID: host.id,
            capability: host.capability
        )
        XCTAssertNotNil(restricted.uploadsRestrictedAt)
        _ = try await guestClient.renewPhotoUpload(
            eventID: guest.id,
            photoID: admitted.photoID,
            capability: guest.capability
        )

        do {
            _ = try await guestClient.reservePhoto(
                eventID: guest.id,
                capability: guest.capability,
                prepared: prepared
            )
            XCTFail("A new post-cutoff reservation should be rejected.")
        } catch APIClientError.uploadsClosed {
            // Expected.
        }

        let members = try await hostClient.listMembers(
            eventID: host.id,
            capability: host.capability
        )
        XCTAssertEqual(members.count, 2)
        XCTAssertTrue(members.contains { $0.id == guest.event.memberID })

        try await hostClient.removeMember(
            eventID: host.id,
            memberID: guest.event.memberID,
            capability: host.capability
        )
        do {
            _ = try await guestClient.getEvent(
                eventID: guest.id,
                capability: guest.capability
            )
            XCTFail("Removed attendee access should be revoked.")
        } catch APIClientError.unauthorized {
            // Expected.
        }
    }

    func testAttendeesKeepPrivateSetsAndDownloadOriginals() async throws {
        guard
            ProcessInfo.processInfo.environment[
                "PHOTODOME_API_INTEGRATION"
            ] == "1"
        else {
            throw XCTSkip("Set PHOTODOME_API_INTEGRATION=1 to run.")
        }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:3000"))
        let hostClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let firstGuestClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let secondGuestClient = APIClient(
            baseURL: baseURL,
            installationIdentity: UUID().uuidString
        )
        let host = try await hostClient.createEvent(
            name: "M5 integration \(UUID().uuidString.prefix(6))",
            displayName: "Curation Host"
        )
        let joinCode = try XCTUnwrap(host.joinCode)
        let firstGuest = try await firstGuestClient.joinEvent(
            code: joinCode,
            displayName: "First Guest"
        )
        let secondGuest = try await secondGuestClient.joinEvent(
            code: joinCode,
            displayName: "Second Guest"
        )

        let firstPhotoID = try await uploadPhoto(
            client: firstGuestClient,
            access: firstGuest,
            color: .black
        )
        let secondPhotoID = try await uploadPhoto(
            client: secondGuestClient,
            access: secondGuest,
            color: .white
        )
        var readyPhotoIDs: Set<String> = []
        for _ in 0..<30 where readyPhotoIDs.count < 2 {
            try await Task.sleep(for: .milliseconds(100))
            readyPhotoIDs = Set(
                try await hostClient.listPhotos(
                    eventID: host.id,
                    capability: host.capability
                ).photos.map(\.id)
            )
        }
        XCTAssertEqual(readyPhotoIDs, Set([firstPhotoID, secondPhotoID]))
        _ = try await hostClient.endEvent(
            eventID: host.id,
            capability: host.capability
        )

        _ = try await firstGuestClient.setPhotoSelection(
            eventID: host.id,
            photoID: firstPhotoID,
            capability: firstGuest.capability,
            decision: .keep
        )
        _ = try await firstGuestClient.setPhotoSelection(
            eventID: host.id,
            photoID: secondPhotoID,
            capability: firstGuest.capability,
            decision: .skip
        )
        _ = try await secondGuestClient.setPhotoSelection(
            eventID: host.id,
            photoID: firstPhotoID,
            capability: secondGuest.capability,
            decision: .skip
        )
        _ = try await secondGuestClient.setPhotoSelection(
            eventID: host.id,
            photoID: secondPhotoID,
            capability: secondGuest.capability,
            decision: .keep
        )

        let firstReview = try await firstGuestClient.getReviewQueue(
            eventID: host.id,
            capability: firstGuest.capability
        )
        let secondReview = try await secondGuestClient.getReviewQueue(
            eventID: host.id,
            capability: secondGuest.capability
        )
        XCTAssertEqual(firstReview.decidedPhotoCount, 2)
        XCTAssertEqual(secondReview.decidedPhotoCount, 2)
        XCTAssertEqual(firstReview.keptPhotoCount, 1)
        XCTAssertEqual(secondReview.keptPhotoCount, 1)
        XCTAssertTrue(firstReview.photos.isEmpty)
        XCTAssertTrue(secondReview.photos.isEmpty)

        let firstManifest = try await firstGuestClient.getDownloadManifest(
            eventID: host.id,
            capability: firstGuest.capability,
            mode: .kept
        )
        let secondManifest = try await secondGuestClient.getDownloadManifest(
            eventID: host.id,
            capability: secondGuest.capability,
            mode: .kept
        )
        XCTAssertEqual(firstManifest.photos.map(\.id), [firstPhotoID])
        XCTAssertEqual(secondManifest.photos.map(\.id), [secondPhotoID])

        for photo in firstManifest.photos + secondManifest.photos {
            let (data, response) = try await URLSession.shared.data(
                from: photo.originalURL
            )
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertFalse(data.isEmpty)
        }

        let undone = try await firstGuestClient.undoLatestSelection(
            eventID: host.id,
            capability: firstGuest.capability
        )
        XCTAssertEqual(undone?.photoID, secondPhotoID)
        let restoredReview = try await firstGuestClient.getReviewQueue(
            eventID: host.id,
            capability: firstGuest.capability
        )
        XCTAssertEqual(restoredReview.photos.map(\.id), [secondPhotoID])
        XCTAssertEqual(restoredReview.decidedPhotoCount, 1)
    }

    private func uploadPhoto(
        client: APIClient,
        access: StoredEventAccess,
        color: UIColor
    ) async throws -> String {
        let sourceData = await MainActor.run {
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: 160, height: 120)
            )
            return renderer.jpegData(withCompressionQuality: 0.9) { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
            }
        }
        let prepared = try await ImagePreprocessor().prepare(sourceData)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }
        let grant = try await client.reservePhoto(
            eventID: access.id,
            capability: access.capability,
            prepared: prepared
        )
        var uploadRequest = URLRequest(url: grant.uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue(
            grant.contentType,
            forHTTPHeaderField: "Content-Type"
        )
        uploadRequest.setValue(
            String(grant.byteSize),
            forHTTPHeaderField: "Content-Length"
        )
        uploadRequest.setValue(
            "bytes 0-\(grant.byteSize - 1)/\(grant.byteSize)",
            forHTTPHeaderField: "Content-Range"
        )
        let (_, response) = try await URLSession.shared.upload(
            for: uploadRequest,
            fromFile: prepared.fileURL
        )
        XCTAssertTrue(
            (200..<300).contains(
                try XCTUnwrap((response as? HTTPURLResponse)?.statusCode)
            )
        )
        try await client.completePhotoUpload(
            eventID: access.id,
            photoID: grant.photoID,
            capability: access.capability
        )
        return grant.photoID
    }
}
