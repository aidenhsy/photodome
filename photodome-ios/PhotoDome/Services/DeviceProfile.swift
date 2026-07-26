import Foundation
import Security

@MainActor
final class DeviceProfile: ObservableObject {
    @Published private(set) var displayName: String?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let store: DeviceDisplayNameStore

    init(store: DeviceDisplayNameStore = DeviceDisplayNameStore()) {
        self.store = store
    }

    func load() async {
        defer { isLoading = false }

        if ProcessInfo.processInfo.arguments.contains(
            "PhotoDomeUITestNeedsName"
        ) {
            displayName = nil
            return
        }
        if ProcessInfo.processInfo.arguments.contains(
            "PhotoDomeUITestPermissionsGranted"
        )
            || ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestPermissionsMissing"
            )
        {
            displayName = "Taylor"
            return
        }

        do {
            displayName = try await store.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(_ value: String) async -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "Enter your name."
            return false
        }
        guard normalized.count <= 50 else {
            errorMessage = "Keep your name to 50 characters or fewer."
            return false
        }

        do {
            try await store.save(normalized)
            displayName = normalized
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

actor DeviceDisplayNameStore {
    private let service: String
    private let account = "display-name"

    init(service: String = "com.younger7jp.photodome.device-profile") {
        self.service = service
    }

    func load() throws -> String? {
        let query = baseQuery().merging([
            kSecReturnData as String: true
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let name = String(data: data, encoding: .utf8),
            !name.isEmpty
        else {
            throw KeychainStoreError.malformedItem
        }
        return name
    }

    func save(_ displayName: String) throws {
        let data = Data(displayName.utf8)
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var item = query
            for (key, value) in attributes {
                item[key] = value
            }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
