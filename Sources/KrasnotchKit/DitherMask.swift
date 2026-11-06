import CoreGraphics
import CoreImage
import Foundation

/// Ordered (Bayer) dithering for the glow's haze: a soft falloff turned into crisp, evenly spaced pixels.
public enum OrderedDither {
  /// Classic 8×8 Bayer index matrix (values 0…63).
  static let bayer8: [Int] = [
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4, 36, 14, 46, 6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21,
  ]

  /// Quantizes an alpha channel to `levels` steps with an 8×8 Bayer threshold.
  ///
  /// The input is normalized to its own peak first, so a faint haze still uses the whole pattern, and the
  /// output is scaled back to that peak so the dithered haze keeps the same overall brightness.
  /// More than two levels gives a smooth ramp of pixel densities instead of a hard dot / no-dot edge.
  public static func apply(alpha: [UInt8], width: Int, height: Int, levels: Int = 3) -> [UInt8] {
    precondition(alpha.count == width * height && levels >= 2)
    let peak = Double(alpha.max() ?? 0)
    guard peak > 0 else { return alpha }
    let steps = Double(levels - 1)
    var out = [UInt8](repeating: 0, count: alpha.count)
    for y in 0..<height {
      for x in 0..<width {
        let i = y * width + x
        let v = Double(alpha[i]) / peak * steps
        let base = floor(v)
        let threshold = (Double(bayer8[(y & 7) * 8 + (x & 7)]) + 0.5) / 64
        let level = min(base + (v - base > threshold ? 1 : 0), steps)
        out[i] = UInt8((level / steps * peak).rounded())
      }
    }
    return out
  }
}

/// Renders a blurred stroke of a path into a dithered mask image, one image pixel per dither cell.
public enum DitherMask {
  /// - Parameters:
  ///   - size: the mask's size in points.
  ///   - cell: the size of one dither pixel in points.
  ///   - flipped: true for top-left-origin paths (SwiftUI), false for bottom-left (Core Animation).
  /// - Returns: an image whose alpha is the mask (white, premultiplied); draw it with nearest-neighbour scaling.
  public static func render(path: CGPath, size: CGSize, cell: CGFloat, strokeWidth: CGFloat, blur: CGFloat,
                            alpha: CGFloat, flipped: Bool, levels: Int = 3, context ciContext: CIContext) -> CGImage? {
    let width = max(Int((size.width / cell).rounded(.up)), 1)
    let height = max(Int((size.height / cell).rounded(.up)), 1)
    guard let stroke = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return nil }
    if flipped {
      stroke.translateBy(x: 0, y: CGFloat(height))
      stroke.scaleBy(x: 1 / cell, y: -1 / cell)
    } else {
      stroke.scaleBy(x: 1 / cell, y: 1 / cell)
    }
    stroke.addPath(path)
    stroke.setLineWidth(strokeWidth)
    stroke.setLineJoin(.round)
    stroke.setLineCap(.round)
    stroke.setStrokeColor(gray: alpha, alpha: 1)
    stroke.strokePath()
    guard let sharp = stroke.makeImage() else { return nil }

    // Blur at cell resolution, then read the blurred coverage back as bytes.
    let extent = CGRect(x: 0, y: 0, width: width, height: height)
    let sigma = Double(blur / cell) / 2
    let blurred = CIImage(cgImage: sharp).clampedToExtent().applyingGaussianBlur(sigma: max(sigma, 0.01)).cropped(to: extent)
    var coverage = [UInt8](repeating: 0, count: width * height)
    ciContext.render(blurred, toBitmap: &coverage, rowBytes: width, bounds: extent, format: .L8, colorSpace: nil)

    let dithered = OrderedDither.apply(alpha: coverage, width: width, height: height, levels: levels)
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    for i in 0..<dithered.count { let a = dithered[i]; rgba[i * 4] = a; rgba[i * 4 + 1] = a; rgba[i * 4 + 2] = a; rgba[i * 4 + 3] = a }
    guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
}
