import Foundation
import XCTest

@testable import PhotoDome

final class ErrorMessageTests: XCTestCase {
    func testConnectionFailureUsesShortMessage() {
        let error = URLError(.cannotConnectToHost)

        XCTAssertEqual(
            error.photoDomeMessage,
            "PhotoDome can’t connect to the server. Try again shortly."
        )
    }

    func testWrappedGeneratedClientFailureUsesShortMessage() {
        let error = NSError(
            domain: "OpenAPIRuntime.ClientError",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Transport threw an error. NSURLErrorDomain Code=-1004 Could not connect to the server."
            ]
        )

        XCTAssertEqual(
            error.photoDomeMessage,
            "PhotoDome can’t connect to the server. Try again shortly."
        )
    }

    func testKnownAPIErrorKeepsItsSpecificMessage() {
        XCTAssertEqual(
            APIClientError.eventFull.photoDomeMessage,
            "This event has reached its 100-person limit."
        )
    }

    func testUnknownErrorUsesGenericMessage() {
        let error = NSError(
            domain: "PhotoDomeTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Internal implementation detail"]
        )

        XCTAssertEqual(
            error.photoDomeMessage,
            "Something went wrong. Please try again."
        )
    }
}
