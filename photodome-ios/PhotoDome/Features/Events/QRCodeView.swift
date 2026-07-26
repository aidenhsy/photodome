import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let url: URL
    var size: CGFloat = 240
    var accessibilityLabel = "PhotoDome QR code"

    var body: some View {
        if let image = Self.image(for: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityHint("Ask the other person to scan this code")
        } else {
            ContentUnavailableView(
                "QR unavailable",
                systemImage: "qrcode"
            )
        }
    }

    private static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        let context = CIContext()
        guard
            let output = filter.outputImage,
            let cgImage = context.createCGImage(
                output,
                from: output.extent
            )
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
