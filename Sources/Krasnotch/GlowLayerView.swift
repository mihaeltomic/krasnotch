import AppKit
import CoreImage
import KrasnotchKit

/// Draws the neon edge with Core Animation.
///
/// The expensive part (blurring the edge shape) is baked once into static mask bitmaps. Per frame the
/// render server only rotates gradients underneath those masks, which is a cheap composite.
final class GlowLayerView: NSView {
  /// A static mask with two counter-rotating gradients behind it.
  struct Band {
    let holder = CALayer()
    let mask = CALayer()
    let primary = CAGradientLayer()
    let secondary = CAGradientLayer()
  }

  let root = CALayer()
  /// Crisp line plus tight glow.
  let line = Band()
  /// Wide, soft haze that bleeds into the screen.
  let haze = Band()
  /// Wand stroke and glitter for the Magic? switch.
  let magic = MagicLayer()

  private let ciContext = CIContext()
  private var applied: (style: GlowStyle, geometry: EdgeGeometry)?
  private var maskInputs: MaskInputs?

  private struct MaskInputs: Equatable {
    var geometry: EdgeGeometry
    var thickness: Double
    var intensity: Double
    var dither: Bool
    var scale: CGFloat
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.addSublayer(root)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(motionPreferenceChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    for band in [haze, line] {
      band.holder.mask = band.mask
      for gradient in [band.primary, band.secondary] {
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        band.holder.addSublayer(gradient)
      }
      root.addSublayer(band.holder)
    }
    root.addSublayer(magic)
  }

  @objc private func motionPreferenceChanged() {
    guard let applied else { return }
    removeGlowAnimations()
    addAnimations(for: applied.style)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  /// No-op when nothing changed, so a flood of hook events doesn't restart the animation.
  func apply(style: GlowStyle, geometry: EdgeGeometry) {
    if let applied, applied.style == style, applied.geometry == geometry { return }
    let previous = applied
    let motionChanged = previous == nil || previous?.style.motion != style.motion || previous?.style.speed != style.speed || previous?.geometry != geometry
      || previous?.style.magic != style.magic || (style.magic && previous?.style != style)
    applied = (style, geometry)

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let bounds = CGRect(origin: .zero, size: geometry.size)
    root.frame = bounds
    for band in [line, haze] {
      [band.holder, band.mask, band.primary, band.secondary].forEach { $0.frame = bounds }
    }
    if let notch = geometry.notch {
      let center = CGPoint(x: (notch.minX + notch.maxX) / 2 / geometry.size.width, y: (geometry.size.height - notch.height / 2) / geometry.size.height)
      for band in [line, haze] {
        for gradient in [band.primary, band.secondary] { gradient.startPoint = center; gradient.endPoint = CGPoint(x: center.x, y: center.y - 0.1) }
      }
    }
    updateMasksIfNeeded(geometry: geometry, style: style)
    updateGradients(style: style)
    if style.magic {
      magic.configure(path: geometry.path(), bounds: bounds, notch: geometry.notch, style: style)
    }
    CATransaction.commit()

    if motionChanged {
      removeGlowAnimations()
      addAnimations(for: style)
    }
  }

  func stop() {
    removeGlowAnimations()
    applied = nil
  }

  private func updateGradients(style: GlowStyle) {
    let colors = style.colors.compactMap(RGBA.init(hex:))
    let palette = colors.isEmpty ? [RGBA(red: 1, green: 1, blue: 1)] : colors
    let isHead = style.motion == .comet || style.motion == .scanner
    // With Magic? on, the animation underneath steps back so the wand and glitter lead.
    let dim: Float = style.magic ? 0.6 : 1

    for band in [line, haze] {
      band.primary.opacity = dim
      if isHead {
        // Transparent for most of the circle, then a tail that brightens into a sharp head.
        let clear = palette[0].withAlpha(0).cgColor
        band.primary.colors = [clear, clear] + palette.map(\.cgColor) + [clear]
        band.primary.locations = Self.headLocations(count: palette.count)
        band.secondary.isHidden = true
      } else {
        let loop = (palette + [palette[0]]).map(\.cgColor)
        band.primary.colors = loop.count > 1 ? loop : loop + loop
        band.primary.locations = nil
        band.secondary.colors = Array(band.primary.colors!.reversed())
        band.secondary.isHidden = false
        band.secondary.opacity = 0.5 * dim
      }
    }
  }

  private static func headLocations(count: Int) -> [NSNumber] {
    let tailStart = 0.62, head = 0.985
    let spread = (0..<count).map { tailStart + (head - tailStart) * Double($0 + 1) / Double(count) }
    return ([0, tailStart] + spread + [1]).map { NSNumber(value: $0) }
  }

  private func updateMasksIfNeeded(geometry: EdgeGeometry, style: GlowStyle) {
    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    let inputs = MaskInputs(geometry: geometry, thickness: style.thickness, intensity: style.intensity, dither: style.dither, scale: scale)
    guard inputs != maskInputs else { return }
    maskInputs = inputs

    // Half of each stroke sits off-screen, so double the width to get the visible thickness.
    let width = CGFloat(style.thickness) * 2
    let intensity = CGFloat(style.intensity)
    let path = geometry.path()

    line.mask.contents = renderMask(path: path, size: geometry.size, scale: scale, strokes: [
      (width: width * 2.5, blur: width * 1.4, alpha: 0.85 * intensity),
      (width: width, blur: width * 0.15, alpha: 1),
    ])
    line.mask.contentsScale = scale

    let hazeWidth = width * 6 * max(intensity, 0.2), hazeBlur = width * 4, hazeAlpha = 0.6 * intensity
    if style.dither {
      // One mask pixel per 2 pt dither cell, scaled up nearest-neighbour so every dot stays a crisp square.
      haze.mask.contents = DitherMask.render(path: path, size: geometry.size, cell: Self.ditherCell, strokeWidth: hazeWidth,
                                             blur: hazeBlur, alpha: hazeAlpha, flipped: false, context: ciContext)
      haze.mask.contentsScale = 1 / Self.ditherCell
      haze.mask.magnificationFilter = .nearest
    } else {
      // The haze is soft, so 1x resolution is indistinguishable and a quarter of the memory.
      haze.mask.contents = renderMask(path: path, size: geometry.size, scale: 1, strokes: [
        (width: hazeWidth, blur: hazeBlur, alpha: hazeAlpha),
      ])
      haze.mask.contentsScale = 1
      haze.mask.magnificationFilter = .linear
    }
  }

  /// Size of one dither pixel in points.
  static let ditherCell: CGFloat = 2

  /// Rasterizes blurred strokes of `path` into an image whose alpha channel is the mask.
  private func renderMask(path: CGPath, size: CGSize, scale: CGFloat, strokes: [(width: CGFloat, blur: CGFloat, alpha: CGFloat)]) -> CGImage? {
    let pixelWidth = Int(size.width * scale), pixelHeight = Int(size.height * scale)
    let extent = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
    var composite = CIImage.empty().cropped(to: extent)

    for stroke in strokes {
      guard let context = CGContext(
        data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return nil }
      context.scaleBy(x: scale, y: scale)
      context.addPath(path)
      context.setLineWidth(stroke.width)
      context.setLineJoin(.round)
      context.setStrokeColor(CGColor(gray: 1, alpha: stroke.alpha))
      context.strokePath()
      guard let image = context.makeImage() else { return nil }

      var layer = CIImage(cgImage: image)
      if stroke.blur * scale > 0.5 {
        layer = layer.clampedToExtent().applyingGaussianBlur(sigma: Double(stroke.blur * scale) / 2).cropped(to: extent)
      }
      composite = layer.composited(over: composite)
    }
    return ciContext.createCGImage(composite, from: extent)
  }

  private func removeGlowAnimations() {
    root.removeAllAnimations()
    root.opacity = 1
    magic.stop()
    for band in [line, haze] {
      band.holder.removeAllAnimations()
      band.holder.opacity = 1
      band.primary.removeAllAnimations()
      band.secondary.removeAllAnimations()
    }
  }
}

extension RGBA {
  var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

  func withAlpha(_ alpha: Double) -> RGBA {
    RGBA(red: red, green: green, blue: blue, alpha: alpha)
  }
}
