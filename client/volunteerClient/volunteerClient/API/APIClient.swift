import Foundation

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case decodingError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .server(let message):
            return message
        case .decodingError:
            return "Ошибка обработки ответа сервера"
        case .unauthorized:
            return "Требуется авторизация"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // Для iOS Simulator:
    //let baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
    //
    // Для реального iPhone нужно IP компьютера в одной сети, например:
    // http://192.168.1.10:8000/api/v1
    private let baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!

    private let session: URLSession = .shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        bearerToken: String? = nil
    ) async throws -> Response {
        try await request(path, method: "POST", body: body, bearerToken: bearerToken)
    }

    func get<Response: Decodable>(
        _ path: String,
        bearerToken: String? = nil
    ) async throws -> Response {
        try await request(path, method: "GET", body: Optional<Int>.none, bearerToken: bearerToken)
    }

    func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        bearerToken: String? = nil
    ) async throws -> Response {
        try await request(path, method: "PATCH", body: body, bearerToken: bearerToken)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?,
        bearerToken: String?
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIClientError.server(apiError.detail)
            }

            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                throw APIClientError.server(raw)
            }

            throw APIClientError.server("Ошибка сервера (\(http.statusCode))")
        }

        guard let decoded = try? decoder.decode(Response.self, from: data) else {
            throw APIClientError.decodingError
        }

        return decoded
    }
}
