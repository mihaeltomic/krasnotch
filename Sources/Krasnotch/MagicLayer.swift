import AppKit
import KrasnotchKit

/// "Magic": a wand stroke arcs along the notch outline, shedding glitter that twinkles, spins and falls.
/// Everything runs as Core Animation in the render server: a stroked head plus two particle emitters.
final class MagicLayer: CALayer {
  private let glow = CAShapeLayer()
  private let core = CAShapeLayer()
  private let wand = CAEmitterLayer()
  private let dust = CAEmitterLayer()
  private var outline: CGPath?

  override init() {
    super.init()
    for shape in [glow, core] {
      shape.fillColor = nil
      shape.lineCap = .round
      shape.lineJoin = .round
      shape.strokeStart = 0
      shape.strokeEnd = 0
      addSublayer(shape)
    }
    glow.shadowOpacity = 1
    glow.shadowOffset = .zero
    for emitter in [wand, dust] {
      emitter.renderMode = .additive
      emitter.birthRate = 0
      addSublayer(emitter)
    }
    wand.emitterShape = .point
    dust.emitterShape = .rectangle
    isHidden = true
  }

  override init(layer: Any) { super.init(layer: layer) }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func configure(path: CGPath, bounds: CGRect, notch: NotchGeometry?, style: GlowStyle) {
    frame = bounds
    outline = path
    let colors = style.colors.compactMap(RGBA.init(hex:)).map(\.cgColor)
    let palette = colors.isEmpty ? [CGColor(srgbRed: 1, green: 0.83, blue: 0.43, alpha: 1)] : colors
    let width = CGFloat(style.thickness) * 2
    let brightest = palette.max { luminance($0) < luminance($1) } ?? palette[0]

    for shape in [glow, core] { shape.frame = bounds; shape.path = path }
    glow.lineWidth = width * 2.2
    glow.strokeColor = palette[0]
    glow.shadowColor = palette[0]
    glow.shadowRadius = width * 2.4 * max(CGFloat(style.intensity), 0.3)
    core.lineWidth = width * 0.9
    core.strokeColor = brightest.copy(alpha: 1) ?? brightest

    wand.frame = bounds
    wand.emitterCells = palette.flatMap { [Self.starCell(color: $0, scale: width, count: palette.count),
                                          Self.dotCell(color: $0, scale: width, count: palette.count)] }
    dust.frame = bounds
    if let notch {
      dust.emitterPosition = CGPoint(x: (notch.minX + notch.maxX) / 2, y: bounds.height - notch.height - width)
      dust.emitterSize = CGSize(width: notch.maxX - notch.minX + width * 6, height: width * 3)
    }
    dust.emitterCells = palette.map { Self.twinkleCell(color: $0, scale: width, count: palette.count) }
  }

  /// One wand stroke per `cycle`: the head eases along the whole outline, then rests for a beat.
  func start(cycle: Double, reduceMotion: Bool) {
    stop()
    guard let outline else { return }
    isHidden = false
    if reduceMotion {
      // A still, softly lit outline instead of the moving wand.
      for shape in [glow, core] { shape.strokeStart = 0; shape.strokeEnd = 1; shape.opacity = 0.5 }
      return
    }
    let travel = cycle * 0.72, total = cycle
    let head = 0.16
    for shape in [glow, core] {
      shape.opacity = 1
      shape.add(keyframes("strokeEnd", [0, 1, 1], at: [0, travel / total, 1], duration: total), forKey: "end")
      shape.add(keyframes("strokeStart", [0, 0, 1, 1], at: [0, head * travel / total, travel / total, 1], duration: total), forKey: "start")
    }
    let move = CAKeyframeAnimation(keyPath: "emitterPosition")
    move.path = outline
    move.calculationMode = .paced
    move.duration = travel
    move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    let group = CAAnimationGroup()
    group.animations = [move]
    group.duration = total
    group.repeatCount = .infinity
    wand.add(group, forKey: "wand")
    // Emit only while the wand moves: on during the stroke, off during the rest.
    wand.add(keyframes("birthRate", [1, 1, 0, 0], at: [0, travel / total, travel / total + 0.01, 1], duration: total, discrete: true), forKey: "emit")
    wand.birthRate = 1
    dust.birthRate = 1
  }

  func stop() {
    for shape in [glow, core] { shape.removeAllAnimations(); shape.strokeStart = 0; shape.strokeEnd = 0 }
    wand.removeAllAnimations()
    wand.birthRate = 0
    dust.birthRate = 0
    isHidden = true
  }

  // MARK: - Pieces

  private func keyframes(_ keyPath: String, _ values: [Double], at times: [Double], duration: Double, discrete: Bool = false) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = times.map { NSNumber(value: $0) }
    animation.duration = duration
    animation.repeatCount = .infinity
    animation.calculationMode = discrete ? .discrete : .linear
    if !discrete {
      animation.timingFunctions = (1..<values.count).map { _ in CAMediaTimingFunction(name: .easeInEaseOut) }
    }
    animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    return animation
  }

  private func luminance(_ color: CGColor) -> CGFloat {
    guard let c = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components, c.count >= 3 else { return 0 }
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
  }

  /// Four-point glints that spin, shrink and fall away from the wand.
  private static func starCell(color: CGColor, scale: CGFloat, count: Int) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.contents = sparkle
    cell.color = color
    cell.birthRate = Float(70 / count)
    cell.lifetime = 1.3
    cell.lifetimeRange = 0.5
    cell.velocity = scale * 6
    cell.velocityRange = scale * 4
    cell.emissionRange = .pi * 2
    cell.yAcceleration = -scale * 9
    cell.scale = scale / 40
    cell.scaleRange = scale / 70
    cell.scaleSpeed = -scale / 90
    cell.alphaSpeed = -0.75
    cell.spin = 2
    cell.spinRange = 5
    return cell
  }

  /// Soft glowing dots that make up the body of the trail.
  private static func dotCell(color: CGColor, scale: CGFloat, count: Int) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.contents = dot
    cell.color = color
    cell.birthRate = Float(160 / count)
    cell.lifetime = 0.9
    cell.lifetimeRange = 0.4
    cell.velocity = scale * 3
    cell.velocityRange = scale * 3
    cell.emissionRange = .pi * 2
    cell.yAcceleration = -scale * 6
    cell.scale = scale / 60
    cell.scaleRange = scale / 120
    cell.alphaSpeed = -1.1
    return cell
  }

  /// Ambient glitter that keeps twinkling around the notch between strokes.
  private static func twinkleCell(color: CGColor, scale: CGFloat, count: Int) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.contents = sparkle
    cell.color = color
    cell.birthRate = Float(10 / count)
    cell.lifetime = 1.6
    cell.lifetimeRange = 0.6
    cell.velocity = scale
    cell.emissionRange = .pi * 2
    cell.yAcceleration = -scale * 2
    cell.scale = scale / 70
    cell.scaleRange = scale / 120
    cell.alphaRange = 0.5
    cell.alphaSpeed = -0.6
    cell.spinRange = 3
    return cell
  }

  /// A white four-point glint with a soft centre; tinted per cell.
  private static let sparkle: CGImage? = {
    let size = 64, c = CGFloat(size) / 2
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let ray = CGMutablePath()
    let long = c * 0.98, thin = c * 0.12
    ray.move(to: CGPoint(x: c, y: c - long)); ray.addQuadCurve(to: CGPoint(x: c + long, y: c), control: CGPoint(x: c + thin, y: c - thin))
    ray.addQuadCurve(to: CGPoint(x: c, y: c + long), control: CGPoint(x: c + thin, y: c + thin))
    ray.addQuadCurve(to: CGPoint(x: c - long, y: c), control: CGPoint(x: c - thin, y: c + thin))
    ray.addQuadCurve(to: CGPoint(x: c, y: c - long), control: CGPoint(x: c - thin, y: c - thin))
    ctx.addPath(ray)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(gray: 1, alpha: 0.9), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glowGradient, startCenter: CGPoint(x: c, y: c), startRadius: 0, endCenter: CGPoint(x: c, y: c), endRadius: c * 0.45, options: [])
    return ctx.makeImage()
  }()

  /// A soft round dot.
  private static let dot: CGImage? = {
    let size = 32, c = CGFloat(size) / 2
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: c, y: c), startRadius: 0, endCenter: CGPoint(x: c, y: c), endRadius: c, options: [])
    return ctx.makeImage()
  }()
}
