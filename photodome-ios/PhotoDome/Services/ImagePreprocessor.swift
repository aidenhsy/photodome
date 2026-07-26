import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImagePreprocessorError: LocalizedError {
    case unreadable
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "That photo could not be prepared."
        case .tooLarge:
            "That photo is larger than PhotoDome’s 20 MB upload limit."
        }
    }
}

struct ImagePreprocessor: Sendable {
    private let maximumBytes = 20 * 1_024 * 1_024

    func prepare(
        _ sourceData: Data,
        capturedAt overrideCapturedAt: Date? = nil,
        captureLocation: PhotoCaptureLocation? = nil
    ) async throws -> PreparedPhoto {
        try await Task.detached(priority: .userInitiated) {
            guard sourceData.count <= maximumBytes else {
                throw ImagePreprocessorError.tooLarge
            }
            guard
                let source = CGImageSourceCreateWithData(
                    sourceData as CFData,
                    nil
                ),
                CGImageSourceGetCount(source) > 0,
                let properties = CGImageSourceCopyPropertiesAtIndex(
                    source,
                    0,
                    nil
                ) as? [CFString: Any],
                let width = Self.integerProperty(
                    properties,
                    key: kCGImagePropertyPixelWidth
                ),
                let height = Self.integerProperty(
                    properties,
                    key: kCGImagePropertyPixelHeight
                ),
                width > 0,
                height > 0
            else {
                throw ImagePreprocessorError.unreadable
            }

            let capturedAt =
                overrideCapturedAt.map {
                    ISO8601DateFormatter().string(from: $0)
                } ?? Self.captureDate(from: properties)
            let orientation =
                Self.integerProperty(
                    properties,
                    key: kCGImagePropertyOrientation
                ) ?? 1

            let preparedData: Data
            if Self.isJPEG(source),
                overrideCapturedAt == nil,
                captureLocation == nil
            {
                // Library JPEGs remain byte-for-byte identical so their image
                // payload and every embedded metadata block survive sharing.
                preparedData = sourceData
            } else {
                preparedData = try Self.makeJPEG(
                    from: source,
                    properties: properties,
                    capturedAt: overrideCapturedAt,
                    captureLocation: captureLocation
                )
            }

            guard preparedData.count <= maximumBytes else {
                throw ImagePreprocessorError.tooLarge
            }

            let directory = try Self.uploadDirectory()
            let fileURL =
                directory
                .appendingPathComponent(UUID().uuidString.lowercased())
                .appendingPathExtension("jpg")
            try preparedData.write(
                to: fileURL,
                options: [
                    .atomic,
                    .completeFileProtectionUntilFirstUserAuthentication,
                ]
            )
            let digest = SHA256.hash(data: preparedData)

            return PreparedPhoto(
                fileURL: fileURL,
                byteSize: preparedData.count,
                sha256: digest.map { String(format: "%02x", $0) }.joined(),
                width: width,
                height: height,
                capturedAt: capturedAt,
                orientation: min(max(orientation, 1), 8)
            )
        }.value
    }

    private static func makeJPEG(
        from source: CGImageSource,
        properties: [CFString: Any],
        capturedAt: Date?,
        captureLocation: PhotoCaptureLocation?
    ) throws -> Data {
        var outputProperties = properties
        outputProperties[kCGImageDestinationLossyCompressionQuality] = 0.95

        if let capturedAt {
            let value = exifDateFormatter.string(from: capturedAt)
            var exif =
                outputProperties[kCGImagePropertyExifDictionary]
                as? [CFString: Any] ?? [:]
            exif[kCGImagePropertyExifDateTimeOriginal] = value
            exif[kCGImagePropertyExifDateTimeDigitized] = value
            outputProperties[kCGImagePropertyExifDictionary] = exif

            var tiff =
                outputProperties[kCGImagePropertyTIFFDictionary]
                as? [CFString: Any] ?? [:]
            tiff[kCGImagePropertyTIFFDateTime] = value
            outputProperties[kCGImagePropertyTIFFDictionary] = tiff
        }

        if let captureLocation {
            outputProperties[kCGImagePropertyGPSDictionary] =
                gpsProperties(for: captureLocation)
        }

        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw ImagePreprocessorError.unreadable
        }
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            outputProperties as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ImagePreprocessorError.unreadable
        }
        return data as Data
    }

    private static func gpsProperties(
        for location: PhotoCaptureLocation
    ) -> [CFString: Any] {
        let latitude = location.latitude
        let longitude = location.longitude
        return [
            kCGImagePropertyGPSVersion: [2, 3, 0, 0],
            kCGImagePropertyGPSLatitudeRef: latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLatitude: abs(latitude),
            kCGImagePropertyGPSLongitudeRef: longitude >= 0 ? "E" : "W",
            kCGImagePropertyGPSLongitude: abs(longitude),
            kCGImagePropertyGPSAltitudeRef: location.altitude < 0 ? 1 : 0,
            kCGImagePropertyGPSAltitude: abs(location.altitude),
            kCGImagePropertyGPSDateStamp:
                gpsDateFormatter.string(from: location.timestamp),
            kCGImagePropertyGPSTimeStamp:
                gpsTimeFormatter.string(from: location.timestamp),
            kCGImagePropertyGPSHPositioningError:
                max(0, location.horizontalAccuracy),
        ]
    }

    private static func isJPEG(_ source: CGImageSource) -> Bool {
        guard let type = CGImageSourceGetType(source) else { return false }
        return UTType(type as String)?.conforms(to: .jpeg) == true
    }

    private static func integerProperty(
        _ properties: [CFString: Any],
        key: CFString
    ) -> Int? {
        if let number = properties[key] as? NSNumber {
            return number.intValue
        }
        return properties[key] as? Int
    }

    private static func uploadDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(
            "PhotoDomeUploads",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func captureDate(
        from properties: [CFString: Any]
    ) -> String? {
        guard
            let exif = properties[kCGImagePropertyExifDictionary]
                as? [CFString: Any],
            let value = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
            let date = exifDateFormatter.date(from: value)
        else {
            return nil
        }
        return ISO8601DateFormatter().string(from: date)
    }

    private static var exifDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }

    private static var gpsDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy:MM:dd"
        return formatter
    }

    private static var gpsTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss.SSSSSS"
        return formatter
    }
}
