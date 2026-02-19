import Foundation

enum ApplicationStatus: String, Codable {
    case draft, published, finished, cancelled
}

struct Application: Identifiable, Codable {
    let id: UUID
    var title: String
    var details: String
    var date: Date
    var location: String
    var status: EventStatus
}

