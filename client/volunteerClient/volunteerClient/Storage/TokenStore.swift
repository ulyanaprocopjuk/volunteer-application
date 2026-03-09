import Foundation
import Security

final class TokenStore {
    static let shared = TokenStore()

    private init() {}

    private let service = "com.yourapp.volunteer.auth"

    private enum Key: String {
        case accessToken
        case refreshToken
    }

    func saveTokens(accessToken: String, refreshToken: String, persist: Bool) {
        // Всегда держим в памяти через UserDefaults volatile не получится удобно,
        // поэтому: если rememberMe = false, просто не пишем в Keychain.
        if persist {
            save(accessToken, for: .accessToken)
            save(refreshToken, for: .refreshToken)
        } else {
            clear()
        }
    }

    func readAccessToken() -> String? {
        read(for: .accessToken)
    }

    func readRefreshToken() -> String? {
        read(for: .refreshToken)
    }

    func clear() {
        delete(for: .accessToken)
        delete(for: .refreshToken)
    }

    // MARK: - Keychain low-level

    private func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = query.merging([
            kSecValueData as String: data
        ]) { $1 }

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func read(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
