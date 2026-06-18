import Foundation
import CoreLocation

struct CityCountry: Decodable, Identifiable, Equatable {
    let country: String
    let cities: [String]

    var id: String { country }
}

struct CountrySearchArea {
    let center: CLLocationCoordinate2D
    let span: CLLocationCoordinate2D
}

enum CityDirectory {
    static let countries: [CityCountry] = loadCountries()

    static var defaultCountry: String {
        countries.first?.country ?? "Беларусь"
    }

    static func cities(for country: String) -> [String] {
        countries.first { normalize($0.country) == normalize(country) }?.cities ?? []
    }

    static func isSupported(country: String) -> Bool {
        countryCode(for: country) != nil
    }

    static func isSupported(city: String, in country: String) -> Bool {
        let normalizedCity = normalize(city)
        return cities(for: country).contains { normalize($0) == normalizedCity }
    }

    static func countryCode(for country: String) -> String? {
        countryCodeMap[normalize(country)]
    }

    static func countryName(forCode code: String) -> String? {
        codeToCountryMap[normalize(code)]
    }

    static func canonicalCountryName(for country: String) -> String {
        countries.first { normalize($0.country) == normalize(country) }?.country ?? country
    }

    static func searchArea(for country: String) -> CountrySearchArea {
        countrySearchAreaMap[normalize(country)] ?? CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 53.9006, longitude: 27.5590),
            span: CLLocationCoordinate2D(latitude: 8.0, longitude: 8.0)
        )
    }

    private static func loadCountries() -> [CityCountry] {
        guard
            let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let countries = try? JSONDecoder().decode([CityCountry].self, from: data)
        else {
            return fallbackCountries
        }

        return countries
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static let countryCodeMap: [String: String] = [
        "беларусь": "BY",
        "белоруссия": "BY",
        "россия": "RU",
        "рф": "RU",
        "казахстан": "KZ",
        "армения": "AM",
        "азербайджан": "AZ",
        "кыргызстан": "KG",
        "киргизия": "KG",
        "молдова": "MD",
        "молдавия": "MD",
        "таджикистан": "TJ",
        "туркменистан": "TM",
        "узбекистан": "UZ"
    ]

    private static let codeToCountryMap: [String: String] = [
        "by": "Беларусь",
        "ru": "Россия",
        "kz": "Казахстан",
        "am": "Армения",
        "az": "Азербайджан",
        "kg": "Кыргызстан",
        "md": "Молдова",
        "tj": "Таджикистан",
        "tm": "Туркменистан",
        "uz": "Узбекистан"
    ]

    private static let countrySearchAreaMap: [String: CountrySearchArea] = [
        "беларусь": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 53.7098, longitude: 27.9534),
            span: CLLocationCoordinate2D(latitude: 4.9, longitude: 10.2)
        ),
        "белоруссия": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 53.7098, longitude: 27.9534),
            span: CLLocationCoordinate2D(latitude: 4.9, longitude: 10.2)
        ),
        "россия": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 61.5240, longitude: 105.3188),
            span: CLLocationCoordinate2D(latitude: 43.0, longitude: 150.0)
        ),
        "рф": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 61.5240, longitude: 105.3188),
            span: CLLocationCoordinate2D(latitude: 43.0, longitude: 150.0)
        ),
        "казахстан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 48.0196, longitude: 66.9237),
            span: CLLocationCoordinate2D(latitude: 21.0, longitude: 33.0)
        ),
        "армения": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 40.0691, longitude: 45.0382),
            span: CLLocationCoordinate2D(latitude: 2.2, longitude: 3.9)
        ),
        "азербайджан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 40.1431, longitude: 47.5769),
            span: CLLocationCoordinate2D(latitude: 5.6, longitude: 8.6)
        ),
        "кыргызстан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 41.2044, longitude: 74.7661),
            span: CLLocationCoordinate2D(latitude: 5.8, longitude: 9.6)
        ),
        "киргизия": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 41.2044, longitude: 74.7661),
            span: CLLocationCoordinate2D(latitude: 5.8, longitude: 9.6)
        ),
        "молдова": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 47.4116, longitude: 28.3699),
            span: CLLocationCoordinate2D(latitude: 3.2, longitude: 5.2)
        ),
        "молдавия": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 47.4116, longitude: 28.3699),
            span: CLLocationCoordinate2D(latitude: 3.2, longitude: 5.2)
        ),
        "таджикистан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 38.8610, longitude: 71.2761),
            span: CLLocationCoordinate2D(latitude: 4.8, longitude: 9.4)
        ),
        "туркменистан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 38.9697, longitude: 59.5563),
            span: CLLocationCoordinate2D(latitude: 9.6, longitude: 13.4)
        ),
        "узбекистан": CountrySearchArea(
            center: CLLocationCoordinate2D(latitude: 41.3775, longitude: 64.5853),
            span: CLLocationCoordinate2D(latitude: 8.5, longitude: 17.8)
        )
    ]

    private static let fallbackCountries: [CityCountry] = [
        CityCountry(country: "Беларусь", cities: ["Минск", "Гомель", "Могилев", "Витебск", "Гродно", "Брест"]),
        CityCountry(country: "Россия", cities: ["Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань"]),
        CityCountry(country: "Казахстан", cities: ["Астана", "Алматы", "Шымкент", "Караганда", "Актобе"]),
        CityCountry(country: "Армения", cities: ["Ереван", "Гюмри", "Ванадзор"]),
        CityCountry(country: "Азербайджан", cities: ["Баку", "Гянджа", "Сумгаит"]),
        CityCountry(country: "Кыргызстан", cities: ["Бишкек", "Ош", "Джалал-Абад"]),
        CityCountry(country: "Молдова", cities: ["Кишинев", "Бельцы", "Тирасполь"]),
        CityCountry(country: "Таджикистан", cities: ["Душанбе", "Худжанд", "Бохтар"]),
        CityCountry(country: "Туркменистан", cities: ["Ашхабад", "Туркменабад", "Дашогуз"]),
        CityCountry(country: "Узбекистан", cities: ["Ташкент", "Самарканд", "Бухара", "Наманган", "Андижан"])
    ]
}
