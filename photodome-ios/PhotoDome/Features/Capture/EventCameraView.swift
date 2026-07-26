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
            EventCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .accessibilityLabel("Close camera")

                    Spacer()

                    Text(eventName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(.black.opacity(0.55), in: Capsule())

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 12) {
                    Text("Tap once. PhotoDome saves and shares it automatically.")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())

                    if !captureLocation.isReady {
                        Text(
                            captureLocation.failureMessage
                                ?? "Waiting for precise location…"
                        )
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                    }

                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 5)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)

                            if isCapturing || !camera.isReady {
                                ProgressView()
                                    .tint(.black)
                            }
                        }
                    }
                    .disabled(
                        isCapturing
                            || !camera.isReady
                            || !captureLocation.isReady
                    )
                    .accessibilityLabel("Take a photo for \(eventName)")
                    .accessibilityHint(
                        "Saves the photo to your library and shares it with the event."
                    )
                }
                .padding(.bottom, 30)
            }
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

    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(
        label: "com.younger7jp.photodome.camera"
    )
    private var isConfigured = false
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

    func capture(
        completion: @escaping @Sendable (Result<Data, CameraError>) -> Void
    ) {
        sessionQueue.async { [self] in
            guard isConfigured, session.isRunning else {
                DispatchQueue.main.async {
                    completion(.failure(.configurationFailed))
                }
                return
            }

            captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            if output.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            if let connection = output.connection(with: .video),
                connection.isVideoRotationAngleSupported(90)
            {
                connection.videoRotationAngle = 90
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
            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }
        guard
            let device =
                AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ) ?? AVCaptureDevice.default(for: .video)
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
            session.commitConfiguration()
            isConfigured = true
            return true
        } catch {
            publishAvailable(false)
            publishReady(false)
            return false
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

    func makeUIView(context: Context) -> EventCameraPreviewView {
        let view = EventCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if view.previewLayer.connection?
            .isVideoRotationAngleSupported(90) == true
        {
            view.previewLayer.connection?.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(
        _ uiView: EventCameraPreviewView,
        context: Context
    ) {}
}

private final class EventCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
