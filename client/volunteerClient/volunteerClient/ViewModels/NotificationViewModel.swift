import Foundation
import Combine

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotificationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: AppSession
    private let api: NotificationAPIProtocol
    private let eventAPI: EventAPIProtocol

    init(
        session: AppSession,
        api: NotificationAPIProtocol? = nil,
        eventAPI: EventAPIProtocol? = nil
    ) {
        self.session = session
        self.api = api ?? NotificationAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.eventAPI = eventAPI ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    var isEmpty: Bool {
        notifications.isEmpty && !isLoading
    }

    var hasNotifications: Bool {
        notifications.contains { !$0.isRead }
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

    func markAsRead(_ notification: AppNotificationItem) async {
        guard !notification.isRead else { return }

        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification.readCopy()
        }

        do {
            try await session.performAuthorizedRequest { token in
                try await api.markNotificationRead(id: notification.id, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptApplication(_ notification: AppNotificationItem) async {
        await reviewApplication(notification, accept: true)
    }

    func rejectApplication(_ notification: AppNotificationItem) async {
        await reviewApplication(notification, accept: false)
    }

    private func reviewApplication(_ notification: AppNotificationItem, accept: Bool) async {
        guard let applicationID = notification.applicationID else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await session.performAuthorizedRequest { token in
                if accept {
                    try await eventAPI.acceptApplication(id: applicationID, token: token)
                } else {
                    try await eventAPI.rejectApplication(id: applicationID, token: token)
                }
            }
            isLoading = false
            await loadNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
