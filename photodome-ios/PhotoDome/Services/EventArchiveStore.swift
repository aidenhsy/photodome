import Foundation

@MainActor
final class EventArchiveStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "archived-event-ids"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func archive(eventID: String) {
        var eventIDs = load()
        eventIDs.insert(eventID)
        save(eventIDs)
    }

    func unarchive(eventID: String) {
        var eventIDs = load()
        eventIDs.remove(eventID)
        save(eventIDs)
    }

    func retain(eventIDs: Set<String>) {
        save(load().intersection(eventIDs))
    }

    private func save(_ eventIDs: Set<String>) {
        defaults.set(eventIDs.sorted(), forKey: key)
    }
}
