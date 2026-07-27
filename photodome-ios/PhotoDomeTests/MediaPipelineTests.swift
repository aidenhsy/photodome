import AVFoundation
import CoreLocation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import PhotoDome

final class MediaPipelineTests: XCTestCase {
    func testCameraFlashModesCycleOffAutoOn() {
        XCTAssertEqual(EventCameraFlashMode.off.next, .auto)
        XCTAssertEqual(EventCameraFlashMode.auto.next, .on)
        XCTAssertEqual(EventCameraFlashMode.on.next, .off)
    }

    func testCameraFlashPolicyDisablesHardwareFlashForFrontCamera() {
        XCTAssertEqual(
            EventCameraCapturePolicy.resolvedFlashMode(
                preference: .on,
                supportedModes: [.off, .auto, .on],
                position: .front
            ),
            .off
        )
        XCTAssertEqual(
            EventCameraCapturePolicy.resolvedFlashMode(
                preference: .auto,
                supportedModes: [.off, .auto, .on],
                position: .back
            ),
            .auto
        )
    }

    func testCameraZoomPolicyClampsToTheActiveLensRange() {
        XCTAssertEqual(
            EventCameraCapturePolicy.clampedZoom(
                current: 1,
                scale: 20,
                minimum: 1,
                maximum: 10
            ),
            10
        )
        XCTAssertEqual(
            EventCameraCapturePolicy.clampedZoom(
                current: 2,
                scale: 0.1,
                minimum: 0.5,
                maximum: 10
            ),
            0.5
        )
    }

    func testCameraZoomPresetsExposeTripleCameraLensesAndTwoTimesCrop() {
        XCTAssertEqual(
            EventCameraCapturePolicy.displayedZoomPresets(
                minimum: 1,
                maximum: 20,
                displayMultiplier: 0.5,
                switchOverFactors: [2, 10]
            ),
            [0.5, 1, 2, 5]
        )
    }

    func testCameraZoomPresetsAdaptToSimplerCameraHardware() {
        XCTAssertEqual(
            EventCameraCapturePolicy.displayedZoomPresets(
                minimum: 1,
                maximum: 10,
                displayMultiplier: 0.5,
                switchOverFactors: [2]
            ),
            [0.5, 1, 2]
        )
        XCTAssertEqual(
            EventCameraCapturePolicy.displayedZoomPresets(
                minimum: 1,
                maximum: 1.5,
                displayMultiplier: 1,
                switchOverFactors: []
            ),
            [1]
        )
    }

    func testJPEGImportPreservesOriginalBytesAndMetadata()
        async throws
    {
        let sourceData = try await makeJPEG(
            properties: [
                kCGImagePropertyOrientation: 6,
                kCGImagePropertyGPSDictionary: [
                    kCGImagePropertyGPSLatitudeRef: "N",
                    kCGImagePropertyGPSLatitude: 35.6812,
                    kCGImagePropertyGPSLongitudeRef: "E",
                    kCGImagePropertyGPSLongitude: 139.7671,
                ],
            ]
        )

        let prepared = try await ImagePreprocessor().prepare(sourceData)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }

        XCTAssertEqual(prepared.width, 320)
        XCTAssertEqual(prepared.height, 180)
        XCTAssertEqual(prepared.orientation, 6)
        XCTAssertEqual(prepared.sha256.count, 64)
        XCTAssertEqual(
            prepared.byteSize,
            try Data(contentsOf: prepared.fileURL).count
        )

        let encoded = try Data(contentsOf: prepared.fileURL)
        XCTAssertEqual(encoded, sourceData)
        let source = try XCTUnwrap(
            CGImageSourceCreateWithData(encoded as CFData, nil)
        )
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        )
        let gps = try XCTUnwrap(
            properties[kCGImagePropertyGPSDictionary]
                as? [CFString: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSLatitude] as? NSNumber
            ).doubleValue,
            35.6812,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSLongitude] as? NSNumber
            ).doubleValue,
            139.7671,
            accuracy: 0.000_001
        )
    }

    func testCameraPreparationEmbedsShutterLocationAndCaptureDate()
        async throws
    {
        let sourceData = try await makeJPEG()
        let capturedAt = Date(timeIntervalSince1970: 1_753_420_000)
        let captureLocation = PhotoCaptureLocation(
            latitude: -33.8688,
            longitude: 151.2093,
            altitude: 42.5,
            horizontalAccuracy: 4.25,
            timestamp: capturedAt
        )

        let prepared = try await ImagePreprocessor().prepare(
            sourceData,
            capturedAt: capturedAt,
            captureLocation: captureLocation
        )
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }

        let encoded = try Data(contentsOf: prepared.fileURL)
        let source = try XCTUnwrap(
            CGImageSourceCreateWithData(encoded as CFData, nil)
        )
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        )
        let gps = try XCTUnwrap(
            properties[kCGImagePropertyGPSDictionary]
                as? [CFString: Any]
        )
        XCTAssertEqual(gps[kCGImagePropertyGPSLatitudeRef] as? String, "S")
        XCTAssertEqual(gps[kCGImagePropertyGPSLongitudeRef] as? String, "E")
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSLatitude] as? NSNumber
            ).doubleValue,
            33.8688,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSLongitude] as? NSNumber
            ).doubleValue,
            151.2093,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSAltitude] as? NSNumber
            ).doubleValue,
            42.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                gps[kCGImagePropertyGPSHPositioningError] as? NSNumber
            ).doubleValue,
            4.25,
            accuracy: 0.001
        )

        let exif = try XCTUnwrap(
            properties[kCGImagePropertyExifDictionary]
                as? [CFString: Any]
        )
        XCTAssertNotNil(exif[kCGImagePropertyExifDateTimeOriginal])
        XCTAssertEqual(
            prepared.capturedAt,
            ISO8601DateFormatter().string(from: capturedAt)
        )
    }

    func testImportWithoutGPSDoesNotReceiveCurrentLocation()
        async throws
    {
        let sourceData = try await makeJPEG()
        let prepared = try await ImagePreprocessor().prepare(sourceData)
        defer { try? FileManager.default.removeItem(at: prepared.fileURL) }

        let encoded = try Data(contentsOf: prepared.fileURL)
        XCTAssertEqual(encoded, sourceData)
        let source = try XCTUnwrap(
            CGImageSourceCreateWithData(encoded as CFData, nil)
        )
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        )
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }

    @MainActor
    func testPreciseLocationIsRequiredForSessionReadiness() {
        XCTAssertEqual(
            PermissionCenter.locationStatus(
                authorizationStatus: .authorizedWhenInUse,
                accuracyAuthorization: .fullAccuracy
            ),
            .authorized
        )
        XCTAssertEqual(
            PermissionCenter.locationStatus(
                authorizationStatus: .authorizedWhenInUse,
                accuracyAuthorization: .reducedAccuracy
            ),
            .reducedAccuracy
        )
        XCTAssertEqual(
            PermissionCenter.locationStatus(
                authorizationStatus: .denied,
                accuracyAuthorization: .fullAccuracy
            ),
            .denied
        )
    }

    func testUploadQueueRoundTripsSensitiveSessionState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UploadQueueStore(directoryURL: directory)
        let item = UploadQueueItem(
            id: UUID(),
            eventID: UUID().uuidString,
            photoID: UUID().uuidString,
            uploadSessionURL: try XCTUnwrap(
                URL(string: "https://storage.example/upload/session-secret")
            ),
            localFileURL: directory.appendingPathComponent("photo.jpg"),
            contentType: "image/jpeg",
            byteSize: 42,
            taskIdentifier: 7,
            state: .uploading,
            bytesSent: 21,
            retryCount: 1,
            failureMessage: nil
        )

        try await store.save([item])
        let restored = try await store.load()
        XCTAssertEqual(restored, [item])
    }

    func testDownloadQueueRoundTripsSignedManifestState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PhotoDownloadQueueStore(directoryURL: directory)
        let item = PhotoDownloadItem(
            id: UUID(),
            eventID: UUID().uuidString,
            photoID: UUID().uuidString,
            sourceURL: try XCTUnwrap(
                URL(string: "https://storage.example/original?signature=secret")
            ),
            capturedAt: "2026-07-25T10:00:00.000Z",
            expectedByteSize: 84,
            localFileURL: directory.appendingPathComponent("photo.jpg"),
            taskIdentifier: 9,
            state: .downloading,
            bytesReceived: 42,
            retryCount: 1,
            failureMessage: nil
        )

        try await store.save([item])
        let restored = try await store.load()
        XCTAssertEqual(restored, [item])
    }

    func testBackgroundDownloadIsStagedBeforeDelegateTemporaryFileExpires()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceURL = directory.appendingPathComponent("url-session.tmp")
        let stagingDirectory = directory.appendingPathComponent(
            "incoming",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let expected = Data("source-quality-photo".utf8)
        try expected.write(to: sourceURL)

        let stagedURL = try PhotoDownloadManager.stageDownloadedFile(
            at: sourceURL,
            taskID: 42,
            directoryURL: stagingDirectory
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: stagedURL.path)
        )
        XCTAssertEqual(try Data(contentsOf: stagedURL), expected)
    }

    private func makeJPEG(
        properties: [CFString: Any] = [:]
    ) async throws -> Data {
        let baseData = await MainActor.run {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: 320, height: 180),
                format: format
            )
            return renderer.jpegData(withCompressionQuality: 1) { context in
                UIColor.black.setFill()
                context.fill(
                    CGRect(x: 0, y: 0, width: 320, height: 180)
                )
            }
        }
        guard !properties.isEmpty else { return baseData }

        let source = try XCTUnwrap(
            CGImageSourceCreateWithData(baseData as CFData, nil)
        )
        let output = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            properties as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
