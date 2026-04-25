import Foundation

protocol AuthAPIProtocol {
    func register(username: String, password: String) async throws -> UserResponse
    func login(username: String, password: String) async throws -> TokenResponse
    func refresh(refreshToken: String) async throws -> TokenResponse
    func logout(refreshToken: String) async throws
    func getCurrentUser(token: String) async throws -> UserResponse
    func getAllUsersForAdmin(token: String) async throws -> [UserResponse]
}

enum AppNetworkError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case unauthorized
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Некорректный base URL"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .unauthorized:
            return "Сессия истекла. Повторите вход."
        case .server(let message):
            return message
        case .decoding:
            return "Ошибка декодирования ответа"
        }
    }
}

final class AuthAPI: AuthAPIProtocol {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let session: URLSession
    private let baseURLString: String

    init(
        baseURLString: String = AppConfig.baseURLString,
        session: URLSession = .shared
    ) {
        self.baseURLString = baseURLString
        self.session = session
    }

    func register(username: String, password: String) async throws -> UserResponse {
        let body = RegisterRequest(username: username, password: password)
        return try await performRequest(
            path: "/auth/register",
            method: "POST",
            body: encoder.encode(body),
            token: nil,
            responseType: UserResponse.self
        )
    }

    func login(username: String, password: String) async throws -> TokenResponse {
        let body = LoginRequest(username: username, password: password)
        return try await performRequest(
            path: "/auth/login",
            method: "POST",
            body: encoder.encode(body),
            token: nil,
            responseType: TokenResponse.self
        )
    }

    func refresh(refreshToken: String) async throws -> TokenResponse {
        let body = RefreshRequest(refreshToken: refreshToken)
        return try await performRequest(
            path: "/auth/refresh",
            method: "POST",
            body: encoder.encode(body),
            token: nil,
            responseType: TokenResponse.self
        )
    }

    func logout(refreshToken: String) async throws {
        let body = RefreshRequest(refreshToken: refreshToken)
        _ = try await performRequest(
            path: "/auth/logout",
            method: "POST",
            body: encoder.encode(body),
            token: nil,
            responseType: EmptyResponse.self
        )
    }

    func getCurrentUser(token: String) async throws -> UserResponse {
        try await performRequest(
            path: "/users/me",
            method: "GET",
            body: nil,
            token: token,
            responseType: UserResponse.self
        )
    }

    func getAllUsersForAdmin(token: String) async throws -> [UserResponse] {
        try await performRequest(
            path: "/admin/users",
            method: "GET",
            body: nil,
            token: token,
            responseType: [UserResponse].self
        )
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        token: String?,
        responseType: Response.Type
    ) async throws -> Response {
        guard let baseURL = URL(string: baseURLString) else {
            throw AppNetworkError.invalidBaseURL
        }

        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appendingPathComponent(cleanPath)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        let (data, response) = try await NetworkRequestExecutor.data(for: request, session: session)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppNetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AppNetworkError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = try? decoder.decode(ServerErrorResponse.self, from: data)
            throw AppNetworkError.server(
                serverMessage?.detail ?? "Ошибка сервера: \(httpResponse.statusCode)"
            )
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw AppNetworkError.decoding
        }
    }
}

private struct EmptyResponse: Decodable {}
