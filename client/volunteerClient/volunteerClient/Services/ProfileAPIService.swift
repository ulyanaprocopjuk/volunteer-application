import Foundation

protocol ProfileAPIProtocol {
    func uploadAvatar(data: Data, token: String?) async throws -> String
    func saveProfile(_ requestModel: ProfileUpsertRequest, token: String?) async throws
    func fetchMyProfile(token: String?) async throws -> ProfileResponse
}

final class ProfileAPI: ProfileAPIProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func uploadAvatar(data: Data, token: String?) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/uploads/avatar"))
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        addAuthorization(token, to: &request)

        let body = makeMultipartBody(
            boundary: boundary,
            fieldName: "file",
            fileName: "avatar.jpg",
            mimeType: "image/jpeg",
            data: data
        )

        let (responseData, response) = try await session.upload(for: request, from: body)
        try validate(response: response, data: responseData)
        let decoded = try JSONDecoder().decode(AvatarUploadResponse.self, from: responseData)
        return decoded.avatarURL
    }

    func saveProfile(_ requestModel: ProfileUpsertRequest, token: String?) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/profile"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthorization(token, to: &request)
        request.httpBody = try JSONEncoder().encode(requestModel)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func fetchMyProfile(token: String?) async throws -> ProfileResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/profile/me"))
        request.httpMethod = "GET"
        addAuthorization(token, to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }

    private func addAuthorization(_ token: String?, to request: inout URLRequest) {
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

struct APIErrorResponse: Decodable {
    let detail: String
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
