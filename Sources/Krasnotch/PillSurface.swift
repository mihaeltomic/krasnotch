import KrasnotchKit
import SwiftUI

/// The thread pill's fill: the state's palette flowing the way its glow does, plus a soap-bubble finish and
/// twinkling glitter when Magic is on.
struct PillSurface: View {
  let style: GlowStyle
  let animate: Bool

  private var flows: Bool { style.colors.count > 1 && style.motion != .solid }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate || !(flows || style.magic))) { context in
      let time = animate ? context.date.timeIntervalSinceReferenceDate : 0
      let phase = flows ? (time / max(style.speed, 0.3)).truncatingRemainder(dividingBy: 1) : 0
      ZStack {
        PaletteFlow(colors: style.swiftUIColors, phase: phase)
          .clipShape(Capsule())
        if style.magic {
          BubbleFinish(time: time)
          Glitter(time: time, tint: style.primaryColor)
        }
      }
    }
  }
}

/// The palette as a seamless gradient band scrolling sideways, one full loop per glow cycle.
private struct PaletteFlow: View {
  let colors: [Color]
  let phase: Double

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      if colors.count < 2 {
        (colors.first ?? .white)
      } else {
        LinearGradient(colors: colors + colors + [colors[0]], startPoint: .leading, endPoint: .trailing)
          .frame(width: width * 2)
          .offset(x: -phase * width)
      }
    }
  }
}

/// Thin-film iridescence, a glossy top highlight and a rainbow rim, like light on a soap bubble.
private struct BubbleFinish: View {
  let time: Double

  private static let film: [Color] = [
    Color(red: 1, green: 0.62, blue: 0.85), Color(red: 0.55, green: 0.9, blue: 1), Color(red: 1, green: 0.96, blue: 0.6),
    Color(red: 0.75, green: 0.65, blue: 1), Color(red: 0.6, green: 1, blue: 0.82), Color(red: 1, green: 0.62, blue: 0.85),
  ]

  var body: some View {
    let swirl = Angle.degrees(time * 50)
    ZStack {
      Capsule()
        .fill(AngularGradient(colors: Self.film, center: .center, angle: swirl))
        .blendMode(.overlay)
        .opacity(0.65)
      // Glossy cap across the upper half.
      Capsule()
        .fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
        .padding(.horizontal, 5)
        .padding(.top, 1.5)
        .frame(maxHeight: .infinity, alignment: .top)
        .scaleEffect(y: 0.48, anchor: .top)
      // Specular glint, top left.
      Ellipse()
        .fill(.white.opacity(0.95))
        .frame(width: 7, height: 2.5)
        .blur(radius: 0.4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: 9, y: 4)
      // Faint bounce light along the bottom.
      Capsule()
        .fill(LinearGradient(colors: [.clear, .white.opacity(0.3)], startPoint: .center, endPoint: .bottom))
      Capsule()
        .strokeBorder(AngularGradient(colors: Self.film, center: .center, angle: -swirl * 1.3), lineWidth: 1)
        .opacity(0.9)
    }
    .clipShape(Capsule())
    .allowsHitTesting(false)
  }
}

/// A few sparkles that twinkle and turn around the pill's edge.
private struct Glitter: View {
  let time: Double
  let tint: Color

  /// Unit positions around the pill, slightly outside its edge.
  private static let spots: [CGPoint] = [
    CGPoint(x: 0.06, y: 0.05), CGPoint(x: 0.3, y: 1.08), CGPoint(x: 0.52, y: -0.08),
    CGPoint(x: 0.74, y: 1.05), CGPoint(x: 0.95, y: 0.12), CGPoint(x: -0.02, y: 0.85),
  ]

  var body: some View {
    GeometryReader { proxy in
      ForEach(Self.spots.indices, id: \.self) { index in
        let spot = Self.spots[index]
        let wave = max(0, sin(time * 2.4 + Double(index) * 1.9))
        Image(systemName: "sparkle")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.white)
          .shadow(color: tint, radius: 2)
          .scaleEffect(0.4 + 0.8 * wave)
          .rotationEffect(.degrees(time * 45 + Double(index) * 30))
          .opacity(wave)
          .position(x: spot.x * proxy.size.width, y: spot.y * proxy.size.height)
      }
    }
    .allowsHitTesting(false)
  }
}
