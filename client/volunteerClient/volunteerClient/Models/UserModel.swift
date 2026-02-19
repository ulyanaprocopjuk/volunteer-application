import Foundation

enum UserRole: String, Codable {
    case volunteer, organizer, admin
}

struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole
}
