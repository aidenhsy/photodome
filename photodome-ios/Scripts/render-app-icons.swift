#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct IconVariant {
    let filename: String
    let background: [CGFloat]
    let foreground: [CGFloat]
}

private let variants = [
    IconVariant(
        filename: "AppIcon.png",
        background: [0, 0, 0, 1],
        foreground: [1, 1, 1, 1]
    ),
    IconVariant(
        filename: "AppIcon-dark.png",
        background: [10 / 255, 10 / 255, 10 / 255, 1],
        foreground: [245 / 255, 245 / 255, 243 / 255, 1]
    ),
    IconVariant(
        filename: "AppIcon-tinted.png",
        background: [1, 1, 1, 1],
        foreground: [0, 0, 0, 1]
    ),
]

private let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let outputDirectory = projectRoot
    .appendingPathComponent("PhotoDome/Assets.xcassets/AppIcon.appiconset")
private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private func color(_ components: [CGFloat]) -> CGColor {
    CGColor(colorSpace: colorSpace, components: components)!
}

private func render(_ variant: IconVariant) throws {
    guard let context = CGContext(
        data: nil,
        width: 1024,
        height: 1024,
        bitsPerComponent: 8,
        bytesPerRow: 1024 * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(
            domain: "PhotoDomeAppIconRenderer",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not create RGB bitmap."]
        )
    }

    context.setFillColor(color(variant.background))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let dome = CGMutablePath()
    dome.move(to: CGPoint(x: 242, y: 403))
    dome.addLine(to: CGPoint(x: 242, y: 538))
    dome.addCurve(
        to: CGPoint(x: 512, y: 808),
        control1: CGPoint(x: 242, y: 687),
        control2: CGPoint(x: 363, y: 808)
    )
    dome.addCurve(
        to: CGPoint(x: 782, y: 538),
        control1: CGPoint(x: 661, y: 808),
        control2: CGPoint(x: 782, y: 687)
    )
    dome.addLine(to: CGPoint(x: 782, y: 403))

    context.addPath(dome)
    context.setStrokeColor(color(variant.foreground))
    context.setLineWidth(54)
    context.setLineCap(.butt)
    context.setLineJoin(.round)
    context.strokePath()

    context.setFillColor(color(variant.foreground))
    context.fill(CGRect(x: 242, y: 242, width: 540, height: 54))

    guard let image = context.makeImage() else {
        throw NSError(
            domain: "PhotoDomeAppIconRenderer",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not make image."]
        )
    }

    let outputURL = outputDirectory.appendingPathComponent(variant.filename)
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(
            domain: "PhotoDomeAppIconRenderer",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination."]
        )
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(
            domain: "PhotoDomeAppIconRenderer",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG."]
        )
    }
}

for variant in variants {
    try render(variant)
}
