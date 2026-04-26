import Foundation
import CoreLocation

protocol GeocodingAPIProtocol {
    func forwardGeocode(query: String, context: EventLocationContext) async throws -> [GeocodingSuggestion]
    func reverseGeocode(coordinate: CLLocationCoordinate2D, context: EventLocationContext) async throws -> EventLocationSelection?
    func geocodeCity(city: String, country: String, area: CountrySearchArea) async throws -> CLLocationCoordinate2D?
}

final class GeocodingAPI: GeocodingAPIProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func forwardGeocode(query: String, context: EventLocationContext) async throws -> [GeocodingSuggestion] {
        let trimmedQuery = trim(query)
        guard !trimmedQuery.isEmpty else { return [] }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/geocode/forward"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery)
        ]

        let response: ForwardGeocodeResponse = try await performRequest(components)
        if let responseCountry = response.country,
           !responseCountry.isEmpty,
           !matchesExpectedCountry(responseCountry, expectedCountry: context.country) {
            return []
        }

        return (response.items ?? []).compactMap { item in
            makeSuggestion(from: item, fallbackCountry: context.country, fallbackCity: context.city)
        }
    }

    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        context: EventLocationContext
    ) async throws -> EventLocationSelection? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/geocode/reverse"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude))
        ]

        let response: ReverseGeocodeResponse = try await performRequest(components)
        guard let item = response.item else { return nil }
        guard let suggestion = makeSuggestion(
            from: item,
            fallbackCountry: context.country,
            fallbackCity: context.city
        ) else {
            return nil
        }
        guard matchesExpectedCountry(suggestion.country, expectedCountry: context.country) else {
            return nil
        }

        return suggestion.selection
    }

    func geocodeCity(city: String, country: String, area: CountrySearchArea) async throws -> CLLocationCoordinate2D? {
        let context = EventLocationContext(
            country: country,
            city: city,
            countrySearchArea: area,
            cityCoordinate: area.center
        )
        let suggestions = try await forwardGeocode(query: "\(city), \(country)", context: context)
        return suggestions.first?.coordinate
    }

    private func performRequest<T: Decodable>(_ components: URLComponents?) async throws -> T {
        guard let url = components?.url else {
            throw AppNetworkError.invalidBaseURL
        }

        let (data, response) = try await NetworkRequestExecutor.data(from: url, session: session)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppNetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AppNetworkError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AppNetworkError.server(apiError.detail)
            }
            throw AppNetworkError.server("Ошибка сервера: \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppNetworkError.decoding
        }
    }

    private func makeSuggestion(
        from item: GeocodingItemDTO,
        fallbackCountry: String,
        fallbackCity: String
    ) -> GeocodingSuggestion? {
        guard let latitude = item.latitude,
              let longitude = item.longitude else {
            return nil
        }

        let title = trim(item.title ?? "")
        let fullAddress = trim(item.fullAddress ?? "")
        guard !title.isEmpty, !fullAddress.isEmpty else { return nil }

        let country = inferCountry(
            from: [item.subtitle ?? "", item.fullAddress ?? "", item.title ?? ""],
            fallbackCountry: fallbackCountry
        )
        let city = inferCity(
            from: [item.subtitle ?? "", item.fullAddress ?? "", item.title ?? ""],
            country: country,
            fallbackCity: fallbackCity
        )

        return GeocodingSuggestion(
            id: "\(latitude)|\(longitude)|\(fullAddress)",
            title: title,
            subtitle: trim(item.subtitle ?? ""),
            fullAddress: fullAddress,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            precision: trim(item.precision ?? ""),
            country: country,
            city: city
        )
    }

    private func inferCountry(from textParts: [String], fallbackCountry: String) -> String {
        let joined = normalize(textParts.joined(separator: ", "))

        if let matched = CityDirectory.countries.first(where: { joined.contains(normalize($0.country)) }) {
            return matched.country
        }

        return CityDirectory.canonicalCountryName(for: fallbackCountry)
    }

    private func inferCity(
        from textParts: [String],
        country: String,
        fallbackCity: String
    ) -> String {
        let addressParts = textParts
            .flatMap { $0.split(separator: ",") }
            .map { trim(String($0)) }
            .filter { !$0.isEmpty }

        let normalizedParts = addressParts.map(normalize)
        if let matched = CityDirectory.cities(for: country).first(where: { city in
            normalizedParts.contains(normalize(city))
        }) {
            return matched
        }

        if let firstSubtitlePart = addressParts.first,
           !firstSubtitlePart.isEmpty,
           CityDirectory.canonicalCountryName(for: firstSubtitlePart) != CityDirectory.canonicalCountryName(for: country) {
            return firstSubtitlePart
        }

        return fallbackCity
    }

    private func matchesExpectedCountry(_ responseCountry: String, expectedCountry: String) -> Bool {
        let expectedCode = CityDirectory.countryCode(for: expectedCountry)?.uppercased()
        let normalizedResponse = trim(responseCountry).uppercased()

        if let expectedCode, !normalizedResponse.isEmpty {
            if normalizedResponse.count == 2 {
                return normalizedResponse == expectedCode
            }

            if let responseCode = CityDirectory.countryCode(for: responseCountry)?.uppercased() {
                return responseCode == expectedCode
            }
        }

        if let responseCountryName = CityDirectory.countryName(forCode: responseCountry) {
            return responseCountryName == CityDirectory.canonicalCountryName(for: expectedCountry)
        }

        return CityDirectory.canonicalCountryName(for: responseCountry) == CityDirectory.canonicalCountryName(for: expectedCountry)
    }

    private func normalize(_ value: String) -> String {
        trim(value)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ForwardGeocodeResponse: Decodable {
    let query: String?
    let country: String?
    let items: [GeocodingItemDTO]?
}

private struct ReverseGeocodeResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let item: GeocodingItemDTO?
}

private struct GeocodingItemDTO: Decodable {
    let title: String?
    let subtitle: String?
    let fullAddress: String?
    let latitude: Double?
    let longitude: Double?
    let precision: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case fullAddress
        case latitude
        case longitude
        case precision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        fullAddress = try container.decodeIfPresent(String.self, forKey: .fullAddress)
        latitude = try Self.decodeFlexibleDouble(forKey: .latitude, from: container)
        longitude = try Self.decodeFlexibleDouble(forKey: .longitude, from: container)
        precision = try container.decodeIfPresent(String.self, forKey: .precision)
    }

    private static func decodeFlexibleDouble(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Double? {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue.replacingOccurrences(of: ",", with: "."))
        }

        return nil
    }
}
