import XCTest

@testable import PhotoDome

final class InvitePayloadTests: XCTestCase {
    func testJoinInviteRoundTrips() throws {
        let payload = InvitePayload.join(code: "ABCD2345")

        XCTAssertEqual(InvitePayload(url: payload.url), payload)
        XCTAssertEqual(payload.url.scheme, "https")
        XCTAssertEqual(payload.url.host, "photodome.invalid")
    }

    func testHostTransferIsDistinctFromPublicInvite() {
        let payload = InvitePayload.hostTransfer(
            token: "pdt_secret",
            eventID: UUID().uuidString,
            joinCode: "EFGH6789"
        )

        XCTAssertEqual(InvitePayload(url: payload.url), payload)
        XCTAssertEqual(payload.url.path, "/host-transfer")
    }

    func testUnknownLinkIsRejected() {
        XCTAssertNil(
            InvitePayload(
                url: URL(string: "https://photodome.invalid/unknown")!
            )
        )
    }

    @MainActor
    func testQRScanSubmissionGateAcceptsOnlyTheFirstDetection() {
        let gate = QRScanSubmissionGate()

        XCTAssertTrue(gate.claim())
        XCTAssertFalse(gate.claim())
        XCTAssertTrue(gate.hasSubmitted)
    }
}
