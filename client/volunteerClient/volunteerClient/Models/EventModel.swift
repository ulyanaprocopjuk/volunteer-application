import Foundation

enum EventStatus: String, Codable {
    case draft, published, finished, cancelled
}

struct Event: Identifiable, Codable {
    let id: UUID
    var title: String
    var details: String
    var date: Date
    var location: String
    var status: EventStatus
}
