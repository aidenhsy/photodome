import Foundation
import ImageIO
import UIKit

enum LocalImageThumbnailer {
    static func make(
        data: Data,
        maximumPixelSize: Int = 512
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            makeThumbnail(
                source: CGImageSourceCreateWithData(data as CFData, nil),
                maximumPixelSize: maximumPixelSize
            )
        }.value
    }

    static func make(
        fileURL: URL,
        maximumPixelSize: Int = 512
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            makeThumbnail(
                source: CGImageSourceCreateWithURL(
                    fileURL as CFURL,
                    nil
                ),
                maximumPixelSize: maximumPixelSize
            )
        }.value
    }

    private static func makeThumbnail(
        source: CGImageSource?,
        maximumPixelSize: Int
    ) -> UIImage? {
        guard let source else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        ]
        guard
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else {
            return nil
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }
}
