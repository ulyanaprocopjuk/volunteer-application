import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    enum Flow {
        case loading
        case auth
        case emailVerification
        case profileSetup
        case main
    }

    enum PostAuthDestination {
        case emailVerification
        case profileSetup
        case main
    }

    @Published private(set) var flow: Flow = .loading
    @Published private(set) var token: String?
    @Published private(set) var currentUser: UserResponse?
    @Published var globalError: String?

    private let authAPI: AuthAPIProtocol
    private let keychain: KeychainStorage
    private let installState: InstallState

    init(
        authAPI: AuthAPIProtocol? = nil,
        keychain: KeychainStorage? = nil,
        installState: InstallState? = nil
    ) {
        self.authAPI = authAPI ?? AuthAPI()
        self.keychain = keychain ?? KeychainStorage()
        self.installState = installState ?? InstallState()

        handleFreshInstallIfNeeded()

        Task {
            await restoreSession()
        }
    }

    func restoreSession() async {
        flow = .loading
        globalError = nil

        do {
            let savedAccessToken = try keychain.loadAccessToken()
            let savedRefreshToken = try keychain.loadRefreshToken()

            if let savedAccessToken, !savedAccessToken.isEmpty, !jwtIsExpired(savedAccessToken) {
                do {
                    let user = try await authAPI.getCurrentUser(token: savedAccessToken)
                    token = savedAccessToken
                    currentUser = user
                    flow = .main
                    return
                } catch {
                    if let savedRefreshToken, !savedRefreshToken.isEmpty, error.isUnauthorizedResponse {
                        _ = try await refreshAccessToken(using: savedRefreshToken)
                        flow = .main
                        return
                    }

                    throw error
                }
            }

            if let savedRefreshToken, !savedRefreshToken.isEmpty {
                _ = try await refreshAccessToken(using: savedRefreshToken)
                flow = .main
                return
            }

            clearLocalStateOnly()
            flow = .auth
        } catch {
            clearSessionState()
            globalError = error.localizedDescription
            flow = .auth
        }
    }

    func authorize(with tokenResponse: TokenResponse, destination: PostAuthDestination) async throws {
        let user = try await authAPI.getCurrentUser(token: tokenResponse.accessToken)

        try keychain.saveAccessToken(tokenResponse.accessToken)
        try keychain.saveRefreshToken(tokenResponse.refreshToken)

        self.token = tokenResponse.accessToken
        self.currentUser = user
        self.globalError = nil

        switch destination {
        case .emailVerification:
            flow = .emailVerification
        case .profileSetup:
            flow = .profileSetup
        case .main:
            flow = .main
        }
    }

    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let token, !token.isEmpty, !jwtIsExpired(token) {
            return token
        }

        guard let savedRefreshToken = try keychain.loadRefreshToken(),
              !savedRefreshToken.isEmpty else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Сессия истекла. Войдите снова."]
            )
        }

        return try await refreshAccessToken(using: savedRefreshToken)
    }

    func performAuthorizedRequest<T>(_ operation: (String) async throws -> T) async throws -> T {
        let token = try await validAccessToken()

        do {
            return try await operation(token)
        } catch {
            guard error.isUnauthorizedResponse else {
                throw error
            }

            let refreshedToken: String
            do {
                refreshedToken = try await validAccessToken(forceRefresh: true)
            } catch {
                if error.isUnauthorizedResponse {
                    clearSessionState()
                    globalError = error.localizedDescription
                    flow = .auth
                }

                throw error
            }

            return try await operation(refreshedToken)
        }
    }

    func completeEmailVerification() {
        flow = .profileSetup
    }

    func completeProfileSetup() {
        flow = .main
    }

    func logout() {
        Task {
            if let refreshToken = try? keychain.loadRefreshToken(),
               !refreshToken.isEmpty {
                try? await authAPI.logout(refreshToken: refreshToken)
            }

            clearSessionState()
            globalError = nil
            flow = .auth
        }
    }

    var isAuthenticated: Bool {
        token != nil && currentUser != nil
    }

    private func handleFreshInstallIfNeeded() {
        guard installState.isFreshInstall() else { return }

        do {
            try keychain.clearAll()
        } catch {
            globalError = error.localizedDescription
        }
    }

    private func refreshAccessToken() async throws -> String {
        guard let savedRefreshToken = try keychain.loadRefreshToken(),
              !savedRefreshToken.isEmpty else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Refresh token отсутствует"]
            )
        }

        return try await refreshAccessToken(using: savedRefreshToken)
    }

    private func refreshAccessToken(using refreshToken: String) async throws -> String {
        let tokenResponse = try await authAPI.refresh(refreshToken: refreshToken)
        let user = try await authAPI.getCurrentUser(token: tokenResponse.accessToken)

        try keychain.saveAccessToken(tokenResponse.accessToken)
        try keychain.saveRefreshToken(tokenResponse.refreshToken)

        self.token = tokenResponse.accessToken
        self.currentUser = user
        self.globalError = nil

        return tokenResponse.accessToken
    }

    private func clearSessionState() {
        do {
            try keychain.clearAll()
        } catch {
            globalError = error.localizedDescription
        }

        clearLocalStateOnly()
    }

    private func clearLocalStateOnly() {
        token = nil
        currentUser = nil
    }

    private func jwtIsExpired(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? NSNumber else {
            return true
        }

        let expiryDate = Date(timeIntervalSince1970: exp.doubleValue)
        return expiryDate <= Date().addingTimeInterval(30)
    }

    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object
    }
}
