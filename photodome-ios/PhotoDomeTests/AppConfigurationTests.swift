import XCTest

@testable import PhotoDome

final class AppConfigurationTests: XCTestCase {
    func testReleaseConfigurationRequiresHTTPS() throws {
        XCTAssertEqual(
            try AppConfiguration.validatedAPIBaseURL(
                "https://api.example.com",
                defaultValue: nil,
                allowsInsecureLocalhost: false
            ).absoluteString,
            "https://api.example.com"
        )
        XCTAssertThrowsError(
            try AppConfiguration.validatedAPIBaseURL(
                "http://api.example.com",
                defaultValue: nil,
                allowsInsecureLocalhost: false
            )
        )
        XCTAssertThrowsError(
            try AppConfiguration.validatedAPIBaseURL(
                nil,
                defaultValue: nil,
                allowsInsecureLocalhost: false
            )
        )
    }

    func testDebugConfigurationAllowsOnlyInsecureLocalhost() throws {
        XCTAssertEqual(
            try AppConfiguration.validatedAPIBaseURL(
                nil,
                defaultValue: "http://127.0.0.1:3000",
                allowsInsecureLocalhost: true
            ).host,
            "127.0.0.1"
        )
        XCTAssertThrowsError(
            try AppConfiguration.validatedAPIBaseURL(
                "http://example.com",
                defaultValue: nil,
                allowsInsecureLocalhost: true
            )
        )
    }
}
