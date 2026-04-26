import Foundation
import Combine

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published private(set) var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let session: AppSession
    private let api: EventAPIProtocol
    private var currentLoadID: UUID?

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

    func loadMyEvents(filter: MyEventsFilter? = nil) async {
        let loadID = UUID()
        currentLoadID = loadID

        isLoading = true
        errorMessage = nil
        defer {
            if currentLoadID == loadID {
                isLoading = false
            }
        }

        do {
            let loadedEvents = try await session.performAuthorizedRequest { token in
                try await api.fetchMyEvents(filter: filter, token: token)
            }
            guard currentLoadID == loadID else { return }
            events = loadedEvents
        } catch {
            guard currentLoadID == loadID else { return }
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
