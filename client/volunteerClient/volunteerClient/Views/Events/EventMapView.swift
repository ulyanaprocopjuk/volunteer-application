import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: UIViewRepresentable {
    let cameraCoordinate: CLLocationCoordinate2D
    let zoomInTrigger: Int
    let zoomOutTrigger: Int
    let onTap: (CLLocationCoordinate2D) -> Void
    let onRegionDidChange: (CLLocationCoordinate2D) -> Void

    init(
        cameraCoordinate: CLLocationCoordinate2D,
        zoomInTrigger: Int = 0,
        zoomOutTrigger: Int = 0,
        onTap: @escaping (CLLocationCoordinate2D) -> Void,
        onRegionDidChange: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        self.cameraCoordinate = cameraCoordinate
        self.zoomInTrigger = zoomInTrigger
        self.zoomOutTrigger = zoomOutTrigger
        self.onTap = onTap
        self.onRegionDidChange = onRegionDidChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onRegionDidChange: onRegionDidChange)
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
                center: cameraCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if context.coordinator.lastZoomInTrigger != zoomInTrigger {
            context.coordinator.lastZoomInTrigger = zoomInTrigger
            context.coordinator.zoom(mapView, multiplier: 0.5)
        }

        if context.coordinator.lastZoomOutTrigger != zoomOutTrigger {
            context.coordinator.lastZoomOutTrigger = zoomOutTrigger
            context.coordinator.zoom(mapView, multiplier: 2)
        }

        let currentCenter = mapView.region.center
        let currentLocation = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
        let targetLocation = CLLocation(latitude: cameraCoordinate.latitude, longitude: cameraCoordinate.longitude)

        guard currentLocation.distance(from: targetLocation) > 15 else { return }

        context.coordinator.isProgrammaticChange = true
        mapView.setCenter(cameraCoordinate, animated: true)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let onTap: (CLLocationCoordinate2D) -> Void
        let onRegionDidChange: (CLLocationCoordinate2D) -> Void

        weak var mapView: MKMapView?
        var isProgrammaticChange = false
        var lastZoomInTrigger = 0
        var lastZoomOutTrigger = 0

        init(
            onTap: @escaping (CLLocationCoordinate2D) -> Void,
            onRegionDidChange: @escaping (CLLocationCoordinate2D) -> Void
        ) {
            self.onTap = onTap
            self.onRegionDidChange = onRegionDidChange
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onTap(coordinate)
        }

        func zoom(_ mapView: MKMapView, multiplier: Double) {
            let currentSpan = mapView.region.span
            let nextLatitudeDelta = min(max(currentSpan.latitudeDelta * multiplier, 0.002), 80)
            let nextLongitudeDelta = min(max(currentSpan.longitudeDelta * multiplier, 0.002), 80)
            let region = MKCoordinateRegion(
                center: mapView.region.center,
                span: MKCoordinateSpan(
                    latitudeDelta: nextLatitudeDelta,
                    longitudeDelta: nextLongitudeDelta
                )
            )

            isProgrammaticChange = true
            mapView.setRegion(region, animated: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticChange {
                isProgrammaticChange = false
                return
            }

            onRegionDidChange(mapView.region.center)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
