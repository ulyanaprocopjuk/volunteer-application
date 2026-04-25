import Foundation
import Combine

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published private(set) var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let session: AppSession
    private let api: EventAPIProtocol

    init(
        session: AppSession,
        api: EventAPIProtocol? = nil
    ) {
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    var isEmpty: Bool {
        events.isEmpty && !isLoading
    }

    func loadMyEvents() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let token = try await session.validAccessToken()
            events = try await api.fetchMyEvents(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prependOrUpdate(_ event: EventResponse) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.insert(event, at: 0)
        }
    }
}
