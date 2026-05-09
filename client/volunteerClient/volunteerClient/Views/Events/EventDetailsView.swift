import SwiftUI

struct EventDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    private let session: AppSession?
    private let api: EventAPIProtocol
    @State private var currentEvent: EventResponse
    @State private var isParticipationLoading = false
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var showsParticipantsManagement = false
    @State private var showsAttendanceConfirmation = false
    @State private var showsGroupFlow = false
    @State private var showsChat = false
    @State private var showsCancelAlert = false
    @State private var showsDeleteAlert = false
    @State private var showsCancelEventPrompt = false
    @State private var cancelEventReason = ""
    @State private var showsFinishAlert = false

    private let eventImageSize: CGFloat = 56

    private let onEventCancelled: (() -> Void)?

    init(
        event: EventResponse,
        session: AppSession? = nil,
        api: EventAPIProtocol? = nil,
        onEventCancelled: (() -> Void)? = nil
    ) {
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.onEventCancelled = onEventCancelled
        _currentEvent = State(initialValue: event)
    }

    private var event: EventResponse {
        currentEvent
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    eventCard
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        .padding(.bottom, 24)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            await loadEventDetails()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Отменить заявку?", isPresented: $showsCancelAlert) {
            Button("Да, отменить", role: .destructive) {
                Task { await cancelApplication() }
            }
            Button("Нет", role: .cancel) { }
        } message: {
            Text("Желаете отменить заявку на участие в событии?")
        }
        .alert("Удалить событие?", isPresented: $showsDeleteAlert) {
            Button("Удалить", role: .destructive) {
                Task { await deleteEvent() }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Событие будет удалено у всех участников.")
        }
        .alert("Отменить событие", isPresented: $showsCancelEventPrompt) {
            TextField("Причина отмены", text: $cancelEventReason)
            Button("Подтвердить", role: .destructive) {
                let reason = cancelEventReason
                cancelEventReason = ""
                Task { await cancelEvent(reason: reason) }
            }
            Button("Назад", role: .cancel) {
                cancelEventReason = ""
            }
        } message: {
            Text("Укажите причину. Все участники получат уведомление.")
        }
        .overlay {
            if let message {
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.84))
                    )
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showsParticipantsManagement) {
            if let session {
                EventParticipantsManagementView(
                    eventID: event.id,
                    session: session,
                    participantsOnly: isAlmostStarting
                )
            }
        }
        .fullScreenCover(isPresented: $showsAttendanceConfirmation) {
            if let session {
                EventAttendanceConfirmationView(
                    eventID: event.id,
                    session: session,
                    isRestoring: isInAttendancePhase
                ) { updatedEvent in
                    currentEvent = updatedEvent
                    showMessage(updatedEvent.message ?? "Событие началось")
                }
            }
        }
        .fullScreenCover(isPresented: $showsGroupFlow) {
            if let session {
                EventGroupFlowView(
                    eventID: event.id,
                    session: session
                ) { updatedEvent in
                    currentEvent = updatedEvent
                    showMessage(updatedEvent.message ?? "Событие началось")
                }
            }
        }
        .fullScreenCover(isPresented: $showsChat) {
            if let session {
                EventChatRouterView(
                    eventID: event.id,
                    session: session,
                    api: api
                )
            }
        }
        .alert("Завершить событие?", isPresented: $showsFinishAlert) {
            Button("Завершить", role: .destructive) {
                Task { await finishEvent() }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Событие будет завершено для всех участников.")
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            HStack(spacing: 0) {
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

                Text("Детали события")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)

                if event.isCreator == true, session != nil {
                    HStack(spacing: 10) {
                        listButton
                        if isAlmostStarting {
                            trashButton
                        }
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var trashButton: some View {
        Button {
            showsDeleteAlert = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .stroke(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.4), lineWidth: 1)
                        .background(Circle().fill(Color.clear))
                )
        }
        .buttonStyle(.plain)
    }

    private var listButton: some View {
        Button {
            showsParticipantsManagement = true
        } label: {
            Image(systemName: "list.bullet.rectangle")
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
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBlock

            if !displayDirection.isEmpty {
                directionRow
                    .padding(.top, 18)
            }

            if !displayDescription.isEmpty {
                Text(displayDescription)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .lineSpacing(8)
                    .padding(.top, displayDirection.isEmpty ? 26 : 18)
            }

            infoBlock
                .padding(.top, 30)

            bottomMetaBlock
                .padding(.top, 28)

            if shouldShowParticipationButton {
                participationButton
                    .padding(.top, 22)
            }

            if event.isCreator == true, (isAlmostStarting || isInAttendancePhase || isInGroupingPhase), session != nil {
                organizerStartRow
                    .padding(.top, 22)
            }

            if isActivePhase, event.isCreator == true, session != nil {
                organizerActiveRow
                    .padding(.top, 22)
            }

            if isActivePhase, session != nil,
               event.isCreator == true || event.userApplicationStatus == "accepted" {
                chatButton
                    .padding(.top, 22)
            }
        }
    }

    private var eventPhotoView: some View {
        ZStack {
            Circle()
                .fill(Color(red: 18/255, green: 162/255, blue: 231/255).opacity(0.12))

            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholderPhoto
                    @unknown default:
                        placeholderPhoto
                    }
                }
            } else {
                placeholderPhoto
            }
        }
        .frame(width: eventImageSize, height: eventImageSize)
        .clipShape(Circle())
    }

    private var placeholderPhoto: some View {
        Image(systemName: "calendar")
            .font(.system(size: 26, weight: .semibold))
            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
    }

    private var topBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            eventPhotoView

            Text(displayTitle)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(
                icon: "mappin.and.ellipse",
                text: displayLocation
            )

            infoRow(
                icon: "calendar",
                text: displayDateRange
            )

            infoRow(
                icon: "clock",
                text: displayTimeRange
            )
        }
    }

    private var bottomMetaBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                volunteersAvailabilityBlock

                Text("Дата создания: \(displayCreatedDate)")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Организатор:")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.48))

                Text(displayOrganizer)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 90, alignment: .leading)
        }
    }

    private var volunteersAvailabilityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                if remainingSlots == 0 {
                    Text("Волонтёры: ")
                        .foregroundColor(.black.opacity(0.62))

                    Text("\(acceptedParticipants)/\(event.volunteersNeeded)")
                        .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

                    Text(" набрано")
                        .foregroundColor(.black.opacity(0.62))
                } else {
                    Text("\(remainingSlots)/\(event.volunteersNeeded)")
                        .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

                    Text(" волонтёров нужно")
                        .foregroundColor(.black.opacity(0.62))
                }
            }
            .font(.system(size: 14, weight: .regular, design: .serif))

            Rectangle()
                .fill(Color(red: 58/255, green: 145/255, blue: 233/255).opacity(0.75))
                .frame(height: 1)
        }
    }

    private var participationButton: some View {
        Button {
            if event.userApplicationStatus == "pending" {
                showsCancelAlert = true
            } else {
                Task { await applyToEvent() }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(participationButtonBackground)
                    .overlay(
                        Group {
                            if event.userApplicationStatus == "pending" {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.5), lineWidth: 1)
                            }
                        }
                    )

                if isParticipationLoading {
                    ProgressView()
                        .tint(participationButtonForeground)
                } else {
                    Text(participationButtonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(participationButtonForeground)
                }
            }
            .frame(width: 220, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(isParticipationButtonDisabled)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var chatButton: some View {
        Button {
            showsChat = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Открыть чат")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    private var organizerStartRow: some View {
        HStack(spacing: 10) {
            Button {
                if isInGroupingPhase {
                    showsGroupFlow = true
                } else {
                    showsAttendanceConfirmation = true
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                    Text(isInGroupingPhase ? "Расстановка групп" : isInAttendancePhase ? "Продолжить отметку" : "Начать")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.plain)

            Button {
                cancelEventReason = ""
                showsCancelEventPrompt = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.5), lineWidth: 1)
                        )

                    Text("Отменить")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.plain)
            .disabled(isParticipationLoading)
        }
    }

    private var organizerActiveRow: some View {
        VStack(spacing: 10) {
            Button {
                showsGroupFlow = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                    Text("Редактировать группы")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.plain)

            Button {
                showsFinishAlert = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(red: 0.80, green: 0.20, blue: 0.20).opacity(0.5), lineWidth: 1)
                        )
                    Text("Завершить событие")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.80, green: 0.20, blue: 0.20))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private var isAlmostStarting: Bool {
        Date() >= startDate.addingTimeInterval(-30 * 60)
    }

    private var isInAttendancePhase: Bool {
        event.status?.lowercased() == "attendance"
    }

    private var isInGroupingPhase: Bool {
        event.status?.lowercased() == "grouping"
    }

    private var isActivePhase: Bool {
        event.status?.lowercased() == "active"
    }

    private var participationButtonBackground: Color {
        switch event.userApplicationStatus {
        case "pending":
            return Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.10)
        case "accepted":
            return Color(red: 44/255, green: 67/255, blue: 102/255)
        default:
            if isParticipationButtonDisabled {
                return Color.gray.opacity(0.28)
            }
            return Color(red: 44/255, green: 67/255, blue: 102/255)
        }
    }

    private var participationButtonForeground: Color {
        switch event.userApplicationStatus {
        case "pending":
            return Color(red: 44/255, green: 67/255, blue: 102/255)
        case "accepted":
            return .white
        default:
            if isParticipationButtonDisabled {
                return .black.opacity(0.42)
            }
            return .white
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private var directionRow: some View {
        HStack(spacing: 8) {
            Text("Направление:")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Text(displayDirection)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var displayTitle: String {
        let value = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var displayDescription: String {
        event.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayDirection: String {
        event.direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var displayLocation: String {
        let location = event.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !location.isEmpty {
            return location
        }

        return "\(event.country), \(event.city)"
    }

    private var displayDateRange: String {
        EventDateDisplayFormatter.dateRangeText(start: startDate, end: endDate)
    }

    private var displayTimeRange: String {
        EventDateDisplayFormatter.timeRangeText(start: startDate, end: endDate)
    }

    private var remainingSlots: Int {
        max(event.volunteersNeeded - acceptedParticipants, 0)
    }

    private var acceptedParticipants: Int {
        min(max(event.acceptedCount ?? 0, 0), event.volunteersNeeded)
    }

    private var participationButtonTitle: String {
        switch event.userApplicationStatus {
        case "accepted":
            return "Вы участник"
        case "pending":
            return "На рассмотрении"
        case "rejected":
            return "Заявка отклонена"
        default:
            if remainingSlots <= 0 {
                return "Мест нет"
            }
            return "Участвовать"
        }
    }

    private var shouldShowParticipationButton: Bool {
        event.isCreator != true
    }

    private var isParticipationButtonDisabled: Bool {
        isParticipationLoading
            || session == nil
            || event.userApplicationStatus == "accepted"
            || event.userApplicationStatus == "rejected"
            || remainingSlots <= 0
    }

    private func loadEventDetails() async {
        guard let session else { return }

        do {
            currentEvent = try await session.performAuthorizedRequest { token in
                try await api.fetchEvent(id: currentEvent.id, token: token)
            }
        } catch {
            return
        }
    }

    private func applyToEvent() async {
        guard let session else { return }

        isParticipationLoading = true
        errorMessage = nil
        defer { isParticipationLoading = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.applyToEvent(id: currentEvent.id, token: token)
            }
            currentEvent = updatedEvent
            showMessage(updatedEvent.message ?? "Заявка отправлена")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent() async {
        guard let session else { return }

        do {
            try await session.performAuthorizedRequest { token in
                try await api.deleteEvent(id: currentEvent.id, token: token)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startEvent() async {
        guard let session else { return }

        isParticipationLoading = true
        errorMessage = nil
        defer { isParticipationLoading = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.startEvent(id: currentEvent.id, token: token)
            }
            currentEvent = updatedEvent
            showMessage(updatedEvent.message ?? "Событие началось")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelEvent(reason: String) async {
        guard let session else { return }

        isParticipationLoading = true
        errorMessage = nil
        defer { isParticipationLoading = false }

        do {
            try await session.performAuthorizedRequest { token in
                try await api.cancelEvent(id: currentEvent.id, reason: reason, token: token)
            }
            onEventCancelled?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelApplication() async {
        guard let session else { return }

        isParticipationLoading = true
        errorMessage = nil
        defer { isParticipationLoading = false }

        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.cancelApplication(eventID: currentEvent.id, token: token)
            }
            currentEvent = updatedEvent
            showMessage(updatedEvent.message ?? "Заявка отменена")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishEvent() async {
        guard let session else { return }
        do {
            let updatedEvent = try await session.performAuthorizedRequest { token in
                try await api.finishEvent(id: currentEvent.id, token: token)
            }
            currentEvent = updatedEvent
            showMessage(updatedEvent.message ?? "Событие завершено")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showMessage(_ value: String) {
        message = value
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if message == value {
                message = nil
            }
        }
    }

    private var displayCreatedDate: String {
        let date = createdDate ?? startDate
        return Self.createdDateFormatter.string(from: date)
    }

    private var displayOrganizer: String {
        let value = event.organizerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Не указано" : value
    }

    private var photoURL: URL? {
        guard let photoURL = event.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !photoURL.isEmpty else {
            return nil
        }

        if let url = URL(string: photoURL), url.scheme != nil {
            return url
        }

        guard let baseURL = URL(string: AppConfig.baseURLString) else {
            return nil
        }

        let path = photoURL.hasPrefix("/") ? String(photoURL.dropFirst()) : photoURL
        return baseURL.appendingPathComponent(path)
    }

    private var startDate: Date {
        Self.isoFormatter.date(from: event.startsAt) ?? Date()
    }

    private var endDate: Date? {
        guard let value = event.endsAt else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private var createdDate: Date? {
        guard let value = event.createdAt else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

#Preview {
    EventDetailsView(
        event: EventResponse(
            id: "1",
            title: "Музыкальный фестиваль",
            direction: EventDirectionOption.culture.rawValue,
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
            acceptedCount: 1,
            status: "pending",
            message: nil,
            organizerName: "Анна Иванова",
            createdAt: "2026-04-24T09:00:00Z"
        )
    )
}
