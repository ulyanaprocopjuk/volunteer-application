import SwiftUI

struct EventDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventResponse

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    EventSummaryCard(event: event, showFullDescription: true)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)

            Text("Детали события")
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
    EventDetailsView(
        event: EventResponse(
            id: "1",
            title: "Музыкальный фестиваль",
            description: "Описание события",
            country: "Беларусь",
            city: "Минск",
            locationName: "ул. Аэродромная, Минск",
            photoURL: nil,
            latitude: 53.9,
            longitude: 27.56,
            startsAt: "2026-04-24T10:00:00Z",
            endsAt: "2026-04-24T14:00:00Z",
            volunteersNeeded: 3,
            status: "pending",
            message: nil,
            organizerName: "Анна Иванова",
            createdAt: "2026-04-24T09:00:00Z"
        )
    )
}
