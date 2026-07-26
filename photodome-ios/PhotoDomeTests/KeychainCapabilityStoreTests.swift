import XCTest

@testable import PhotoDome

final class KeychainCapabilityStoreTests: XCTestCase {
    func testSynchronizableEventAccessCanBeSavedUpdatedAndRemoved() async throws {
        let service = "com.younger7jp.photodome.tests.\(UUID().uuidString)"
        let store = KeychainCapabilityStore(service: service)
        let eventID = UUID().uuidString
        var access = StoredEventAccess(
            event: EventSnapshot(
                id: eventID,
                name: "Keychain test",
                hostDisplayName: "Taylor",
                locationLabel: nil,
                state: .live,
                memberCount: 1,
                readyPhotoCount: 0,
                createdAt: "2026-07-25T00:00:00.000Z",
                endedAt: nil,
                expiresAt: nil,
                uploadsRestrictedAt: nil,
                memberID: UUID().uuidString,
                role: .host
            ),
            capability: "pdc_test_secret",
            joinCode: "ABCD2345"
        )

        try await store.save(access)
        var saved = try await store.loadAll()
        XCTAssertEqual(saved, [access])

        access.joinCode = "WXYZ6789"
        try await store.save(access)
        saved = try await store.loadAll()
        XCTAssertEqual(saved, [access])

        try await store.remove(eventID: eventID)
        saved = try await store.loadAll()
        XCTAssertEqual(saved, [])
    }

    func testDeviceDisplayNamePersistsWithoutAnAccount() async throws {
        let service = "com.younger7jp.photodome.profile-tests.\(UUID().uuidString)"
        let store = DeviceDisplayNameStore(service: service)

        let initial = try await store.load()
        XCTAssertNil(initial)

        try await store.save("Taylor")
        let saved = try await store.load()
        XCTAssertEqual(saved, "Taylor")
    }
}
