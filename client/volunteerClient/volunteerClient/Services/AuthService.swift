import Foundation

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let api = APIClient.shared
    private let tokenStore = TokenStore.shared

    private(set) var currentUser: UserDTO?
    private(set) var accessTokenInMemory: String?
    private(set) var refreshTokenInMemory: String?

    private init() {}

    func register(username: String, password: String, rememberMe: Bool = true) async throws -> AuthResponseDTO {
        let response: AuthResponseDTO = try await api.post(
            "auth/register",
            body: RegisterRequestDTO(username: username, password: password)
        )

        applyAuth(response, rememberMe: rememberMe)
        return response
    }

    func login(username: String, password: String, rememberMe: Bool) async throws -> AuthResponseDTO {
        let response: AuthResponseDTO = try await api.post(
            "auth/login",
            body: LoginRequestDTO(username: username, password: password)
        )

        applyAuth(response, rememberMe: rememberMe)
        return response
    }

    func refreshIfNeeded() async throws {
        let refreshToken = refreshTokenInMemory ?? tokenStore.readRefreshToken()
        guard let refreshToken else {
            throw APIClientError.unauthorized
        }

        let response: TokenPairDTO = try await api.post(
            "auth/refresh",
            body: RefreshRequestDTO(refreshToken: refreshToken)
        )

        accessTokenInMemory = response.accessToken
        refreshTokenInMemory = response.refreshToken

        // Если токены были в Keychain — обновим
        if tokenStore.readRefreshToken() != nil {
            tokenStore.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                persist: true
            )
        }
    }

    func me() async throws -> UserDTO {
        let token = try await validAccessToken()
        let user: UserDTO = try await api.get("users/me", bearerToken: token)
        currentUser = user
        return user
    }

    func logout() {
        currentUser = nil
        accessTokenInMemory = nil
        refreshTokenInMemory = nil
        tokenStore.clear()
    }

    // MARK: - Helpers

    private func applyAuth(_ response: AuthResponseDTO, rememberMe: Bool) {
        currentUser = response.user
        accessTokenInMemory = response.accessToken
        refreshTokenInMemory = response.refreshToken

        tokenStore.saveTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            persist: rememberMe
        )
    }

    private func validAccessToken() async throws -> String {
        if let token = accessTokenInMemory {
            return token
        }

        if let token = tokenStore.readAccessToken() {
            accessTokenInMemory = token
            refreshTokenInMemory = tokenStore.readRefreshToken()
            return token
        }

        throw APIClientError.unauthorized
    }
}
