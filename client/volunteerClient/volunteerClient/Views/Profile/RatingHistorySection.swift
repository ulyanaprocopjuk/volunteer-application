import SwiftUI

struct RatingHistorySection: View {
    let profileID: Int
    let session: AppSession
    let profileAPI: ProfileAPIProtocol

    @State private var history: [RatingHistoryItem] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .padding(.horizontal, 24)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if history.isEmpty {
                Text("История изменений рейтинга пуста")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(history) { item in
                        historyRow(item: item)

                        if item.id != history.last?.id {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            }
        }
        .task { await load() }
    }

    private func historyRow(item: RatingHistoryItem) -> some View {
        HStack(spacing: 12) {
            Text(item.delta >= 0 ? "+\(item.delta)" : "\(item.delta)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(item.delta >= 0
                    ? Color(red: 0.2, green: 0.72, blue: 0.4)
                    : Color(red: 0.85, green: 0.2, blue: 0.2))
                .frame(minWidth: 48, alignment: .leading)

            Text(item.eventTitle ?? "Без события")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.75))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            history = try await session.performAuthorizedRequest { token in
                try await profileAPI.fetchRatingHistory(profileID: profileID, token: token)
            }
        } catch {
            history = []
        }
    }
}
