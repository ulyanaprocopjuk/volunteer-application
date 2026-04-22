import Foundation
import CoreLocation
import Combine

struct EventDraft {
    let title: String
    let description: String
    let locationAddress: String
    let locationCoordinate: CLLocationCoordinate2D
    let startAt: Date
    let endDay: Date
    let endAt: Date?
    let durationMinutes: Int?
    let volunteersCount: Int
}

struct SelectedLocation {
    let address: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor
final class EventFormViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var descriptionText: String = ""

    @Published var selectedLocation: SelectedLocation?

    @Published var startDay: Date?
    @Published var startTime: Date?

    @Published var endDay: Date?
    @Published var endTime: Date?

    @Published var volunteersCount: Int = 1
    @Published var volunteersInput: String = "1"

    init(now: Date = Date()) {
        let roundedNow = Self.roundToHour(now)
        self.startDay = nil
        self.startTime = nil
        self.endDay = nil
        self.endTime = nil
        self.volunteersInput = "1"
    }

    var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var locationDisplayText: String {
        selectedLocation?.address ?? ""
    }

    var formattedStart: String {
        guard let startAt else { return "" }
        return DateFormatters.dateTime.string(from: startAt)
    }

    var formattedEnd: String {
        guard let endDay else { return "" }

        if let endAt {
            return DateFormatters.dateTime.string(from: endAt)
        } else {
            return DateFormatters.dateOnly.string(from: endDay)
        }
    }

    var startAt: Date? {
        guard let startDay, let startTime else { return nil }
        return Self.combine(day: startDay, time: startTime)
    }

    var endAt: Date? {
        guard let endDay, let endTime else { return nil }
        return Self.combine(day: endDay, time: endTime)
    }

    var durationMinutes: Int? {
        guard let startAt, let endAt else { return nil }
        let interval = endAt.timeIntervalSince(startAt)
        guard interval > 0 else { return nil }
        return Int(interval / 60)
    }

    var durationDisplayText: String {
        guard let durationMinutes else { return "—" }
        return Self.durationString(from: durationMinutes)
    }

    var isVolunteersValid: Bool {
        volunteersError == nil
    }

    var volunteersError: String? {
        let trimmed = volunteersInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "Введите количество волонтёров"
        }

        guard let value = Int(trimmed) else {
            return "Введите число"
        }

        if value == 0 {
            return "Количество волонтёров должно быть больше 0"
        }

        if value < 0 {
            return "Введите корректное число"
        }

        return nil
    }

    var isValid: Bool {
        !titleTrimmed.isEmpty &&
        !descriptionTrimmed.isEmpty &&
        selectedLocation != nil &&
        startDay != nil &&
        startTime != nil &&
        endDay != nil &&
        endValidationError == nil &&
        isVolunteersValid
    }

    var endValidationError: String? {
        guard let startDay, let endDay else { return nil }

        let normalizedStart = Calendar.current.startOfDay(for: startDay)
        let normalizedEnd = Calendar.current.startOfDay(for: endDay)

        if normalizedEnd < normalizedStart {
            return "Дата окончания не может быть раньше даты начала"
        }

        if let startAt, let endAt, endAt <= startAt {
            return "Конец события должен быть позже начала"
        }

        return nil
    }

    var titleTrimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var descriptionTrimmed: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setLocation(_ location: SelectedLocation) {
        selectedLocation = location
    }

    func saveStart(day: Date, time: Date) {
        startDay = Calendar.current.startOfDay(for: day)
        startTime = time

        if let endDay, let startDay, endDay < startDay {
            self.endDay = startDay
        }

        if let startAt, let endAt, endAt <= startAt {
            self.endTime = nil
        }
    }

    func saveEnd(day: Date, time: Date?) {
        endDay = Calendar.current.startOfDay(for: day)
        endTime = time
    }

    func incrementVolunteers() {
        let next = currentVolunteers + 1
        volunteersCount = next
        volunteersInput = "\(next)"
    }

    func decrementVolunteers() {
        let next = max(1, currentVolunteers - 1)
        volunteersCount = next
        volunteersInput = "\(next)"
    }

    func updateVolunteersInput(_ newValue: String) {
        let digitsOnly = newValue.filter(\.isNumber)

        if digitsOnly != newValue {
            volunteersInput = digitsOnly
            return
        }

        if let value = Int(digitsOnly) {
            volunteersCount = value
        }
    }

    func buildDraft() -> EventDraft? {
        guard
            let selectedLocation,
            let startAt,
            let endDay,
            isValid
        else {
            return nil
        }

        return EventDraft(
            title: titleTrimmed,
            description: descriptionTrimmed,
            locationAddress: selectedLocation.address,
            locationCoordinate: selectedLocation.coordinate,
            startAt: startAt,
            endDay: endDay,
            endAt: endAt,
            durationMinutes: durationMinutes,
            volunteersCount: currentVolunteers
        )
    }

    func defaultStartDate() -> Date {
        let rounded = Self.roundToHour(Date())
        return max(rounded, todayStart)
    }

    func defaultEndDate() -> Date {
        if let startDay {
            return startDay
        }
        return todayStart
    }

    func defaultStartTime() -> Date {
        Self.roundToHour(Date())
    }

    func defaultEndTime() -> Date {
        if let startTime {
            return Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        }
        return Calendar.current.date(byAdding: .hour, value: 1, to: defaultStartTime()) ?? defaultStartTime()
    }

    var currentVolunteers: Int {
        Int(volunteersInput) ?? volunteersCount
    }

    private static func combine(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute

        return calendar.date(from: merged) ?? day
    }

    private static func roundToHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func durationString(from minutes: Int) -> String {
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let mins = minutes % 60

        var parts: [String] = []

        if days > 0 { parts.append("\(days) д") }
        if hours > 0 { parts.append("\(hours) ч") }
        if mins > 0 && days == 0 { parts.append("\(mins) мин") }

        return parts.isEmpty ? "0 мин" : parts.joined(separator: " ")
    }
}

enum DateFormatters {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()
}
