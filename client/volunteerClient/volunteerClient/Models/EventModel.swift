import Foundation
import CoreLocation

struct CreateEventRequest: Encodable {
    let title: String
    let direction: String
    let description: String
    let country: String
    let city: String
    let locationName: String
    let photoURL: String?
    let latitude: Double
    let longitude: Double
    let startsAt: String
    let endsAt: String?
    let volunteersNeeded: Int
}

struct EventResponse: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let direction: String?
    let description: String
    let country: String
    let city: String
    let locationName: String
    let photoURL: String?
    let latitude: Double
    let longitude: Double
    let startsAt: String
    let endsAt: String?
    let volunteersNeeded: Int
    let acceptedCount: Int?
    let userApplicationStatus: String?
    let isCreator: Bool?
    let status: String?
    let message: String?
    let organizerName: String?
    let createdAt: String?
    let presentCount: Int?
    let groupCount: Int?

    init(
        id: String,
        title: String,
        direction: String?,
        description: String,
        country: String,
        city: String,
        locationName: String,
        photoURL: String?,
        latitude: Double,
        longitude: Double,
        startsAt: String,
        endsAt: String?,
        volunteersNeeded: Int,
        acceptedCount: Int? = nil,
        userApplicationStatus: String? = nil,
        isCreator: Bool? = nil,
        status: String?,
        message: String?,
        organizerName: String?,
        createdAt: String?,
        presentCount: Int? = nil,
        groupCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.direction = direction
        self.description = description
        self.country = country
        self.city = city
        self.locationName = locationName
        self.photoURL = photoURL
        self.latitude = latitude
        self.longitude = longitude
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.volunteersNeeded = volunteersNeeded
        self.acceptedCount = acceptedCount
        self.userApplicationStatus = userApplicationStatus
        self.isCreator = isCreator
        self.status = status
        self.message = message
        self.organizerName = organizerName
        self.createdAt = createdAt
        self.presentCount = presentCount
        self.groupCount = groupCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case direction
        case description
        case country
        case city
        case locationName
        case photoURL
        case latitude
        case longitude
        case startsAt
        case endsAt
        case volunteersNeeded
        case acceptedCount = "accepted_count"
        case userApplicationStatus = "user_application_status"
        case isCreator = "is_creator"
        case status
        case message
        case organizerName
        case createdAt = "created_at"
        case presentCount = "present_count"
        case groupCount = "group_count"
    }
}

enum EventDirectionOption: String, CaseIterable, Identifiable {
    case animals = "Животные"
    case ecology = "Экология"
    case elderly = "Пожилые люди"
    case children = "Дети и подростки"
    case disability = "Люди с инвалидностью"
    case humanitarian = "Гуманитарная помощь"
    case education = "Образование"
    case medicine = "Медицина и здоровье"
    case culture = "Культура и мероприятия"
    case social = "Социальная помощь"

    var id: String { rawValue }
}

struct EventPhotoUploadResponse: Decodable {
    let photoURL: String

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
    }
}

struct EventParticipantResponse: Decodable, Identifiable, Hashable {
    let applicationID: Int
    let eventID: String
    let eventTitle: String
    let status: String
    let isCreator: Bool
    let profile: ProfileResponse

    var id: Int {
        applicationID
    }

    var applicationStatus: EventApplicationDisplayStatus {
        EventApplicationDisplayStatus(rawValue: status) ?? .pending
    }

    enum CodingKeys: String, CodingKey {
        case applicationID = "application_id"
        case eventID = "event_id"
        case eventTitle = "event_title"
        case status
        case isCreator = "is_creator"
        case profile
    }
}

enum EventApplicationDisplayStatus: String {
    case pending
    case accepted
    case rejected
    case cancelled

    var title: String {
        switch self {
        case .pending:
            return "Ожидает решения"
        case .accepted:
            return "Принята"
        case .rejected:
            return "Отклонена"
        case .cancelled:
            return "Удалён"
        }
    }
}

struct AttendanceItem: Decodable, Identifiable {
    let applicationID: Int
    let isPresent: Bool
    let profile: ProfileResponse

    var id: Int { applicationID }

    enum CodingKeys: String, CodingKey {
        case applicationID = "application_id"
        case isPresent = "is_present"
        case profile
    }
}

struct ConfirmAttendanceRequest: Encodable {
    let presentApplicationIDs: [Int]
}

struct RemoveEventParticipantRequest: Encodable {
    let reason: String
}

struct ChatMessage: Decodable, Identifiable, Hashable {
    let id: Int
    let eventID: String
    let senderProfileID: Int
    let content: String?
    let photoURL: String?
    let createdAt: String
    let isOrganizer: Bool
    let isLeader: Bool?
    let leaderLabel: String?
    let profile: ProfileResponse

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case senderProfileID = "sender_profile_id"
        case content
        case photoURL = "photo_url"
        case createdAt = "created_at"
        case isOrganizer = "is_organizer"
        case isLeader = "is_leader"
        case leaderLabel = "leader_label"
        case profile
    }
}

struct ChatRoom: Decodable, Identifiable, Hashable {
    let id: Int
    let eventID: String
    let type: String
    let groupNumber: Int?
    let title: String

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case type
        case groupNumber = "group_number"
        case title
    }
}

struct GroupMember: Decodable, Identifiable, Hashable {
    let profileID: Int
    let role: String
    let profile: ProfileResponse

    var id: Int { profileID }

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case role
        case profile
    }
}

struct EventGroup: Decodable, Identifiable, Hashable {
    let id: Int
    let eventID: String
    let groupNumber: Int
    let leaderID: Int?
    let leader: ProfileResponse?
    let members: [GroupMember]

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case groupNumber = "group_number"
        case leaderID = "leader_id"
        case leader
        case members
    }
}

enum MyEventsFilter: String {
    case active
    case history
}

enum EventFeedTimeFilter: String, CaseIterable, Identifiable {
    case any
    case today
    case tomorrow
    case weekend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any:
            return "Любое время"
        case .today:
            return "Сегодня"
        case .tomorrow:
            return "Завтра"
        case .weekend:
            return "Выходные"
        }
    }
}

struct EventFeedFilters {
    var direction: String?
    var time: EventFeedTimeFilter
    var country: String?
    var city: String?

    static let empty = EventFeedFilters(
        direction: nil,
        time: .any,
        country: nil,
        city: nil
    )
}

struct CurrentCountryEventResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let latitude: Double
    let longitude: Double
    let address: String?
}

struct EventLocationSelection {
    let title: String
    let address: String
    let country: String
    let city: String
    let coordinate: CLLocationCoordinate2D
}

struct GeocodingSuggestion: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let fullAddress: String
    let coordinate: CLLocationCoordinate2D
    let precision: String
    let country: String
    let city: String

    var selection: EventLocationSelection {
        EventLocationSelection(
            title: title,
            address: fullAddress,
            country: country,
            city: city,
            coordinate: coordinate
        )
    }
}

struct EventLocationContext {
    let country: String
    let city: String
    let countrySearchArea: CountrySearchArea
    let cityCoordinate: CLLocationCoordinate2D
}

enum EventModerationStatus {
    case pending
    case approved
    case rejected
    case cancelled
    case completed

    init(rawValue: String?) {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if value.contains("completed")
            || value.contains("заверш") {
            self = .completed
        } else if value.contains("cancel")
            || value.contains("отмен") {
            self = .cancelled
        } else if value.contains("approved")
            || value.contains("confirmed")
            || value.contains("accept")
            || value.contains("active")
            || value.contains("attendance")
            || value.contains("grouping")
            || value.contains("актив")
            || value.contains("published")
            || value.contains("подтверж") {
            self = .approved
        } else if value.contains("reject")
            || value.contains("declin")
            || value.contains("deny")
            || value.contains("отклон") {
            self = .rejected
        } else if value.contains("pending")
            || value.contains("ожида") {
            self = .pending
        } else {
            self = .pending
        }
    }
}
