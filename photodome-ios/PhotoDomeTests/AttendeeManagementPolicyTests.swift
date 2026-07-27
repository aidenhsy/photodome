import XCTest

@testable import PhotoDome

final class AttendeeManagementPolicyTests: XCTestCase {
    func testOnlyHostCanOpenAttendeeManagement() {
        XCTAssertTrue(
            AttendeeManagementPolicy.canOpenList(viewerRole: .host)
        )
        XCTAssertFalse(
            AttendeeManagementPolicy.canOpenList(viewerRole: .guest)
        )
    }

    func testHostCanRemoveGuestButCannotRemoveHost() {
        XCTAssertTrue(
            AttendeeManagementPolicy.canRemove(
                member(role: .guest),
                viewerRole: .host
            )
        )
        XCTAssertFalse(
            AttendeeManagementPolicy.canRemove(
                member(role: .host),
                viewerRole: .host
            )
        )
    }

    func testGuestCannotRemoveAnotherGuest() {
        XCTAssertFalse(
            AttendeeManagementPolicy.canRemove(
                member(role: .guest),
                viewerRole: .guest
            )
        )
    }

    private func member(role: EventRole) -> EventMember {
        EventMember(
            id: UUID().uuidString,
            displayName: "Taylor",
            role: role,
            joinedAt: "2026-07-28T00:00:00.000Z",
            isViewer: false
        )
    }
}
