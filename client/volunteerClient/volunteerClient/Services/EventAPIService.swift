import Foundation

protocol EventAPIProtocol {
    func uploadEventPhoto(data: Data, token: String?) async throws -> String
    func createEvent(_ request: CreateEventRequest, token: String?) async throws -> EventResponse
    func fetchMyEvents(filter: MyEventsFilter?, token: String?) async throws -> [EventResponse]
    func fetchEvent(id: String, token: String?) async throws -> EventResponse
    func applyToEvent(id: String, token: String) async throws -> EventResponse
    func cancelApplication(eventID: String, token: String) async throws -> EventResponse
    func deleteEvent(id: String, token: String) async throws
    func startEvent(id: String, token: String) async throws -> EventResponse
    func cancelEvent(id: String, reason: String, token: String) async throws -> EventResponse
    func acceptApplication(id: Int, token: String) async throws -> EventResponse
    func rejectApplication(id: Int, token: String) async throws -> EventResponse
    func fetchEventApplications(eventID: String, token: String) async throws -> [EventParticipantResponse]
    func removeParticipant(applicationID: Int, reason: String, token: String) async throws -> EventResponse
    func fetchEventFeed(searchText: String?, token: String?) async throws -> [EventResponse]
    func fetchEventFeed(searchText: String?, filters: EventFeedFilters, token: String?) async throws -> [EventResponse]
    func fetchAttendance(eventID: String, token: String) async throws -> [AttendanceItem]
    func confirmAttendance(eventID: String, presentApplicationIDs: [Int], token: String) async throws -> EventResponse
    func saveGroupCountDraft(eventID: String, groupCount: Int, token: String) async throws -> EventResponse
    func confirmGrouping(eventID: String, groupCount: Int, token: String) async throws -> EventResponse
    func fetchGroups(eventID: String, token: String) async throws -> [EventGroup]
    func autoDistribute(eventID: String, token: String) async throws -> [EventGroup]
    func setGroupLeader(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup
    func removeGroupLeader(eventID: String, groupNumber: Int, token: String) async throws -> EventGroup
    func addGroupMember(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup
    func removeGroupMember(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup
    func confirmGroups(eventID: String, token: String) async throws -> EventResponse
    func addGroup(eventID: String, token: String) async throws -> EventGroup
    func deleteGroup(eventID: String, groupNumber: Int, token: String) async throws
    func fetchMessages(eventID: String, token: String) async throws -> [ChatMessage]
    func sendMessage(eventID: String, content: String?, photoURL: String?, token: String) async throws -> ChatMessage
    func uploadMessagePhoto(data: Data, token: String) async throws -> String
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

    func fetchEvent(id: String, token: String?) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(id)"))
        urlRequest.httpMethod = "GET"

        if let token, !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func applyToEvent(id: String, token: String) async throws -> EventResponse {
        try await postEventAction(path: "api/events/\(id)/applications", token: token)
    }

    func cancelApplication(eventID: String, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/applications"))
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func deleteEvent(id: String, token: String) async throws {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(id)"))
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
    }

    func startEvent(id: String, token: String) async throws -> EventResponse {
        try await postEventAction(path: "api/events/\(id)/start", token: token)
    }

    func cancelEvent(id: String, reason: String, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(id)/cancel"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(["reason": reason])

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func acceptApplication(id: Int, token: String) async throws -> EventResponse {
        try await postEventAction(path: "api/events/applications/\(id)/accept", token: token)
    }

    func rejectApplication(id: Int, token: String) async throws -> EventResponse {
        try await postEventAction(path: "api/events/applications/\(id)/reject", token: token)
    }

    func fetchEventApplications(eventID: String, token: String) async throws -> [EventParticipantResponse] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/applications"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([EventParticipantResponse].self, from: data)
    }

    func removeParticipant(applicationID: Int, reason: String, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/applications/\(applicationID)/remove"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(RemoveEventParticipantRequest(reason: reason))

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func fetchEventFeed(searchText: String?, token: String?) async throws -> [EventResponse] {
        try await fetchEventFeed(searchText: searchText, filters: .empty, token: token)
    }

    func fetchEventFeed(searchText: String?, filters: EventFeedFilters, token: String?) async throws -> [EventResponse] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/events/feed"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = []
        let query = searchText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        if let direction = filters.direction?.trimmingCharacters(in: .whitespacesAndNewlines),
           !direction.isEmpty {
            queryItems.append(URLQueryItem(name: "direction", value: direction))
        }

        if filters.time != .any {
            queryItems.append(URLQueryItem(name: "when", value: filters.time.rawValue))
        }

        if let country = filters.country?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }

        if let city = filters.city?.trimmingCharacters(in: .whitespacesAndNewlines),
           !city.isEmpty {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
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

    func fetchAttendance(eventID: String, token: String) async throws -> [AttendanceItem] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/attendance"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([AttendanceItem].self, from: data)
    }

    func confirmAttendance(eventID: String, presentApplicationIDs: [Int], token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/attendance/confirm"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(ConfirmAttendanceRequest(presentApplicationIDs: presentApplicationIDs))

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func saveGroupCountDraft(eventID: String, groupCount: Int, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/grouping"))
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(["groupCount": groupCount])

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func confirmGrouping(eventID: String, groupCount: Int, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/grouping/confirm"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(["groupCount": groupCount])

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func fetchGroups(eventID: String, token: String) async throws -> [EventGroup] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([EventGroup].self, from: data)
    }

    func autoDistribute(eventID: String, token: String) async throws -> [EventGroup] {
        try await postGroupAction(path: "api/events/\(eventID)/groups/auto", token: token)
    }

    func setGroupLeader(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/\(groupNumber)/leader"))
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(["profileID": profileID])

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventGroup.self, from: data)
    }

    func removeGroupLeader(eventID: String, groupNumber: Int, token: String) async throws -> EventGroup {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/\(groupNumber)/leader"))
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventGroup.self, from: data)
    }

    func addGroupMember(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/\(groupNumber)/members"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(["profileID": profileID])

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventGroup.self, from: data)
    }

    func removeGroupMember(eventID: String, groupNumber: Int, profileID: Int, token: String) async throws -> EventGroup {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/\(groupNumber)/members/\(profileID)"))
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventGroup.self, from: data)
    }

    func confirmGroups(eventID: String, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/confirm"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }

    func addGroup(eventID: String, token: String) async throws -> EventGroup {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventGroup.self, from: data)
    }

    func deleteGroup(eventID: String, groupNumber: Int, token: String) async throws {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/groups/\(groupNumber)"))
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
    }

    func fetchMessages(eventID: String, token: String) async throws -> [ChatMessage] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/messages"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([ChatMessage].self, from: data)
    }

    func sendMessage(eventID: String, content: String?, photoURL: String?, token: String) async throws -> ChatMessage {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/events/\(eventID)/messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: String] = [:]
        if let content { body["content"] = content }
        if let photoURL { body["photoURL"] = photoURL }
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ChatMessage.self, from: data)
    }

    func uploadMessagePhoto(data: Data, token: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/uploads/message-photo"))
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fieldName: "file",
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            data: data
        )

        let (responseData, response) = try await NetworkRequestExecutor.data(for: request, session: session)
        try validate(response: response, data: responseData)
        guard let url = try? JSONDecoder().decode([String: String].self, from: responseData)["photo_url"] else {
            throw EventAPIError.invalidResponse
        }
        return url
    }

    private func postGroupAction(path: String, token: String) async throws -> [EventGroup] {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([EventGroup].self, from: data)
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

    private func postEventAction(path: String, token: String) async throws -> EventResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await NetworkRequestExecutor.data(for: urlRequest, session: session)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(EventResponse.self, from: data)
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
