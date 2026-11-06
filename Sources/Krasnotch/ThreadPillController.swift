import AppKit
import KrasnotchKit
import SwiftUI

/// Shows the thread pill under the notch, keeps it up while hovered, and sends a click back to the thread.
@MainActor
final class ThreadPillController {
  private static let panelSize = CGSize(width: 300, height: 66)
  private static let hoverOutGrace: TimeInterval = 2.5
  private static let exitDuration: TimeInterval = 0.32

  private let model = ThreadPillModel()
  private var panel: ThreadPillPanel?
  private var session: String?
  private var origin: SessionOrigin?
  private var dismissTask: Task<Void, Never>?
  /// While Settings previews a state on the notch, the pill shows it too and real pills wait.
  private var previewing = false

  func show(session: String, state: GlowState, style: GlowStyle, title: String, origin: SessionOrigin?,
            duration: TimeInterval, hideFromCapture: Bool) {
    guard !previewing else { return }
    present(session: session, state: state, style: style, title: title, origin: origin, hideFromCapture: hideFromCapture)
    scheduleDismiss(after: duration)
  }

  /// A stand-in pill that stays up and follows the style being edited.
  func preview(state: GlowState, style: GlowStyle, hideFromCapture: Bool) {
    previewing = true
    dismissTask?.cancel()
    present(session: nil, state: state, style: style, title: "Your thread’s name", origin: nil, hideFromCapture: hideFromCapture)
  }

  func endPreview() {
    guard previewing else { return }
    previewing = false
    dismiss()
  }

  private func present(session: String?, state: GlowState, style: GlowStyle, title: String, origin: SessionOrigin?,
                       hideFromCapture: Bool) {
    guard let screen = NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.main else { return }
    self.session = session
    self.origin = origin
    model.title = title
    model.state = state
    model.style = style
    model.hasTarget = origin != nil

    let panel = panel ?? makePanel()
    panel.sharingType = hideFromCapture ? .none : .readOnly
    panel.setFrame(Self.frame(on: screen), display: false)
    if !model.visible {
      panel.orderFrontRegardless()
      // Let the hidden state render first so the drop animates from behind the notch.
      Task { @MainActor in self.model.visible = true }
    }
  }

  /// Hides the pill; with a session, only if the pill belongs to it.
  func dismiss(session: String? = nil) {
    guard model.visible, session == nil || session == self.session else { return }
    dismissTask?.cancel()
    model.visible = false
    model.hovering = false
    self.session = nil
    self.origin = nil
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(Self.exitDuration))
      guard let self, !self.model.visible else { return }
      self.panel?.orderOut(nil)
    }
  }

  private func click() {
    guard !previewing else { return }
    origin?.activate()
    dismiss()
  }

  private func hover(_ inside: Bool) {
    model.hovering = inside
    if inside { dismissTask?.cancel() } else { scheduleDismiss(after: Self.hoverOutGrace) }
  }

  private func scheduleDismiss(after delay: TimeInterval) {
    dismissTask?.cancel()
    guard !model.hovering, !previewing else { return }
    dismissTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      self?.dismiss()
    }
  }

  private func makePanel() -> ThreadPillPanel {
    let view = ThreadPillView(model: model) { [weak self] in self?.click() }
    let panel = ThreadPillPanel(contentRect: CGRect(origin: .zero, size: Self.panelSize), content: view, model: model) { [weak self] in
      self?.hover($0)
    }
    self.panel = panel
    return panel
  }

  /// Centered on the notch, top edge flush with its bottom (or with the menu bar's on screens without one).
  private static func frame(on screen: NSScreen) -> CGRect {
    let top: CGFloat
    let midX: CGFloat
    if let notch = screen.notch {
      top = screen.frame.maxY - notch.height
      midX = screen.frame.minX + (notch.minX + notch.maxX) / 2
    } else {
      top = screen.visibleFrame.maxY
      midX = screen.frame.midX
    }
    return CGRect(x: midX - panelSize.width / 2, y: top - panelSize.height, width: panelSize.width, height: panelSize.height)
  }
}

/// Transparent panel for the pill. Clicks land only where the pill is drawn; the clear margins pass through.
@MainActor
final class ThreadPillPanel: NSPanel {
  init(contentRect: CGRect, content: ThreadPillView, model: ThreadPillModel, onHover: @escaping (Bool) -> Void) {
    super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    isReleasedWhenClosed = false
    acceptsMouseMovedEvents = true
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    let host = PillHostingView(rootView: content)
    host.model = model
    host.onHover = onHover
    contentView = host
  }

  // Borderless windows get nudged below the menu bar unless we opt out.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// Acts on the first click and tracks hover even though Krasnotch never becomes the active app.
private final class PillHostingView: NSHostingView<ThreadPillView> {
  weak var model: ThreadPillModel?
  var onHover: ((Bool) -> Void)?
  private var inside = false
  private var hoverArea: NSTrackingArea?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  // `.inVisibleRect` keeps the area sized with the view, so installing it once per window is enough.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    hoverArea.map(removeTrackingArea)
    let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
    addTrackingArea(area)
    hoverArea = area
  }

  override func mouseMoved(with event: NSEvent) { track(event) }
  override func mouseEntered(with event: NSEvent) { track(event) }
  override func mouseExited(with event: NSEvent) { setInside(false) }

  private func track(_ event: NSEvent) {
    guard let model else { return }
    let point = convert(event.locationInWindow, from: nil)
    let topLeft = isFlipped ? point : CGPoint(x: point.x, y: bounds.height - point.y)
    setInside(model.visible && model.pillRect.contains(topLeft))
  }

  private func setInside(_ value: Bool) {
    guard value != inside else { return }
    inside = value
    onHover?(value)
  }
}
