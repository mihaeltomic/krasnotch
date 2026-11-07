import AppKit
import KrasnotchKit
@preconcurrency import ScreenCaptureKit

/// The outline another app draws over the notch, in the screen's local points.
struct NeighborOutline: Equatable {
  var notch: NotchGeometry
  var cornerRadius: CGFloat

  func union(_ other: NeighborOutline) -> NeighborOutline {
    NeighborOutline(notch: notch.union(other.notch), cornerRadius: max(cornerRadius, other.cornerRadius))
  }
}

/// Watches for other apps (Alcove, NotchNook, …) drawing over the notch and measures their shape,
/// so the glow and the pill can wrap around it instead of hiding behind it.
///
/// Finding the windows is free (window list). Their bounds are a fixed transparent canvas though, so
/// the visible shape is read from a 1x capture of just those windows, which needs Screen Recording.
@MainActor
final class NotchNeighborWatcher {
  /// Sampling is quick right after a change and backs off once the shape has held still a while.
  private static let quickInterval: Duration = .milliseconds(400)
  private static let steadyInterval: Duration = .seconds(1)
  private static let samplesBeforeSteady = 5
  private static let contentRefetch: Duration = .seconds(2)

  /// Outlines that reach past the hardware notch, per display. Kept while stopped.
  private(set) var outlines: [CGDirectDisplayID: NeighborOutline] = [:]
  var onChange: (() -> Void)?

  private var task: Task<Void, Never>?
  /// A changed measurement waits for one more matching sample, so a shape mid-animation is skipped.
  private var pending: [CGDirectDisplayID: NeighborOutline]?
  private var steadySamples = 0
  private var captureWindows: [CGWindowID: SCWindow] = [:]
  private var lastContentFetch: ContinuousClock.Instant?

  func start() {
    guard task == nil else { return }
    task = Task { [weak self] in
      var first = true
      while !Task.isCancelled {
        await self?.sample(confirm: !first)
        first = false
        let steady = (self?.steadySamples ?? 0) >= Self.samplesBeforeSteady
        try? await Task.sleep(for: steady ? Self.steadyInterval : Self.quickInterval)
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
    pending = nil
    steadySamples = 0
  }

  /// Stops and forgets every outline (the feature was switched off).
  func reset() {
    stop()
    outlines = [:]
    captureWindows = [:]
  }

  private func sample(confirm: Bool) async {
    var measured: [CGDirectDisplayID: NeighborOutline] = [:]
    for screen in NSScreen.screens {
      guard let notch = screen.notch else { continue }
      let display = CGDisplayBounds(screen.displayID)
      let notchRect = CGRect(x: display.minX + notch.minX, y: display.minY, width: notch.maxX - notch.minX, height: notch.height)
      var outline: NeighborOutline?
      var measuredApps: Set<pid_t> = []
      // Front to back. Only each app's frontmost shape counts: windows behind it are backdrops (Alcove's
      // blur, for one, captures as a solid black rectangle even though it's translucent on screen).
      for candidate in Self.windows(over: notchRect, in: display) where !measuredApps.contains(candidate.pid) {
        guard let found = await measure(window: candidate.id, bounds: candidate.bounds, seedX: notchRect.midX, display: display) else { continue }
        measuredApps.insert(candidate.pid)
        outline = outline.map { $0.union(found) } ?? found
      }
      if let outline, notch.isExceeded(by: outline.notch) { measured[screen.displayID] = outline }
    }
    guard !Task.isCancelled else { return }

    guard measured != outlines else {
      pending = nil
      steadySamples += 1
      return
    }
    steadySamples = 0
    // The first sample after a start applies straight away; later changes need to hold for two samples.
    guard !confirm || measured == pending else {
      pending = measured
      return
    }
    pending = nil
    outlines = measured
    onChange?()
  }

  /// Other apps' windows hanging from the top edge over the notch, front to back, from the window list
  /// (no permission needed).
  private static func windows(over notch: CGRect, in display: CGRect) -> [(id: CGWindowID, pid: pid_t, bounds: CGRect)] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let ownPID = ProcessInfo.processInfo.processIdentifier
    return list.compactMap { info in
      guard let id = info[kCGWindowNumber as String] as? CGWindowID,
            let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
            let layer = info[kCGWindowLayer as String] as? Int, layer >= Int(CGWindowLevelForKey(.statusWindow)),
            (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
            let dict = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: dict),
            bounds.minY <= display.minY + 1, bounds.intersects(notch),
            // Full-width bars (the menu bar itself) and full-screen overlays aren't notch UI.
            bounds.width < display.width * 0.9, bounds.height < display.height * 0.75
      else { return nil }
      return (id, pid, bounds)
    }
  }

  private func measure(window id: CGWindowID, bounds: CGRect, seedX: CGFloat, display: CGRect) async -> NeighborOutline? {
    guard let window = await captureWindow(id) else { return nil }
    let config = SCStreamConfiguration()
    // One pixel per point is precise enough and keeps each capture tiny.
    config.width = max(1, Int(bounds.width))
    config.height = max(1, Int(bounds.height))
    config.showsCursor = false
    config.ignoreShadowsSingleWindow = true
    guard let image = try? await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config
    ) else { return nil }

    let scaleX = bounds.width / CGFloat(image.width), scaleY = bounds.height / CGFloat(image.height)
    guard let shape = NotchShape.measure(image: image, seedX: Int((seedX - bounds.minX) / scaleX)) else { return nil }
    let left = bounds.minX - display.minX, top = bounds.minY - display.minY
    return NeighborOutline(
      notch: NotchGeometry(minX: left + CGFloat(shape.minX) * scaleX, maxX: left + CGFloat(shape.maxX) * scaleX,
                           height: top + CGFloat(shape.height) * scaleY),
      cornerRadius: CGFloat(shape.cornerRadius) * scaleY
    )
  }

  /// ScreenCaptureKit's handle for a window. Listing shareable content is slow, so it's cached and refetched sparingly.
  private func captureWindow(_ id: CGWindowID) async -> SCWindow? {
    if let window = captureWindows[id] { return window }
    let now = ContinuousClock.now
    if let last = lastContentFetch, now - last < Self.contentRefetch { return nil }
    lastContentFetch = now
    guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else { return nil }
    captureWindows = Dictionary(content.windows.map { ($0.windowID, $0) }) { first, _ in first }
    return captureWindows[id]
  }
}
