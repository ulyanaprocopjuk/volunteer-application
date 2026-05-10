import Foundation

enum UserRole: String, Decodable {
    case admin
    case user
}

struct RegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
}

struct SendVerificationCodeRequest: Encodable {}

struct VerifyEmailRequest: Encodable {
    let code: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case newPassword = "new_password"
    }
}

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case role
    }
}

struct UserResponse: Decodable, Identifiable {
    let id: Int
    let username: String
    let email: String?
    let emailVerified: Bool
    let role: UserRole
    let isActive: Bool
    let isBanned: Bool
    let frozenUntil: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case emailVerified = "email_verified"
        case role
        case isActive = "is_active"
        case isBanned = "is_banned"
        case frozenUntil = "frozen_until"
    }
}

struct ServerErrorResponse: Decodable {
    let detail: String
}
