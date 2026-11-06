import Foundation

public struct RGBA: Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  /// Accepts "#RRGGBB" or "#RRGGBBAA" (leading "#" optional).
  public init?(hex: String) {
    let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
    guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
    let hasAlpha = digits.count == 8
    let shift: UInt64 = hasAlpha ? 8 : 0
    red = Double((value >> (16 + shift)) & 0xFF) / 255
    green = Double((value >> (8 + shift)) & 0xFF) / 255
    blue = Double((value >> shift) & 0xFF) / 255
    alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
  }

  /// WCAG relative luminance, 0 (black) to 1 (white).
  public var luminance: Double {
    func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  public var hex: String {
    let channels = [red, green, blue].map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
    let base = String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    guard alpha < 1 else { return base }
    return base + String(format: "%02X", Int((alpha * 255).rounded()).clamped(to: 0...255))
  }
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
