import Foundation

enum UserRole: String, Codable {
    case admin
    case volunteer
    case organizer
}

struct UserDTO: Codable {
    let id: Int
    let username: String
    let role: UserRole
    let isActive: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, username, role
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct AuthResponseDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

struct TokenPairDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct RegisterRequestDTO: Codable {
    let username: String
    let password: String
}

struct LoginRequestDTO: Codable {
    let username: String
    let password: String
}

struct RefreshRequestDTO: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct APIErrorResponse: Codable {
    let detail: String
}
