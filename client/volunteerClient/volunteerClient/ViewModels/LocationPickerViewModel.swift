import SwiftUI
import Combine
import MapKit
import CoreLocation

struct CISCitiesCountry: Decodable {
    let country: String
    let cities: [String]
}

@MainActor
final class LocationPickerViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchText: String = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var region: MKCoordinateRegion
    @Published var selectedAddress: String?
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var isLoadingSearchResult = false
    @Published var isResolvingCenter = false
    @Published var errorText: String?

    private let completer = MKLocalSearchCompleter()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()

    private let cisCountries: [String]
    private let cisCities: [String]

    init(initialLocation: SelectedLocation?) {
        let cisData = Self.loadCISCities()
        self.cisCountries = cisData.map { $0.country.lowercased() }
        self.cisCities = cisData.flatMap { $0.cities }.map { $0.lowercased() }

        if let initialLocation {
            self.region = MKCoordinateRegion(
                center: initialLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
            self.selectedAddress = initialLocation.address
            self.selectedCoordinate = initialLocation.coordinate
        } else {
            let minskCenter = CLLocationCoordinate2D(latitude: 53.9006, longitude: 27.5590)
            self.region = MKCoordinateRegion(
                center: minskCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }

        super.init()

        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        $searchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.count < 2 {
                    self.completions = []
                    self.completer.queryFragment = ""
                    return
                }

                self.completer.queryFragment = trimmed
            }
            .store(in: &cancellables)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = Array(completer.results.prefix(12))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        errorText = "Не удалось получить подсказки адреса"
        completions = []
    }

    func chooseCompletion(_ completion: MKLocalSearchCompletion) {
        errorText = nil
        isLoadingSearchResult = true

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingSearchResult = false

                if let error {
                    self.errorText = "Не удалось найти этот адрес"
                    print(error.localizedDescription)
                    return
                }

                guard let item = response?.mapItems.first else {
                    self.errorText = "Адрес не найден"
                    return
                }

                guard self.isAllowedCISMapItem(item) else {
                    self.errorText = "Доступны только адреса стран СНГ"
                    return
                }

                let coordinate = item.placemark.coordinate
                self.region.center = coordinate
                self.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                self.selectedCoordinate = coordinate
                self.selectedAddress = Self.addressString(from: item.placemark, fallbackName: item.name)
                self.searchText = Self.addressString(from: item.placemark, fallbackName: item.name)
                self.completions = []
            }
        }
    }

    func useMapCenter() {
        errorText = nil
        isResolvingCenter = true

        let center = region.center
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isResolvingCenter = false

                if let error {
                    self.errorText = "Ошибка определения адреса"
                    print(error.localizedDescription)
                    return
                }

                guard let placemark = placemarks?.first else {
                    self.errorText = "Не удалось определить адрес"
                    return
                }

                let address = Self.addressString(from: placemark, fallbackName: nil)
                self.selectedCoordinate = center
                self.selectedAddress = address
            }
        }
    }

    var selectedLocation: SelectedLocation? {
        guard let selectedAddress, let selectedCoordinate else { return nil }
        return SelectedLocation(address: selectedAddress, coordinate: selectedCoordinate)
    }

    private func isAllowedCISSuggestion(title: String, subtitle: String) -> Bool {
        let combined = "\(title.lowercased()) \(subtitle.lowercased())"

        if cisCountries.contains(where: { combined.contains($0) }) {
            return true
        }

        if cisCities.contains(where: { combined.contains($0) }) {
            return true
        }

        return false
    }

    private func isAllowedCISMapItem(_ item: MKMapItem) -> Bool {
        let placemark = item.placemark

        let country = placemark.country?.lowercased() ?? ""
        let locality = placemark.locality?.lowercased() ?? ""
        let administrativeArea = placemark.administrativeArea?.lowercased() ?? ""
        let name = placemark.name?.lowercased() ?? ""

        let combined = "\(country) \(locality) \(administrativeArea) \(name)"

        if cisCountries.contains(where: { combined.contains($0) }) {
            return true
        }

        if cisCities.contains(where: { combined.contains($0) }) {
            return true
        }

        return false
    }

    private static func addressString(from placemark: CLPlacemark, fallbackName: String?) -> String {
        let streetPart: String? = {
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                if let sub = placemark.subThoroughfare, !sub.isEmpty {
                    return "\(thoroughfare), \(sub)"
                }
                return thoroughfare
            }
            if let name = fallbackName, !name.isEmpty {
                return name
            }
            return nil
        }()

        let cityPart = placemark.locality?.nilIfEmpty

        let parts: [String] = [
            streetPart.nilIfEmpty,
            cityPart
        ]
        .compactMap { $0 }

        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }

        return fallbackName?.nilIfEmpty ?? placemark.country?.nilIfEmpty ?? "Выберите местоположение"
    }

    private static func addressString(from placemark: MKPlacemark, fallbackName: String?) -> String {
        let streetPart: String? = {
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                if let sub = placemark.subThoroughfare, !sub.isEmpty {
                    return "\(thoroughfare), \(sub)"
                }
                return thoroughfare
            }
            if let name = fallbackName, !name.isEmpty {
                return name
            }
            return nil
        }()

        let cityPart = placemark.locality?.nilIfEmpty

        let parts: [String] = [
            streetPart.nilIfEmpty,
            cityPart
        ]
        .compactMap { $0 }

        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }

        return fallbackName?.nilIfEmpty ?? placemark.country?.nilIfEmpty ?? "Выберите местоположение"
    }

    private static func loadCISCities() -> [CISCitiesCountry] {
        guard
            let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([CISCitiesCountry].self, from: data)
        else {
            return []
        }

        return decoded
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .none:
            return nil
        }
    }
}
