import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authAPI: AuthAPIProtocol
    private unowned let session: AppSession

    init(
        session: AppSession,
        authAPI: AuthAPIProtocol = AuthAPI()
    ) {
        self.session = session
        self.authAPI = authAPI
    }

    var isLoginDisabled: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    func clearError() {
        errorMessage = nil
    }

    func login() async {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty else {
            errorMessage = "Введите username"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Введите пароль"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let auth = try await authAPI.login(username: cleanUsername, password: password)
            try await session.authorize(with: auth.accessToken, destination: .main)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
