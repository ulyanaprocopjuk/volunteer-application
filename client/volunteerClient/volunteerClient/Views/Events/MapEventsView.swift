import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MapEventsView: View {
    var onCreateEventTap: () -> Void = {}
    var onNotificationsTap: () -> Void = {}
    var hasNotifications: Bool = false

    @StateObject private var viewModel = MapEventsViewModel()
    @State private var selectedEvent: EventResponse?
    @State private var detailsEvent: EventResponse?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ZStack(alignment: .bottom) {
                EventsMapView(
                    events: viewModel.events,
                    selectedEventID: selectedEvent?.id,
                    fallbackCoordinate: viewModel.fallbackCoordinate,
                    onSelectEvent: { event in
                        selectedEvent = event
                    },
                    onTapMap: {
                        selectedEvent = nil
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)

                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView()
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if let selectedEvent {
                    Button {
                        detailsEvent = selectedEvent
                    } label: {
                        EventMapPreviewCard(event: selectedEvent)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
        .task {
            await viewModel.loadEvents()
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
            EventDetailsView(event: event)
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Главная страница")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button {
                    onCreateEventTap()
                } label: {
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

                Button {
                    onNotificationsTap()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                    .background(Circle().fill(Color.clear))
                            )

                        if hasNotifications {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 9, height: 9)
                                .offset(x: -4, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

@MainActor
private final class MapEventsViewModel: ObservableObject {
    @Published private(set) var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let fallbackCoordinate = CLLocationCoordinate2D(latitude: 53.9023, longitude: 27.5619)

    private let api: EventAPIProtocol

    init(api: EventAPIProtocol? = nil) {
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await api.fetchEventFeed(searchText: nil, token: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
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

                Text(locationText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

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
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
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
        let eventIDs = events.map(\.id)
        if context.coordinator.renderedEventIDs != eventIDs {
            context.coordinator.renderedEventIDs = eventIDs
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(events.map(EventMapAnnotation.init(event:)))

            if !events.isEmpty {
                fit(events: events, in: mapView, animated: true)
            } else {
                mapView.setRegion(
                    MKCoordinateRegion(
                        center: fallbackCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                    ),
                    animated: true
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
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ),
                animated: animated
            )
            return
        }

        let points = events.map { MKMapPoint($0.coordinate) }
        let rect = points.reduce(MKMapRect.null) { partialResult, point in
            partialResult.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 60, left: 50, bottom: 120, right: 50),
            animated: animated
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let onSelectEvent: (EventResponse) -> Void
        let onTapMap: () -> Void

        var renderedEventIDs: [String] = []
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

            if let markerView = view as? MKMarkerAnnotationView {
                markerView.markerTintColor = Color(red: 44/255, green: 67/255, blue: 102/255).uiColor
                markerView.glyphImage = UIImage(systemName: "figure.wave")
                markerView.glyphTintColor = .white
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

    nonisolated var coordinate: CLLocationCoordinate2D {
        event.coordinate
    }

    nonisolated var title: String? {
        event.title
    }

    nonisolated init(event: EventResponse) {
        self.event = event
    }
}

private extension EventResponse {
    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}
