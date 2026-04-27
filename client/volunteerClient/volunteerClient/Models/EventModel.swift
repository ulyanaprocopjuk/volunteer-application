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
    let status: String?
    let message: String?
    let organizerName: String?
    let createdAt: String?

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
        case status
        case message
        case organizerName
        case createdAt = "created_at"
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

enum MyEventsFilter: String {
    case active
    case history
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
    case completed

    init(rawValue: String?) {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if value.contains("completed")
            || value.contains("заверш") {
            self = .completed
        } else if value.contains("approved")
            || value.contains("confirmed")
            || value.contains("accept")
            || value.contains("active")
            || value.contains("актив")
            || value.contains("published")
            || value.contains("подтверж") {
            self = .approved
        } else if value.contains("reject")
            || value.contains("declin")
            || value.contains("deny")
            || value.contains("cancel")
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
