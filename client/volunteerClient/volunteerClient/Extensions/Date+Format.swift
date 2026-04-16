import Foundation

extension Date {
    var dayMonthShort: String {
        formatted(.dateTime.day().month(.abbreviated))
    }

    var dayMonthYearShort: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }

    var timeShort: String {
        formatted(.dateTime.hour().minute())
    }
}
