//
//  DeviceKeyStore.swift
//  Grow Companion
//
//  The device's long-lived identity for protected envelopes: an X25519 key for
//  agreement and an Ed25519 key for signatures, both kept in the Keychain and
//  available only while the device is unlocked. Nothing is uploaded and no
//  feature sends data yet; see docs/E2EE_DESIGN.md.
//

import CryptoKit
import Foundation
import Security

enum DeviceKeyStoreError: LocalizedError {
    case keychain(OSStatus)
    case unreadableKey

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return String(localized: "The device key could not be stored securely (Keychain error \(status)).")
        case .unreadableKey:
            return String(localized: "The stored device key could not be read.")
        }
    }
}

enum DeviceKeyStore {
    private static let agreementAccount = "identity.agreement.v1"
    private static let signingAccount = "identity.signing.v1"

    private static var service: String {
        (Bundle.main.bundleIdentifier ?? "com.organizationName.Grow-Companion") + ".e2ee"
    }

    /// Loads the device identity, creating it on first use.
    static func identity() throws -> SecureEnvelope.Identity {
        if let existing = try existingIdentity() { return existing }

        let identity = SecureEnvelope.Identity(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
        try store(identity.agreement.rawRepresentation, account: agreementAccount)
        try store(identity.signing.rawRepresentation, account: signingAccount)
        return identity
    }

    /// Reads the device identity without creating one.
    static func existingIdentity() throws -> SecureEnvelope.Identity? {
        guard let agreementData = try data(account: agreementAccount) else { return nil }
        guard let signingData = try data(account: signingAccount) else { return nil }

        do {
            return SecureEnvelope.Identity(
                agreement: try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData),
                signing: try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
            )
        } catch {
            throw DeviceKeyStoreError.unreadableKey
        }
    }

    static var hasIdentity: Bool {
        (try? existingIdentity()) != nil
    }

    /// When the signing key was created, for the status screen.
    static func createdAt() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: signingAccount,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any],
              let date = attributes[kSecAttrCreationDate as String] as? Date else { return nil }
        return date
    }

    /// Removes both keys, for the delete-all flow.
    @discardableResult
    static func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func store(_ value: Data, account: String) throws {
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw DeviceKeyStoreError.keychain(status) }
    }

    private static func data(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw DeviceKeyStoreError.keychain(status) }
        return result as? Data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
