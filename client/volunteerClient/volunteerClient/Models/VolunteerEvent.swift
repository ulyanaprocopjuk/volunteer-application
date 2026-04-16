import Foundation

struct VolunteerEvent: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let status: EventStatus
    let priority: EventPriority
    let description: String
    let location: String
    let startDate: Date
    let endDate: Date
    let durationHours: Int
    let organizerName: String
    let publishedAt: Date
    let currentVolunteers: Int
    let neededVolunteers: Int
    let imageName: String?
}

enum EventStatus: String, Codable, CaseIterable, Hashable {
    case open
    case closed
    case inProgress

    var title: String {
        switch self {
        case .open:
            return "Open"
        case .closed:
            return "Closed"
        case .inProgress:
            return "In Progress"
        }
    }
}

enum EventPriority: String, Codable, CaseIterable, Hashable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

extension VolunteerEvent {
    var volunteersProgress: Double {
        guard neededVolunteers > 0 else { return 0 }
        return Double(currentVolunteers) / Double(neededVolunteers)
    }

    var dateRangeText: String {
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return startDate.dayMonthYearShort
        } else {
            return "\(startDate.dayMonthShort) - \(endDate.dayMonthYearShort)"
        }
    }

    var timeAndDurationText: String {
        "\(startDate.timeShort) - \(durationHours) Hour(s)"
    }

    var publishedAtText: String {
        publishedAt.dayMonthYearShort
    }

    var volunteersNeededText: String {
        "\(currentVolunteers)/\(neededVolunteers) Volunteers Needed"
    }
}
