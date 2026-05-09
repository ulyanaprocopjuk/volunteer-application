import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileSetupViewModel

    var onEditProfile: () -> Void = {}
    var onDeleteAccount: () -> Void = {}
    var onLogout: () -> Void = {}

    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
                .appNavigationStack("Профиль") {
                    ToolbarItem(placement: .topBarTrailing) {
                        settingsButton
                    }
                }
                .blur(radius: showSettings ? 2 : 0)
                .scaleEffect(showSettings ? 0.992 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.9), value: showSettings)

            if showSettings {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.18))
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSettings()
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if showSettings {
                AccountSettingsBottomSheet(
                    onEditProfile: {
                        closeSettings()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onEditProfile()
                        }
                    },
                    onLogout: {
                        closeSettings()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onLogout()
                        }
                    },
                    onDeleteAccount: {
                        closeSettings()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onDeleteAccount()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: showSettings)
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                profileStatusView
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                avatarSection
                    .padding(.top, 24)

                if model.isVolunteer {
                    ratingCard
                        .padding(.top, 18)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 22) {
                    if model.isVolunteer {
                        volunteerFields
                    } else {
                        organizationFields
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            .padding(.bottom, 24)
        }
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                showSettings = true
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black.opacity(0.82))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Color.white.opacity(0.96))
                )
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var avatarSection: some View {
        ZStack {
            Circle()
                .fill(Color(red: 231/255, green: 243/255, blue: 247/255))
                .frame(width: 104, height: 104)

            avatarContent
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var profileStatusView: some View {
        if model.isProfileLoading {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color(red: 18/255, green: 162/255, blue: 231/255))

                Text("Загружаем профиль...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else if let error = model.profileLoadError {
            VStack(spacing: 10) {
                Text("Не удалось загрузить профиль")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.84))

                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await model.loadMyProfile()
                    }
                } label: {
                    Text("Повторить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(red: 18/255, green: 162/255, blue: 231/255))
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let avatarImage = model.avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
        } else if let avatarRemoteURL {
            AsyncImage(url: avatarRemoteURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(Color(red: 18/255, green: 162/255, blue: 231/255))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                case .failure:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: model.isVolunteer ? "person.fill" : "building.2.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
    }

    private var avatarRemoteURL: URL? {
        guard let avatarURL = model.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !avatarURL.isEmpty else {
            return nil
        }

        if let url = URL(string: avatarURL), url.scheme != nil {
            return url
        }

        guard let baseURL = URL(string: AppConfig.baseURLString) else {
            return nil
        }

        let path = avatarURL.hasPrefix("/") ? String(avatarURL.dropFirst()) : avatarURL
        return baseURL.appendingPathComponent(path)
    }

    private var ratingCard: some View {
        let navy = Color(red: 44/255, green: 67/255, blue: 102/255)
        let r = model.rating
        let (levelName, levelColor): (String, Color) = {
            switch r {
            case 80...: return ("Надёжный", Color(red: 0.2, green: 0.7, blue: 0.4))
            case 50..<80: return ("Хороший", Color(red: 0.3, green: 0.6, blue: 0.9))
            case 20..<50: return ("Средний", Color(red: 1.0, green: 0.65, blue: 0.0))
            default: return ("Низкий", Color(red: 0.85, green: 0.2, blue: 0.2))
            }
        }()

        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ваш текущий рейтинг")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(r)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text(levelName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(levelColor)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(navy.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundColor(navy)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var volunteerFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            ReadOnlyField(title: "Имя", value: model.firstName)
            ReadOnlyField(title: "Фамилия", value: model.lastName)
            ReadOnlyField(title: "Номер телефона", value: model.volunteerPhone)
            ReadOnlyField(title: "Местонахождение", value: model.volunteerLocation)
            ReadOnlySkillsField(title: "Навыки", values: Array(model.selectedSkills))
            ReadOnlyMultilineField(title: "Обо мне", value: model.aboutMe)
        }
    }

    private var organizationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            ReadOnlyField(title: "Название организации", value: model.organizationName)
            ReadOnlyField(title: "Телефон", value: model.organizationPhone)
            ReadOnlyField(title: "Местонахождение", value: model.organizationLocation)
            ReadOnlyMultilineField(title: "О нас", value: model.aboutOrganization)
        }
    }

    private func closeSettings() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showSettings = false
        }
    }
}

struct AccountSettingsBottomSheet: View {
    var onEditProfile: () -> Void
    var onLogout: () -> Void
    var onDeleteAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("Настройки аккаунта")
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(.black.opacity(0.92))
                .padding(.top, 30)
                .padding(.horizontal, 30)

            VStack(spacing: 15) {
                SettingsSheetActionRow(
                    title: "Редактировать профиль",
                    systemImage: "square.and.pencil",
                    foregroundColor: Color.black.opacity(0.84),
                    backgroundColor: .white,
                    showsChevron: true,
                    action: onEditProfile
                )

                SettingsSheetActionRow(
                    title: "Выйти из профиля",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    foregroundColor: Color.black.opacity(0.84),
                    backgroundColor: .white,
                    showsChevron: false,
                    action: onLogout
                )
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            SettingsSheetActionRow(
                title: "Удалить аккаунт",
                systemImage: "trash",
                foregroundColor: .red,
                backgroundColor: Color.red.opacity(0.018),
                showsChevron: false,
                action: onDeleteAccount
            )
            .padding(.top, 32)
            .padding(.horizontal, 20)
            .padding(.bottom, 13)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedCornerShape(
                radius: 28,
                corners: [.topLeft, .topRight]
            )
            .fill(Color(uiColor: .systemBackground).opacity(0.985))
        )
        .overlay(
            RoundedCornerShape(
                radius: 28,
                corners: [.topLeft, .topRight]
            )
            .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: -4)
        .fixedSize(horizontal: false, vertical: true)
        .ignoresSafeArea(edges: .bottom)
    }

    private var bottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }
}

struct SettingsSheetActionRow: View {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color
    let showsChevron: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(foregroundColor.opacity(0.08))
                        .frame(width: 28, height: 28)

                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(foregroundColor)
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.82))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.gray.opacity(0.13), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ReadOnlyField: View {
    let title: String
    let value: String

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private var isEmptyValue: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(.black)
                .padding(.leading, 8)

            HStack {
                Text(displayValue)
                    .font(.system(size: 15))
                    .foregroundColor(isEmptyValue ? .gray : .black)

                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(Color.white)
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
            )
        }
    }
}

struct ReadOnlySkillsField: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(.black)
                .padding(.leading, 8)

            if values.isEmpty {
                HStack {
                    Text("—")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                )
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(values, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.10))
                            )
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                )
            }
        }
    }
}

struct ReadOnlyMultilineField: View {
    let title: String
    let value: String

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private var isEmptyValue: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(.black)
                .padding(.leading, 8)

            HStack(alignment: .top) {
                Text(displayValue)
                    .font(.system(size: 15))
                    .foregroundColor(isEmptyValue ? .gray : .black)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 128, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
            )
        }
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = 28
    var corners: UIRectCorner = [.topLeft, .topRight]

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0

        guard maxWidth > 0 else {
            let totalHeight = subviews.reduce(CGFloat.zero) {
                $0 + $1.sizeThatFits(.unspecified).height + spacing
            }
            let maxSubviewWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
            return CGSize(width: maxSubviewWidth, height: totalHeight)
        }

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ProfileView(model: ProfileSetupViewModel(session: AppSession()))
}
