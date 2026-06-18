import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "Keychain вернул неожиданные данные"
        case .unhandledError(let status):
            return "Ошибка Keychain: \(status)"
        }
    }
}

final class KeychainStorage {
    private let service = "com.yourapp.localauth"
    private let accessAccount = "access_token"
    private let refreshAccount = "refresh_token"

    func saveAccessToken(_ token: String) throws {
        try save(token, account: accessAccount)
    }

    func saveRefreshToken(_ token: String) throws {
        try save(token, account: refreshAccount)
    }

    func loadAccessToken() throws -> String? {
        try load(account: accessAccount)
    }

    func loadRefreshToken() throws -> String? {
        try load(account: refreshAccount)
    }

    func clearAccessToken() throws {
        try clear(account: accessAccount)
    }

    func clearRefreshToken() throws {
        try clear(account: refreshAccount)
    }

    func clearAll() throws {
        try clearAccessToken()
        try clearRefreshToken()
    }

    private func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainError.unhandledError(status: updateStatus)
        }

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(newItem as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandledError(status: addStatus)
        }
    }

    private func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return value
    }

    private func clear(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }

        throw KeychainError.unhandledError(status: status)
    }
}
