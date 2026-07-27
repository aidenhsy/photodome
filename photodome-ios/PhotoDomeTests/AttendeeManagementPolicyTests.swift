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

final class EventTakeHomePolicyTests: XCTestCase {
    func testTakeHomeIsAvailableForLiveAndEndedEventsWithReadyPhotos() {
        XCTAssertTrue(
            EventTakeHomePolicy.isAvailable(
                for: event(state: .live, readyPhotoCount: 1)
            )
        )
        XCTAssertTrue(
            EventTakeHomePolicy.isAvailable(
                for: event(state: .ended, readyPhotoCount: 1)
            )
        )
    }

    func testTakeHomeIsHiddenWithoutReadyPhotosOrDuringExpiry() {
        XCTAssertFalse(
            EventTakeHomePolicy.isAvailable(
                for: event(state: .live, readyPhotoCount: 0)
            )
        )
        XCTAssertFalse(
            EventTakeHomePolicy.isAvailable(
                for: event(state: .expiring, readyPhotoCount: 1)
            )
        )
    }

    func testLiveBulkSaveLabelMakesTheSnapshotBehaviorExplicit() {
        XCTAssertEqual(
            EventTakeHomePolicy.saveAllLabel(for: .live),
            "Save current photos"
        )
        XCTAssertEqual(
            EventTakeHomePolicy.saveAllLabel(for: .ended),
            "Save all"
        )
    }

    private func event(
        state: EventLifecycle,
        readyPhotoCount: Int
    ) -> EventSnapshot {
        EventSnapshot(
            id: "event",
            name: "Birthday",
            hostDisplayName: "Host",
            locationLabel: nil,
            state: state,
            memberCount: 2,
            readyPhotoCount: readyPhotoCount,
            createdAt: "2099-01-01T00:00:00.000Z",
            endedAt: state == .live ? nil : "2099-01-01T01:00:00.000Z",
            expiresAt: state == .live ? nil : "2099-01-08T01:00:00.000Z",
            uploadsRestrictedAt: nil,
            memberID: "member",
            role: .guest
        )
    }
}
