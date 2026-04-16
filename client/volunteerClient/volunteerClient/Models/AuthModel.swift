import Foundation

enum UserRole: String, Decodable {
    case admin
    case user
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case role
    }
}

struct UserResponse: Decodable, Identifiable {
    let id: Int
    let username: String
    let role: UserRole
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case isActive = "is_active"
    }
}

struct ServerErrorResponse: Decodable {
    let detail: String
}
