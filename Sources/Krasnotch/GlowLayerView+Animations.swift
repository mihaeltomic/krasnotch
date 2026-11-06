import AppKit
import KrasnotchKit

extension GlowLayerView {
  /// 60fps is plenty for a soft glow; keeps ProMotion panels from rendering it at 120Hz.
  private static let frameRate = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)

  func addAnimations(for style: GlowStyle) {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      if style.magic { magic.start(cycle: style.speed, reduceMotion: true) }
      return
    }
    let cycle = max(style.speed, 0.2)

    switch style.motion {
    case .flow:
      spinGradients(cycle: cycle)
      let breathe = basic("opacity", from: 0.75, to: 1, duration: cycle / 3)
      breathe.autoreverses = true
      haze.holder.add(breathe, forKey: "breathe")
    case .pulse:
      spinGradients(cycle: cycle * 4)
      let pulse = basic("opacity", from: 0.5, to: 1, duration: cycle / 2)
      pulse.autoreverses = true
      root.add(pulse, forKey: "pulse")
    case .comet:
      for band in [line, haze] {
        band.primary.add(spin(duration: cycle, clockwise: true, easing: .linear), forKey: "spin")
      }
    case .scanner:
      for band in [line, haze] {
        let sweep = spin(duration: cycle / 2, clockwise: true, easing: .easeInEaseOut, sweep: .pi)
        sweep.autoreverses = true
        band.primary.add(sweep, forKey: "spin")
      }
    case .blink:
      let blink = CAKeyframeAnimation(keyPath: "opacity")
      blink.values = [0.35, 1, 0.35, 1, 0.35, 0.35]
      blink.keyTimes = [0, 0.08, 0.16, 0.24, 0.4, 1]
      blink.duration = cycle
      blink.repeatCount = .infinity
      blink.preferredFrameRateRange = Self.frameRate
      root.add(blink, forKey: "blink")
    case .solid:
      break
    }
    // Magic? rides on top of any animation; its wand keeps its own pace (a stroke at least every 1.6 s).
    if style.magic { magic.start(cycle: max(cycle, 1.6), reduceMotion: false) }
  }

  private func spinGradients(cycle: Double) {
    for band in [line, haze] {
      band.primary.add(spin(duration: cycle, clockwise: true, easing: .linear), forKey: "spin")
      band.secondary.add(spin(duration: cycle * 1.7, clockwise: false, easing: .linear), forKey: "spin")
    }
  }

  /// Rotates a conic gradient by moving its end point around the center. Unlike rotating the layer,
  /// this keeps the gradient layer screen-sized instead of needing a diagonal-sized square.
  private func spin(duration: Double, clockwise: Bool, easing: CAMediaTimingFunctionName, sweep: Double = 2 * .pi) -> CAKeyframeAnimation {
    let steps = 72
    let direction = clockwise ? -1.0 : 1.0
    let center = line.primary.startPoint
    let bounds = line.primary.bounds
    let aspect = bounds.height > 0 ? bounds.width / bounds.height : 1
    let animation = CAKeyframeAnimation(keyPath: "endPoint")
    animation.values = (0...steps).map { step in
      let angle = direction * sweep * Double(step) / Double(steps)
      return NSValue(point: CGPoint(x: center.x + 0.1 * sin(angle), y: center.y + 0.1 * aspect * cos(angle)))
    }
    animation.duration = duration
    animation.repeatCount = .infinity
    animation.timingFunction = CAMediaTimingFunction(name: easing)
    animation.preferredFrameRateRange = Self.frameRate
    return animation
  }

  private func basic(_ keyPath: String, from: Any, to: Any, duration: Double) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: keyPath)
    animation.fromValue = from
    animation.toValue = to
    animation.duration = duration
    animation.repeatCount = .infinity
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    animation.preferredFrameRateRange = Self.frameRate
    return animation
  }
}
