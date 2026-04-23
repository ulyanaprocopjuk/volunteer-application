import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class EventViewModel: ObservableObject {
    @Published var eventTitle = ""
    @Published var eventDescription = ""

    @Published var locationText = ""
    @Published var selectedCoordinate: CLLocationCoordinate2D?

    @Published var startDate: Date?
    @Published var startTime: Date?

    @Published var endDate: Date?
    @Published var endTime: Date?

    @Published var volunteersCount: Int = 1
    @Published var volunteersManualInput: String = "1"

    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var canSubmit: Bool {
        !trim(eventTitle).isEmpty &&
        !trim(eventDescription).isEmpty &&
        selectedCoordinate != nil &&
        !trim(locationText).isEmpty &&
        startDate != nil &&
        startTime != nil &&
        !trim(volunteersManualInput).isEmpty &&
        volunteersInputIsValid &&
        endError == nil
    }

    var locationPlaceholder: String {
        "Выберите местоположение"
    }

    var formattedStartText: String {
        guard let startDate, let startTime else {
            return "Выберите начало события"
        }
        return Self.dateTimeFormatter.string(from: combine(day: startDate, time: startTime))
    }

    var formattedEndText: String {
        guard let endDate else {
            return "Выберите конец события"
        }

        if let endTime {
            return Self.dateTimeFormatter.string(from: combine(day: endDate, time: endTime))
        } else {
            return Self.dateFormatter.string(from: endDate)
        }
    }

    var calculatedDurationMinutes: Int? {
        guard
            let startDate,
            let startTime,
            let endDate,
            let endTime
        else {
            return nil
        }

        let startDateTime = combine(day: startDate, time: startTime)
        let endDateTime = combine(day: endDate, time: endTime)

        guard endDateTime > startDateTime else {
            return nil
        }

        return Int(endDateTime.timeIntervalSince(startDateTime) / 60)
    }

    var calculatedDurationDisplay: String {
        guard let calculatedDurationMinutes else {
            return "—"
        }
        return Self.formatDuration(minutes: calculatedDurationMinutes)
    }

    var locationError: String? {
        return nil
    }

    var startError: String? {
        return nil
    }

    var endError: String? {
        guard let endDate else {
            return nil
        }

        if let startDate, endDate < stripTime(from: startDate) {
            return "Дата окончания не может быть раньше даты начала"
        }

        if let startDate, let startTime, let endTime {
            let startDateTime = combine(day: startDate, time: startTime)
            let endDateTime = combine(day: endDate, time: endTime)

            if endDateTime <= startDateTime {
                return "Конец события должен быть позже начала"
            }
        }

        return nil
    }

    var volunteersError: String? {
        let trimmed = volunteersManualInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return nil
        }

        guard let value = Int(trimmed) else {
            return "Введите число"
        }

        if value <= 0 {
            return "Количество волонтёров должно быть больше 0"
        }

        return nil
    }

    private var volunteersInputIsValid: Bool {
        volunteersError == nil
    }

    func setLocation(title: String, coordinate: CLLocationCoordinate2D) {
        locationText = title
        selectedCoordinate = coordinate
    }

    func increaseVolunteers() {
        volunteersCount += 1
        volunteersManualInput = "\(volunteersCount)"
    }

    func decreaseVolunteers() {
        volunteersCount = max(1, volunteersCount - 1)
        volunteersManualInput = "\(volunteersCount)"
    }

    func updateVolunteersFromInput(_ rawValue: String) {
        let filtered = rawValue.filter(\.isNumber)

        if filtered != rawValue {
            volunteersManualInput = filtered
            return
        }

        if let value = Int(filtered), value > 0 {
            volunteersCount = value
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func submit() async {
        clearMessages()

        guard canSubmit else {
            errorMessage = "Заполните все обязательные поля"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        try? await Task.sleep(nanoseconds: 500_000_000)
        successMessage = "Событие готово к отправке"
    }

    func defaultStartSelection() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)

        return calendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 10,
            minute: 0
        )) ?? now
    }

    func defaultEndSelection() -> Date {
        if let startDate, let startTime {
            let start = combine(day: startDate, time: startTime)
            return Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start
        }

        let start = defaultStartSelection()
        return Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start
    }

    func stripTime(from date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func combine(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(from: DateComponents(
            year: dayComponents.year,
            month: dayComponents.month,
            day: dayComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )) ?? day
    }

    private func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatDuration(minutes: Int) -> String {
        let totalHours = minutes / 60
        let remainingMinutes = minutes % 60

        let days = totalHours / 24
        let hours = totalHours % 24

        var parts: [String] = []

        if days > 0 {
            parts.append("\(days) д")
        }
        if hours > 0 {
            parts.append("\(hours) ч")
        }
        if days == 0 && hours == 0 && remainingMinutes > 0 {
            parts.append("\(remainingMinutes) мин")
        }

        return parts.isEmpty ? "0 ч" : parts.joined(separator: " ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()
}

struct CISCitiesCountry: Decodable {
    let country: String
    let cities: [String]
}

@MainActor
final class EventLocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion
    }

    @Published var query = ""
    @Published var suggestions: [Suggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    private let cisCountries: [String]
    private let cisCities: [String]

    override init() {
        let data = Self.loadCISCities()
        self.cisCountries = data.map { $0.country.lowercased() }
        self.cisCities = data.flatMap { $0.cities }.map { $0.lowercased() }

        super.init()

        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.updateQuery(text)
            }
            .store(in: &cancellables)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
            .filter { isAllowedCISSuggestion(title: $0.title, subtitle: $0.subtitle) }
            .map {
                Suggestion(
                    title: $0.title,
                    subtitle: $0.subtitle,
                    completion: $0
                )
            }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }

    func search(for suggestion: Suggestion) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else {
            return nil
        }

        return isAllowedCISMapItem(item) ? item : nil
    }

    private func updateQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            suggestions = []
        }

        completer.queryFragment = trimmed
    }

    private func isAllowedCISSuggestion(title: String, subtitle: String) -> Bool {
        let combined = "\(title.lowercased()) \(subtitle.lowercased())"

        if cisCountries.contains(where: { combined.contains($0) }) {
            return true
        }

        if cisCities.contains(where: { combined.contains($0) }) {
            return true
        }

        return false
    }

    private func isAllowedCISMapItem(_ item: MKMapItem) -> Bool {
        let placemark = item.placemark

        let country = placemark.country?.lowercased() ?? ""
        let locality = placemark.locality?.lowercased() ?? ""
        let administrativeArea = placemark.administrativeArea?.lowercased() ?? ""
        let name = placemark.name?.lowercased() ?? ""
        let combined = "\(country) \(locality) \(administrativeArea) \(name)"

        if cisCountries.contains(where: { combined.contains($0) }) {
            return true
        }

        if cisCities.contains(where: { combined.contains($0) }) {
            return true
        }

        return false
    }

    private static func loadCISCities() -> [CISCitiesCountry] {
        guard
            let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([CISCitiesCountry].self, from: data)
        else {
            return []
        }

        return decoded
    }
}
