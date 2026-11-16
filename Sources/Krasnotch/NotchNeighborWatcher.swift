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
  /// How many samples in a row a window may be uncapturable before it's passed over. Covers the wait for
  /// the next content refetch, which is when a window that just appeared gets its capture handle.
  private static let captureGrace = 6

  /// Outlines that reach past the hardware notch, per display. Kept while stopped.
  private(set) var outlines: [CGDirectDisplayID: NeighborOutline] = [:]
  var onChange: (() -> Void)?

  private var task: Task<Void, Never>?
  /// A changed measurement waits for one more matching sample, so a shape mid-animation is skipped.
  private var pending: [CGDirectDisplayID: NeighborOutline]?
  private var steadySamples = 0
  private var captureWindows: [CGWindowID: SCWindow] = [:]
  private var lastContentFetch: ContinuousClock.Instant?
  /// Consecutive samples each window couldn't be captured in.
  private var misses: [CGWindowID: Int] = [:]

  private enum Measurement {
    case shape(NeighborOutline)
    /// Captured, with nothing opaque hanging over the notch.
    case nothing
    /// Not captured, so what the window shows is unknown.
    case unavailable
  }

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
    lastContentFetch = nil
    misses = [:]
  }

  private func sample(confirm: Bool) async {
    var measured: [CGDirectDisplayID: NeighborOutline] = [:]
    var listed: Set<CGWindowID> = []
    var inconclusive = false
    for screen in NSScreen.screens {
      guard let notch = screen.notch else { continue }
      let display = CGDisplayBounds(screen.displayID)
      let notchRect = CGRect(x: display.minX + notch.minX, y: display.minY, width: notch.maxX - notch.minX, height: notch.height)
      var outline: NeighborOutline?
      var measuredApps: Set<pid_t> = []
      var waiting = false
      let candidates = Self.windows(over: notchRect, in: display)
      listed.formUnion(candidates.map(\.id))
      // Front to back. Only each app's frontmost shape counts: windows behind it are backdrops (Alcove's
      // blur, for one, captures as a solid black rectangle even though it's translucent on screen).
      for candidate in candidates where !measuredApps.contains(candidate.pid) {
        switch await measure(window: candidate.id, bounds: candidate.bounds, seedX: notchRect.midX, display: display) {
        case let .shape(found):
          misses[candidate.id] = nil
          measuredApps.insert(candidate.pid)
          outline = outline.map { $0.union(found) } ?? found
        case .nothing:
          misses[candidate.id] = nil
        case .unavailable:
          let count = misses[candidate.id, default: 0] + 1
          misses[candidate.id] = count
          waiting = count <= Self.captureGrace
        }
        // Reading on past a window that can't be captured yet would measure the backdrop behind it, or
        // find nothing at all. Either is wrong, so this display waits instead.
        if waiting { break }
      }
      if waiting {
        measured[screen.displayID] = outlines[screen.displayID]
        inconclusive = true
      } else if let outline, notch.isExceeded(by: outline.notch) {
        measured[screen.displayID] = outline
      }
    }
    misses = misses.filter { listed.contains($0.key) }
    guard !Task.isCancelled else { return }

    guard measured != outlines else {
      pending = nil
      // Keep sampling quickly while a display is waiting on a window.
      steadySamples = inconclusive ? 0 : steadySamples + 1
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

  private func measure(window id: CGWindowID, bounds: CGRect, seedX: CGFloat, display: CGRect) async -> Measurement {
    guard let window = await captureWindow(id) else { return .unavailable }
    let config = SCStreamConfiguration()
    // One pixel per point is precise enough and keeps each capture tiny.
    config.width = max(1, Int(bounds.width))
    config.height = max(1, Int(bounds.height))
    config.showsCursor = false
    config.ignoreShadowsSingleWindow = true
    guard let image = try? await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config
    ) else {
      // The handle may be stale; fetch a new one next time.
      captureWindows[id] = nil
      return .unavailable
    }

    let scaleX = bounds.width / CGFloat(image.width), scaleY = bounds.height / CGFloat(image.height)
    guard let shape = NotchShape.measure(image: image, seedX: Int((seedX - bounds.minX) / scaleX)) else { return .nothing }
    let left = bounds.minX - display.minX, top = bounds.minY - display.minY
    return .shape(NeighborOutline(
      notch: NotchGeometry(minX: left + CGFloat(shape.minX) * scaleX, maxX: left + CGFloat(shape.maxX) * scaleX,
                           height: top + CGFloat(shape.height) * scaleY),
      cornerRadius: CGFloat(shape.cornerRadius) * scaleY
    ))
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
