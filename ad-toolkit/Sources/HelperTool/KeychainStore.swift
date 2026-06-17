//
//  KeychainStore.swift
//  HelperTool
//
//  CRUD wrapper for storing ADConfigModel in the system Keychain.
//  Uses Security.framework (kSecClassGenericPassword) for encrypted-at-rest
//  storage that survives app reinstall and binary update.
//
//  Accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//  — encrypted at rest, no iCloud backup, available after first unlock.
//

import Foundation
import Security

/// Errors thrown by KeychainStore operations.
enum KeychainError: Error, LocalizedError {
    /// SecItemAdd failed with the given OSStatus
    case saveFailed(status: OSStatus)
    /// SecItemCopyMatching failed with the given OSStatus
    case loadFailed(status: OSStatus)
    /// SecItemDelete failed with the given OSStatus
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed (OSStatus: \(status))"
        case .loadFailed(let status):
            if status == errSecItemNotFound {
                return "No AD configuration found in Keychain."
            }
            return "Keychain load failed (OSStatus: \(status))"
        case .deleteFailed(let status):
            return "Keychain delete failed (OSStatus: \(status))"
        }
    }
}

/// Singleton that manages ADConfigModel persistence in the system Keychain.
///
/// All operations run as root via the Helper Tool context,
/// so kSecClassGenericPassword writes to the system Keychain.
class KeychainStore {

    // MARK: - Singleton

    static let shared = KeychainStore()

    private init() {}

    // MARK: - Thread Safety

    /// Serial queue for atomic CRUD operations to prevent race conditions
    /// between delete-then-add in save() and concurrent calls from XPC.
    private let queue = DispatchQueue(label: "com.cisa.ad-toolkit.keychain",
                                     qos: .default,
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)

    // MARK: - Constants

    private let service = "com.cisa.ad-toolkit.ad-config"
    private let account = "active-directory"

    // MARK: - Public API

    /// Save an ADConfigModel to the system Keychain.
    ///
    /// If an existing entry exists for the same service + account,
    /// it is deleted first to avoid errSecDuplicateItem.
    ///
    /// - Parameter config: The model to persist
    /// - Throws: `KeychainError.saveFailed` if SecItemAdd fails
    func save(_ config: ADConfigModel) throws {
        var configError: Error?
        queue.sync {
            do {
                let data = try JSONEncoder().encode(config)

                // Remove any existing item first (internal — already on serial queue)
                try _delete()

                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecUseDataProtectionKeychain as String: true,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                    kSecValueData as String: data
                ]

                let status = SecItemAdd(query as CFDictionary, nil)
                guard status == errSecSuccess else {
                    throw KeychainError.saveFailed(status: status)
                }
            } catch {
                configError = error
            }
        }
        if let error = configError { throw error }
    }

    /// Load the ADConfigModel from the system Keychain.
    ///
    /// - Returns: The decoded `ADConfigModel`
    /// - Throws: `KeychainError.loadFailed` on failure (including item not found)
    func load() throws -> ADConfigModel {
        return try queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecUseDataProtectionKeychain as String: true,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                throw KeychainError.loadFailed(status: status)
            }

            return try JSONDecoder().decode(ADConfigModel.self, from: data)
        }
    }

    /// Delete the AD config entry from the system Keychain.
    ///
    /// This is a no-op if no entry exists (SecItemDelete returns
    /// errSecItemNotFound, which we ignore).
    /// Internal delete — no queue synchronization.
    /// Call only from within `queue.sync` (e.g., via `save()`) or wrap externally.
    private func _delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound is acceptable — nothing to delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    /// Thread-safe delete wrapping `_delete()` through the serial queue.
    func delete() throws {
        try queue.sync {
            try _delete()
        }
    }
}
