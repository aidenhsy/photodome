import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct EventCameraView: View {
    let eventName: String
    let onCapture: (Data, Date?, PhotoCaptureLocation?, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = EventCameraController()
    @StateObject private var captureLocation = CaptureLocationProvider()
    @State private var authorization = AVCaptureDevice.authorizationStatus(
        for: .video
    )
    @State private var fallbackSelection: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var captureError: String?

    var body: some View {
        Group {
            if !captureLocation.status.isAuthorized {
                locationUnavailable
            } else {
                switch authorization {
                case .authorized:
                    if camera.isAvailable {
                        cameraSurface
                    } else {
                        cameraUnavailable
                    }
                case .notDetermined:
                    ProgressView("Opening camera…")
                        .task { await requestCameraAccess() }
                default:
                    cameraUnavailable
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: fallbackSelection) { _, item in
            guard let item else { return }
            Task {
                defer { fallbackSelection = nil }
                guard let data = try? await item.loadTransferable(type: Data.self)
                else {
                    captureError = "PhotoDome couldn’t read that photo."
                    return
                }
                onCapture(data, nil, nil, false)
                dismiss()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization = AVCaptureDevice.authorizationStatus(
                    for: .video
                )
                captureLocation.refresh()
                captureLocation.start()
            }
        }
        .alert(
            "Photo wasn’t captured",
            isPresented: Binding(
                get: { captureError != nil },
                set: { if !$0 { captureError = nil } }
            )
        ) {
            Button("Try again") { captureError = nil }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text(captureError ?? "")
        }
    }

    private var cameraSurface: some View {
        ZStack {
            EventCameraPreview(
                session: camera.session,
                position: camera.position,
                onFocus: camera.focus,
                onZoom: camera.zoom
            )
            .ignoresSafeArea()

            EventCameraControlOverlay(
                eventName: eventName,
                isCapturing: isCapturing,
                isCameraReady: camera.isReady,
                isLocationReady: captureLocation.isReady,
                locationMessage: captureLocation.failureMessage,
                position: camera.position,
                canSwitchCamera: camera.canSwitchCamera,
                flashMode: camera.flashMode,
                supportsFlash: camera.supportsFlash,
                zoomFactor: camera.zoomFactor,
                close: { dismiss() },
                cycleFlash: camera.cycleFlashMode,
                cycleZoom: camera.cycleZoom,
                capture: capturePhoto,
                switchCamera: camera.switchCamera
            )
        }
        .task {
            captureLocation.start()
            camera.start()
        }
        .onDisappear {
            captureLocation.stop()
            camera.stop()
        }
    }

    private var cameraUnavailable: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 38))
                .accessibilityHidden(true)
            Text("Camera unavailable")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(
                "Allow camera access in Settings, or choose a photo for \(eventName) from your library."
            )
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            if authorization == .denied || authorization == .restricted {
                Button("Open Settings") {
                    guard
                        let url = URL(
                            string: UIApplication.openSettingsURLString
                        )
                    else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(MonochromeButtonStyle())
            }

            PhotosPicker(
                selection: $fallbackSelection,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                Text("Choose from library")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlineButtonStyle())

            Button("Cancel") { dismiss() }
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(AppTheme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas)
    }

    private var locationUnavailable: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.fill")
                .font(.system(size: 38))
                .accessibilityHidden(true)
            Text("Precise Location required")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(
                "PhotoDome adds the shutter-time location to photos captured for \(eventName). Enable While Using the App and Precise Location in Settings, or choose a photo from your library."
            )
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Open Settings") {
                guard
                    let url = URL(
                        string: UIApplication.openSettingsURLString
                    )
                else {
                    return
                }
                UIApplication.shared.open(url)
            }
            .buttonStyle(MonochromeButtonStyle())

            PhotosPicker(
                selection: $fallbackSelection,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                Text("Choose from library")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlineButtonStyle())

            Button("Cancel") { dismiss() }
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(AppTheme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas)
    }

    private func requestCameraAccess() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func capturePhoto() {
        guard
            let location = captureLocation.currentCaptureLocation()
        else {
            captureError =
                "PhotoDome needs a current precise location before taking this photo."
            return
        }
        isCapturing = true
        camera.capture { result in
            Task { @MainActor in
                isCapturing = false
                switch result {
                case .success(let data):
                    onCapture(data, Date(), location, true)
                    dismiss()
                case .failure(let error):
                    captureError = error.localizedDescription
                }
            }
        }
    }
}

enum EventCameraFlashMode: CaseIterable, Equatable {
    case off
    case auto
    case on

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:
            .off
        case .auto:
            .auto
        case .on:
            .on
        }
    }

    var title: String {
        switch self {
        case .off:
            "Off"
        case .auto:
            "Auto"
        case .on:
            "On"
        }
    }

    var systemImage: String {
        switch self {
        case .off:
            "bolt.slash.fill"
        case .auto:
            "bolt.badge.a.fill"
        case .on:
            "bolt.fill"
        }
    }

    var next: EventCameraFlashMode {
        switch self {
        case .off:
            .auto
        case .auto:
            .on
        case .on:
            .off
        }
    }
}

enum EventCameraCapturePolicy {
    static func resolvedFlashMode(
        preference: EventCameraFlashMode,
        supportedModes: [AVCaptureDevice.FlashMode],
        position: AVCaptureDevice.Position
    ) -> AVCaptureDevice.FlashMode {
        guard position == .back else { return .off }
        let requested = preference.captureMode
        if supportedModes.contains(requested) {
            return requested
        }
        return supportedModes.contains(.off) ? .off : supportedModes.first ?? .off
    }

    static func clampedZoom(
        current: CGFloat,
        scale: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        min(max(current * scale, minimum), maximum)
    }
}

private struct EventCameraControlOverlay: View {
    let eventName: String
    let isCapturing: Bool
    let isCameraReady: Bool
    let isLocationReady: Bool
    let locationMessage: String?
    let position: AVCaptureDevice.Position
    let canSwitchCamera: Bool
    let flashMode: EventCameraFlashMode
    let supportsFlash: Bool
    let zoomFactor: CGFloat
    let close: () -> Void
    let cycleFlash: () -> Void
    let cycleZoom: () -> Void
    let capture: () -> Void
    let switchCamera: () -> Void

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .accessibilityLabel("Close camera")

                    Spacer()

                    Button(action: cycleFlash) {
                        Label(
                            supportsFlash ? flashMode.title : "Unavailable",
                            systemImage: supportsFlash
                                ? flashMode.systemImage
                                : "bolt.slash.fill"
                        )
                        .font(
                            .system(
                                .footnote,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                    .disabled(
                        !supportsFlash || !isCameraReady || isCapturing
                    )
                    .accessibilityLabel(
                        supportsFlash
                            ? "Flash \(flashMode.title)"
                            : "Flash unavailable"
                    )
                    .accessibilityHint(
                        supportsFlash
                            ? "Changes the flash mode."
                            : "Flash is unavailable for this camera."
                    )
                    .accessibilityIdentifier("cameraFlashButton")
                }

                Text(eventName)
                    .font(
                        .system(
                            .subheadline,
                            design: .rounded,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.black.opacity(0.55), in: Capsule())
                    .frame(maxWidth: 140)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Text("Tap once. PhotoDome saves and shares it automatically.")
                    .font(
                        .system(
                            .footnote,
                            design: .rounded,
                            weight: .medium
                        )
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: Capsule())

                if !isLocationReady {
                    Text(locationMessage ?? "Waiting for precise location…")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                }

                Button(action: cycleZoom) {
                    Text(Self.zoomLabel(zoomFactor))
                        .font(
                            .system(
                                .footnote,
                                design: .rounded,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(minWidth: 48, minHeight: 36)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                .disabled(!isCameraReady || isCapturing)
                .accessibilityLabel("Zoom")
                .accessibilityValue(Self.zoomAccessibilityValue(zoomFactor))
                .accessibilityHint(
                    "Double tap to change zoom, or pinch anywhere on the preview."
                )
                .accessibilityIdentifier("cameraZoomButton")

                HStack {
                    Color.clear
                        .frame(width: 54, height: 54)

                    Spacer()

                    Button(action: capture) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 5)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)

                            if isCapturing || !isCameraReady {
                                ProgressView()
                                    .tint(.black)
                            }
                        }
                    }
                    .disabled(
                        isCapturing || !isCameraReady || !isLocationReady
                    )
                    .accessibilityLabel("Take a photo for \(eventName)")
                    .accessibilityHint(
                        "Saves the photo to your library and shares it with the event."
                    )
                    .accessibilityIdentifier("cameraShutterButton")

                    Spacer()

                    Button(action: switchCamera) {
                        Image(
                            systemName:
                                "arrow.triangle.2.circlepath.camera.fill"
                        )
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(.black.opacity(0.55), in: Circle())
                    }
                    .disabled(
                        !canSwitchCamera || !isCameraReady || isCapturing
                    )
                    .accessibilityLabel(
                        position == .back
                            ? "Switch to front camera"
                            : "Switch to back camera"
                    )
                    .accessibilityIdentifier("cameraSwitchButton")
                }
                .padding(.horizontal, 30)
            }
            .padding(.bottom, 30)
        }
    }

    private static func zoomLabel(_ value: CGFloat) -> String {
        if value.rounded() == value {
            return "\(Int(value))×"
        }
        return String(format: "%.1f×", value)
    }

    private static func zoomAccessibilityValue(_ value: CGFloat) -> String {
        String(format: "%.1f times", value)
    }
}

#if DEBUG
    struct CameraControlsRegressionView: View {
        @State private var position: AVCaptureDevice.Position = .back
        @State private var flashMode: EventCameraFlashMode = .auto
        @State private var zoomFactor: CGFloat = 1
        @State private var captureCount = 0

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.gray, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                EventCameraControlOverlay(
                    eventName: "Camera controls",
                    isCapturing: false,
                    isCameraReady: true,
                    isLocationReady: true,
                    locationMessage: nil,
                    position: position,
                    canSwitchCamera: true,
                    flashMode: flashMode,
                    supportsFlash: position == .back,
                    zoomFactor: zoomFactor,
                    close: {},
                    cycleFlash: {
                        flashMode = flashMode.next
                    },
                    cycleZoom: {
                        zoomFactor = zoomFactor < 1.5 ? 2 : 1
                    },
                    capture: {
                        captureCount += 1
                    },
                    switchCamera: {
                        position = position == .back ? .front : .back
                        zoomFactor = 1
                    }
                )

                Text("Captured \(captureCount)")
                    .accessibilityIdentifier("cameraCaptureResult")
                    .opacity(0.001)
            }
        }
    }
#endif

private final class EventCameraController: NSObject, ObservableObject,
    AVCapturePhotoCaptureDelegate, @unchecked Sendable
{
    enum CameraError: LocalizedError {
        case unavailable
        case configurationFailed
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "No camera is available on this iPhone."
            case .configurationFailed:
                "PhotoDome couldn’t start the camera."
            case .captureFailed:
                "PhotoDome couldn’t finish that photo. Please try again."
            }
        }
    }

    @Published private(set) var isReady = false
    @Published private(set) var isAvailable =
        AVCaptureDevice.default(for: .video) != nil
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var canSwitchCamera = false
    @Published private(set) var flashMode: EventCameraFlashMode = .auto
    @Published private(set) var supportsFlash = false
    @Published private(set) var zoomFactor: CGFloat = 1

    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(
        label: "com.younger7jp.photodome.camera"
    )
    private var isConfigured = false
    private var currentInput: AVCaptureDeviceInput?
    private var isCaptureInProgress = false
    private var selectedFlashMode: EventCameraFlashMode = .auto
    private var captureCompletion: (@Sendable (Result<Data, CameraError>) -> Void)?

    func start() {
        sessionQueue.async { [self] in
            guard configureIfNeeded() else { return }
            if !session.isRunning {
                session.startRunning()
            }
            publishReady(true)
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
            publishReady(false)
        }
    }

    func switchCamera() {
        sessionQueue.async { [self] in
            guard
                isConfigured,
                !isCaptureInProgress,
                let currentInput,
                let nextPosition = oppositePosition(for: currentInput.device.position),
                let nextDevice = preferredDevice(position: nextPosition),
                let nextInput = try? AVCaptureDeviceInput(device: nextDevice)
            else {
                return
            }

            publishReady(false)
            session.beginConfiguration()
            session.removeInput(currentInput)

            guard session.canAddInput(nextInput) else {
                session.addInput(currentInput)
                session.commitConfiguration()
                publishReady(true)
                return
            }

            session.addInput(nextInput)
            self.currentInput = nextInput
            configureDeviceForCapture(nextDevice, resetZoom: true)
            session.commitConfiguration()
            publishCameraState(for: nextDevice)
            publishReady(true)
        }
    }

    func cycleFlashMode() {
        sessionQueue.async { [self] in
            guard
                !isCaptureInProgress,
                supportsFlashForCurrentDevice
            else {
                return
            }
            let next = selectedFlashMode.next
            selectedFlashMode = next
            DispatchQueue.main.async { [weak self] in
                self?.flashMode = next
            }
        }
    }

    func cycleZoom() {
        sessionQueue.async { [self] in
            guard
                !isCaptureInProgress,
                let device = currentInput?.device
            else {
                return
            }
            let displayZoom = displayedZoomFactor(
                device.videoZoomFactor,
                for: device
            )
            let maximumDisplayZoom = displayedZoomFactor(
                usableMaximumZoom(for: device),
                for: device
            )
            let targetDisplayZoom: CGFloat =
                displayZoom < 1.5 && maximumDisplayZoom >= 2 ? 2 : 1
            let target = targetDisplayZoom / displayZoomMultiplier(for: device)
            setZoom(target, on: device)
        }
    }

    func zoom(by scale: CGFloat) {
        sessionQueue.async { [self] in
            guard
                scale.isFinite,
                scale > 0,
                !isCaptureInProgress,
                let device = currentInput?.device
            else {
                return
            }
            let target = EventCameraCapturePolicy.clampedZoom(
                current: device.videoZoomFactor,
                scale: scale,
                minimum: device.minAvailableVideoZoomFactor,
                maximum: usableMaximumZoom(for: device)
            )
            setZoom(target, on: device)
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [self] in
            guard
                (0...1).contains(point.x),
                (0...1).contains(point.y),
                !isCaptureInProgress,
                let device = currentInput?.device
            else {
                return
            }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }

                device.isSubjectAreaChangeMonitoringEnabled = true
            } catch {
                return
            }
        }
    }

    func capture(
        completion: @escaping @Sendable (Result<Data, CameraError>) -> Void
    ) {
        sessionQueue.async { [self] in
            guard
                isConfigured,
                session.isRunning,
                !isCaptureInProgress
            else {
                DispatchQueue.main.async {
                    completion(.failure(.configurationFailed))
                }
                return
            }

            isCaptureInProgress = true
            captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.flashMode = EventCameraCapturePolicy.resolvedFlashMode(
                preference: selectedFlashMode,
                supportedModes: output.supportedFlashModes,
                position: currentInput?.device.position ?? .unspecified
            )
            if let connection = output.connection(with: .video),
                connection.isVideoRotationAngleSupported(90)
            {
                connection.videoRotationAngle = 90
            }
            if let connection = output.connection(with: .video),
                connection.isVideoMirroringSupported
            {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored =
                    currentInput?.device.position == .front
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: Result<Data, CameraError>
        if error == nil, let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(.captureFailed)
        }

        sessionQueue.async { [self] in
            let completion = captureCompletion
            captureCompletion = nil
            isCaptureInProgress = false
            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        guard
            let device =
                preferredDevice(position: .back)
                ?? preferredDevice(position: .front)
        else {
            publishAvailable(false)
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .photo
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                publishAvailable(false)
                publishReady(false)
                return false
            }
            session.addInput(input)
            session.addOutput(output)
            output.maxPhotoQualityPrioritization = .quality
            currentInput = input
            configureDeviceForCapture(device, resetZoom: true)
            session.commitConfiguration()
            isConfigured = true
            publishCameraState(for: device)
            return true
        } catch {
            publishAvailable(false)
            publishReady(false)
            return false
        }
    }

    private var supportsFlashForCurrentDevice: Bool {
        guard
            currentInput?.device.position == .back,
            currentInput?.device.hasFlash == true
        else {
            return false
        }
        return output.supportedFlashModes.contains(.auto)
            || output.supportedFlashModes.contains(.on)
    }

    private func configureDeviceForCapture(
        _ device: AVCaptureDevice,
        resetZoom: Bool
    ) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if resetZoom {
                device.videoZoomFactor = min(
                    max(
                        1 / displayZoomMultiplier(for: device),
                        device.minAvailableVideoZoomFactor
                    ),
                    usableMaximumZoom(for: device)
                )
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            return
        }
    }

    private func setZoom(_ value: CGFloat, on device: AVCaptureDevice) {
        let target = min(
            max(value, device.minAvailableVideoZoomFactor),
            usableMaximumZoom(for: device)
        )
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = target
            device.unlockForConfiguration()
            publishZoom(displayedZoomFactor(target, for: device))
        } catch {
            return
        }
    }

    private func usableMaximumZoom(for device: AVCaptureDevice) -> CGFloat {
        min(
            device.maxAvailableVideoZoomFactor,
            10 / displayZoomMultiplier(for: device)
        )
    }

    private func displayedZoomFactor(
        _ value: CGFloat,
        for device: AVCaptureDevice
    ) -> CGFloat {
        value * displayZoomMultiplier(for: device)
    }

    private func displayZoomMultiplier(
        for device: AVCaptureDevice
    ) -> CGFloat {
        max(device.displayVideoZoomFactorMultiplier, 0.01)
    }

    private func oppositePosition(
        for position: AVCaptureDevice.Position
    ) -> AVCaptureDevice.Position? {
        switch position {
        case .back:
            .front
        case .front:
            .back
        default:
            nil
        }
    }

    private func preferredDevice(
        position: AVCaptureDevice.Position
    ) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType]
        switch position {
        case .back:
            types = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
            ]
        case .front:
            types = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
            ]
        default:
            return nil
        }

        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        ).devices
        return types.lazy.compactMap { type in
            devices.first { $0.deviceType == type }
        }.first
    }

    private func publishCameraState(for device: AVCaptureDevice) {
        let currentPosition = device.position
        let canSwitch =
            preferredDevice(position: oppositePosition(for: currentPosition) ?? .unspecified)
            != nil
        let flashAvailable = supportsFlashForCurrentDevice
        let currentZoom = displayedZoomFactor(
            device.videoZoomFactor,
            for: device
        )
        DispatchQueue.main.async { [weak self] in
            self?.position = currentPosition
            self?.canSwitchCamera = canSwitch
            self?.supportsFlash = flashAvailable
            self?.zoomFactor = currentZoom
        }
    }

    private func publishZoom(_ value: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            self?.zoomFactor = value
        }
    }

    private func publishReady(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isReady = value
        }
    }

    private func publishAvailable(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = value
        }
    }
}

private struct EventCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let position: AVCaptureDevice.Position
    let onFocus: (CGPoint) -> Void
    let onZoom: (CGFloat) -> Void

    func makeUIView(context: Context) -> EventCameraPreviewView {
        let view = EventCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        view.onZoom = onZoom
        updatePreviewConnection(view)
        return view
    }

    func updateUIView(
        _ uiView: EventCameraPreviewView,
        context: Context
    ) {
        uiView.onFocus = onFocus
        uiView.onZoom = onZoom
        updatePreviewConnection(uiView)
    }

    private func updatePreviewConnection(_ view: EventCameraPreviewView) {
        guard let connection = view.previewLayer.connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
    }
}

private final class EventCameraPreviewView: UIView {
    var onFocus: ((CGPoint) -> Void)?
    var onZoom: ((CGFloat) -> Void)?

    private let focusIndicator = UIView()

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureInteraction() {
        isAccessibilityElement = true
        accessibilityLabel = "Camera preview"
        accessibilityHint = "Tap to focus. Pinch to zoom."

        addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(didTapPreview(_:))
            )
        )
        addGestureRecognizer(
            UIPinchGestureRecognizer(
                target: self,
                action: #selector(didPinchPreview(_:))
            )
        )

        focusIndicator.isUserInteractionEnabled = false
        focusIndicator.layer.borderColor = UIColor.white.cgColor
        focusIndicator.layer.borderWidth = 2
        focusIndicator.layer.cornerRadius = 8
        focusIndicator.alpha = 0
        addSubview(focusIndicator)
    }

    @objc
    private func didTapPreview(_ recognizer: UITapGestureRecognizer) {
        let layerPoint = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(
            fromLayerPoint: layerPoint
        )
        onFocus?(devicePoint)
        showFocusIndicator(at: layerPoint)
    }

    @objc
    private func didPinchPreview(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .changed else { return }
        onZoom?(recognizer.scale)
        recognizer.scale = 1
    }

    private func showFocusIndicator(at point: CGPoint) {
        focusIndicator.layer.removeAllAnimations()
        focusIndicator.bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
        focusIndicator.center = point
        focusIndicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        focusIndicator.alpha = 1

        UIView.animate(
            withDuration: 0.2,
            animations: {
                self.focusIndicator.transform = .identity
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0.65,
                    options: [.curveEaseOut],
                    animations: {
                        self.focusIndicator.alpha = 0
                    }
                )
            }
        )
    }
}
