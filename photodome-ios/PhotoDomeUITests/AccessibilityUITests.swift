import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestPermissionsGranted")
        app.launch()
        XCTAssertTrue(
            app.buttons["settingsButton"].waitForExistence(timeout: 5)
        )
    }

    func testHomePassesAutomatedAccessibilityAudit() throws {
        launchApp()
        try auditCurrentScreen()
    }

    func testCreateEventPassesAutomatedAccessibilityAudit() throws {
        launchApp()
        app.buttons["Create an event"].tap()
        XCTAssertTrue(app.navigationBars["New event"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Place"].exists)
        try auditCurrentScreen()
    }

    func testFirstLaunchCollectsANameBeforeShowingHome() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestNeedsName")
        app.launch()

        XCTAssertTrue(
            app.staticTexts["What’s your name?"].waitForExistence(timeout: 5)
        )
        let nameField = app.textFields["Your name"]
        nameField.tap()
        nameField.typeText("Taylor")
        app.buttons["nameContinueButton"].tap()

        XCTAssertTrue(
            app.buttons["settingsButton"].waitForExistence(timeout: 5)
        )
    }

    func testNamePromptCanGoBackAndReturnsBeforeCreating() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestNeedsName")
        app.launch()

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(
            app.buttons["Create an event"].waitForExistence(timeout: 5)
        )

        app.buttons["Create an event"].tap()
        XCTAssertTrue(
            app.staticTexts["What’s your name?"].waitForExistence(timeout: 2)
        )
    }

    func testJoinPassesAutomatedAccessibilityAudit() throws {
        launchApp()
        app.buttons["Join an event"].tap()
        XCTAssertTrue(app.navigationBars["Join"].waitForExistence(timeout: 2))
        try auditCurrentScreen()
    }

    func testSettingsPassesAutomatedAccessibilityAudit() throws {
        launchApp()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(
                timeout: 2
            )
        )
        try auditCurrentScreen()
    }

    func testNameCanBeChangedFromSettings() {
        launchApp()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 2)
        )

        app.buttons["Your name, Taylor"].tap()
        XCTAssertTrue(
            app.navigationBars["Your name"].waitForExistence(timeout: 2)
        )

        let field = app.textFields["Your name"]
        field.tap()
        field.typeText(" Updated")
        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.buttons["Your name, Taylor Updated"].waitForExistence(
                timeout: 2
            )
        )
    }

    func testCreateStopsAtPermissionSetupWhenAccessIsMissing() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestPermissionsMissing")
        app.launch()
        XCTAssertTrue(
            app.buttons["settingsButton"].waitForExistence(timeout: 5)
        )

        app.buttons["Create an event"].tap()

        XCTAssertTrue(
            app.navigationBars["Permissions"].waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
    }

    private func auditCurrentScreen() throws {
        try app.performAccessibilityAudit(
            for: [
                .contrast,
                .hitRegion,
                .sufficientElementDescription,
                .dynamicType,
                .textClipped,
                .trait,
            ]
        )
    }
}
