import Foundation
import XCTest

@testable import PhotoDome

@MainActor
final class EventArchiveStoreTests: XCTestCase {
    func testArchiveStatePersistsAndCanBeReversed() throws {
        let suiteName =
            "com.younger7jp.photodome.archive-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let key = "test-archive-ids"
        let store = EventArchiveStore(defaults: defaults, key: key)

        XCTAssertEqual(store.load(), [])

        store.archive(eventID: "event-b")
        store.archive(eventID: "event-a")
        XCTAssertEqual(store.load(), ["event-a", "event-b"])
        XCTAssertEqual(
            defaults.stringArray(forKey: key),
            ["event-a", "event-b"]
        )

        let restored = EventArchiveStore(defaults: defaults, key: key)
        restored.unarchive(eventID: "event-a")
        XCTAssertEqual(restored.load(), ["event-b"])
    }

    func testRetainRemovesArchiveStateForForgottenEvents() throws {
        let suiteName =
            "com.younger7jp.photodome.archive-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = EventArchiveStore(
            defaults: defaults,
            key: "test-archive-ids"
        )

        store.archive(eventID: "available")
        store.archive(eventID: "forgotten")
        store.retain(eventIDs: ["available"])

        XCTAssertEqual(store.load(), ["available"])
    }
}
