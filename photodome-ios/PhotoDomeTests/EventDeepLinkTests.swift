import XCTest

@testable import PhotoDome

final class EventDeepLinkTests: XCTestCase {
    func testEventAndCaptureLinksRoundTripWithoutCapabilities() throws {
        let eventID = UUID().uuidString.lowercased()

        let event = EventDeepLink.event(eventID: eventID)
        let capture = EventDeepLink.capture(eventID: eventID)

        XCTAssertEqual(EventDeepLink(url: event.url), event)
        XCTAssertEqual(EventDeepLink(url: capture.url), capture)
        XCTAssertNil(
            URLComponents(url: capture.url, resolvingAgainstBaseURL: false)?
                .query)
        XCTAssertFalse(capture.url.absoluteString.contains("pdc_"))
    }

    func testRejectsUnknownOrMalformedRoutes() {
        XCTAssertNil(EventDeepLink(url: URL(string: "https://example.com")!))
        XCTAssertNil(
            EventDeepLink(url: URL(string: "photodome://event/not-a-uuid")!)
        )
        XCTAssertNil(
            EventDeepLink(
                url: URL(
                    string:
                        "photodome://event/\(UUID().uuidString)/unexpected"
                )!
            )
        )
    }

    func testLiveActivityCaptureURLUsesTheCapabilityFreeCameraRoute() throws {
        let eventID = UUID()
        let attributes = EventActivityAttributes(
            eventID: eventID,
            eventName: "Birthday"
        )

        XCTAssertEqual(
            EventDeepLink(url: attributes.captureURL),
            .capture(eventID: eventID.uuidString.lowercased())
        )
        XCTAssertNil(
            URLComponents(
                url: attributes.captureURL,
                resolvingAgainstBaseURL: false
            )?.query
        )
    }
}
