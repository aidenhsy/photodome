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

    func testAlbumGridEdgeTapsSelectTheVisiblePhoto() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestAlbumGridHitTargets")
        app.launch()

        let top = app.buttons["albumPhoto.top"]
        let bottom = app.buttons["albumPhoto.bottom"]
        let result = app.staticTexts["albumGridTapResult"]
        XCTAssertTrue(top.waitForExistence(timeout: 5))
        XCTAssertTrue(bottom.exists)

        top.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)
        ).tap()
        XCTAssertEqual(result.label, "Tapped top")

        bottom.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)
        ).tap()
        XCTAssertEqual(result.label, "Tapped bottom")
    }

    func testInviteOffersCopyWithVisibleConfirmationButNotShare() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestInviteCodeCopy")
        app.launch()

        let copyButton = app.buttons["copyJoinCodeButton"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        XCTAssertEqual(copyButton.label, "Copy code")
        XCTAssertFalse(app.buttons["Share invite"].exists)

        copyButton.tap()

        XCTAssertEqual(copyButton.label, "Code copied")
    }

    func testEventCanBeArchivedAndUnarchivedFromTheMenu() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestEventArchive")
        app.launch()

        let eventCard = app.buttons["eventCard.archive-regression"]
        XCTAssertTrue(eventCard.waitForExistence(timeout: 5))
        eventCard.swipeLeft()
        let archiveButton = app.buttons["Archive"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 2))
        archiveButton.tap()
        XCTAssertFalse(eventCard.exists)

        app.buttons["menuButton"].tap()
        let archivesButton = app.buttons["archivesMenuButton"]
        XCTAssertTrue(archivesButton.waitForExistence(timeout: 2))
        archivesButton.tap()
        XCTAssertTrue(
            app.navigationBars["Archives"].waitForExistence(timeout: 2)
        )

        let archivedCard = app.buttons["eventCard.archive-regression"]
        XCTAssertTrue(archivedCard.waitForExistence(timeout: 2))
        archivedCard.press(forDuration: 1)
        let unarchiveButton = app.buttons["Unarchive"]
        XCTAssertTrue(unarchiveButton.waitForExistence(timeout: 2))
        unarchiveButton.tap()
        XCTAssertTrue(
            app.staticTexts["No archived events."].waitForExistence(
                timeout: 2
            )
        )
    }

    func testAttendingCountOpensHostAttendeeManagement() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestAttendeeList")
        app.launch()

        let attendeeCount = app.buttons["attendeeCountButton"]
        XCTAssertTrue(attendeeCount.waitForExistence(timeout: 5))
        attendeeCount.tap()

        XCTAssertTrue(
            app.navigationBars["Attendees"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Host Person"].exists)
        XCTAssertTrue(app.staticTexts["Guest Person 1"].exists)
        XCTAssertFalse(app.buttons["removeAttendee.host"].exists)
        XCTAssertTrue(app.buttons["removeAttendee.guest-1"].exists)
    }

    func testLowerAttendeeWarningUsesTheTappedRowAsItsSource() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestAttendeeList")
        app.launch()

        let attendeeCount = app.buttons["attendeeCountButton"]
        XCTAssertTrue(attendeeCount.waitForExistence(timeout: 5))
        attendeeCount.tap()

        let lowerRemoveButton = app.buttons["removeAttendee.guest-8"]
        for _ in 0..<4 where !lowerRemoveButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(lowerRemoveButton.isHittable)
        let sourceMidY = lowerRemoveButton.frame.midY

        lowerRemoveButton.tap()

        let warningTitle = app.staticTexts["Remove Guest Person 8?"]
        XCTAssertTrue(warningTitle.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(
            warningTitle.frame.midY,
            app.windows.firstMatch.frame.midY,
            "A lower-row confirmation should remain in the lower screen region."
        )
        XCTAssertLessThan(
            abs(warningTitle.frame.midY - sourceMidY),
            300,
            "The confirmation should stay near the tapped lower row."
        )
    }

    func testCameraExposesFlashZoomAndLensSwitchingControls() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("PhotoDomeUITestCameraControls")
        app.launch()

        let flash = app.buttons["cameraFlashButton"]
        let zoom = app.buttons["cameraZoomButton"]
        let switchCamera = app.buttons["cameraSwitchButton"]
        let shutter = app.buttons["cameraShutterButton"]

        XCTAssertTrue(flash.waitForExistence(timeout: 5))
        XCTAssertEqual(flash.label, "Flash Auto")
        XCTAssertTrue(flash.isEnabled)
        XCTAssertTrue(zoom.exists)
        XCTAssertEqual(zoom.value as? String, "1.0 times")
        XCTAssertTrue(switchCamera.exists)
        XCTAssertEqual(switchCamera.label, "Switch to front camera")
        XCTAssertTrue(shutter.exists)

        flash.tap()
        XCTAssertEqual(flash.label, "Flash On")

        zoom.tap()
        XCTAssertEqual(zoom.value as? String, "2.0 times")

        switchCamera.tap()
        XCTAssertEqual(switchCamera.label, "Switch to back camera")
        XCTAssertEqual(flash.label, "Flash unavailable")
        XCTAssertFalse(flash.isEnabled)
        XCTAssertEqual(zoom.value as? String, "1.0 times")

        shutter.tap()
        XCTAssertEqual(
            app.staticTexts["cameraCaptureResult"].label,
            "Captured 1"
        )
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
