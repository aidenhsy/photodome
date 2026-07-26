import AVFoundation
import Combine
import CoreLocation
import Photos
import UIKit

enum PhotoDomePermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case reducedAccuracy
    case unavailable

    var isAuthorized: Bool {
        self == .authorized || self == .unavailable
    }

    var label: String {
        switch self {
        case .notDetermined: "Not set"
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .reducedAccuracy: "Precise Location Off"
        case .unavailable: "Not available"
        }
    }
}

@MainActor
final class PermissionCenter: NSObject, ObservableObject,
    @preconcurrency CLLocationManagerDelegate
{
    @Published private(set) var camera: PhotoDomePermissionStatus =
        .notDetermined
    @Published private(set) var photoLibrary: PhotoDomePermissionStatus =
        .notDetermined
    @Published private(set) var location: PhotoDomePermissionStatus =
        .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        refresh()
    }

    var isReadyForSession: Bool {
        camera.isAuthorized
            && photoLibrary.isAuthorized
            && location.isAuthorized
    }

    func refresh() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("PhotoDomeUITestPermissionsGranted") {
            camera = .authorized
            photoLibrary = .authorized
            location = .authorized
            return
        }
        if arguments.contains("PhotoDomeUITestPermissionsMissing") {
            camera = .notDetermined
            photoLibrary = .notDetermined
            location = .notDetermined
            return
        }

        camera = Self.cameraStatus()
        photoLibrary = Self.photoLibraryStatus()
        location = Self.locationStatus(
            authorizationStatus: locationManager.authorizationStatus,
            accuracyAuthorization: locationManager.accuracyAuthorization
        )
    }

    func requestCamera() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            camera = .unavailable
            return
        }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        refresh()
    }

    func requestPhotoLibrary() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        refresh()
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func openSystemSettings() {
        guard
            let url = URL(string: UIApplication.openSettingsURLString)
        else {
            return
        }
        UIApplication.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        refresh()
    }

    private static func cameraStatus() -> PhotoDomePermissionStatus {
        guard AVCaptureDevice.default(for: .video) != nil else {
            return .unavailable
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    private static func photoLibraryStatus() -> PhotoDomePermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined: return .notDetermined
        case .authorized, .limited: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    static func locationStatus(
        authorizationStatus: CLAuthorizationStatus,
        accuracyAuthorization: CLAccuracyAuthorization
    ) -> PhotoDomePermissionStatus {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            return accuracyAuthorization == .fullAccuracy
                ? .authorized : .reducedAccuracy
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
}

@MainActor
final class CaptureLocationProvider: NSObject, ObservableObject,
    @preconcurrency CLLocationManagerDelegate
{
    @Published private(set) var status: PhotoDomePermissionStatus =
        .notDetermined
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var failureMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        refresh()
    }

    var isReady: Bool {
        status.isAuthorized && currentCaptureLocation() != nil
    }

    func start() {
        refresh()
        guard status.isAuthorized else { return }
        failureMessage = nil
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func refresh() {
        status = PermissionCenter.locationStatus(
            authorizationStatus: manager.authorizationStatus,
            accuracyAuthorization: manager.accuracyAuthorization
        )
        if !status.isAuthorized {
            latestLocation = nil
            manager.stopUpdatingLocation()
        }
    }

    func currentCaptureLocation(
        now: Date = Date()
    ) -> PhotoCaptureLocation? {
        guard
            status.isAuthorized,
            let latestLocation,
            latestLocation.horizontalAccuracy >= 0,
            abs(latestLocation.timestamp.timeIntervalSince(now)) <= 60
        else {
            return nil
        }
        return PhotoCaptureLocation(
            latitude: latestLocation.coordinate.latitude,
            longitude: latestLocation.coordinate.longitude,
            altitude: latestLocation.altitude,
            horizontalAccuracy: latestLocation.horizontalAccuracy,
            timestamp: latestLocation.timestamp
        )
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        refresh()
        if status.isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard
            let newest =
                locations
                .filter({ $0.horizontalAccuracy >= 0 })
                .max(by: { $0.timestamp < $1.timestamp })
        else {
            return
        }
        latestLocation = newest
        failureMessage = nil
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        if let locationError = error as? CLError,
            locationError.code == .locationUnknown
        {
            return
        }
        failureMessage =
            "PhotoDome couldn’t get a precise location. Try again."
    }
}
