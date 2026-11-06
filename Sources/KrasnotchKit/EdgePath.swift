import CoreGraphics

public struct NotchGeometry: Equatable, Sendable {
  /// Horizontal extent of the notch in the screen's local coordinates.
  public var minX: CGFloat
  public var maxX: CGFloat
  public var height: CGFloat

  public init(minX: CGFloat, maxX: CGFloat, height: CGFloat) {
    self.minX = minX
    self.maxX = maxX
    self.height = height
  }
}

public struct EdgeGeometry: Equatable, Sendable {
  public var size: CGSize
  public var topCornerRadius: CGFloat
  public var bottomCornerRadius: CGFloat
  public var notch: NotchGeometry?
  public var notchCornerRadius: CGFloat

  public init(size: CGSize, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat, notch: NotchGeometry?, notchCornerRadius: CGFloat) {
    self.size = size
    self.topCornerRadius = topCornerRadius
    self.bottomCornerRadius = bottomCornerRadius
    self.notch = notch
    self.notchCornerRadius = notchCornerRadius
  }

  /// Open path following the visible sides and lower edge of the notch.
  public func path() -> CGPath {
    let path = CGMutablePath()
    guard let notch else { return path }
    let radius = max(0, min(notchCornerRadius, notch.height / 2, (notch.maxX - notch.minX) / 2))
    let inset: CGFloat = 2
    let left = notch.minX - inset, right = notch.maxX + inset
    let floor = size.height - notch.height - inset
    path.move(to: CGPoint(x: left, y: size.height))
    path.corner(CGPoint(x: left, y: floor), next: CGPoint(x: right, y: floor), radius: radius)
    path.corner(CGPoint(x: right, y: floor), next: CGPoint(x: right, y: size.height), radius: radius)
    path.addLine(to: CGPoint(x: right, y: size.height))
    return path
  }

}

private extension CGMutablePath {
  func corner(_ point: CGPoint, next: CGPoint, radius: CGFloat) {
    if radius > 0 {
      addArc(tangent1End: point, tangent2End: next, radius: radius)
    } else {
      addLine(to: point)
    }
  }
}
