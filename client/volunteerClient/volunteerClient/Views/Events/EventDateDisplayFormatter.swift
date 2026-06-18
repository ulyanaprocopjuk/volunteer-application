import Foundation

enum EventDateDisplayFormatter {
    static func dateRangeText(start: Date, end: Date?) -> String {
        guard let end else {
            return shortDateText(start)
        }

        if Calendar.current.isDate(start, inSameDayAs: end) {
            return shortDateText(start)
        }

        if Calendar.current.component(.year, from: start) == Calendar.current.component(.year, from: end) {
            return "\(dayMonthText(start)) — \(dayMonthText(end)) \(yearText(end))"
        }

        return "\(shortDateText(start)) — \(shortDateText(end))"
    }

    static func timeRangeText(start: Date, end: Date?) -> String {
        let startText = timeText(start)

        guard let end,
              Calendar.current.isDate(start, inSameDayAs: end) else {
            return startText
        }

        return "\(startText) — \(timeText(end))"
    }

    static func dateTimeText(date: Date) -> String {
        "\(shortDateText(date)), \(timeText(date))"
    }

    static func shortDateText(_ date: Date) -> String {
        "\(dayText(date)) \(monthText(date)) \(yearText(date))"
    }

    static func dayMonthText(_ date: Date) -> String {
        "\(dayText(date)) \(monthText(date))"
    }

    static func timeText(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func dayText(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private static func monthText(_ date: Date) -> String {
        monthFormatter.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func yearText(_ date: Date) -> String {
        "\(Calendar.current.component(.year, from: date))"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
