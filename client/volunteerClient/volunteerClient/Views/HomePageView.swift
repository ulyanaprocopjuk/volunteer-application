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
    @State private var selectedActiveEvent: EventResponse?

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
            .overlay(alignment: .bottom) {
                if let event = activeEvent {
                    ActiveEventBanner(event: event) {
                        selectedActiveEvent = event
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 94)
                }
            }
            .fullScreenCover(item: $selectedActiveEvent) { event in
                EventDetailsView(event: event, session: session)
            }
            .task {
                await profileModel.loadMyProfileIfNeeded()
                await notificationModel.loadNotifications()
                await myEventsModel.loadMyEvents()
            }
            .onChange(of: selectedTab) { _, tab in
                guard tab == .events else { return }
                Task {
                    await myEventsModel.loadMyEvents()
                }
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
                NotificationsListView(viewModel: notificationModel, session: session)
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
                session: session,
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
            SearchEventsView(session: session)

        case .events:
            MyEventsView(
                viewModel: myEventsModel,
                session: session,
                onEventCancelled: { selectedTab = .map },
                onCreateEvent: { isEventFormPresented = true }
            )
        }
    }

    private var activeEvent: EventResponse? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        return myEventsModel.events.first { event in
            let s = event.status?.lowercased() ?? ""
            guard s == "active" || s == "активно" || s == "началось" else { return false }
            let end = event.endsAt.flatMap { isoFormatter.date(from: $0) }
                ?? isoFormatter.date(from: event.startsAt)
                ?? Date.distantPast
            return end > Date()
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

private struct ActiveEventBanner: View {
    let event: EventResponse
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Событие идёт сейчас")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.72))

                    let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(title.isEmpty ? "Без названия" : title)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomePageView(session: AppSession())
}
