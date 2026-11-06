import AppKit
import KrasnotchKit

/// The Krasnotch symbol for the menu bar: the square-cut notch block with two pixel eyes (geometry from Figma).
enum KrasnotchIcon {
  // Figma symbol: 239.13 × 125 block, eyes 32.609 square at x 101.369 / 161.152, y 38.043 (from the top).
  private static let blockAspect = 239.13 / 125.0
  private static let eyes: [CGFloat] = [101.369, 161.152]
  private static let eyeTop: CGFloat = 38.043, eyeSize: CGFloat = 32.609, figmaHeight: CGFloat = 125

  /// How far the eyes can glance, in points: left to the block's left margin, a little further right.
  static let glanceRange: ClosedRange<CGFloat> = -7...1.5

  /// Template image: macOS tints it for light and dark menu bars and the highlighted state.
  /// `eyeOffset` shifts both eyes horizontally (clamped to `glanceRange`); 0 is the Figma resting pose.
  static func menuBar(state: GlowState?, enabled: Bool, eyeOffset: CGFloat = 0) -> NSImage {
    let height: CGFloat = 12, blockWidth = (height * blockAspect).rounded()
    let badge = enabled && state == .needsInput
    let size = NSSize(width: blockWidth + (badge ? 5 : 0), height: 16)
    let image = NSImage(size: size, flipped: false) { _ in
      let k = height / figmaHeight, y0: CGFloat = 2
      let path = NSBezierPath(rect: NSRect(x: 0, y: y0, width: blockWidth, height: height))
      // Snap the eyes to half points (one pixel at 2×): crisp, with the Figma gap between them preserved.
      let snap = { (v: CGFloat) in (v * 2).rounded() / 2 }
      let side = snap(eyeSize * k)
      for ex in eyes {
        let x = snap(ex * k + min(max(eyeOffset, glanceRange.lowerBound), glanceRange.upperBound))
        path.append(NSBezierPath(rect: NSRect(x: x, y: y0 + height - snap(eyeTop * k) - side, width: side, height: side)))
      }
      path.windingRule = .evenOdd
      NSColor.black.withAlphaComponent(enabled ? 1 : 0.4).setFill()
      path.fill()
      if badge {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: blockWidth + 1.5, y: y0 + height - 3.5, width: 3.5, height: 3.5)).fill()
      }
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Krasnotch"
    return image
  }
}
