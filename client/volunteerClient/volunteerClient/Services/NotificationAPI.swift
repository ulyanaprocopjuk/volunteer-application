import Foundation

protocol NotificationAPIProtocol {
    func fetchNotifications(token: String) async throws -> [AppNotificationItem]
    func clearNotifications(token: String) async throws
}

final class NotificationAPI: NotificationAPIProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchNotifications(token: String) async throws -> [AppNotificationItem] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/notifications"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder().decode([AppNotificationItem].self, from: data)
    }

    func clearNotifications(token: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/notifications"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppNetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AppNetworkError.server(apiError.detail)
            }
            throw AppNetworkError.server("Ошибка сервера: \(httpResponse.statusCode)")
        }
    }
}
