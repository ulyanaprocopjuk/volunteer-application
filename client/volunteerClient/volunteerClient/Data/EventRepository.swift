import Foundation

protocol EventRepository {
    func fetchAll() async throws -> [VolunteerEvent]
}
