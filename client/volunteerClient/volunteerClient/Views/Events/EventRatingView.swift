import SwiftUI

struct EventRatingView: View {
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol
    var onCompleted: ((EventResponse) -> Void)?

    @State private var profiles: [RatableProfile] = []
    @State private var scores: [Int: Int] = [:]
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let navy = Color(red: 44/255, green: 67/255, blue: 102/255)
    private let scoreOptions = stride(from: -50, through: 50, by: 10).map { $0 }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if profiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(navy)
                        Text("Оценки уже выставлены")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        Text("Нет участников для оценки")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(profiles) { profile in
                                ratingRow(profile: profile)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Оценить участников")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(navy)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !profiles.isEmpty {
                        Button("Отправить") {
                            Task { await submitRatings() }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(navy)
                        .disabled(isSubmitting)
                    }
                }
            }
            .overlay {
                if let msg = errorMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    errorMessage = nil
                                }
                            }
                    }
                }
            }
        }
        .task { await loadProfiles() }
    }

    private func ratingRow(profile: RatableProfile) -> some View {
        let score = scores[profile.profileID] ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: profile.avatarURL.flatMap { URL(string: $0) }) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(navy.opacity(0.5))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .background(Circle().fill(navy.opacity(0.1)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Рейтинг: \(profile.currentRating)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()

                Text(score > 0 ? "+\(score)" : "\(score)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(score > 0 ? Color(red: 0.2, green: 0.7, blue: 0.4) : score < 0 ? Color(red: 0.85, green: 0.2, blue: 0.2) : .gray)
                    .frame(minWidth: 44, alignment: .trailing)
            }

            scorePicker(for: profile.profileID, current: score)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func scorePicker(for profileID: Int, current: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scoreOptions, id: \.self) { value in
                    Button {
                        scores[profileID] = value
                    } label: {
                        Text(value > 0 ? "+\(value)" : "\(value)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(current == value ? .white : scoreColor(value))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(current == value ? scoreColor(value) : scoreColor(value).opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scoreColor(_ value: Int) -> Color {
        if value > 0 { return Color(red: 0.2, green: 0.7, blue: 0.4) }
        if value < 0 { return Color(red: 0.85, green: 0.2, blue: 0.2) }
        return .gray
    }

    private func loadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await session.performAuthorizedRequest { token in
                try await api.fetchRatableProfiles(eventID: eventID, token: token)
            }
            profiles = fetched
            for p in profiles {
                scores[p.profileID] = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRatings() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let items = profiles.map { RatingItem(profileID: $0.profileID, score: scores[$0.profileID] ?? 0) }
            let updated = try await session.performAuthorizedRequest { token in
                try await api.submitRatings(eventID: eventID, ratings: items, token: token)
            }
            onCompleted?(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
