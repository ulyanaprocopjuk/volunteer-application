import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: UIViewRepresentable {
    let cameraCoordinate: CLLocationCoordinate2D
    let onTap: (CLLocationCoordinate2D) -> Void
    let onRegionDidChange: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onRegionDidChange: onRegionDidChange)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
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
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let currentCenter = mapView.region.center
        let currentLocation = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
        let targetLocation = CLLocation(latitude: cameraCoordinate.latitude, longitude: cameraCoordinate.longitude)

        guard currentLocation.distance(from: targetLocation) > 15 else { return }

        context.coordinator.isProgrammaticChange = true
        mapView.setCenter(cameraCoordinate, animated: true)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onTap: (CLLocationCoordinate2D) -> Void
        let onRegionDidChange: (CLLocationCoordinate2D) -> Void

        weak var mapView: MKMapView?
        var isProgrammaticChange = false

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

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticChange {
                isProgrammaticChange = false
                return
            }

            onRegionDidChange(mapView.region.center)
        }
    }
}
