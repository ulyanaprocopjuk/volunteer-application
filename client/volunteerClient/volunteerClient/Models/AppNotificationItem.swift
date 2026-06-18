import Foundation

struct AppNotificationItem: Identifiable, Decodable, Hashable {
    let id: Int
    let senderName: String
    let eventID: String?
    let applicationID: Int?
    let eventTitle: String?
    let applicantName: String?
    let applicationStatus: String?
    let message: String
    let createdAt: String
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case senderName = "sender_name"
        case eventID = "event_id"
        case applicationID = "application_id"
        case eventTitle = "event_title"
        case applicantName = "applicant_name"
        case applicationStatus = "application_status"
        case message
        case createdAt = "created_at"
        case isRead = "is_read"
    }

    var formattedDate: String {
        guard let date = Self.parseDate(from: createdAt) else {
            return createdAt
        }

        if Calendar.current.isDateInToday(date) {
            return "Сегодня, \(Self.timeFormatter.string(from: date))"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера, \(Self.timeFormatter.string(from: date))"
        }

        if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date()) {
            return Self.currentYearFormatter.string(from: date)
        }

        return Self.fullDateFormatter.string(from: date)
    }

    func readCopy() -> AppNotificationItem {
        AppNotificationItem(
            id: id,
            senderName: senderName,
            eventID: eventID,
            applicationID: applicationID,
            eventTitle: eventTitle,
            applicantName: applicantName,
            applicationStatus: applicationStatus,
            message: message,
            createdAt: createdAt,
            isRead: true
        )
    }

    private static func parseDate(from value: String) -> Date? {
        isoFormatterWithFractionalSeconds.date(from: value)
            ?? isoFormatter.date(from: value)
            ?? fallbackFormatter.date(from: value)
    }

    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let currentYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()
}
