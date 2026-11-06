import AppKit
import KrasnotchKit

/// Transparent, click-through window covering an entire screen, menu bar and notch area included.
final class OverlayWindow: NSWindow {
  let glowView: GlowLayerView

  init(screen: NSScreen) {
    glowView = GlowLayerView(frame: CGRect(origin: .zero, size: screen.frame.size))
    super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    isReleasedWhenClosed = false
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    alphaValue = 0
    contentView = glowView
    setFrame(screen.frame, display: false)
  }

  // Borderless windows still get nudged below the menu bar unless we opt out.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

extension NSScreen {
  var displayID: CGDirectDisplayID {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
  }

  var isBuiltIn: Bool { CGDisplayIsBuiltin(displayID) != 0 }

  var notch: NotchGeometry? {
    guard safeAreaInsets.top > 0, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
    // Treat the auxiliary areas as global if they fall inside this screen's global frame, local otherwise.
    let originX = frame.contains(CGPoint(x: left.midX, y: left.midY)) ? frame.minX : 0
    return NotchGeometry(minX: left.maxX - originX, maxX: right.minX - originX, height: safeAreaInsets.top)
  }
}
