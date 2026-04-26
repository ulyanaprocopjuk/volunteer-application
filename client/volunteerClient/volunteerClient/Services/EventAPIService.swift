import Foundation

protocol EventAPIProtocol {
    func uploadEventPhoto(data: Data, token: String?) async throws -> String
    func createEvent(_ request: CreateEventRequest, token: String?) async throws -> EventResponse
    func fetchMyEvents(filter: MyEventsFilter?, token: String?) async throws -> [EventResponse]
}

final class EventAPI: EventAPIProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func uploadEventPhoto(data: Data, token: String?) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/uploads/event-photo"))
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fieldName: "file",
            fileName: "event-photo.jpg",
            mimeType: "image/jpeg",
            data: data
        )

        let (responseData, response) = try await NetworkRequestExecutor.data(for: request, session: session)
        try validate(response: response, data: responseData)

        return try JSONDecoder().decode(EventPhotoUploadResponse.self, from: responseData).photoURL
    }

    func createEvent(_ request: CreateEventRequest, token: String?) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func fetchMyEvents(filter: MyEventsFilter?, token: String?) async throws -> [EventResponse] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/events/my"),
            resolvingAgainstBaseURL: false
        )

        if let filter {
            components?.queryItems = [
                URLQueryItem(name: "filter", value: filter.rawValue)
            ]
        }

        guard let url = components?.url else {
            throw EventAPIError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        if let token, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([EventResponse].self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EventAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw EventAPIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorMessage.self, from: data).message)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw EventAPIError.server(message)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) -> Data {
        let lineBreak = "\r\n"
        var body = Data()
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(data)
        body.append(lineBreak)
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

private struct APIErrorMessage: Decodable {
    let message: String
}

enum EventAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .unauthorized:
            return "Сессия истекла. Повторите вход."
        case .server(let message):
            return message
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
