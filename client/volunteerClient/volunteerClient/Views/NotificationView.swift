import SwiftUI

struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss
    let notification: AppNotificationItem

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("От кого: \(notification.senderName)")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(notification.message)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(notification.formattedDate)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)

            Text("Уведомление")
                .font(.system(size: 22, weight: .semibold, design: .serif))
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
        .frame(height: 74)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

#Preview {
    NotificationView(
        notification: AppNotificationItem(
            id: 1,
            senderName: "Администратор",
            message: "Ваше событие отправлено на модерацию.",
            createdAt: "2026-04-24T10:30:00Z",
            isRead: false
        )
    )
}
