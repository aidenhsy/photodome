import Foundation
import XCTest

@testable import PhotoDome

final class EventTimestampFormatterTests: XCTestCase {
    func testFormatsEventTimeInTheRequestedLocalTimeZone() throws {
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let formatted = try XCTUnwrap(
            EventTimestampFormatter.localDateTime(
                "2026-07-25T15:04:00.000Z",
                timeZone: tokyo,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertTrue(formatted.contains("12:04"))
        XCTAssertTrue(formatted.contains("(Japan Standard Time)"))
    }

    func testUsesFriendlyLocalizedNameForUserTimeZone() throws {
        let miami = try XCTUnwrap(
            TimeZone(identifier: "America/New_York")
        )
        let formatted = try XCTUnwrap(
            EventTimestampFormatter.localDateTime(
                "2026-08-02T15:04:00.000Z",
                timeZone: miami,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertTrue(formatted.contains("11:04"))
        XCTAssertTrue(formatted.contains("(Eastern Time)"))
        XCTAssertFalse(formatted.contains("GMT-4"))
        XCTAssertFalse(formatted.contains("GMT-04"))
    }

    func testHidesNumericGMTOffsetBehindLocalTimeLabel() throws {
        let numericOffset = try XCTUnwrap(
            TimeZone(secondsFromGMT: -4 * 60 * 60)
        )
        let formatted = try XCTUnwrap(
            EventTimestampFormatter.localDateTime(
                "2026-08-02T15:04:00.000Z",
                timeZone: numericOffset,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertTrue(formatted.hasSuffix("(local time)"))
        XCTAssertFalse(formatted.contains("GMT-"))
    }
}
