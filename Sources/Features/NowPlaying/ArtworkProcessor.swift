import AppKit
import ImageIO
import SwiftUI

/// Artwork ready for display: downsampled once, plus its average colour for the glow.
struct Artwork {
    let image: NSImage
    let tint: Color
}

/// Downsamples artwork off the main actor. Full-size artwork is never handed to SwiftUI.
enum ArtworkProcessor {
    /// Largest edge in pixels (the 108 pt artwork at 2x, with headroom).
    static let maxPixelSize = 256

    static func process(_ data: Data) async -> Artwork? {
        await Task.detached(priority: .utility) {
            makeArtwork(from: data)
        }.value
    }

    static func makeArtwork(from data: Data) -> Artwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return Artwork(image: image, tint: averageColor(of: cgImage))
    }

    /// Average colour, nudged brighter so the glow reads on pure black.
    static func averageColor(of image: CGImage) -> Color {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .white }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        var r = Double(pixel[0]) / 255
        var g = Double(pixel[1]) / 255
        var b = Double(pixel[2]) / 255
        let brightness = max(r, g, b)
        if brightness < 0.55, brightness > 0 {
            let lift = 0.55 / brightness
            r = min(r * lift, 1)
            g = min(g * lift, 1)
            b = min(b * lift, 1)
        } else if brightness == 0 {
            r = 0.6; g = 0.6; b = 0.6
        }
        return Color(red: r, green: g, blue: b)
    }
}
