import Foundation

public enum GlowState: String, CaseIterable, Codable, Sendable, Identifiable {
  case working, needsInput, done

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .working: "Working"
    case .needsInput: "Needs you"
    case .done: "Done"
    }
  }

  var priority: Int {
    switch self {
    case .needsInput: 3
    case .working: 2
    case .done: 1
    }
  }
}

public enum GlowAnimation: String, CaseIterable, Codable, Sendable, Identifiable {
  case flow, pulse, comet, scanner, blink, solid

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .flow: "Flow"
    case .pulse: "Pulse"
    case .comet: "Comet"
    case .scanner: "Ping-pong"
    case .blink: "Double blink"
    case .solid: "Solid"
    }
  }
}

public struct GlowStyle: Codable, Equatable, Sendable {
  public var motion: GlowAnimation
  /// sRGB hex strings, e.g. "#2EA8FF".
  public var colors: [String]
  /// Seconds per animation cycle.
  public var speed: Double
  /// Visible line thickness in points.
  public var thickness: Double
  /// 0...1, scales the soft outer glow.
  public var intensity: Double
  public var dither: Bool = false
  /// Sprinkles the Magic wand and glitter on top of whichever animation runs.
  public var magic: Bool = false

  private enum CodingKeys: String, CodingKey { case motion, colors, speed, thickness, intensity, dither, magic }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // Magic used to be an animation; a saved "magic" motion becomes Flow with Magic switched on.
    let rawMotion = try c.decode(String.self, forKey: .motion)
    motion = GlowAnimation(rawValue: rawMotion) ?? .flow
    colors = try c.decode([String].self, forKey: .colors)
    speed = try c.decode(Double.self, forKey: .speed)
    thickness = try c.decode(Double.self, forKey: .thickness)
    intensity = try c.decode(Double.self, forKey: .intensity)
    dither = try c.decodeIfPresent(Bool.self, forKey: .dither) ?? false
    magic = try c.decodeIfPresent(Bool.self, forKey: .magic) ?? (rawMotion == "magic")
  }

  public init(motion: GlowAnimation, colors: [String], speed: Double, thickness: Double, intensity: Double) {
    self.motion = motion
    self.colors = colors
    self.speed = speed
    self.thickness = thickness
    self.intensity = intensity
  }
}

public struct GlowConfig: Codable, Equatable, Sendable {
  public var enabled = true
  public var working = GlowStyle.defaultStyle(for: .working)
  public var needsInput = GlowStyle.defaultStyle(for: .needsInput)
  public var done = GlowStyle.defaultStyle(for: .done)
  public var topCornerRadius = 10.0
  public var bottomCornerRadius = 0.0
  public var notchCornerRadius = 8.0
  public var doneDuration = 4.0
  public var showOnExternalDisplays = false
  public var hideFromScreenCapture = true
  /// 0.2...1, overall opacity of the glow on screen.
  public var brightness = 1.0
  /// Shows a clickable pill with the thread's name under the notch when an agent finishes.
  public var showDonePill = true
  /// Same pill, when an agent is waiting on you.
  public var showNeedsInputPill = true
  /// Seconds the pill stays up (it holds while hovered).
  public var pillDuration = 8.0

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case enabled, working, needsInput, done, topCornerRadius, bottomCornerRadius, notchCornerRadius
    case doneDuration, showOnExternalDisplays, hideFromScreenCapture, brightness, showDonePill, showNeedsInputPill, pillDuration
  }

  /// Missing keys fall back to defaults, so adding a setting never wipes someone's saved config.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = GlowConfig()
    enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
    working = try c.decodeIfPresent(GlowStyle.self, forKey: .working) ?? d.working
    needsInput = try c.decodeIfPresent(GlowStyle.self, forKey: .needsInput) ?? d.needsInput
    done = try c.decodeIfPresent(GlowStyle.self, forKey: .done) ?? d.done
    topCornerRadius = try c.decodeIfPresent(Double.self, forKey: .topCornerRadius) ?? d.topCornerRadius
    bottomCornerRadius = try c.decodeIfPresent(Double.self, forKey: .bottomCornerRadius) ?? d.bottomCornerRadius
    notchCornerRadius = try c.decodeIfPresent(Double.self, forKey: .notchCornerRadius) ?? d.notchCornerRadius
    doneDuration = try c.decodeIfPresent(Double.self, forKey: .doneDuration) ?? d.doneDuration
    showOnExternalDisplays = try c.decodeIfPresent(Bool.self, forKey: .showOnExternalDisplays) ?? d.showOnExternalDisplays
    hideFromScreenCapture = try c.decodeIfPresent(Bool.self, forKey: .hideFromScreenCapture) ?? d.hideFromScreenCapture
    brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? d.brightness
    showDonePill = try c.decodeIfPresent(Bool.self, forKey: .showDonePill) ?? d.showDonePill
    showNeedsInputPill = try c.decodeIfPresent(Bool.self, forKey: .showNeedsInputPill) ?? d.showNeedsInputPill
    pillDuration = try c.decodeIfPresent(Double.self, forKey: .pillDuration) ?? d.pillDuration
  }

  public func showsPill(for state: GlowState) -> Bool {
    switch state {
    case .done: showDonePill
    case .needsInput: showNeedsInputPill
    case .working: false
    }
  }

  public subscript(state: GlowState) -> GlowStyle {
    get {
      switch state {
      case .working: working
      case .needsInput: needsInput
      case .done: done
      }
    }
    set {
      switch state {
      case .working: working = newValue
      case .needsInput: needsInput = newValue
      case .done: done = newValue
      }
    }
  }
}

extension GlowStyle {
  /// Whether text on this palette reads better dark than white, judged on its darkest color.
  public var prefersDarkText: Bool {
    let darkest = colors.compactMap(RGBA.init(hex:)).map(\.luminance).min() ?? 1
    // WCAG: dark text wins once (L + 0.05)² > 1.05 × 0.05, i.e. above ~0.18.
    return darkest > 0.179
  }

  public static func defaultStyle(for state: GlowState) -> GlowStyle {
    switch state {
    case .working:
      GlowStyle(
        motion: .flow,
        colors: ["#2EA8FF", "#8E5CFF", "#FF4FA3", "#FF9A3D"],
        speed: 6, thickness: 4, intensity: 0.8
      )
    case .needsInput:
      GlowStyle(
        motion: .pulse,
        colors: ["#FF9F0A", "#FF375F"],
        speed: 1.4, thickness: 5, intensity: 0.9
      )
    case .done:
      GlowStyle(
        motion: .solid,
        colors: ["#30D158", "#7CF5B0"],
        speed: 2, thickness: 4, intensity: 0.7
      )
    }
  }
}
