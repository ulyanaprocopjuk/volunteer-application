import Foundation
import CoreLocation

struct CreateEventRequest: Encodable {
    let title: String
    let description: String
    let country: String
    let city: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startsAt: String
    let endsAt: String?
    let volunteersNeeded: Int
}

struct EventResponse: Decodable {
    let id: String
    let title: String
    let description: String
    let country: String
    let city: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let startsAt: String
    let endsAt: String?
    let volunteersNeeded: Int
    let status: String?
    let message: String?
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
