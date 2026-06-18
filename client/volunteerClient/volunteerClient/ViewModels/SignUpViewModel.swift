import Foundation
import Combine

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var signUpError: String?

    private let authAPI: AuthAPIProtocol
    private unowned let session: AppSession

    init(
        session: AppSession,
        authAPI: AuthAPIProtocol? = nil
    ) {
        self.session = session
        self.authAPI = authAPI ?? AuthAPI()
    }

    var passwordValidationErrors: [String] {
        var errors: [String] = []

        if password.count < 8 {
            errors.append("Минимум 8 символов")
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            errors.append("Хотя бы одна заглавная буква")
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            errors.append("Хотя бы одна цифра")
        }

        return errors
    }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return password == confirmPassword ? nil : "Пароли не совпадают"
    }

    var emailError: String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let valid = NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
        return valid ? nil : "Введите корректную почту"
    }

    var isSignUpDisabled: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 ||
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        emailError != nil ||
        !passwordValidationErrors.isEmpty ||
        password != confirmPassword ||
        confirmPassword.isEmpty
    }

    func clearServerError() {
        signUpError = nil
    }

    func signUp() async {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard cleanUsername.count >= 3 else {
            signUpError = "Username должен быть не короче 3 символов"
            return
        }

        guard !cleanEmail.isEmpty, emailError == nil else {
            signUpError = "Введите корректную почту"
            return
        }

        guard passwordValidationErrors.isEmpty else {
            signUpError = "Пароль не соответствует требованиям"
            return
        }

        guard password == confirmPassword else {
            signUpError = "Пароли не совпадают"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await authAPI.register(username: cleanUsername, email: cleanEmail, password: password)
            let auth = try await authAPI.login(username: cleanUsername, password: password)
            try await session.authorize(with: auth, destination: .emailVerification)
        } catch {
            signUpError = error.localizedDescription
        }
    }
}
