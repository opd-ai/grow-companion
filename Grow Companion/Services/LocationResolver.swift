//
//  LocationResolver.swift
//  Grow Companion
//
//  Optional, off by default. Resolves the device's rough location to a state
//  and locality through Apple's geocoding service. The app keeps only the
//  resolved names: no coordinates are stored, and nothing is sent to us.
//

import Foundation
import CoreLocation

final class LocationResolver: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isResolving = false
    @Published var errorMessage: String?
    @Published var resolvedStateName: String?
    @Published var resolvedLocality: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func resolve() {
        isResolving = true
        errorMessage = nil
        resolvedStateName = nil
        resolvedLocality = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isResolving = false
            errorMessage = "Location access is off. Pick your state manually."
        @unknown default:
            isResolving = false
            errorMessage = "Location is unavailable. Pick your state manually."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isResolving else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isResolving = false
            errorMessage = "Location access is off. Pick your state manually."
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isResolving = false
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            if let placemark = placemarks?.first, let area = placemark.administrativeArea {
                self.resolvedStateName = area
                self.resolvedLocality = placemark.subAdministrativeArea ?? placemark.locality
                self.errorMessage = nil
            } else {
                self.errorMessage = "Couldn't resolve a state from your location. Pick it manually."
            }
            self.isResolving = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isResolving = false
        errorMessage = "Couldn't read your location. Pick your state manually."
    }
}
