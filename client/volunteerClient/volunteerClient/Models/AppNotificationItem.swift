import Foundation

struct AppNotificationItem: Identifiable, Decodable, Hashable {
    let id: Int
    let senderName: String
    let message: String
    let createdAt: String
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case senderName = "sender_name"
        case message
        case createdAt = "created_at"
        case isRead = "is_read"
    }

    var formattedDate: String {
        guard let date = Self.isoFormatter.date(from: createdAt) else {
            return createdAt
        }
        return Self.outputFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
