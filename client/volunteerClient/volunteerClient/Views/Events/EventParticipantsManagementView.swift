import SwiftUI
import Combine
import PhotosUI

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
    @State private var selectedProfile: ProfileResponse? = nil

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
            EventGroupFlowView(
                eventID: eventID,
                session: session,
                api: api,
                presentProfiles: attendanceItems
                    .filter { presentIDs.contains($0.applicationID) }
                    .map { $0.profile },
                onBack: { withAnimation(.easeInOut(duration: 0.25)) { self.groupingEvent = nil } },
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
        .fullScreenCover(item: $selectedProfile) { profile in
            ParticipantProfileDetailsView(profile: profile)
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
            Button {
                selectedProfile = item.profile
            } label: {
                HStack(spacing: 14) {
                    ParticipantAvatarView(avatarURL: item.profile.avatarURL, size: 52)

                    Text(item.profile.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

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
            let serverPresent = Set(items.filter { $0.isPresent }.map { $0.applicationID })
            // If no one is marked present yet (fresh start), default to everyone present
            presentIDs = serverPresent.isEmpty ? Set(items.map { $0.applicationID }) : serverPresent
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
                        ? Color(red: 209/255, green: 252/255, blue: 189/255)
                        : Color(red: 255/255, green: 156/255, blue: 156/255))
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

// MARK: - Group Flow

struct EventGroupFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol
    private let passedPresentProfiles: [ProfileResponse]
    let onBack: (() -> Void)?
    let onConfirmed: ((EventResponse) -> Void)?

    @State private var phase: Phase = .list
    @State private var resolvedProfiles: [ProfileResponse] = []

    private enum Phase {
        case list
        case groupEdit(EventGroup)
        case chat
    }

    init(
        eventID: String,
        session: AppSession,
        api: EventAPIProtocol? = nil,
        presentProfiles: [ProfileResponse] = [],
        onBack: (() -> Void)? = nil,
        onConfirmed: ((EventResponse) -> Void)? = nil
    ) {
        self.eventID = eventID
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.passedPresentProfiles = presentProfiles
        self.onBack = onBack
        self.onConfirmed = onConfirmed
    }

    var body: some View {
        Group {
            switch phase {
            case .list:
                EventGroupListView(
                    eventID: eventID,
                    session: session,
                    api: api,
                    presentProfiles: resolvedProfiles,
                    onBack: onBack,
                    onGroupSelected: { group in
                        withAnimation(.easeInOut(duration: 0.25)) { phase = .groupEdit(group) }
                    },
                    onConfirmed: { event in
                        onConfirmed?(event)
                        withAnimation(.easeInOut(duration: 0.25)) { phase = .chat }
                    }
                )
            case .groupEdit(let group):
                EventSingleGroupEditView(
                    eventID: eventID,
                    initialGroup: group,
                    session: session,
                    api: api,
                    presentProfiles: resolvedProfiles,
                    onBack: {
                        if let onBack { onBack() } else { dismiss() }
                    },
                    onGoToList: {
                        withAnimation(.easeInOut(duration: 0.25)) { phase = .list }
                    },
                    onDone: { event in
                        onConfirmed?(event)
                        withAnimation(.easeInOut(duration: 0.25)) { phase = .chat }
                    }
                )
            case .chat:
                EventChatRouterView(
                    eventID: eventID,
                    session: session,
                    api: api
                )
            }
        }
        .task {
            if passedPresentProfiles.isEmpty {
                let items = (try? await session.performAuthorizedRequest { token in
                    try await api.fetchAttendance(eventID: eventID, token: token)
                }) ?? []
                resolvedProfiles = items.filter { $0.isPresent }.map { $0.profile }
            } else {
                resolvedProfiles = passedPresentProfiles
            }
        }
    }
}

// MARK: - Group List

private struct EventGroupListView: View {
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol
    let presentProfiles: [ProfileResponse]
    let onBack: (() -> Void)?
    let onGroupSelected: (EventGroup) -> Void
    let onConfirmed: (EventResponse) -> Void

    @State private var groups: [EventGroup] = []
    @State private var isLoading = false
    @State private var isAdding = false
    @State private var isConfirming = false
    @State private var showsConfirmAlert = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            listHeader

            if isLoading && groups.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if groups.isEmpty {
                Spacer()
                Text("Групп нет")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(groups) { group in
                            groupRow(group)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
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
        .task { await loadGroups() }
        .alert("Вы уверены?", isPresented: $showsConfirmAlert) {
            Button("Подтвердить", role: .destructive) {
                Task { await doConfirm() }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Группы не будут созданы. Все участники будут в одном общем чате.")
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

    private var listHeader: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea(edges: .top)

            Text("Создание групп")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
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

                Button {
                    Task { await addGroup() }
                } label: {
                    if isAdding {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                    .background(Circle().fill(Color.clear))
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func groupRow(_ group: EventGroup) -> some View {
        Button {
            onGroupSelected(group)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.12))
                        .frame(width: 44, height: 44)

                    Text("\(group.groupNumber)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Группа \(group.groupNumber)")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

                    let count = group.members.count + (group.leaderID != nil ? 1 : 0)
                    Text(count == 0 ? "Пусто" : "\(count) чел.")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await deleteGroup(group) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10)))
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(14)
            .background(Color(.systemGray6).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var confirmButton: some View {
        Button {
            if groups.isEmpty {
                showsConfirmAlert = true
            } else {
                Task { await doConfirm() }
            }
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
        .disabled(isConfirming || isAdding)
        .opacity((isConfirming || isAdding) ? 0.6 : 1)
    }

    private func loadGroups() async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await session.performAuthorizedRequest { token in
                try await api.fetchGroups(eventID: eventID, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addGroup() async {
        isAdding = true
        defer { isAdding = false }
        do {
            let newGroup = try await session.performAuthorizedRequest { token in
                try await api.addGroup(eventID: eventID, token: token)
            }
            groups.append(newGroup)
            onGroupSelected(newGroup)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteGroup(_ group: EventGroup) async {
        do {
            try await session.performAuthorizedRequest { token in
                try await api.deleteGroup(eventID: eventID, groupNumber: group.groupNumber, token: token)
            }
            groups.removeAll { $0.id == group.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func doConfirm() async {
        isConfirming = true
        defer { isConfirming = false }
        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.confirmGroups(eventID: eventID, token: token)
            }
            onConfirmed(updatedEvent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Single Group Edit

private struct EventSingleGroupEditView: View {
    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol
    let presentProfiles: [ProfileResponse]
    let initialGroup: EventGroup
    let onBack: () -> Void
    let onGoToList: () -> Void
    let onDone: (EventResponse) -> Void

    @State private var allGroups: [EventGroup] = []
    @State private var currentGroupIndex: Int = 0
    @State private var showsLeaderPicker = false
    @State private var showsMemberPicker = false
    @State private var showsDeleteAlert = false
    @State private var isAdding = false
    @State private var isDeleting = false
    @State private var isClearing = false
    @State private var showsAutoSheet = false
    @State private var autoFillCount: Int = 1
    @State private var isAutoFilling = false
    @State private var isConfirming = false
    @State private var errorMessage: String?

    init(
        eventID: String,
        initialGroup: EventGroup,
        session: AppSession,
        api: EventAPIProtocol,
        presentProfiles: [ProfileResponse],
        onBack: @escaping () -> Void,
        onGoToList: @escaping () -> Void,
        onDone: @escaping (EventResponse) -> Void
    ) {
        self.eventID = eventID
        self.initialGroup = initialGroup
        self.session = session
        self.api = api
        self.presentProfiles = presentProfiles
        self.onBack = onBack
        self.onGoToList = onGoToList
        self.onDone = onDone
    }

    private var canAddGroup: Bool {
        let emptyGroups = allGroups.filter { $0.leaderID == nil && $0.members.isEmpty }.count
        return unassignedProfiles.count >= 2 * (emptyGroups + 1)
    }

    private var currentGroup: EventGroup? {
        guard currentGroupIndex < allGroups.count else { return nil }
        return allGroups[currentGroupIndex]
    }

    private var assignedProfileIDs: Set<Int> {
        var ids = Set<Int>()
        for g in allGroups {
            if let leaderID = g.leaderID { ids.insert(leaderID) }
            for member in g.members { ids.insert(member.profileID) }
        }
        return ids
    }

    private var unassignedProfiles: [ProfileResponse] {
        presentProfiles.filter { !assignedProfileIDs.contains($0.id) }
    }

    private var canConfirm: Bool {
        !allGroups.isEmpty && allGroups.allSatisfy { $0.leaderID != nil && !$0.members.isEmpty }
    }

    private var autoFillMax: Int {
        guard let group = currentGroup else { return 0 }
        let others = allGroups.filter { $0.groupNumber != group.groupNumber }
        let occupiedSlots = others.reduce(0) { $0 + max(1, $1.members.count) }
        return max(0, presentProfiles.count - allGroups.count - occupiedSlots)
    }

    private var autoFillDefault: Int {
        guard let group = currentGroup else { return 1 }
        let others = allGroups.filter { $0.groupNumber != group.groupNumber }
        let actualSlots = others.reduce(0) { $0 + $1.members.count }
        let raw = Double(presentProfiles.count - allGroups.count - actualSlots) / 2.0
        return min(autoFillMax, max(1, Int(ceil(raw))))
    }

    var body: some View {
        VStack(spacing: 0) {
            editHeader
            groupNavRow

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
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) * 1.5, abs(h) > 40 else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if h < 0 {
                            currentGroupIndex = min(currentGroupIndex + 1, allGroups.count - 1)
                        } else {
                            currentGroupIndex = max(currentGroupIndex - 1, 0)
                        }
                    }
                }
        )
        .safeAreaInset(edge: .bottom) {
            confirmButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.background)
        }
        .task { await loadAllGroups() }
        .sheet(isPresented: $showsLeaderPicker) {
            ProfilePickerSheet(title: "Выбрать лидера", profiles: unassignedProfiles) { profile in
                Task { await setLeader(profileID: profile.id) }
            }
        }
        .sheet(isPresented: $showsMemberPicker) {
            ProfilePickerSheet(title: "Добавить участника", profiles: unassignedProfiles) { profile in
                Task { await addMember(profileID: profile.id) }
            }
        }
        .sheet(isPresented: $showsAutoSheet) {
            autoFillSheet
                .presentationDetents([.fraction(0.25)])
                .presentationDragIndicator(.hidden)
        }
        .alert("Удалить группу?", isPresented: $showsDeleteAlert) {
            Button("Удалить", role: .destructive) {
                Task { await deleteCurrentGroup() }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Вы уверены? Группа будет удалена.")
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

    private var editHeader: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea(edges: .top)

            Text("Создание групп")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button { onBack() } label: {
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

                Button {
                    Task { await addGroup() }
                } label: {
                    if isAdding {
                        ProgressView().frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(canAddGroup ? .black.opacity(0.75) : .black.opacity(0.22))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .stroke(
                                        canAddGroup ? Color.black.opacity(0.35) : Color.black.opacity(0.15),
                                        lineWidth: 1
                                    )
                                    .background(Circle().fill(Color.clear))
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canAddGroup || isAdding)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var groupNavRow: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { currentGroupIndex -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .opacity(currentGroupIndex > 0 ? 1 : 0)
            .disabled(currentGroupIndex == 0)

            Spacer()

            if let group = currentGroup {
                HStack(spacing: 10) {
                    Text("Группа \(group.groupNumber)")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.78))

                    Button {
                        showsDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { currentGroupIndex += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .opacity(currentGroupIndex < allGroups.count - 1 ? 1 : 0)
            .disabled(currentGroupIndex >= allGroups.count - 1)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(Color(.systemGray6).opacity(0.4))
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
                        .foregroundColor(Color(red: 0.22, green: 0.44, blue: 0.87))

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
                Button { showsLeaderPicker = true } label: {
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
                    Task { await clearMembers(group: group) }
                } label: {
                    Image(systemName: "xmark.bin")
                        .font(.system(size: 15))
                        .foregroundColor(
                            group.members.isEmpty
                                ? Color(.systemGray3)
                                : Color(red: 0.80, green: 0.20, blue: 0.20)
                        )
                }
                .buttonStyle(.plain)
                .disabled(group.members.isEmpty || isClearing)
                .padding(.trailing, 10)

                Button {
                    autoFillCount = autoFillDefault
                    showsAutoSheet = true
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
                .disabled(autoFillMax == 0)
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

            Button { showsMemberPicker = true } label: {
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
        }
    }

    private var confirmButton: some View {
        Button {
            Task { await confirmAllGroups() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        canConfirm
                            ? Color(red: 44/255, green: 67/255, blue: 102/255)
                            : Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.4)
                    )
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
        .disabled(!canConfirm || isConfirming)
    }

    private func loadAllGroups() async {
        do {
            let fetched = try await session.performAuthorizedRequest { token in
                try await api.fetchGroups(eventID: eventID, token: token)
            }
            allGroups = fetched
            if let idx = fetched.firstIndex(where: { $0.id == initialGroup.id }) {
                currentGroupIndex = idx
            }
        } catch { }
    }

    private func updateGroupState(_ updated: EventGroup) {
        if let index = allGroups.firstIndex(where: { $0.id == updated.id }) {
            allGroups[index] = updated
        }
    }

    private func addGroup() async {
        isAdding = true
        defer { isAdding = false }
        do {
            let newGroup = try await session.performAuthorizedRequest { token in
                try await api.addGroup(eventID: eventID, token: token)
            }
            allGroups.append(newGroup)
            withAnimation(.easeInOut(duration: 0.2)) {
                currentGroupIndex = allGroups.count - 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCurrentGroup() async {
        guard let group = currentGroup else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await session.performAuthorizedRequest { token in
                try await api.deleteGroup(eventID: eventID, groupNumber: group.groupNumber, token: token)
            }
            let fetched = try await session.performAuthorizedRequest { token in
                try await api.fetchGroups(eventID: eventID, token: token)
            }
            if fetched.isEmpty {
                onGoToList()
            } else {
                allGroups = fetched
                currentGroupIndex = max(0, currentGroupIndex - 1)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setLeader(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updated = try await session.performAuthorizedRequest { token in
                try await api.setGroupLeader(
                    eventID: eventID,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroupState(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeLeader() async {
        guard let group = currentGroup else { return }
        do {
            let updated = try await session.performAuthorizedRequest { token in
                try await api.removeGroupLeader(
                    eventID: eventID,
                    groupNumber: group.groupNumber,
                    token: token
                )
            }
            updateGroupState(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addMember(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updated = try await session.performAuthorizedRequest { token in
                try await api.addGroupMember(
                    eventID: eventID,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroupState(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(profileID: Int) async {
        guard let group = currentGroup else { return }
        do {
            let updated = try await session.performAuthorizedRequest { token in
                try await api.removeGroupMember(
                    eventID: eventID,
                    groupNumber: group.groupNumber,
                    profileID: profileID,
                    token: token
                )
            }
            updateGroupState(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearMembers(group: EventGroup) async {
        isClearing = true
        defer { isClearing = false }
        var current = group
        for member in group.members {
            do {
                current = try await session.performAuthorizedRequest { token in
                    try await api.removeGroupMember(
                        eventID: eventID,
                        groupNumber: group.groupNumber,
                        profileID: member.profileID,
                        token: token
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }
        updateGroupState(current)
    }

    @ViewBuilder
    private var autoFillSheet: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Автозаполнение")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

                HStack {
                    Spacer()
                    Button("Отмена") {
                        showsAutoSheet = false
                    }
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            HStack(spacing: 16) {
                Picker("", selection: $autoFillCount) {
                    ForEach(1...max(1, autoFillMax), id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                .clipped()

                Button {
                    showsAutoSheet = false
                    Task { await applyAutoFill() }
                } label: {
                    if isAutoFilling {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Text("Принять")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAutoFilling || autoFillMax == 0)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }

    private func applyAutoFill() async {
        guard let group = currentGroup else { return }
        isAutoFilling = true
        defer { isAutoFilling = false }
        let toAdd = Array(unassignedProfiles.prefix(autoFillCount))
        var current = group
        for profile in toAdd {
            do {
                current = try await session.performAuthorizedRequest { token in
                    try await api.addGroupMember(eventID: eventID, groupNumber: group.groupNumber,
                        profileID: profile.id, token: token)
                }
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }
        updateGroupState(current)
    }

    private func confirmAllGroups() async {
        isConfirming = true
        defer { isConfirming = false }
        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.confirmGroups(eventID: eventID, token: token)
            }
            onDone(updatedEvent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Event Chat Router

struct EventChatRouterView: View {
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let session: AppSession
    let api: EventAPIProtocol

    @State private var chatRooms: [ChatRoom] = []
    @State private var isLoading = true
    @State private var selectedRoom: ChatRoom?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let room = selectedRoom {
                EventChatView(chatRoom: room, session: session, api: api)
            } else {
                routerBody
            }
        }
        .task { await loadChats() }
    }

    private var routerBody: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(.systemGray6).ignoresSafeArea(edges: .top)
                Text("Чаты")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .frame(width: 36, height: 36)
                            .background(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 60)
            .overlay(alignment: .bottom) { Divider() }

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(chatRooms) { room in
                            Button { selectedRoom = room } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.12))
                                        Image(systemName: room.type == "leaders" ? "star.fill" : "bubble.left.and.bubble.right.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                    }
                                    .frame(width: 48, height: 48)

                                    Text(room.title)
                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.3))
                                }
                                .padding(14)
                                .background(Color(.systemGray6).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadChats() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rooms = try await session.performAuthorizedRequest { token in
                try await api.fetchChats(eventID: eventID, token: token)
            }
            chatRooms = rooms
            if rooms.count == 1 { selectedRoom = rooms.first }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Event Chat

struct EventChatView: View {
    @Environment(\.dismiss) private var dismiss

    let chatRoom: ChatRoom
    let session: AppSession
    let api: EventAPIProtocol

    private var eventID: String { chatRoom.eventID }

    @State private var messages: [ChatMessage] = []
    @State private var participants: [EventParticipantResponse] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var showsParticipantList = false
    @State private var selectedProfile: ProfileResponse?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageList
            Divider()
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .task {
            await loadParticipants()
            await loadMessages()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                await loadMessages()
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await sendPhoto(item) }
        }
        .sheet(isPresented: $showsParticipantList) {
            participantListSheet
        }
        .fullScreenCover(item: $selectedProfile) { profile in
            ParticipantProfileDetailsView(profile: profile)
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

    private var chatHeader: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea(edges: .top)

            Button {
                showsParticipantList = true
            } label: {
                HStack(spacing: 6) {
                    Text(chatRoom.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.78))
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            HStack {
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
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { message in
                        ChatBubbleView(message: message) {
                            selectedProfile = message.profile
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages) { _, newMessages in
                if let lastID = newMessages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .frame(width: 36, height: 36)
            }

            TextField("Сообщение...", text: $inputText, axis: .vertical)
                .font(.system(size: 16, design: .serif))
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            Button {
                Task { await sendText() }
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(.systemGray3)
                                : Color(red: 44/255, green: 67/255, blue: 102/255)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    private var participantListSheet: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(.systemGray6).ignoresSafeArea(edges: .top)

                Text("Участники")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))

                HStack {
                    Spacer()
                    Button("Закрыть") { showsParticipantList = false }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 56)
            .overlay(alignment: .bottom) { Divider() }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(participants) { participant in
                        HStack(spacing: 12) {
                            ParticipantAvatarView(avatarURL: participant.profile.avatarURL, size: 46)

                            Text(participant.profile.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if participant.isCreator {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.22, green: 0.44, blue: 0.87))
                            }
                        }
                        .padding(14)
                        .background(Color(.systemGray6).opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func loadMessages() async {
        do {
            let fetched = try await session.performAuthorizedRequest { token in
                try await api.fetchChatMessages(eventID: eventID, chatID: chatRoom.id, token: token)
            }
            if fetched != messages { messages = fetched }
        } catch { }
    }

    private func loadParticipants() async {
        do {
            participants = try await session.performAuthorizedRequest { token in
                try await api.fetchEventApplications(eventID: eventID, token: token)
            }
        } catch { }
    }

    private func sendText() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isSending = true
        defer { isSending = false }
        do {
            let msg = try await session.performAuthorizedRequest { token in
                try await api.sendChatMessage(eventID: eventID, chatID: chatRoom.id, content: text, photoURL: nil, token: token)
            }
            messages.append(msg)
        } catch {
            inputText = text
            errorMessage = error.localizedDescription
        }
    }

    private func sendPhoto(_ item: PhotosPickerItem) async {
        selectedPhoto = nil
        isSending = true
        defer { isSending = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let photoURL = try await session.performAuthorizedRequest { token in
                try await api.uploadMessagePhoto(data: data, token: token)
            }
            let msg = try await session.performAuthorizedRequest { token in
                try await api.sendChatMessage(eventID: eventID, chatID: chatRoom.id, content: nil, photoURL: photoURL, token: token)
            }
            messages.append(msg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage
    let onTapProfile: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onTapProfile) {
                ParticipantAvatarView(avatarURL: message.profile.avatarURL, size: 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button(action: onTapProfile) {
                        Text(message.leaderLabel ?? message.profile.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    }
                    .buttonStyle(.plain)

                    if message.isOrganizer || message.isLeader == true {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.22, green: 0.44, blue: 0.87))
                    }
                }

                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.black.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                }

                if let photoURL = message.photoURL, let url = resolvedURL(photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        case .empty:
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray5))
                                .frame(width: 120, height: 90)
                                .overlay(ProgressView())
                        case .failure:
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray5))
                                .frame(width: 120, height: 90)
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                Text(formattedTime(message.createdAt))
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.black.opacity(0.4))
            }

            Spacer(minLength: 60)
        }
    }

    private func resolvedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        guard let base = URL(string: AppConfig.baseURLString) else { return nil }
        let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        return base.appendingPathComponent(path)
    }

    private func formattedTime(_ isoString: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: isoString) {
            let d = DateFormatter(); d.dateFormat = "HH:mm"
            return d.string(from: date)
        }
        f.formatOptions = [.withInternetDateTime]
        guard let date = f.date(from: isoString) else { return "" }
        let d = DateFormatter(); d.dateFormat = "HH:mm"
        return d.string(from: date)
    }
}

// MARK: - Profile Picker Sheet

private struct ProfilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let profiles: [ProfileResponse]
    let onSelect: (ProfileResponse) -> Void

    @State private var searchText = ""

    private var filtered: [ProfileResponse] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return profiles }
        return profiles.filter { profile in
            let lastName = (profile.lastName ?? "").lowercased()
            let firstName = (profile.firstName ?? "").lowercased()
            let orgName = (profile.organizationName ?? "").lowercased()
            return lastName.hasPrefix(query)
                || firstName.hasPrefix(query)
                || orgName.contains(query)
        }
    }

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
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))

                    TextField("Поиск по фамилии", text: $searchText)
                        .font(.system(size: 15, design: .serif))
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.black.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                if filtered.isEmpty {
                    Spacer()
                    Text("Ничего не найдено")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { profile in
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
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                    }
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
            about: "Готова помогать на городских событиях.", rating: 92
        )
    )
}
