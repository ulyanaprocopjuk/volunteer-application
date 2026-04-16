import Foundation

final class MockEventRepository: EventRepository {
    func fetchAll() async throws -> [VolunteerEvent] {
        VolunteerEvent.mockData
    }
}
