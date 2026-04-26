import SwiftUI

enum HomeTab {
    case profile
    case map
    case explore
    case events
}

struct HomePageView: View {
    @ObservedObject var session: AppSession
    @StateObject private var profileModel: ProfileSetupViewModel
    @StateObject private var notificationModel: NotificationViewModel
    @StateObject private var myEventsModel: MyEventsViewModel

    @State private var selectedTab: HomeTab = .map
    @State private var isEditingProfile = false
    @State private var isEventFormPresented = false
    @State private var isNotificationsPresented = false
    @State private var showModerationMessage = false

    init(session: AppSession) {
        self.session = session
        _profileModel = StateObject(wrappedValue: ProfileSetupViewModel(session: session))
        _notificationModel = StateObject(wrappedValue: NotificationViewModel(session: session))
        _myEventsModel = StateObject(wrappedValue: MyEventsViewModel(session: session))
    }

    var body: some View {
        currentTabView
            .includeTabBar()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6).ignoresSafeArea())
            .overlay(alignment: .bottom) {
                BottomTabBar(selectedTab: $selectedTab)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .overlay {
                if showModerationMessage {
                    Text("Отправлено на модерацию")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.85))
                        )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color(.systemGray6).ignoresSafeArea())
            .task {
                await profileModel.loadMyProfileIfNeeded()
                await notificationModel.loadNotifications()
                await myEventsModel.loadMyEvents()
            }
            .fullScreenCover(isPresented: $isEventFormPresented) {
                NavigationStack {
                    EventFormView(
                        session: session,
                        onBack: {
                            isEventFormPresented = false
                        },
                        onEventSubmitted: { _ in
                            isEventFormPresented = false
                            presentModerationMessage()
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $isNotificationsPresented) {
                NotificationsListView(viewModel: notificationModel)
            }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .profile:
            if isEditingProfile {
                ProfileEditView(
                    viewModel: profileModel,
                    onBack: {
                        isEditingProfile = false
                    },
                    onSave: {
                        isEditingProfile = false
                    }
                )
            } else {
                ProfileView(
                    model: profileModel,
                    onEditProfile: {
                        isEditingProfile = true
                    },
                    onLogout: {
                        session.logout()
                    }
                )
            }

        case .map:
            MapEventsView(
                onCreateEventTap: {
                    isEventFormPresented = true
                },
                onNotificationsTap: {
                    Task {
                        await notificationModel.loadNotifications()
                        isNotificationsPresented = true
                    }
                },
                hasNotifications: notificationModel.hasNotifications
            )

        case .explore:
            SearchEventsView()

        case .events:
            MyEventsView(viewModel: myEventsModel) {
                isEventFormPresented = true
            }
        }
    }

    private func presentModerationMessage() {
        showModerationMessage = true

        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                showModerationMessage = false
            }
        }
    }
}

#Preview {
    HomePageView(session: AppSession())
}
