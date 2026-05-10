import Foundation

struct AvatarUploadResponse: Decodable {
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

struct ProfileResponse: Decodable, Identifiable, Hashable {
    let id: Int
    let userID: Int?
    let type: String?
    let avatarURL: String?
    let firstName: String?
    let lastName: String?
    let organizationName: String?
    let phone: String?
    let email: String?
    let city: String?
    let country: String?
    let skills: [String]?
    let about: String?
    let rating: Int?
    let isVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id, type, phone, email, city, country, skills, about, rating
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case firstName = "first_name"
        case lastName = "last_name"
        case organizationName = "organization_name"
        case isVerified = "is_verified"
    }
}

struct RatingHistoryItem: Decodable, Identifiable {
    let delta: Int
    let eventTitle: String?
    let createdAt: String

    var id: String { "\(createdAt)-\(delta)" }

    enum CodingKeys: String, CodingKey {
        case delta
        case eventTitle = "event_title"
        case createdAt = "created_at"
    }
}

struct ProfileUpsertRequest: Encodable {
    let type: String
    let avatarURL: String?
    let firstName: String?
    let lastName: String?
    let organizationName: String?
    let phone: String
    let email: String?
    let city: String
    let country: String
    let skills: [String]?
    let about: String?

    enum CodingKeys: String, CodingKey {
        case type, phone, email, city, country, skills, about
        case avatarURL = "avatar_url"
        case firstName = "first_name"
        case lastName = "last_name"
        case organizationName = "organization_name"
    }
}
