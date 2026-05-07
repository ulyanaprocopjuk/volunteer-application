import SwiftUI

struct MyEventsView: View {
    @ObservedObject var viewModel: MyEventsViewModel
    let session: AppSession
    var onEventCancelled: (() -> Void)? = nil
    let onCreateEvent: () -> Void

    @State private var selectedEvent: EventResponse?
    @State private var selectedSegment: MyEventsSegment = .active

    var body: some View {
        VStack(spacing: 0) {
            headerView
            segmentControl
                .padding(.horizontal, 20)
                .padding(.top, 14)

            if viewModel.isLoading && viewModel.events.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if visibleEvents.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleEvents) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                MyEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 140)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .task {
            await viewModel.loadMyEvents(filter: selectedSegment.apiFilter)
        }
        .onChange(of: selectedSegment) { _, newValue in
            Task {
                await viewModel.loadMyEvents(filter: newValue.apiFilter)
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $selectedEvent) { event in
            EventDetailsView(event: event, session: session, onEventCancelled: {
                selectedEvent = nil
                onEventCancelled?()
            })
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(MyEventsSegment.allCases, id: \.self) { segment in
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

    private var visibleEvents: [EventResponse] {
        switch selectedSegment {
        case .active:
            return viewModel.events.filter { event in
                event.myEventsModerationStatus == .approved && !event.hasExpired
            }
        case .history:
            return viewModel.events.filter { event in
                event.myEventsModerationStatus == .rejected
                    || event.myEventsModerationStatus == .completed
                    || event.myEventsModerationStatus == .cancelled
                    || (event.myEventsModerationStatus == .approved && event.hasExpired)
            }
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Мои события")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button(action: onCreateEvent) {
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(selectedSegment.emptyText)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum MyEventsSegment: CaseIterable {
    case active
    case history

    var title: String {
        switch self {
        case .active:
            return "Активные"
        case .history:
            return "История"
        }
    }

    var emptyText: String {
        switch self {
        case .active:
            return "Нет активных событий"
        case .history:
            return "История событий пуста"
        }
    }

    var apiFilter: MyEventsFilter {
        switch self {
        case .active:
            return .active
        case .history:
            return .history
        }
    }
}

struct MyEventCard: View {
    let event: EventResponse

    private let eventImageSize: CGFloat = 56

    private var moderationStatus: EventModerationStatus {
        event.myEventsModerationStatus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBlock

            if !directionText.isEmpty {
                directionRow
                    .padding(.top, 16)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(icon: "calendar", text: dateRangeText)

                    HStack(spacing: 6) {
                        Text("Статус:")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(.black.opacity(0.55))

                        Text(statusText)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(statusColor)
                    }
                }

                Spacer(minLength: 8)

                organizerBlock
            }
            .padding(.top, directionText.isEmpty ? 22 : 16)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 68/255, green: 185/255, blue: 255/255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var organizerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Организатор:")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.48))

            Text(organizerText)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.62))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 90, alignment: .leading)
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

            Spacer(minLength: 0)
        }
    }

    private var directionRow: some View {
        HStack(spacing: 6) {
            Text("Направление:")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Text(directionText)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .lineLimit(2)
        }
    }

    private var directionText: String {
        event.direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var displayTitle: String {
        let value = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var organizerText: String {
        let value = event.organizerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Не указано" : value
    }

    private var statusText: String {
        if event.hasExpired && moderationStatus != .cancelled {
            return "Завершено"
        }

        switch moderationStatus {
        case .pending:
            return "Ожидает подтверждения"
        case .approved:
            return "Активно"
        case .rejected:
            return "Отклонено"
        case .cancelled:
            return "Отменено"
        case .completed:
            return "Завершено"
        }
    }

    private var statusColor: Color {
        if event.hasExpired && moderationStatus != .cancelled {
            return .black.opacity(0.45)
        }

        switch moderationStatus {
        case .pending:
            return Color(red: 0.82, green: 0.62, blue: 0.07)
        case .approved:
            return Color(red: 0.16, green: 0.56, blue: 0.23)
        case .rejected:
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        case .cancelled:
            return Color(red: 0.75, green: 0.38, blue: 0.10)
        case .completed:
            return .black.opacity(0.45)
        }
    }

    private var dateRangeText: String {
        EventDateDisplayFormatter.dateRangeText(start: startDate, end: endDate)
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

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension EventResponse {
    var myEventsModerationStatus: EventModerationStatus {
        EventModerationStatus(rawValue: status)
    }

    var hasExpired: Bool {
        (myEventsEndDate ?? myEventsStartDate) < Date()
    }

    var myEventsStartDate: Date {
        MyEventDateParser.isoFormatter.date(from: startsAt) ?? Date()
    }

    var myEventsEndDate: Date? {
        guard let endsAt else { return nil }
        return MyEventDateParser.isoFormatter.date(from: endsAt)
    }
}

private enum MyEventDateParser {
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct MyEventsPreviewScreen: View {
    let events: [EventResponse]
    @State private var selectedSegment: MyEventsSegment = .active

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea(edges: .top)

                Text("Мои события")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))

                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                .background(Circle().fill(Color.clear))
                        )

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 60)
            .overlay(alignment: .bottom) {
                Divider()
            }

            HStack(spacing: 0) {
                ForEach(MyEventsSegment.allCases, id: \.self) { segment in
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
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(visibleEvents) { event in
                        MyEventCard(event: event)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
        }
        .background(Color.white)
    }

    private var visibleEvents: [EventResponse] {
        switch selectedSegment {
        case .active:
            return events.filter { event in
                event.myEventsModerationStatus == .approved && !event.hasExpired
            }
        case .history:
            return events.filter { event in
                event.myEventsModerationStatus == .rejected
                    || event.myEventsModerationStatus == .completed
                    || event.myEventsModerationStatus == .cancelled
                    || (event.myEventsModerationStatus == .approved && event.hasExpired)
            }
        }
    }
}

#Preview("Мои события") {
    MyEventsPreviewScreen(
        events: [
            EventResponse(
                id: "1",
                title: "Музыкальный фестиваль",
                direction: EventDirectionOption.culture.rawValue,
                description: "Помощь с гостями и площадками",
                country: "Беларусь",
                city: "Минск",
                locationName: "пр-т Независимости, 95",
                photoURL: nil,
                latitude: 53.93,
                longitude: 27.64,
                startsAt: "2026-05-10T10:00:00Z",
                endsAt: "2026-05-10T14:00:00Z",
                volunteersNeeded: 5,
                status: "approved",
                message: nil,
                organizerName: "Анна Иванова",
                createdAt: "2026-04-27T09:00:00Z"
            ),
            EventResponse(
                id: "2",
                title: "Помощь приюту",
                direction: EventDirectionOption.animals.rawValue,
                description: "Уборка и выгул собак",
                country: "Россия",
                city: "Москва",
                locationName: "ул. Лесная, 12",
                photoURL: nil,
                latitude: 55.75,
                longitude: 37.62,
                startsAt: "2026-05-12T12:30:00Z",
                endsAt: nil,
                volunteersNeeded: 3,
                status: "pending",
                message: nil,
                organizerName: "Добрые лапы",
                createdAt: "2026-04-27T10:00:00Z"
            ),
            EventResponse(
                id: "3",
                title: "Сбор вещей для центра поддержки",
                direction: EventDirectionOption.social.rawValue,
                description: "Сортировка и прием вещей",
                country: "Казахстан",
                city: "Алматы",
                locationName: "ул. Абая, 45",
                photoURL: nil,
                latitude: 43.24,
                longitude: 76.95,
                startsAt: "2026-05-15T09:00:00Z",
                endsAt: "2026-05-15T11:00:00Z",
                volunteersNeeded: 7,
                status: "rejected",
                message: nil,
                organizerName: "Центр помощи",
                createdAt: "2026-04-27T11:00:00Z"
            ),
            EventResponse(
                id: "4",
                title: "Городской субботник",
                direction: EventDirectionOption.ecology.rawValue,
                description: "Помощь с уборкой парка",
                country: "Беларусь",
                city: "Гродно",
                locationName: "парк Жилибера",
                photoURL: nil,
                latitude: 53.68,
                longitude: 23.83,
                startsAt: "2026-04-10T09:00:00Z",
                endsAt: "2026-04-10T12:00:00Z",
                volunteersNeeded: 10,
                status: "completed",
                message: nil,
                organizerName: "ЭкоГродно",
                createdAt: "2026-04-01T11:00:00Z"
            )
        ]
    )
}
