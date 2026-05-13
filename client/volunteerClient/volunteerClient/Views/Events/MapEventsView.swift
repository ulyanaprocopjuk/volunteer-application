import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MapEventsView: View {
    var onCreateEventTap: () -> Void = {}
    var onNotificationsTap: () -> Void = {}
    var onRatingCompleted: () -> Void = {}
    var hasNotifications: Bool = false

    @StateObject private var viewModel: MapEventsViewModel
    @State private var selectedEvent: EventResponse?
    @State private var detailsEvent: EventResponse?
    @State private var isLocationFilterPresented = false
    @State private var isFullMapPresented = false

    init(
        session: AppSession? = nil,
        onCreateEventTap: @escaping () -> Void = {},
        onNotificationsTap: @escaping () -> Void = {},
        onRatingCompleted: @escaping () -> Void = {},
        hasNotifications: Bool = false
    ) {
        self.onCreateEventTap = onCreateEventTap
        self.onNotificationsTap = onNotificationsTap
        self.onRatingCompleted = onRatingCompleted
        self.hasNotifications = hasNotifications
        _viewModel = StateObject(wrappedValue: MapEventsViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        mapCard
                            .frame(height: max(260, min(360, proxy.size.height * 0.40)))
                            .padding(.horizontal, 20)
                            .padding(.top, 18)

                        filtersView

                        statisticsView
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 150)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            await viewModel.loadInitialData()
        }
        .sheet(isPresented: $isLocationFilterPresented) {
            LocationSelectionSheet(
                country: Binding(
                    get: { viewModel.selectedCountry },
                    set: { viewModel.updateCountry($0) }
                ),
                city: Binding(
                    get: { viewModel.selectedCity },
                    set: { viewModel.updateCity($0) }
                ),
                countries: CityDirectory.countries
            )
            .onDisappear {
                Task { await viewModel.applyFilters() }
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
        .fullScreenCover(item: $detailsEvent) { event in
            EventDetailsView(
                event: event,
                session: viewModel.session,
                onRatingCompleted: {
                    detailsEvent = nil
                    onRatingCompleted()
                }
            )
        }
        .fullScreenCover(isPresented: $isFullMapPresented) {
            FullScreenEventsMapView(
                events: viewModel.events,
                fallbackCoordinate: viewModel.mapCenterCoordinate,
                session: viewModel.session,
                onRatingCompleted: onRatingCompleted
            )
        }
    }

    private var mapCard: some View {
        VStack(spacing: 0) {
            mapBlock

            HStack {
                Text(viewModel.locationFilterText)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .lineLimit(1)

                Spacer()

                Button {
                    isFullMapPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Открыть карту")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 7)
    }

    private var mapBlock: some View {
        ZStack(alignment: .bottom) {
            EventsMapView(
                events: viewModel.events,
                selectedEventID: selectedEvent?.id,
                fallbackCoordinate: viewModel.mapCenterCoordinate,
                onSelectEvent: { event in
                    selectedEvent = event
                },
                onTapMap: {
                    selectedEvent = nil
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if viewModel.isLoading {
                ProgressView()
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, selectedEvent == nil ? 18 : 112)
            }

            if let selectedEvent {
                Button {
                    detailsEvent = selectedEvent
                } label: {
                    EventMapPreviewCard(event: selectedEvent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var filtersView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    HStack(spacing: 10) {
                        Menu {
                            Button("Любое направление") {
                                Task { await viewModel.selectDirection(nil) }
                            }

                            ForEach(EventDirectionOption.allCases) { direction in
                                Button(direction.rawValue) {
                                    Task { await viewModel.selectDirection(direction.rawValue) }
                                }
                            }
                        } label: {
                            filterChip(
                                title: viewModel.directionFilterTitle,
                                isActive: viewModel.selectedDirection != nil
                            )
                        }

                        if viewModel.selectedDirection != nil {
                            resetFilterButton {
                                Task { await viewModel.resetDirectionFilter() }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Menu {
                            ForEach(EventFeedTimeFilter.allCases) { filter in
                                Button(filter.title) {
                                    Task { await viewModel.selectTimeFilter(filter) }
                                }
                            }
                        } label: {
                            filterChip(
                                title: viewModel.timeFilterTitle,
                                isActive: viewModel.selectedTimeFilter != .any
                            )
                        }

                        if viewModel.selectedTimeFilter != .any {
                            resetFilterButton {
                                Task { await viewModel.resetTimeFilter() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        isLocationFilterPresented = true
                    } label: {
                        filterChip(
                            title: viewModel.locationFilterTitle,
                            isActive: viewModel.isLocationFilterActive
                        )
                    }
                    .buttonStyle(.plain)

                    if viewModel.isLocationFilterActive {
                        resetFilterButton {
                            Task { await viewModel.resetLocationFilter() }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func filterChip(title: String, isActive: Bool) -> some View {
        let accentColor = Color(red: 44/255, green: 67/255, blue: 102/255)

        return HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isActive ? .white : accentColor)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? .white.opacity(0.78) : accentColor.opacity(0.62))
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(isActive ? accentColor : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isActive ? accentColor : Color(red: 68/255, green: 185/255, blue: 255/255).opacity(0.65),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isActive ? 0.09 : 0.04), radius: 7, y: 3)
    }

    private func resetFilterButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .frame(width: 34, height: 34)
                .background(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color(red: 68/255, green: 185/255, blue: 255/255).opacity(0.65), lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.04), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var statisticsView: some View {
        Group {
            if viewModel.events.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.events.isEmpty ? "Событий не найдено" : "Найдено событий: \(viewModel.events.count)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.78))

                    VStack(spacing: 12) {
                        ForEach(viewModel.events) { event in
                            Button {
                                detailsEvent = event
                            } label: {
                                EventFeedSummaryCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Событий не найдено")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.80))

            Text("Попробуйте изменить фильтры или создайте новое событие помощи.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.58))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Помощь рядом")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundColor(.black.opacity(0.86))

                    Text("Найдите события, где нужна помощь")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundColor(.black.opacity(0.56))
                }

                Spacer()

                Button {
                    onNotificationsTap()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.white))
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )

                        if hasNotifications {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 9, height: 9)
                                .offset(x: -5, y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                onCreateEventTap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 19, weight: .semibold))

                    Text("Создать событие помощи")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.75)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                )
                .shadow(color: Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.18), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(Color(.systemGray6).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct FullScreenEventsMapView: View {
    @Environment(\.dismiss) private var dismiss

    let events: [EventResponse]
    let fallbackCoordinate: CLLocationCoordinate2D
    let session: AppSession?
    let onRatingCompleted: () -> Void

    @State private var selectedEvent: EventResponse?
    @State private var detailsEvent: EventResponse?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Карта событий")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.78))

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white))
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 62)
            .background(Color(.systemGray6).ignoresSafeArea(edges: .top))
            .overlay(alignment: .bottom) {
                Divider()
            }

            ZStack(alignment: .bottom) {
                EventsMapView(
                    events: events,
                    selectedEventID: selectedEvent?.id,
                    fallbackCoordinate: fallbackCoordinate,
                    onSelectEvent: { event in
                        selectedEvent = event
                    },
                    onTapMap: {
                        selectedEvent = nil
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if let selectedEvent {
                    Button {
                        detailsEvent = selectedEvent
                    } label: {
                        EventMapPreviewCard(event: selectedEvent)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .fullScreenCover(item: $detailsEvent) { event in
            EventDetailsView(
                event: event,
                session: session,
                onRatingCompleted: {
                    detailsEvent = nil
                    dismiss()
                    onRatingCompleted()
                }
            )
        }
    }
}

@MainActor
private final class MapEventsViewModel: ObservableObject {
    @Published private(set) var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var selectedDirection: String?
    @Published var selectedTimeFilter: EventFeedTimeFilter = .any
    @Published var selectedCountry: String
    @Published var selectedCity: String
    @Published var errorMessage: String?
    @Published private(set) var isLocationFilterActive = false
    @Published private(set) var mapCenterCoordinate: CLLocationCoordinate2D

    let session: AppSession?
    private let api: EventAPIProtocol
    private let profileAPI: ProfileAPIProtocol
    private let geocodingAPI: GeocodingAPIProtocol
    private var hasLoadedContext = false
    private var activeRequestID = UUID()
    private var profileCountry: String
    private var profileCity: String

    init(
        session: AppSession? = nil,
        api: EventAPIProtocol? = nil,
        profileAPI: ProfileAPIProtocol? = nil,
        geocodingAPI: GeocodingAPIProtocol? = nil
    ) {
        let defaultCountry = CityDirectory.defaultCountry
        let defaultCity = CityDirectory.cities(for: defaultCountry).first ?? ""
        self.session = session
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.profileAPI = profileAPI ?? ProfileAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.geocodingAPI = geocodingAPI ?? GeocodingAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.selectedCountry = defaultCountry
        self.selectedCity = defaultCity
        self.profileCountry = defaultCountry
        self.profileCity = defaultCity
        self.mapCenterCoordinate = CityDirectory.searchArea(for: defaultCountry).center
    }

    var locationFilterText: String {
        let country = selectedCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)

        if !country.isEmpty && !city.isEmpty {
            return "\(country), \(city)"
        }

        return country.isEmpty ? "Любое" : country
    }

    var directionFilterTitle: String {
        selectedDirection?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? selectedDirection!
            : "Направление"
    }

    var timeFilterTitle: String {
        selectedTimeFilter == .any ? "Когда" : selectedTimeFilter.title
    }

    var locationFilterTitle: String {
        isLocationFilterActive ? locationFilterText : "Расположение"
    }

    func loadInitialData() async {
        guard !hasLoadedContext else {
            await loadEvents()
            return
        }

        hasLoadedContext = true
        await loadProfileLocation()
        await updateMapCenter()
        await loadEvents()
    }

    func selectDirection(_ direction: String?) async {
        selectedDirection = direction
        await applyFilters()
    }

    func selectTimeFilter(_ filter: EventFeedTimeFilter) async {
        selectedTimeFilter = filter
        await applyFilters()
    }

    func resetDirectionFilter() async {
        selectedDirection = nil
        await applyFilters()
    }

    func resetTimeFilter() async {
        selectedTimeFilter = .any
        await applyFilters()
    }

    func updateCountry(_ country: String) {
        isLocationFilterActive = true
        selectedCountry = CityDirectory.canonicalCountryName(for: country)
        let cities = CityDirectory.cities(for: selectedCountry)
        if !cities.contains(selectedCity) {
            selectedCity = cities.first ?? ""
        }
    }

    func updateCity(_ city: String) {
        isLocationFilterActive = true
        selectedCity = city
    }

    func resetLocationFilter() async {
        isLocationFilterActive = false
        selectedCountry = profileCountry
        selectedCity = profileCity
        await applyFilters()
    }

    func applyFilters() async {
        await updateMapCenter()
        await loadEvents()
    }

    private func loadEvents() async {
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil

        do {
            let filters = EventFeedFilters(
                direction: selectedDirection,
                time: selectedTimeFilter,
                country: selectedCountry,
                city: selectedCity
            )
            let loadedEvents = try await api.fetchEventFeed(
                searchText: nil,
                filters: filters,
                token: nil
            )

            guard activeRequestID == requestID else { return }
            events = loadedEvents
        } catch {
            guard activeRequestID == requestID else { return }
            events = []
            errorMessage = error.localizedDescription
        }

        if activeRequestID == requestID {
            isLoading = false
        }
    }

    private func loadProfileLocation() async {
        guard let session else { return }

        do {
            let profile = try await session.performAuthorizedRequest { token in
                try await profileAPI.fetchMyProfile(token: token)
            }
            let country = profile.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let city = profile.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !country.isEmpty {
                selectedCountry = CityDirectory.canonicalCountryName(for: country)
            }

            if !city.isEmpty {
                selectedCity = city
            } else {
                selectedCity = CityDirectory.cities(for: selectedCountry).first ?? ""
            }
            profileCountry = selectedCountry
            profileCity = selectedCity
        } catch {
            return
        }
    }

    private func updateMapCenter() async {
        let country = selectedCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchArea = CityDirectory.searchArea(for: country)

        guard !city.isEmpty else {
            mapCenterCoordinate = searchArea.center
            return
        }

        do {
            mapCenterCoordinate = try await geocodingAPI.geocodeCity(
                city: city,
                country: country,
                area: searchArea
            ) ?? searchArea.center
        } catch {
            mapCenterCoordinate = searchArea.center
        }
    }
}

private struct EventFeedSummaryCard: View {
    let event: EventResponse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(displayTitle)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if event.shouldShowRatingRewardBadge {
                        EventRatingRewardBadgeIcon(size: 24, symbolSize: 11)
                    }
                }

                if !directionText.isEmpty {
                    Text(directionText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))
                        .lineLimit(1)
                }

                Label(dateText, systemImage: "calendar")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.black.opacity(0.58))
                    .lineLimit(1)

                Label(locationText, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.black.opacity(0.58))
                    .lineLimit(2)

                if !organizerText.isEmpty {
                    HStack(spacing: 4) {
                        Text(organizerText)
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundColor(.black.opacity(0.48))
                            .lineLimit(1)
                        if event.isOrganizerVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.32))
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 68/255, green: 185/255, blue: 255/255).opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 244/255, green: 248/255, blue: 252/255))

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
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: "figure.wave")
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
    }

    private var displayTitle: String {
        let value = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var directionText: String {
        event.direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var locationText: String {
        let location = event.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? "\(event.country), \(event.city)" : location
    }

    private var organizerText: String {
        let value = event.organizerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "" : "Организатор: \(value)"
    }

    private var dateText: String {
        EventDateDisplayFormatter.dateRangeText(start: startDate, end: endDate)
    }

    private var startDate: Date {
        Self.isoFormatter.date(from: event.startsAt) ?? Date()
    }

    private var endDate: Date? {
        guard let endsAt = event.endsAt else { return nil }
        return Self.isoFormatter.date(from: endsAt)
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

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct EventMapPreviewCard: View {
    let event: EventResponse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .lineLimit(2)

                Text(dateText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.62))

                if !directionText.isEmpty {
                    Text(directionText)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .lineLimit(1)
                }

                Text(locationText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if event.shouldShowRatingRewardBadge {
                EventRatingRewardBadgeIcon(size: 24, symbolSize: 11)
                    .padding(.top, 1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black.opacity(0.35))
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 68/255, green: 185/255, blue: 255/255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }

    private var displayTitle: String {
        let value = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var dateText: String {
        EventDateDisplayFormatter.dateRangeText(start: startDate, end: endDate)
    }

    private var locationText: String {
        let location = event.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return location.isEmpty ? "\(event.country), \(event.city)" : location
    }

    private var directionText: String {
        event.direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var startDate: Date {
        Self.isoFormatter.date(from: event.startsAt) ?? Date()
    }

    private var endDate: Date? {
        guard let endsAt = event.endsAt else { return nil }
        return Self.isoFormatter.date(from: endsAt)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct EventsMapView: UIViewRepresentable {
    let events: [EventResponse]
    let selectedEventID: String?
    let fallbackCoordinate: CLLocationCoordinate2D
    let onSelectEvent: (EventResponse) -> Void
    let onTapMap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectEvent: onSelectEvent, onTapMap: onTapMap)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(
            MKCoordinateRegion(
                center: fallbackCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            ),
            animated: false
        )

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let eventKeys = events.map { event in
            "\(event.id):\(event.latitude):\(event.longitude)"
        }
        let fallbackKey = "\(fallbackCoordinate.latitude),\(fallbackCoordinate.longitude)"
        if context.coordinator.renderedEventKeys != eventKeys
            || context.coordinator.renderedFallbackKey != fallbackKey {
            context.coordinator.renderedEventKeys = eventKeys
            context.coordinator.renderedFallbackKey = fallbackKey

            let eventAnnotations = mapView.annotations.compactMap { $0 as? EventMapAnnotation }
            mapView.removeAnnotations(eventAnnotations)
            mapView.addAnnotations(makeAnnotations(for: events))

            if !events.isEmpty {
                fit(events: events, in: mapView, animated: false)
            } else {
                mapView.setRegion(
                    MKCoordinateRegion(
                        center: fallbackCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                    ),
                    animated: false
                )
            }
        }

        context.coordinator.selectedEventID = selectedEventID
    }

    private func fit(events: [EventResponse], in mapView: MKMapView, animated: Bool) {
        guard events.count > 1 else {
            guard let event = events.first else { return }
            mapView.setRegion(
                MKCoordinateRegion(
                    center: event.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
                ),
                animated: animated
            )
            return
        }

        let latitudes = events.map(\.latitude)
        let longitudes = events.map(\.longitude)
        guard let minLatitude = latitudes.min(),
              let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(),
              let maxLongitude = longitudes.max() else {
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let latitudeSpan = max((maxLatitude - minLatitude) * 1.35, 0.045)
        let longitudeSpan = max((maxLongitude - minLongitude) * 1.35, 0.045)

        mapView.setRegion(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
            ),
            animated: animated
        )
    }

    private func makeAnnotations(for events: [EventResponse]) -> [EventMapAnnotation] {
        let indexedEvents = events.enumerated().map { (index: $0.offset, event: $0.element) }
        let eventsByCoordinate = Dictionary(grouping: indexedEvents) { item in
            coordinateKey(for: item.event.coordinate)
        }

        return eventsByCoordinate.values
            .flatMap { group -> [EventMapAnnotation] in
                let sortedGroup = group.sorted { $0.index < $1.index }

                guard sortedGroup.count > 1 else {
                    return sortedGroup.map { EventMapAnnotation(event: $0.event) }
                }

                return sortedGroup.enumerated().map { position, item in
                    let angle = (Double(position) / Double(sortedGroup.count)) * 2 * Double.pi
                    let radius = 0.00022 * Double(1 + position / 8)
                    let coordinate = CLLocationCoordinate2D(
                        latitude: item.event.latitude + sin(angle) * radius,
                        longitude: item.event.longitude + cos(angle) * radius
                    )
                    return EventMapAnnotation(event: item.event, coordinate: coordinate)
                }
            }
            .sorted { $0.event.id < $1.event.id }
    }

    private func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude.rounded(toPlaces: 5)):\(coordinate.longitude.rounded(toPlaces: 5))"
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let onSelectEvent: (EventResponse) -> Void
        let onTapMap: () -> Void

        var renderedEventKeys: [String] = []
        var renderedFallbackKey: String?
        var selectedEventID: String?

        init(
            onSelectEvent: @escaping (EventResponse) -> Void,
            onTapMap: @escaping () -> Void
        ) {
            self.onSelectEvent = onSelectEvent
            self.onTapMap = onTapMap
        }

        @objc
        func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onTapMap()
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? EventMapAnnotation else { return nil }

            let identifier = "EventPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.displayPriority = .required

            if let markerView = view as? MKMarkerAnnotationView {
                markerView.markerTintColor = Color(red: 44/255, green: 67/255, blue: 102/255).uiColor
                markerView.glyphImage = UIImage(systemName: "figure.wave")
                markerView.glyphTintColor = .white
                markerView.titleVisibility = .hidden
                markerView.subtitleVisibility = .hidden
            }

            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let annotation = annotation as? EventMapAnnotation else { return }
            selectedEventID = annotation.event.id
            onSelectEvent(annotation.event)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let currentView = view {
                if currentView is MKAnnotationView {
                    return false
                }
                view = currentView.superview
            }
            return true
        }
    }
}

private final class EventMapAnnotation: NSObject, MKAnnotation {
    nonisolated let event: EventResponse
    private let displayCoordinate: CLLocationCoordinate2D

    nonisolated var coordinate: CLLocationCoordinate2D {
        displayCoordinate
    }

    nonisolated var title: String? { nil }
    nonisolated var subtitle: String? { nil }

    nonisolated init(event: EventResponse, coordinate: CLLocationCoordinate2D? = nil) {
        self.event = event
        self.displayCoordinate = coordinate ?? event.coordinate
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private extension EventResponse {
    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var shortMapSummary: String {
        let directionText = direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = location.isEmpty ? "\(city), \(country)" : location
        let date = EventDateDisplayFormatter.dateRangeText(start: mapStartDate, end: mapEndDate)

        if directionText.isEmpty {
            return "\(date), \(place)"
        }

        return "\(directionText), \(date), \(place)"
    }

    private var mapStartDate: Date {
        Self.mapISOFormatter.date(from: startsAt) ?? Date()
    }

    private var mapEndDate: Date? {
        guard let endsAt else { return nil }
        return Self.mapISOFormatter.date(from: endsAt)
    }

    private static let mapISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}
