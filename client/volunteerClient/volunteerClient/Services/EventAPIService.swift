import Foundation

protocol EventAPIProtocol {
    func createEvent(_ request: CreateEventRequest, token: String?) async throws -> EventResponse
    func fetchMyEvents(token: String?) async throws -> [EventResponse]
}

final class EventAPI: EventAPIProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func createEvent(_ request: CreateEventRequest, token: String?) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func fetchMyEvents(token: String?) async throws -> [EventResponse] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/my"))
        urlRequest.httpMethod = "GET"

        if let token, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([EventResponse].self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EventAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorMessage.self, from: data).message)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw EventAPIError.server(message)
        }
    }
}

private struct APIErrorMessage: Decodable {
    let message: String
}

enum EventAPIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .server(let message):
            return message
        }
    }
}
