import Foundation
import Combine

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotificationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: AppSession
    private let api: NotificationAPIProtocol

    init(
        session: AppSession,
        api: NotificationAPIProtocol? = nil
    ) {
        self.session = session
        self.api = api ?? NotificationAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    var isEmpty: Bool {
        notifications.isEmpty && !isLoading
    }

    var hasNotifications: Bool {
        !notifications.isEmpty
    }

    func loadNotifications() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            notifications = try await session.performAuthorizedRequest { token in
                try await api.fetchNotifications(token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAll() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await session.performAuthorizedRequest { token in
                try await api.clearNotifications(token: token)
            }
            notifications = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
