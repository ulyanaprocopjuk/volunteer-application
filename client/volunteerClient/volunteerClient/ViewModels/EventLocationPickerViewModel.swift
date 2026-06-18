import Foundation
import Combine
import CoreLocation

@MainActor
final class EventLocationPickerViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var suggestions: [GeocodingSuggestion] = []
    @Published private(set) var selectedLocation: EventLocationSelection?
    @Published private(set) var cameraCoordinate: CLLocationCoordinate2D
    @Published private(set) var errorMessage: String?
    @Published private(set) var searchFeedbackMessage: String?
    @Published private(set) var searchFeedbackIsError = false
    @Published private(set) var isSearching = false
    @Published private(set) var isInitialLocationLoading = false

    var selectedCoordinate: CLLocationCoordinate2D? {
        selectedLocation?.coordinate
    }

    private let context: EventLocationContext
    private let geocodingAPI: GeocodingAPIProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var reverseTask: Task<Void, Never>?
    private var suppressNextQuerySearch = false
    private var latestSearchToken = UUID()
    private var latestReverseToken = UUID()
    private var lastResolvedCoordinate: CLLocationCoordinate2D?
    private var hasSkippedInitialRegionChange = false

    init(
        context: EventLocationContext,
        initialSelection: EventLocationSelection? = nil,
        geocodingAPI: GeocodingAPIProtocol? = nil
    ) {
        self.context = context
        self.geocodingAPI = geocodingAPI ?? GeocodingAPI(baseURL: URL(string: AppConfig.baseURLString)!)
        self.cameraCoordinate = initialSelection?.coordinate ?? context.cityCoordinate
        self.selectedLocation = initialSelection
        self.lastResolvedCoordinate = initialSelection?.coordinate
        self.query = initialSelection?.address ?? ""
        self.hasSkippedInitialRegionChange = initialSelection != nil

        bindQuery()
    }

    func loadInitialLocationIfNeeded() async {
        guard selectedLocation == nil else { return }
        isInitialLocationLoading = true
        defer { isInitialLocationLoading = false }
        cameraCoordinate = context.cityCoordinate
    }

    func chooseSuggestion(_ suggestion: GeocodingSuggestion) async {
        applySelection(suggestion.selection)
    }

    func handleMapTap(_ coordinate: CLLocationCoordinate2D) async {
        reverseTask?.cancel()
        cameraCoordinate = coordinate
        await reverseGeocode(for: coordinate)
    }

    func handleMapRegionDidChange(to coordinate: CLLocationCoordinate2D) {
        if !hasSkippedInitialRegionChange,
           selectedLocation == nil,
           query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hasSkippedInitialRegionChange = true
            return
        }

        guard shouldReverseGeocode(for: coordinate) else { return }
        reverseTask?.cancel()
        reverseTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return
            }

            await self?.reverseGeocode(for: coordinate)
        }
    }

    func clearSearch() {
        suppressNextQuerySearch = true
        query = ""
        suggestions = []
        searchFeedbackMessage = nil
        searchFeedbackIsError = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func bindQuery() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }

                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                self.searchTask?.cancel()

                if self.suppressNextQuerySearch {
                    self.suppressNextQuerySearch = false
                    return
                }

                guard trimmed.count >= 2 else {
                    self.suggestions = []
                    self.searchFeedbackMessage = nil
                    self.searchFeedbackIsError = false
                    return
                }

                self.searchTask = Task {
                    await self.searchSuggestions(text: trimmed)
                }
            }
            .store(in: &cancellables)
    }

    private func searchSuggestions(text: String) async {
        let token = UUID()
        latestSearchToken = token
        isSearching = true
        searchFeedbackMessage = nil
        searchFeedbackIsError = false

        defer {
            if latestSearchToken == token {
                isSearching = false
            }
        }

        do {
            let items = try await geocodingAPI.forwardGeocode(query: text, context: context)

            if Task.isCancelled || latestSearchToken != token { return }
            suggestions = items
            errorMessage = nil
            searchFeedbackIsError = false
            searchFeedbackMessage = items.isEmpty ? "Адрес не найден" : nil
        } catch {
            if Task.isCancelled || latestSearchToken != token { return }
            suggestions = []
            searchFeedbackMessage = "Не удалось выполнить поиск адреса"
            searchFeedbackIsError = true
        }
    }

    private func reverseGeocode(for coordinate: CLLocationCoordinate2D) async {
        let token = UUID()
        latestReverseToken = token
        isSearching = true
        searchFeedbackMessage = nil
        searchFeedbackIsError = false

        defer {
            if latestReverseToken == token {
                isSearching = false
            }
        }

        do {
            guard let selection = try await geocodingAPI.reverseGeocode(coordinate: coordinate, context: context) else {
                if Task.isCancelled || latestReverseToken != token { return }
                selectedLocation = nil
                cameraCoordinate = coordinate
                searchFeedbackIsError = false
                searchFeedbackMessage = "Адрес для выбранной точки не найден"
                return
            }

            if Task.isCancelled || latestReverseToken != token { return }
            applySelection(selection)
        } catch {
            if Task.isCancelled || latestReverseToken != token { return }
            cameraCoordinate = coordinate
            searchFeedbackMessage = "Не удалось определить адрес для выбранной точки"
            searchFeedbackIsError = true
        }
    }

    private func applySelection(_ selection: EventLocationSelection) {
        selectedLocation = selection
        cameraCoordinate = selection.coordinate
        lastResolvedCoordinate = selection.coordinate
        suppressNextQuerySearch = true
        query = selection.address
        suggestions = []
        searchFeedbackMessage = nil
        searchFeedbackIsError = false
        errorMessage = nil
    }

    private func shouldReverseGeocode(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let lastResolvedCoordinate else { return true }

        let lastLocation = CLLocation(
            latitude: lastResolvedCoordinate.latitude,
            longitude: lastResolvedCoordinate.longitude
        )
        let nextLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return lastLocation.distance(from: nextLocation) > 20
    }
}
