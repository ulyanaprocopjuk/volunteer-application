import SwiftUI
import Combine

struct EventParticipantsManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventParticipantsManagementViewModel

    @State private var selectedSegment: EventParticipantsSegment
    @State private var selectedProfile: ProfileResponse?
    @State private var participantForRemoval: EventParticipantResponse?
    @State private var removalReason = ""
    @State private var showsRemovalPrompt = false

    init(
        eventID: String,
        session: AppSession,
        initialSegment: EventParticipantsSegment = .participants,
        api: EventAPIProtocol? = nil
    ) {
        _selectedSegment = State(initialValue: initialSegment)
        _viewModel = StateObject(
            wrappedValue: EventParticipantsManagementViewModel(eventID: eventID, session: session, api: api)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            segmentControl
                .padding(.horizontal, 20)
                .padding(.top, 14)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .task {
            await viewModel.loadApplications()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Удалить участника", isPresented: $showsRemovalPrompt) {
            TextField("Причина удаления", text: $removalReason)

            Button("Отменить", role: .cancel) {
                participantForRemoval = nil
                removalReason = ""
            }

            Button("Удалить", role: .destructive) {
                guard let participant = participantForRemoval else { return }
                Task {
                    await viewModel.removeParticipant(participant, reason: removalReason)
                    participantForRemoval = nil
                    removalReason = ""
                }
            }
        } message: {
            Text("Участнику придёт уведомление с указанной причиной.")
        }
        .fullScreenCover(item: $selectedProfile) { profile in
            ParticipantProfileDetailsView(profile: profile)
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Участники")
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
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(EventParticipantsSegment.allCases, id: \.self) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    Text(segment.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(selectedSegment == segment ? .white : .black.opacity(0.62))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSegment == segment
                                      ? Color(red: 44/255, green: 67/255, blue: 102/255)
                                      : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.applications.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            switch selectedSegment {
            case .participants:
                participantsContent
            case .applications:
                applicationsContent
            }
        }
    }

    @ViewBuilder
    private var participantsContent: some View {
        if viewModel.participants.isEmpty {
            emptyState("Участников пока нет")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.participants) { participant in
                        participantRow(participant)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var applicationsContent: some View {
        if viewModel.applicationRequests.isEmpty {
            emptyState("Заявок пока нет")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.applicationRequests) { application in
                        applicationRow(application)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
    }

    private func participantRow(_ participant: EventParticipantResponse) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedProfile = participant.profile
            } label: {
                HStack(spacing: 12) {
                    ParticipantAvatarView(avatarURL: participant.profile.avatarURL)

                    Text(participant.profile.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if !participant.isCreator {
                switch participant.applicationStatus {
                case .pending:
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.82, green: 0.62, blue: 0.07))
                case .accepted:
                    Button {
                        participantForRemoval = participant
                        removalReason = ""
                        showsRemovalPrompt = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                default:
                    EmptyView()
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func applicationRow(_ application: EventParticipantResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    selectedProfile = application.profile
                } label: {
                    HStack(spacing: 12) {
                        ParticipantAvatarView(avatarURL: application.profile.avatarURL)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(application.profile.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                .lineLimit(2)

                            Text(applicationStatusText(application.applicationStatus))
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundColor(statusColor(application.applicationStatus))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }

            if application.applicationStatus == .pending {
                HStack(spacing: 10) {
                    applicationActionButton("Принять", filled: true) {
                        Task {
                            await viewModel.acceptApplication(application)
                        }
                    }

                    applicationActionButton("Отклонить", filled: false) {
                        Task {
                            await viewModel.rejectApplication(application)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 68/255, green: 185/255, blue: 255/255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func applicationActionButton(
        _ title: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(filled ? .white : Color(red: 44/255, green: 67/255, blue: 102/255))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(filled ? Color(red: 44/255, green: 67/255, blue: 102/255) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 44/255, green: 67/255, blue: 102/255), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isLoading)
    }

    private func applicationStatusText(_ status: EventApplicationDisplayStatus) -> String {
        switch status {
        case .pending:
            return "Ожидает решения"
        case .accepted:
            return "Заявка принята"
        case .rejected:
            return "Заявка отклонена"
        case .cancelled:
            return "Заявка удалена"
        }
    }

    private func statusColor(_ status: EventApplicationDisplayStatus) -> Color {
        switch status {
        case .pending:
            return Color(red: 0.82, green: 0.62, blue: 0.07)
        case .accepted:
            return Color(red: 0.16, green: 0.56, blue: 0.23)
        case .rejected:
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        case .cancelled:
            return .black.opacity(0.45)
        }
    }

    private func emptyState(_ text: String) -> some View {
        VStack {
            Spacer()

            Text(text)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class EventParticipantsManagementViewModel: ObservableObject {
    @Published private(set) var applications: [EventParticipantResponse] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let eventID: String
    private let session: AppSession
    private let api: EventAPIProtocol

    init(eventID: String, session: AppSession, api: EventAPIProtocol? = nil) {
        self.eventID = eventID
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    var participants: [EventParticipantResponse] {
        applications.filter {
            $0.applicationStatus == .accepted || $0.applicationStatus == .pending
        }
    }

    var applicationRequests: [EventParticipantResponse] {
        applications.filter { application in
            !application.isCreator && application.applicationStatus != .cancelled
        }
    }

    func loadApplications() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            applications = try await session.performAuthorizedRequest { token in
                try await api.fetchEventApplications(eventID: eventID, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeParticipant(_ participant: EventParticipantResponse, reason: String) async {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReason.isEmpty else {
            errorMessage = "Укажите причину удаления"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await session.performAuthorizedRequest { token in
                try await api.removeParticipant(
                    applicationID: participant.applicationID,
                    reason: normalizedReason,
                    token: token
                )
            }
            await loadApplications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptApplication(_ application: EventParticipantResponse) async {
        await reviewApplication(application, accept: true)
    }

    func rejectApplication(_ application: EventParticipantResponse) async {
        await reviewApplication(application, accept: false)
    }

    private func reviewApplication(_ application: EventParticipantResponse, accept: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await session.performAuthorizedRequest { token in
                if accept {
                    try await api.acceptApplication(id: application.applicationID, token: token)
                } else {
                    try await api.rejectApplication(id: application.applicationID, token: token)
                }
            }
            await loadApplications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum EventParticipantsSegment: CaseIterable {
    case participants
    case applications

    var title: String {
        switch self {
        case .participants:
            return "Участники"
        case .applications:
            return "Заявки"
        }
    }
}

private struct ParticipantProfileDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: ProfileResponse

    private var isOrganization: Bool { profile.type == "organization" }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    avatarSection
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 22) {
                        if isOrganization {
                            organizationFields
                        } else {
                            volunteerFields
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Профиль участника")
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
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
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
    private var avatarContent: some View {
        if let remoteURL {
            AsyncImage(url: remoteURL) { phase in
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
        Image(systemName: isOrganization ? "building.2.fill" : "person.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
    }

    private var remoteURL: URL? {
        guard let avatarURL = profile.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !avatarURL.isEmpty else { return nil }
        if let url = URL(string: avatarURL), url.scheme != nil { return url }
        guard let baseURL = URL(string: AppConfig.baseURLString) else { return nil }
        let path = avatarURL.hasPrefix("/") ? String(avatarURL.dropFirst()) : avatarURL
        return baseURL.appendingPathComponent(path)
    }

    private var volunteerFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            ReadOnlyField(title: "Имя", value: profile.firstName ?? "")
            ReadOnlyField(title: "Фамилия", value: profile.lastName ?? "")
            ReadOnlyField(title: "Номер телефона", value: profile.phone ?? "")
            ReadOnlyField(title: "Электронная почта", value: profile.email ?? "")
            ReadOnlyField(title: "Местонахождение", value: profile.locationText)
            ReadOnlySkillsField(title: "Навыки", values: profile.skills ?? [])
            ReadOnlyMultilineField(title: "Обо мне", value: profile.about ?? "")
        }
    }

    private var organizationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            ReadOnlyField(title: "Название организации", value: profile.organizationName ?? "")
            ReadOnlyField(title: "Телефон", value: profile.phone ?? "")
            ReadOnlyField(title: "Электронная почта", value: profile.email ?? "")
            ReadOnlyField(title: "Местонахождение", value: profile.locationText)
            ReadOnlyMultilineField(title: "О нас", value: profile.about ?? "")
        }
    }
}

private struct ParticipantAvatarView: View {
    let avatarURL: String?
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 18/255, green: 162/255, blue: 231/255).opacity(0.12))

            if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
    }

    private var remoteURL: URL? {
        guard let avatarURL = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
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
}

private extension ProfileResponse {
    var displayName: String {
        let organizationName = organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !organizationName.isEmpty {
            return organizationName
        }

        let fullName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? "Участник" : fullName
    }

    var displayType: String {
        type == "organization" ? "Организация" : "Волонтёр"
    }

    var locationText: String {
        let parts = [country, city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.isEmpty ? "Не указано" : parts.joined(separator: ", ")
    }

    var skillsText: String {
        (skills ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

#Preview("Участник") {
    ParticipantProfileDetailsView(
        profile: ProfileResponse(
            id: 1,
            userID: 10,
            type: "volunteer",
            avatarURL: nil,
            firstName: "Анна",
            lastName: "Иванова",
            organizationName: nil,
            phone: "+375291234567",
            email: "anna@example.com",
            city: "Минск",
            country: "Беларусь",
            skills: ["Первая помощь", "Организация мероприятий"],
            about: "Готова помогать на городских событиях."
        )
    )
}
