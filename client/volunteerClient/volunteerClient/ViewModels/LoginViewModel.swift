import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var passwordError: String? = nil
    @Published var rememberMe: Bool

    @Published var isLoading: Bool = false

    init() {
        let saved = UserDefaults.standard.object(forKey: "rememberMe") as? Bool
        self.rememberMe = saved ?? true
    }

    var isLoginDisabled: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    func clearPasswordError() {
        passwordError = nil
    }

    @discardableResult
    func login() async -> Bool {
        guard !isLoginDisabled, !isLoading else { return false }

        isLoading = true
        defer { isLoading = false }

        passwordError = nil

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(rememberMe, forKey: "rememberMe")

        do {
            let response = try await AuthService.shared.login(
                username: trimmedUsername,
                password: password,
                rememberMe: rememberMe
            )

            print("Login success. user:", response.user.username, "role:", response.user.role.rawValue)
            return true
        } catch {
            passwordError = (error as? LocalizedError)?.errorDescription ?? "Ошибка входа"
            return false
        }
    }
}
