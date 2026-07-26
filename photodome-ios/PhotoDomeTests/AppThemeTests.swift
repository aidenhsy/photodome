import SwiftUI
import XCTest

@testable import PhotoDome

final class AppThemeTests: XCTestCase {
    func testBrandPrimitivesRemainMonochrome() {
        XCTAssertEqual(PhotoDomeTokens.Brand.ink, Color.black)
        XCTAssertEqual(PhotoDomeTokens.Brand.white, Color.white)
    }

    func testFoundationGeometryUsesDesignTokens() {
        XCTAssertEqual(
            AppTheme.pagePadding,
            PhotoDomeTokens.Space.x6
        )
        XCTAssertEqual(
            AppTheme.cornerRadius,
            PhotoDomeTokens.Radius.default
        )
        XCTAssertEqual(
            PhotoDomeTokens.Size.minimumTouchTarget,
            44
        )
    }
}
