import Foundation
import Combine

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var username = ""
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

    var isSignUpDisabled: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 ||
        !passwordValidationErrors.isEmpty ||
        password != confirmPassword ||
        confirmPassword.isEmpty
    }

    func clearServerError() {
        signUpError = nil
    }

    func signUp() async {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanUsername.count >= 3 else {
            signUpError = "Username должен быть не короче 3 символов"
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
            _ = try await authAPI.register(username: cleanUsername, password: password)
            let auth = try await authAPI.login(username: cleanUsername, password: password)
            try await session.authorize(with: auth.accessToken, destination: .profileSetup)
        } catch {
            signUpError = error.localizedDescription
        }
    }
}
