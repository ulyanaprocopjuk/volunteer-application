import Foundation
import CoreLocation
import Combine

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
    @Published var isProfileContextLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var locationContext: EventLocationContext?

    private let session: AppSession
    private let profileAPI: ProfileAPIProtocol
    private let eventAPI: EventAPIProtocol
    private let geocodingAPI: GeocodingAPIProtocol

    private var selectedLocation: EventLocationSelection?
    private var hasLoadedProfileContext = false

    init(
        session: AppSession,
        profileAPI: ProfileAPIProtocol? = nil,
        eventAPI: EventAPIProtocol? = nil,
        geocodingAPI: GeocodingAPIProtocol? = nil
    ) {
        self.session = session
        self.profileAPI = profileAPI ?? ProfileAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.eventAPI = eventAPI ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.geocodingAPI = geocodingAPI ?? GeocodingAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

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
        if let locationContext {
            return "Искать адрес в \(locationContext.city), \(locationContext.country)"
        }

        return "Выберите местоположение"
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
        }

        return Self.dateFormatter.string(from: endDate)
    }

    var currentLocationSelection: EventLocationSelection? {
        selectedLocation
    }

    var locationError: String? {
        nil
    }

    var startError: String? {
        nil
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

    func loadProfileContextIfNeeded() async {
        guard !hasLoadedProfileContext, !isProfileContextLoading else { return }

        isProfileContextLoading = true
        defer { isProfileContextLoading = false }

        do {
            let profile = try await session.performAuthorizedRequest { token in
                try await profileAPI.fetchMyProfile(token: token)
            }
            let country = canonicalCountry(from: profile.country)
            let city = canonicalCity(from: profile.city, in: country)
            let searchArea = CityDirectory.searchArea(for: country)
            let cityCoordinate = try await geocodingAPI.geocodeCity(city: city, country: country, area: searchArea)
                ?? searchArea.center

            locationContext = EventLocationContext(
                country: country,
                city: city,
                countrySearchArea: searchArea,
                cityCoordinate: cityCoordinate
            )
            hasLoadedProfileContext = true
        } catch {
            let country = CityDirectory.defaultCountry
            let city = CityDirectory.cities(for: country).first ?? "Минск"
            let searchArea = CityDirectory.searchArea(for: country)

            locationContext = EventLocationContext(
                country: country,
                city: city,
                countrySearchArea: searchArea,
                cityCoordinate: searchArea.center
            )
            hasLoadedProfileContext = true
        }
    }

    func setLocation(_ selection: EventLocationSelection) {
        selectedLocation = selection
        locationText = selection.address
        selectedCoordinate = selection.coordinate
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

    func clearSuccessMessage() {
        successMessage = nil
    }

    func submit() async -> EventResponse? {
        clearMessages()

        guard canSubmit else {
            errorMessage = "Заполните все обязательные поля"
            return nil
        }

        guard let selectedCoordinate,
              let country = selectedLocation?.country ?? locationContext?.country,
              let city = selectedLocation?.city ?? locationContext?.city,
              !country.isEmpty,
              !city.isEmpty else {
            errorMessage = "Не удалось определить местоположение события"
            return nil
        }

        guard let volunteersNeeded = Int(volunteersManualInput),
              let startDate,
              let startTime else {
            errorMessage = "Заполните все обязательные поля"
            return nil
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let request = CreateEventRequest(
                title: trim(eventTitle),
                description: trim(eventDescription),
                country: CityDirectory.canonicalCountryName(for: country),
                city: city,
                locationName: trim(locationText),
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                startsAt: iso8601String(from: combine(day: startDate, time: startTime)),
                endsAt: endTimestamp,
                volunteersNeeded: volunteersNeeded
            )

            let response = try await session.performAuthorizedRequest { token in
                try await eventAPI.createEvent(request, token: token)
            }
            successMessage = response.message ?? "Событие создано"
            resetFormKeepingContext()
            return response
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
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

    private var endTimestamp: String? {
        guard let endDate, let endTime else { return nil }
        return iso8601String(from: combine(day: endDate, time: endTime))
    }

    private func resetFormKeepingContext() {
        eventTitle = ""
        eventDescription = ""
        locationText = ""
        selectedCoordinate = nil
        selectedLocation = nil
        startDate = nil
        startTime = nil
        endDate = nil
        endTime = nil
        volunteersCount = 1
        volunteersManualInput = "1"
    }

    private func canonicalCountry(from profileCountry: String?) -> String {
        let fallbackCountry = CityDirectory.defaultCountry
        let raw = trim(profileCountry ?? "")
        guard !raw.isEmpty else { return fallbackCountry }
        return CityDirectory.canonicalCountryName(for: raw)
    }

    private func canonicalCity(from profileCity: String?, in country: String) -> String {
        let trimmedCity = trim(profileCity ?? "")
        if !trimmedCity.isEmpty {
            return trimmedCity
        }

        return CityDirectory.cities(for: country).first ?? "Минск"
    }

    private func iso8601String(from date: Date) -> String {
        Self.iso8601Formatter.string(from: date)
    }

    private func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    
}
