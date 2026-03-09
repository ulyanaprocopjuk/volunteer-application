import Foundation
import Combine

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""

    @Published var isLoading: Bool = false
    @Published var signUpError: String? = nil

    var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Password validation

    var passwordValidationErrors: [String] {
        guard !password.isEmpty else { return [] }

        var errors: [String] = []

        if password.count < 7 {
            errors.append("Минимум 7 символов")
        }

        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            errors.append("Хотя бы одна заглавная буква")
        }

        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            errors.append("Хотя бы одна строчная буква")
        }

        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            errors.append("Хотя бы одна цифра")
        }

        let specialSet = CharacterSet.punctuationCharacters.union(.symbols)
        if password.rangeOfCharacter(from: specialSet) == nil {
            errors.append("Хотя бы один спецсимвол")
        }

        if password.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            errors.append("Без пробелов")
        }

        return errors
    }

    var isPasswordValid: Bool {
        !password.isEmpty && passwordValidationErrors.isEmpty
    }

    // MARK: - Confirm password

    var passwordsMatch: Bool {
        password == confirmPassword
    }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Пароли не совпадают"
    }

    // MARK: - Form state

    var isSignUpDisabled: Bool {
        trimmedUsername.isEmpty ||
        !isPasswordValid ||
        confirmPassword.isEmpty ||
        !passwordsMatch
    }

    func clearServerError() {
        signUpError = nil
    }

    @discardableResult
    func signUp() async -> Bool {
        guard !isSignUpDisabled, !isLoading else { return false }

        isLoading = true
        defer { isLoading = false }

        signUpError = nil

        do {
            let response = try await AuthService.shared.register(
                username: trimmedUsername,
                password: password,
                rememberMe: true
            )

            print("Signup success. user:", response.user.username, "role:", response.user.role.rawValue)
            return true
        } catch {
            signUpError = (error as? LocalizedError)?.errorDescription ?? "Не удалось зарегистрироваться"
            return false
        }
    }
}
