import Foundation

struct CityCountry: Decodable, Identifiable, Equatable {
    let country: String
    let cities: [String]

    var id: String {
        country
    }
}

enum CityDirectory {
    static let countries: [CityCountry] = loadCountries()

    static var defaultCountry: String {
        countries.first?.country ?? "Беларусь"
    }

    static func cities(for country: String) -> [String] {
        countries.first { $0.country == country }?.cities ?? []
    }

    private static func loadCountries() -> [CityCountry] {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let countries = try? JSONDecoder().decode([CityCountry].self, from: data) else {
            return fallbackCountries
        }

        return countries
    }

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
