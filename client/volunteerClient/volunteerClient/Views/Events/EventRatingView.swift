import SwiftUI

// MARK: - Custom flat face shapes

private struct SadFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        // left eye
        p.addEllipse(in: CGRect(x: cx - r * 0.35 - r * 0.08, y: cy - r * 0.28, width: r * 0.16, height: r * 0.18))
        // right eye
        p.addEllipse(in: CGRect(x: cx + r * 0.35 - r * 0.08, y: cy - r * 0.28, width: r * 0.16, height: r * 0.18))
        // mouth — frown
        p.move(to: CGPoint(x: cx - r * 0.38, y: cy + r * 0.38))
        p.addQuadCurve(
            to: CGPoint(x: cx + r * 0.38, y: cy + r * 0.38),
            control: CGPoint(x: cx, y: cy + r * 0.12)
        )
        return p
    }
}

private struct NeutralFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        // left eye
        p.addEllipse(in: CGRect(x: cx - r * 0.35 - r * 0.08, y: cy - r * 0.28, width: r * 0.16, height: r * 0.18))
        // right eye
        p.addEllipse(in: CGRect(x: cx + r * 0.35 - r * 0.08, y: cy - r * 0.28, width: r * 0.16, height: r * 0.18))
        // mouth — flat line
        p.move(to: CGPoint(x: cx - r * 0.38, y: cy + r * 0.28))
        p.addLine(to: CGPoint(x: cx + r * 0.38, y: cy + r * 0.28))
        return p
    }
}

private struct HappyFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        // left eye
        p.addEllipse(in: CGRect(x: cx - r * 0.35 - r * 0.08, y: cy - r * 0.30, width: r * 0.16, height: r * 0.18))
        // right eye
        p.addEllipse(in: CGRect(x: cx + r * 0.35 - r * 0.08, y: cy - r * 0.30, width: r * 0.16, height: r * 0.18))
        // mouth — smile
        p.move(to: CGPoint(x: cx - r * 0.38, y: cy + r * 0.14))
        p.addQuadCurve(
            to: CGPoint(x: cx + r * 0.38, y: cy + r * 0.14),
            control: CGPoint(x: cx, y: cy + r * 0.52)
        )
        return p
    }
}

private struct FaceButton: View {
    enum Mood { case sad, neutral, happy }

    let mood: Mood
    let isSelected: Bool
    let activeColor: Color
    let size: CGFloat
    let action: () -> Void

    private var strokeWidth: CGFloat { size * 0.072 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Group {
                    switch mood {
                    case .sad:
                        SadFaceShape()
                            .fill(isSelected ? activeColor : Color(.systemGray3))
                            .frame(width: size, height: size)
                        SadFaceShape()
                            .stroke(isSelected ? activeColor : Color(.systemGray3), lineWidth: strokeWidth * 0.8)
                            .frame(width: size, height: size)
                    case .neutral:
                        NeutralFaceShape()
                            .fill(isSelected ? activeColor : Color(.systemGray3))
                            .frame(width: size, height: size)
                        NeutralFaceShape()
                            .stroke(isSelected ? activeColor : Color(.systemGray3), lineWidth: strokeWidth * 0.8)
                            .frame(width: size, height: size)
                    case .happy:
                        HappyFaceShape()
                            .fill(isSelected ? activeColor : Color(.systemGray3))
                            .frame(width: size, height: size)
                        HappyFaceShape()
                            .stroke(isSelected ? activeColor : Color(.systemGray3), lineWidth: strokeWidth * 0.8)
                            .frame(width: size, height: size)
                    }
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(isSelected ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Main View

struct EventRatingView: View {
    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol
    let isOrganizerVerified: Bool
    let eventRatingPoints: Int
    var onCompleted: ((EventResponse?) -> Void)?

    @State private var profiles: [RatableProfile] = []
    // nil = nothing selected; Int = chosen score
    @State private var selectedScores: [Int: Int?] = [:]
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let navy = Color(red: 44/255, green: 67/255, blue: 102/255)
    private let faceSize: CGFloat = 27

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if profiles.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(navy)
                    Text("Нет участников для оценки")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(.black)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(profiles) { profile in
                            ratingRow(profile: profile)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                submitButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .padding(.top, 8)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
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
        .task { await loadProfiles() }
    }

    private var header: some View {
        Text("Оцените участников")
            .font(.system(size: 17, weight: .semibold, design: .serif))
            .foregroundColor(navy)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color.white)
    }

    private var submitButton: some View {
        Button {
            Task { await submitRatings() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(navy)
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Отправить")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private func ratingRow(profile: RatableProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
                .opacity(profile.isPresent ? 1 : 0.5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        if profile.isLeader {
                            Text("Лидер")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(red: 44/255, green: 67/255, blue: 102/255)))
                        }
                    }
                    HStack(spacing: 6) {
                        Text("Рейтинг: \(profile.currentRating)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        if !profile.isPresent {
                            Text("• Не явился")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                        }
                    }
                }
                Spacer()
            }

            facePicker(for: profile.profileID)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(profile.isPresent ? Color.white : Color(.systemGray6))
        )
        .shadow(color: .black.opacity(profile.isPresent ? 0.05 : 0.02), radius: 8, x: 0, y: 3)
    }

    private func facePicker(for profileID: Int) -> some View {
        let current: Int?? = selectedScores[profileID]
        let currentScore: Int? = current ?? nil

        return HStack(spacing: 10) {
            FaceButton(mood: .sad, isSelected: currentScore == -50, activeColor: Color(red: 0.85, green: 0.2, blue: 0.2), size: faceSize) {
                selectedScores[profileID] = currentScore == -50 ? nil : -50
            }
            FaceButton(mood: .neutral, isSelected: currentScore == 0, activeColor: Color(red: 0.9, green: 0.72, blue: 0.1), size: faceSize) {
                selectedScores[profileID] = currentScore == 0 ? nil : 0
            }
            FaceButton(mood: .happy, isSelected: currentScore == 50, activeColor: Color(red: 0.2, green: 0.72, blue: 0.4), size: faceSize) {
                selectedScores[profileID] = currentScore == 50 ? nil : 50
            }

            if isOrganizerVerified {
                Spacer()
                starButton(profileID: profileID, currentScore: currentScore)
            }
        }
    }

    private func starButton(profileID: Int, currentScore: Int?) -> some View {
        let isSelected = currentScore == eventRatingPoints
        let yellow = Color(red: 255/255, green: 214/255, blue: 0/255)
        return Button {
            selectedScores[profileID] = isSelected ? nil : eventRatingPoints
        } label: {
            Image(systemName: "star.fill")
                .font(.system(size: faceSize, weight: .bold))
                .foregroundColor(isSelected ? yellow : Color(.systemGray3))
                .frame(width: faceSize, height: faceSize)
                .scaleEffect(isSelected ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
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
                selectedScores[p.profileID] = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRatings() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let items = profiles.map { profile -> RatingItem in
                let raw: Int = (selectedScores[profile.profileID] ?? nil) ?? 0
                let score: Int
                if raw == eventRatingPoints && isOrganizerVerified {
                    // Star selected: add % bonus on top of event points
                    let bonusPct = profile.isLeader ? 0.30 : 0.20
                    let bonus = Int(Double(profile.currentRating) * bonusPct)
                    score = raw + bonus
                } else {
                    score = raw
                }
                return RatingItem(profileID: profile.profileID, score: score)
            }
            let updated = try await session.performAuthorizedRequest { token in
                try await api.submitRatings(eventID: eventID, ratings: items, token: token)
            }
            onCompleted?(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
