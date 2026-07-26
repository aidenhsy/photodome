import Foundation
import XCTest

@testable import PhotoDome

final class EventTimestampFormatterTests: XCTestCase {
    func testFormatsEventTimeInTheRequestedLocalTimeZone() throws {
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let formatted = try XCTUnwrap(
            EventTimestampFormatter.localDateTime(
                "2026-07-25T15:04:00.000Z",
                timeZone: tokyo
            )
        )

        XCTAssertTrue(formatted.contains("12:04"))
        XCTAssertTrue(formatted.contains("JST"))
    }
}
