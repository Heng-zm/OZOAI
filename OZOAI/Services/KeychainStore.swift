import Foundation
import Security

enum KeychainStore {
    private static let service = "com.ozoai.app"

    static func readAPIKey(for provider: AIProvider) -> String {
        readString(account: provider.keychainAccount) ?? ""
    }

    @discardableResult
    static func saveAPIKey(_ value: String, for provider: AIProvider) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(for: provider)
            return true
        }
        return saveString(
            trimmed,
            account: provider.keychainAccount,
            label: "OZO AI — \(provider.displayName)"
        )
    }

    static func deleteAPIKey(for provider: AIProvider) {
        delete(account: provider.keychainAccount)
    }

    // MARK: - Generic values

    static func readString(account: String) -> String? {
        guard let data = readData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveString(_ value: String, account: String, label: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, account: account, label: label)
    }

    static func readData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
            return nil
        }
        return item as? Data
    }

    @discardableResult
    static func saveData(_ data: Data, account: String, label: String) -> Bool {
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: label,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
