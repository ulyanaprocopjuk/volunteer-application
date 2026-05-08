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
    private let participantsOnly: Bool

    init(
        eventID: String,
        session: AppSession,
        initialSegment: EventParticipantsSegment = .participants,
        participantsOnly: Bool = false,
        api: EventAPIProtocol? = nil
    ) {
        _selectedSegment = State(initialValue: initialSegment)
        self.participantsOnly = participantsOnly
        _viewModel = StateObject(
            wrappedValue: EventParticipantsManagementViewModel(eventID: eventID, session: session, api: api)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if !participantsOnly {
                segmentControl
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

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
        } else if participantsOnly {
            acceptedOnlyContent
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
    private var acceptedOnlyContent: some View {
        let accepted = viewModel.applications.filter { $0.applicationStatus == .accepted }
        if accepted.isEmpty {
            emptyState("Подтверждённых участников нет")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(accepted) { participant in
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
            ReadOnlyField(title: "Местонахождение", value: profile.locationText)
            ReadOnlySkillsField(title: "Навыки", values: profile.skills ?? [])
            ReadOnlyMultilineField(title: "Обо мне", value: profile.about ?? "")
        }
    }

    private var organizationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            ReadOnlyField(title: "Название организации", value: profile.organizationName ?? "")
            ReadOnlyField(title: "Телефон", value: profile.phone ?? "")
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

// MARK: - Attendance Confirmation

struct EventAttendanceConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    private let eventID: String
    private let session: AppSession
    private let api: EventAPIProtocol
    private let isRestoring: Bool
    private let onConfirmed: ((EventResponse) -> Void)?

    @State private var attendanceItems: [AttendanceItem] = []
    @State private var presentIDs: Set<Int> = []
    @State private var isLoading = false
    @State private var isConfirming = false
    @State private var errorMessage: String?
    @State private var groupingEvent: EventResponse? = nil

    init(
        eventID: String,
        session: AppSession,
        api: EventAPIProtocol? = nil,
        isRestoring: Bool = false,
        onConfirmed: ((EventResponse) -> Void)? = nil
    ) {
        self.eventID = eventID
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.isRestoring = isRestoring
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        if let groupingEvent {
            EventGroupSelectionView(
                event: groupingEvent,
                presentCount: groupingEvent.presentCount ?? presentIDs.count,
                session: session,
                api: api,
                presentProfiles: attendanceItems
                    .filter { presentIDs.contains($0.applicationID) }
                    .map { $0.profile },
                onConfirmed: onConfirmed
            )
        } else {
            attendanceContent
        }
    }

    private var attendanceContent: some View {
        VStack(spacing: 0) {
            attendanceHeader

            if isLoading && attendanceItems.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if attendanceItems.isEmpty {
                Spacer()
                Text("Подтверждённых участников нет")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(attendanceItems) { item in
                            attendanceRow(item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            confirmButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.background)
        }
        .task { await loadData() }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var attendanceHeader: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            HStack(spacing: 0) {
                Button { dismiss() } label: {
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

                Text("Отметить присутствие")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func attendanceRow(_ item: AttendanceItem) -> some View {
        let isPresent = presentIDs.contains(item.applicationID)

        return HStack(spacing: 14) {
            ParticipantAvatarView(avatarURL: item.profile.avatarURL, size: 52)

            Text(item.profile.displayName)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            AttendanceToggle(isOn: isPresent) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isPresent {
                        presentIDs.remove(item.applicationID)
                    } else {
                        presentIDs.insert(item.applicationID)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var confirmButton: some View {
        Button {
            Task { await confirmAttendance() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .frame(height: 54)

                if isConfirming {
                    ProgressView().tint(.white)
                } else {
                    Text("Подтвердить")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isConfirming || isLoading)
        .opacity((isConfirming || isLoading) ? 0.6 : 1)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if !isRestoring {
                _ = try await session.performAuthorizedRequest { token in
                    try await api.startEvent(id: eventID, token: token)
                }
            }

            let items = try await session.performAuthorizedRequest { token in
                try await api.fetchAttendance(eventID: eventID, token: token)
            }
            attendanceItems = items
            presentIDs = Set(items.filter { $0.isPresent }.map { $0.applicationID })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmAttendance() async {
        isConfirming = true
        defer { isConfirming = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.confirmAttendance(
                    eventID: eventID,
                    presentApplicationIDs: Array(presentIDs),
                    token: token
                )
            }

            if updatedEvent.status?.lowercased() == "grouping" {
                withAnimation(.easeInOut(duration: 0.25)) {
                    groupingEvent = updatedEvent
                }
            } else {
                onConfirmed?(updatedEvent)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AttendanceToggle: View {
    let isOn: Bool
    let onToggle: () -> Void

    private let trackWidth: CGFloat = 48
    private let trackHeight: CGFloat = 28
    private let thumbDiameter: CGFloat = 22
    private let thumbInset: CGFloat = 3

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(isOn
                        ? Color(red: 0.30, green: 0.62, blue: 0.42)
                        : Color(red: 0.72, green: 0.30, blue: 0.30))
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: isOn
                        ? trackWidth / 2 - thumbDiameter / 2 - thumbInset
                        : -(trackWidth / 2 - thumbDiameter / 2 - thumbInset))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group Selection

struct EventGroupSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventResponse
    let presentCount: Int
    let session: AppSession
    let api: EventAPIProtocol
    let onConfirmed: ((EventResponse) -> Void)?

    private let passedPresentProfiles: [ProfileResponse]

    @State private var selectedGroupCount: Int
    @State private var showsNoGroupsConfirmation = false
    @State private var isConfirming = false
    @State private var isLoadingGroups = true
    @State private var groups: [EventGroup]? = nil
    @State private var presentProfiles: [ProfileResponse]
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>? = nil

    init(
        event: EventResponse,
        presentCount: Int,
        session: AppSession,
        api: EventAPIProtocol? = nil,
        presentProfiles: [ProfileResponse] = [],
        onConfirmed: ((EventResponse) -> Void)? = nil
    ) {
        self.event = event
        self.presentCount = presentCount
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.passedPresentProfiles = presentProfiles
        self.onConfirmed = onConfirmed
        _selectedGroupCount = State(initialValue: event.groupCount ?? 0)
        _presentProfiles = State(initialValue: presentProfiles)
    }

    private var maxGroups: Int {
        min(5, presentCount / 2)
    }

    private var availableOptions: [Int] {
        var options = [0]
        if maxGroups >= 2 {
            options += Array(2...maxGroups)
        }
        return options
    }

    var body: some View {
        if let groups, !groups.isEmpty {
            EventGroupAssignmentView(
                event: event,
                initialGroups: groups,
                presentProfiles: presentProfiles,
                session: session,
                api: api,
                onConfirmed: onConfirmed
            )
        } else if isLoadingGroups {
            VStack(spacing: 0) {
                groupHeader
                Spacer()
                ProgressView()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white.ignoresSafeArea())
            .task { await loadInitialState() }
        } else {
            pickerContent
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 0) {
            groupHeader

            Spacer()

            Text("Выберите количество групп")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.7))
                .padding(.bottom, 8)

            Picker("", selection: $selectedGroupCount) {
                ForEach(availableOptions, id: \.self) { option in
                    Text(option == 0 ? "Без групп" : "\(option)")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
            .onChange(of: selectedGroupCount) { _, newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                scheduleSave(newValue)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            nextButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.background)
        }
        .alert("Без групп", isPresented: $showsNoGroupsConfirmation) {
            Button("Подтвердить", role: .destructive) {
                Task { await confirm(groupCount: 0) }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Вы уверены, что хотите провести событие без групп?")
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var groupHeader: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            HStack(spacing: 0) {
                Button { dismiss() } label: {
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

                Text("Количество групп")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var nextButton: some View {
        Button {
            if selectedGroupCount == 0 {
                showsNoGroupsConfirmation = true
            } else {
                Task { await confirm(groupCount: selectedGroupCount) }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .frame(height: 54)

                if isConfirming {
                    ProgressView().tint(.white)
                } else {
                    Text("Далее")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isConfirming)
        .opacity(isConfirming ? 0.6 : 1)
    }

    private func loadInitialState() async {
        defer { isLoadingGroups = false }

        do {
            let fetchedGroups = try await session.performAuthorizedRequest { token in
                try await api.fetchGroups(eventID: event.id, token: token)
            }

            if !fetchedGroups.isEmpty {
                if passedPresentProfiles.isEmpty {
                    let items = (try? await session.performAuthorizedRequest { token in
                        try await api.fetchAttendance(eventID: event.id, token: token)
                    }) ?? []
                    presentProfiles = items.filter { $0.isPresent }.map { $0.profile }
                }
                groups = fetchedGroups
            } else {
                groups = []
            }
        } catch {
            groups = []
        }
    }

    private func scheduleSave(_ groupCount: Int) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            _ = try? await session.performAuthorizedRequest { token in
                try await api.saveGroupCountDraft(eventID: event.id, groupCount: groupCount, token: token)
            }
        }
    }

    private func confirm(groupCount: Int) async {
        isConfirming = true
        saveTask?.cancel()
        defer { isConfirming = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.confirmGrouping(eventID: event.id, groupCount: groupCount, token: token)
            }

            if (updatedEvent.status ?? "").lowercased() == "grouping" {
                let fetchedGroups = try await session.performAuthorizedRequest { token in
                    try await api.fetchGroups(eventID: event.id, token: token)
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    groups = fetchedGroups
                }
            } else {
                onConfirmed?(updatedEvent)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Group Assignment

struct EventGroupAssignmentView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventResponse
    let session: AppSession
    let api: EventAPIProtocol
    let onConfirmed: ((EventResponse) -> Void)?
    let presentProfiles: [ProfileResponse]

    @State private var groups: [EventGroup]
    @State private var currentGroupIndex: Int = 0
    @State private var showsLeaderPicker = false
    @State private var showsMemberPicker = false
    @State private var isConfirming = false
    @State private var errorMessage: String?

    init(
        event: EventResponse,
        initialGroups: [EventGroup],
        presentProfiles: [ProfileResponse],
        session: AppSession,
        api: EventAPIProtocol? = nil,
        onConfirmed: ((EventResponse) -> Void)? = nil
    ) {
        self.event = event
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.onConfirmed = onConfirmed
        self.presentProfiles = presentProfiles
        _groups = State(initialValue: initialGroups)
    }

    private var currentGroup: EventGroup? {
        guard currentGroupIndex < groups.count else { return nil }
        return groups[currentGroupIndex]
    }

    private var assignedProfileIDs: Set<Int> {
        var ids = Set<Int>()
        for group in groups {
            if let leaderID = group.leaderID { ids.insert(leaderID) }
            for member in group.members { ids.insert(member.profileID) }
        }
        return ids
    }

    private var unassignedProfiles: [ProfileResponse] {
        presentProfiles.filter { !assignedProfileIDs.contains($0.id) }
    }

    private var canConfirm: Bool {
        groups.allSatisfy { $0.leaderID != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            assignmentHeader

            if let group = currentGroup {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        leaderSection(group: group)
                        membersSection(group: group)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            confirmButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.background)
        }
        .sheet(isPresented: $showsLeaderPicker) {
            ProfilePickerSheet(
                title: "Выбрать лидера",
                profiles: unassignedProfiles
            ) { profile in
                Task { await setLeader(profileID: profile.id) }
            }
        }
        .sheet(isPresented: $showsMemberPicker) {
            ProfilePickerSheet(
                title: "Добавить участника",
                profiles: unassignedProfiles
            ) { profile in
                Task { await addMember(profileID: profile.id) }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var assignmentHeader: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea(edges: .top)

            HStack(spacing: 0) {
                Button { dismiss() } label: {
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

                HStack(spacing: 16) {
                    Button {
                        if currentGroupIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentGroupIndex -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(currentGroupIndex > 0 ? Color(red: 44/255, green: 67/255, blue: 102/255) : .clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentGroupIndex == 0)

                    Text("Группа \(currentGroupIndex + 1) из \(groups.count)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.78))

                    Button {
                        if currentGroupIndex < groups.count - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentGroupIndex += 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(currentGroupIndex < groups.count - 1 ? Color(red: 44/255, green: 67/255, blue: 102/255) : .clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentGroupIndex >= groups.count - 1)
                }

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func leaderSection(group: EventGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Лидер")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            if let leader = group.leader {
                HStack(spacing: 12) {
                    ParticipantAvatarView(avatarURL: leader.avatarURL, size: 48)

                    Text(leader.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.82, green: 0.62, blue: 0.07))

                    Button {
                        Task { await removeLeader() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color(.systemGray6).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Button {
                    showsLeaderPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

                        Text("Выбрать лидера")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.systemGray6).opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(unassignedProfiles.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func membersSection(group: EventGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Участники")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.55))

                Spacer()

                Button {
                    Task { await autoDistribute() }
                } label: {
                    Text("Авто")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(red: 44/255, green: 67/255, blue: 102/255), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            ForEach(group.members) { member in
                HStack(spacing: 12) {
                    ParticipantAvatarView(avatarURL: member.profile.avatarURL, size: 48)

                    Text(member.profile.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task { await removeMember(profileID: member.profileID) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color(.systemGray6).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                showsMemberPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

                    Text("Добавить участника")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.systemGray6).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(unassignedProfiles.isEmpty)
        }
    }

    private var confirmButton: some View {
        Button {
            Task { await confirmGroups() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(canConfirm
                          ? Color(red: 44/255, green: 67/255, blue: 102/255)
                          : Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.4))
                    .frame(height: 54)

                if isConfirming {
                    ProgressView().tint(.white)
                } else {
                    Text("Подтвердить группы")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isConfirming || !canConfirm)
    }

    private func updateGroup(_ updatedGroup: EventGroup) {
        if let index = groups.firstIndex(where: { $0.id == updatedGroup.id }) {
            groups[index] = updatedGroup
        }
    }

    private func setLeader(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updatedGroup = try await session.performAuthorizedRequest { token in
                try await api.setGroupLeader(
                    eventID: event.id,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroup(updatedGroup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeLeader() async {
        guard let group = currentGroup else { return }
        do {
            let updatedGroup = try await session.performAuthorizedRequest { token in
                try await api.removeGroupLeader(
                    eventID: event.id,
                    groupNumber: group.groupNumber,
                    token: token
                )
            }
            updateGroup(updatedGroup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addMember(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updatedGroup = try await session.performAuthorizedRequest { token in
                try await api.addGroupMember(
                    eventID: event.id,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroup(updatedGroup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updatedGroup = try await session.performAuthorizedRequest { token in
                try await api.removeGroupMember(
                    eventID: event.id,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroup(updatedGroup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func autoDistribute() async {
        do {
            let updatedGroups = try await session.performAuthorizedRequest { token in
                try await api.autoDistribute(eventID: event.id, token: token)
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                groups = updatedGroups
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmGroups() async {
        isConfirming = true
        defer { isConfirming = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.confirmGroups(eventID: event.id, token: token)
            }
            onConfirmed?(updatedEvent)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Profile Picker Sheet

private struct ProfilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let profiles: [ProfileResponse]
    let onSelect: (ProfileResponse) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(.systemGray6).ignoresSafeArea(edges: .top)

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))

                HStack {
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)
            .overlay(alignment: .bottom) { Divider() }

            if profiles.isEmpty {
                Spacer()
                Text("Все участники уже распределены")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.5))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(profiles) { profile in
                            Button {
                                onSelect(profile)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ParticipantAvatarView(avatarURL: profile.avatarURL, size: 46)

                                    Text(profile.displayName)
                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(14)
                                .background(Color(.systemGray6).opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
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
