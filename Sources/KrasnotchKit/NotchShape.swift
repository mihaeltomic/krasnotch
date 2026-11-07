import CoreGraphics

/// The opaque shape another notch app (Alcove, NotchNook, …) hangs from the top of the screen, measured
/// from its window's alpha. Those apps draw into a fixed, mostly transparent canvas, so the window's
/// bounds say nothing about what you actually see.
public struct NotchShape: Equatable, Sendable {
  /// Horizontal extent and depth, in the measured image's pixels.
  public var minX: Int
  public var maxX: Int
  public var height: Int
  public var cornerRadius: Int

  public init(minX: Int, maxX: Int, height: Int, cornerRadius: Int) {
    self.minX = minX
    self.maxX = maxX
    self.height = height
    self.cornerRadius = cornerRadius
  }

  public var width: Int { maxX - minX }

  /// Measures the shape hanging from the top edge at column `seedX`.
  ///
  /// - Parameter alpha: one byte per pixel, row-major, top row first.
  /// - Returns: nil when nothing opaque hangs from the top at `seedX`.
  public static func measure(alpha: [UInt8], width: Int, height: Int, seedX: Int, threshold: UInt8 = 128) -> NotchShape? {
    guard width > 0, height > 0, alpha.count >= width * height, (0..<width).contains(seedX) else { return nil }
    let opaque = { (x: Int, y: Int) in alpha[y * width + x] >= threshold }

    var depth = 0
    while depth < height, opaque(seedX, depth) { depth += 1 }
    guard depth > 0 else { return nil }

    // Measure the width halfway down: clear of top flares ("ears") and of the rounded bottom corners.
    let (left, right) = run(at: depth / 2, from: seedX, width: width, opaque: opaque)

    // A rounded corner pulls the bottom row in by i ≈ r - √r, so r ≈ i + √i.
    let (bottomLeft, bottomRight) = run(at: depth - 1, from: seedX, width: width, opaque: opaque)
    let inset = Double(bottomLeft - left + right - bottomRight) / 2
    let radius = min(Int((inset + inset.squareRoot()).rounded()), depth / 2, (right - left) / 2)
    return NotchShape(minX: left, maxX: right, height: depth, cornerRadius: radius)
  }

  /// Measures a captured window image; `seedX` is in the image's pixels.
  public static func measure(image: CGImage, seedX: Int) -> NotchShape? {
    let width = image.width, height = image.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(
        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return nil }
    // The context's first row in memory is the image's top row.
    let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    return measure(alpha: alpha, width: width, height: height, seedX: seedX)
  }

  /// The opaque run on row `y` that contains column `x`, as a half-open range.
  private static func run(at y: Int, from x: Int, width: Int, opaque: (Int, Int) -> Bool) -> (Int, Int) {
    var left = x, right = x
    while left > 0, opaque(left - 1, y) { left -= 1 }
    while right < width, opaque(right, y) { right += 1 }
    return (left, right)
  }
}

extension NotchGeometry {
  /// The smallest outline covering both notches, so the glow never ends up hidden behind either.
  public func union(_ other: NotchGeometry) -> NotchGeometry {
    NotchGeometry(minX: min(minX, other.minX), maxX: max(maxX, other.maxX), height: max(height, other.height))
  }

  /// True when `other` reaches meaningfully past this notch on any side.
  public func isExceeded(by other: NotchGeometry, tolerance: CGFloat = 2) -> Bool {
    other.minX < minX - tolerance || other.maxX > maxX + tolerance || other.height > height + tolerance
  }
}
