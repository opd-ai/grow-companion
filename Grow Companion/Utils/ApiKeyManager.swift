//
//  ApiKeyManager.swift
//  Grow Companion
//
//  Secure storage for API keys using Keychain Services.
//

import Foundation
import Security
import CryptoKit

/// Manages secure storage of API keys using the Keychain.
final class ApiKeyManager {
    static let shared = ApiKeyManager()

    private let initializationKey = "ApiKeyManager_Initialized"

    private init() {
        initializeKeysFromEncryptedFile()
    }

    private var service: String {
        Bundle.main.bundleIdentifier ?? "com.projectname.apiKeys"
    }

    private var projectName: String {
        Bundle.main.bundleIdentifier?.components(separatedBy: ".").last ?? "Grow-Companion"
    }

    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func has(key: String) -> Bool { get(key: key) != nil }

    private func initializeKeysFromEncryptedFile() {
        guard !UserDefaults.standard.bool(forKey: initializationKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: initializationKey) }
        guard let path = Bundle.main.path(forResource: "ENCRYPTED_KEYS", ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return }

        for (key, value) in plist {
            guard let encrypted = value as? String,
                  let decrypted = decryptValue(encrypted, projectName: projectName) else { continue }
            _ = save(key: key, value: decrypted)
        }
    }

    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func decryptValue(_ encryptedValue: String, projectName: String) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedValue),
              let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData) else { return nil }
        let key = deriveKey(from: projectName)
        guard let decryptedData = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return String(data: decryptedData, encoding: .utf8)
    }

    private func deriveKey(from projectName: String) -> SymmetricKey {
        let keyData = SHA256.hash(data: projectName.data(using: .utf8) ?? Data())
        return SymmetricKey(data: keyData)
    }
}
