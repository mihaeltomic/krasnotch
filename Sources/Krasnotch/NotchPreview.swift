import KrasnotchKit
import SwiftUI

/// Miniature notch rendering one style, animated the same way the real overlay is.
struct NotchPreview: View {
  let style: GlowStyle
  var scale: CGFloat = 0.6

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || (style.motion == .solid && !style.magic))) { context in
      let frame = PreviewFrame(style: style, time: context.date.timeIntervalSinceReferenceDate)
      GeometryReader { geometry in
        let notch = NotchMetrics(size: geometry.size)
        let t = style.thickness * scale
        let gradient = frame.gradient(center: notch.center(in: geometry.size))
        let base = style.magic ? 0.6 : 1.0  // the animation steps back under Magic?, like the real notch
        ZStack {
          // Light the "screen" below the notch so the card reads as a display, not an empty box.
          Ellipse()
            .fill(RadialGradient(colors: [style.primaryColor.opacity(0.22 * style.intensity), .clear], center: .center, startRadius: 0, endRadius: notch.width * 0.9))
            .frame(width: notch.width * 2.2, height: notch.height * 7)
            .position(x: notch.midX, y: notch.height)
          if style.dither, let mask = DitherPreviewCache.mask(size: geometry.size, metrics: notch, thickness: t, intensity: style.intensity, cell: 2 * scale) {
            // Same ordered dither as the real notch, at the preview's scale, drawn as crisp square pixels.
            Rectangle().fill(gradient)
              .mask(Image(decorative: mask, scale: 1 / (2 * scale)).interpolation(.none).resizable())
              .opacity(frame.haze * base)
          } else {
            NotchOutline(metrics: notch).stroke(gradient, style: .init(lineWidth: t * 6, lineCap: .round))
              .blur(radius: t * 3).opacity(0.6 * style.intensity * frame.haze * base)
          }
          NotchOutline(metrics: notch).stroke(gradient, style: .init(lineWidth: t * 2.5, lineCap: .round))
            .blur(radius: t).opacity(0.85 * style.intensity * base)
          NotchOutline(metrics: notch).stroke(gradient, style: .init(lineWidth: t, lineCap: .round)).opacity(base)
          if style.magic {
            MagicPreview(style: style, metrics: notch, size: geometry.size, thickness: t,
                         time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
          }
          NotchOutline(metrics: notch, closed: true).fill(.black)
        }
        .opacity(frame.opacity)
      }
    }
    .background(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.07)], startPoint: .top, endPoint: .bottom))
    .clipShape(.rect(cornerRadius: 10))
    .accessibilityHidden(true)
  }
}

/// Dithered haze masks are static per size and style, so build each once rather than every frame.
@MainActor
private enum DitherPreviewCache {
  private static var images: [String: CGImage] = [:]
  private static let context = CIContext()

  static func mask(size: CGSize, metrics: NotchMetrics, thickness: CGFloat, intensity: Double, cell: CGFloat) -> CGImage? {
    guard size.width > 0, size.height > 0 else { return nil }
    let key = "\(Int(size.width))x\(Int(size.height))-\(thickness)-\(intensity)-\(cell)"
    if let image = images[key] { return image }
    let path = NotchOutline(metrics: metrics).path(in: CGRect(origin: .zero, size: size)).cgPath
    guard let image = DitherMask.render(path: path, size: size, cell: cell, strokeWidth: thickness * 6, blur: thickness * 6,
                                        alpha: 0.6 * intensity, flipped: true, context: context) else { return nil }
    if images.count > 32 { images.removeAll() }
    images[key] = image
    return image
  }
}

/// Per-frame animation values, mirroring GlowLayerView+Animations.
private struct PreviewFrame {
  let style: GlowStyle
  let time: TimeInterval

  private var cycle: Double { max(style.speed, 0.2) }
  private var phase: Double { time / cycle }

  var angle: Angle {
    switch style.motion {
    case .flow, .comet: .degrees(phase * 360)
    case .pulse: .degrees(phase * 90)
    case .scanner: .degrees((1 - cos(phase * 2 * .pi)) / 2 * 180)
    case .blink, .solid: .zero
    }
  }

  var opacity: Double {
    switch style.motion {
    case .pulse: return 0.75 + 0.25 * cos(phase * 2 * .pi)
    case .blink:
      let p = phase.truncatingRemainder(dividingBy: 1)
      return (p < 0.08 || (p > 0.16 && p < 0.24)) ? 1 : 0.35
    default: return 1
    }
  }

  var haze: Double {
    style.motion == .flow ? 0.875 + 0.125 * cos(phase * 6 * .pi) : 1
  }

  func gradient(center: UnitPoint) -> AngularGradient {
    let colors = style.swiftUIColors
    if style.motion == .comet || style.motion == .scanner {
      let tail = colors.enumerated().map { Gradient.Stop(color: $1, location: 0.62 + 0.365 * Double($0 + 1) / Double(colors.count)) }
      let stops = [Gradient.Stop(color: colors[0].opacity(0), location: 0), .init(color: colors[0].opacity(0), location: 0.62)]
        + tail + [.init(color: colors[0].opacity(0), location: 1)]
      return AngularGradient(stops: stops, center: center, angle: angle)
    }
    return AngularGradient(colors: colors + [colors[0]], center: center, angle: angle)
  }
}

struct NotchMetrics {
  let width: CGFloat
  let height: CGFloat
  let radius: CGFloat
  let midX: CGFloat

  init(size: CGSize) {
    width = size.width * 0.42
    height = min(size.height * 0.36, width * 0.19)
    radius = height * 0.45
    midX = size.width / 2
  }

  func center(in size: CGSize) -> UnitPoint {
    UnitPoint(x: 0.5, y: height / 2 / max(size.height, 1))
  }
}

/// The notch's sides and lower edge; closed fills the notch body itself.
struct NotchOutline: Shape {
  let metrics: NotchMetrics
  var closed = false

  func path(in rect: CGRect) -> Path {
    let left = metrics.midX - metrics.width / 2
    let right = metrics.midX + metrics.width / 2
    let bottom = metrics.height
    var path = Path()
    path.move(to: CGPoint(x: left, y: -1))
    path.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: right, y: bottom), radius: metrics.radius)
    path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: right, y: -1), radius: metrics.radius)
    path.addLine(to: CGPoint(x: right, y: -1))
    if closed { path.closeSubpath() }
    return path
  }
}

/// The Magic wand stroke in miniature: same easing and rest beat as MagicLayer, glitter drawn per frame.
private struct MagicPreview: View {
  let style: GlowStyle
  let metrics: NotchMetrics
  let size: CGSize
  let thickness: CGFloat
  let time: TimeInterval

  var body: some View {
    let colors: [Color] = style.swiftUIColors
    let cycle: Double = max(style.speed, 1.6)
    let travel: Double = cycle * 0.72
    let local: Double = time.truncatingRemainder(dividingBy: cycle)
    let raw: Double = min(local / travel, 1)
    let head: Double = raw < 0.5 ? 2 * raw * raw : 1 - pow(-2 * raw + 2, 2) / 2
    let moving: Bool = local < travel
    let shape = NotchOutline(metrics: metrics)
    let outline: Path = shape.path(in: CGRect(origin: .zero, size: size))
    let tail = shape.trim(from: moving ? max(head - 0.16, 0) : 0, to: moving ? head : 0)

    ZStack {
      tail.stroke(colors[0], style: StrokeStyle(lineWidth: thickness * 2.2, lineCap: .round))
        .shadow(color: colors[0], radius: thickness * 2)
      tail.stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: thickness * 0.8, lineCap: .round))
      Canvas { context, _ in
        drawGlitter(in: &context, outline: outline, head: head, moving: moving, colors: colors)
      }
    }
  }

  /// 28 sparks shed along the trail; each one's age decides how far it fell and how much it faded.
  private func drawGlitter(in context: inout GraphicsContext, outline: Path, head: Double, moving: Bool, colors: [Color]) {
    context.blendMode = .plusLighter
    for i in 0..<28 {
      let age: Double = Double(i) / 28 * 0.9
      let born: Double = head - age * 0.25
      guard moving || age > 0.3, born > 0, born < 1 else { continue }
      let point: CGPoint = outline.trimmedPath(from: born, to: min(born + 0.0005, 1)).boundingRect.origin
      let seed: CGFloat = CGFloat((i * 7919) % 97) / 97
      let ageF = CGFloat(age)
      let x: CGFloat = point.x + (seed - 0.5) * thickness * 6 * ageF
      let y: CGFloat = point.y + thickness * 10 * ageF * ageF + seed * thickness
      let r: CGFloat = thickness * (0.9 - ageF * 0.8) * (0.6 + seed * 0.6)
      guard r > 0 else { continue }
      let color: Color = colors[i % colors.count].opacity(1 - age)
      let shape: Path = i % 3 == 0 ? starPath(x: x, y: y, r: r) : Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r))
      context.fill(shape, with: .color(color))
    }
  }

  private func starPath(x: CGFloat, y: CGFloat, r: CGFloat) -> Path {
    let center = CGPoint(x: x, y: y)
    var star = Path()
    star.move(to: CGPoint(x: x, y: y - r * 2))
    star.addQuadCurve(to: CGPoint(x: x + r * 2, y: y), control: center)
    star.addQuadCurve(to: CGPoint(x: x, y: y + r * 2), control: center)
    star.addQuadCurve(to: CGPoint(x: x - r * 2, y: y), control: center)
    star.addQuadCurve(to: CGPoint(x: x, y: y - r * 2), control: center)
    return star
  }
}
