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
    private let account = "auth_token"

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)

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

    func loadToken() throws -> String? {
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
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return token
    }

    func clearToken() throws {
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
