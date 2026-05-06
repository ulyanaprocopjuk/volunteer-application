import SwiftUI

struct NotificationsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NotificationViewModel
    private let shouldLoadOnAppear: Bool
    private let session: AppSession?

    init(session: AppSession) {
        _viewModel = StateObject(wrappedValue: NotificationViewModel(session: session))
        self.shouldLoadOnAppear = true
        self.session = session
    }

    init(viewModel: NotificationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.shouldLoadOnAppear = false
        self.session = nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    listView
                }

                if !viewModel.notifications.isEmpty {
                    clearButton
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        .background(Color.white)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .task {
                guard shouldLoadOnAppear else { return }
                await viewModel.loadNotifications()
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Уведомления")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                .background(Circle().fill(Color.clear))
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.gray.opacity(0.7))

            Text("У вас нет уведомлений")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { item in
                    NavigationLink {
                        NotificationView(notification: item, session: session)
                    } label: {
                        notificationRow(item)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Task {
                            await viewModel.markAsRead(item)
                        }
                    })

                    Divider()
                        .padding(.leading, 20)
                }
            }
            .padding(.top, 10)
        }
    }

    private func notificationRow(_ item: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.isRead ? Color.clear : Color.red)
                .frame(width: 8, height: 8)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.senderName)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(item.isRead ? .gray : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.message)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundColor(item.isRead ? .gray.opacity(0.8) : .black.opacity(0.6))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.formattedDate)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(item.isRead ? .gray.opacity(0.7) : .gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 20)
        .background(Color.white)
        .opacity(item.isRead ? 0.72 : 1)
    }

    private var clearButton: some View {
        Button {
            Task {
                await viewModel.clearAll()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                if viewModel.isLoading && !viewModel.notifications.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Очистить")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.notifications.isEmpty || viewModel.isLoading)
        .opacity((viewModel.notifications.isEmpty || viewModel.isLoading) ? 0.6 : 1)
    }
}

#Preview("Со списком уведомлений") {
    let vm = NotificationViewModel(session: AppSession())
    vm.notifications = [
        AppNotificationItem(
            id: 1,
            senderName: "Администратор",
            eventID: nil,
            applicationID: nil,
            eventTitle: nil,
            applicantName: nil,
            applicationStatus: nil,
            message: "Ваше событие отправлено на модерацию.",
            createdAt: "2026-04-24T10:30:00Z",
            isRead: false
        ),
        AppNotificationItem(
            id: 2,
            senderName: "EcoHand Foundation",
            eventID: nil,
            applicationID: nil,
            eventTitle: nil,
            applicantName: nil,
            applicationStatus: nil,
            message: "Приглашаем вас присоединиться к новому волонтёрскому мероприятию в эту субботу.",
            createdAt: "2026-04-24T12:15:00Z",
            isRead: true
        )
    ]
    return NotificationsListView(viewModel: vm)
}

#Preview("Пустой список") {
    let vm = NotificationViewModel(session: AppSession())
    return NotificationsListView(viewModel: vm)
}
