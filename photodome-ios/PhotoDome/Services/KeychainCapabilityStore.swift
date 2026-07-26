import Foundation
import Security

protocol EventAccessStoring: Sendable {
    func loadAll() async throws -> [StoredEventAccess]
    func save(_ access: StoredEventAccess) async throws
    func remove(eventID: String) async throws
}

enum KeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case malformedItem

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            "Keychain operation failed with status \(status)."
        case .malformedItem:
            "A saved PhotoDome event could not be read."
        }
    }
}

actor KeychainCapabilityStore: EventAccessStoring {
    private let service: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String = "com.younger7jp.photodome.event-access") {
        self.service = service
    }

    func loadAll() throws -> [StoredEventAccess] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }

        let dataItems: [Data]
        if let values = result as? [Data] {
            dataItems = values
        } else if let value = result as? Data {
            dataItems = [value]
        } else {
            throw KeychainStoreError.malformedItem
        }

        return try dataItems.map { try decoder.decode(StoredEventAccess.self, from: $0) }
    }

    func save(_ access: StoredEventAccess) throws {
        let data = try encoder.encode(access)
        let lookup = baseQuery(eventID: access.id)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var add = lookup
            for (key, value) in attributes {
                add[key] = value
            }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }
    }

    func remove(eventID: String) throws {
        let status = SecItemDelete(baseQuery(eventID: eventID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(eventID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: eventID,
            kSecAttrSynchronizable as String: true,
        ]
    }
}

actor InstallationIdentityStore {
    private let service: String
    private let account = "installation"

    init(service: String = "com.younger7jp.photodome.installation") {
        self.service = service
    }

    func identity() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            guard
                let data = result as? Data,
                let identity = String(data: data, encoding: .utf8)
            else {
                throw KeychainStoreError.malformedItem
            }
            return identity
        }
        guard status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }

        let identity = UUID().uuidString.lowercased()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(identity.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
        return identity
    }
}
