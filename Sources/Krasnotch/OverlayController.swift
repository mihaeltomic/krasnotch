import AppKit
import KrasnotchKit

struct SessionTarget {
  let id: String
  let state: GlowState
  let origin: SessionOrigin?

  /// The host app when known, otherwise the agent ("claude:…") or the name a script reported.
  var displayName: String {
    if let origin { return origin.name }
    return id.hasPrefix("claude:") ? "Claude Code" : id
  }
}

@MainActor
final class OverlayController: NSObject {
  private var clickWindows: [CGDirectDisplayID: NotchClickWindow] = [:]
  private var targets: [SessionTarget] = []
  private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
  private var visible = false
  private var last: (state: GlowState?, config: GlowConfig)?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensChanged() }
    }
  }

  func render(state: GlowState?, config: GlowConfig, sessions: [SessionTarget]) {
    targets = sessions
    last = (state, config)
    guard config.enabled, let state else {
      hide()
      return
    }

    syncWindows(config: config)
    for screen in targetScreens(config: config) {
      guard let window = windows[screen.displayID] else { continue }
      window.sharingType = config.hideFromScreenCapture ? .none : .readOnly
      window.glowView.apply(style: config[state], geometry: geometry(for: screen, config: config))
      if visible { window.alphaValue = config.brightness }
      window.orderFrontRegardless()
      if !sessions.isEmpty, let notch = screen.notch {
        let click = clickWindows[screen.displayID] ?? NotchClickWindow(screen: screen, notch: notch)
        click.onClick = { [weak self, weak click] in
          guard let self, let click else { return }
          self.openSession(from: click)
        }
        clickWindows[screen.displayID] = click
        click.orderFrontRegardless()
      } else {
        clickWindows.removeValue(forKey: screen.displayID)?.close()
      }
    }

    guard !visible else { return }
    visible = true
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      windows.values.forEach { $0.animator().alphaValue = config.brightness }
    }
  }

  private func openSession(from window: NotchClickWindow) {
    guard !targets.isEmpty else { return }
    if targets.count == 1, let origin = targets[0].origin {
      origin.activate()
      return
    }
    let menu = NSMenu()
    for (index, session) in targets.enumerated() {
      let name = session.displayName
      let shortID = String(session.id.suffix(8))
      let item = NSMenuItem(title: "\(name) · \(session.state.title) · \(shortID)", action: #selector(selectSession(_:)), keyEquivalent: "")
      item.target = self
      item.tag = index
      item.isEnabled = session.origin != nil
      menu.addItem(item)
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: window.contentView)
  }

  @objc private func selectSession(_ sender: NSMenuItem) {
    guard targets.indices.contains(sender.tag) else { return }
    targets[sender.tag].origin?.activate()
  }

  private func hide() {
    guard visible else { return }
    visible = false
    clickWindows.values.forEach { $0.orderOut(nil) }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      windows.values.forEach { $0.animator().alphaValue = 0 }
    } completionHandler: {
      MainActor.assumeIsolated {
        // A new state may have arrived during the fade.
        guard !self.visible else { return }
        self.windows.values.forEach {
          $0.orderOut(nil)
          $0.glowView.stop()
        }
      }
    }
  }

  private func screensChanged() {
    clickWindows.values.forEach { $0.close() }
    clickWindows.removeAll()
    windows.values.forEach { $0.close() }
    windows.removeAll()
    visible = false
    guard let last else { return }
    render(state: last.state, config: last.config, sessions: targets)
  }

  private func syncWindows(config: GlowConfig) {
    let screens = targetScreens(config: config)
    let ids = Set(screens.map(\.displayID))
    for (id, window) in windows where !ids.contains(id) {
      window.close()
      clickWindows.removeValue(forKey: id)?.close()
      windows[id] = nil
    }
    for screen in screens where windows[screen.displayID] == nil {
      let window = OverlayWindow(screen: screen)
      window.alphaValue = visible ? config.brightness : 0
      windows[screen.displayID] = window
    }
  }

  private func targetScreens(config: GlowConfig) -> [NSScreen] {
    if config.showOnExternalDisplays { return NSScreen.screens }
    let builtIn = NSScreen.screens.filter(\.isBuiltIn)
    return builtIn.isEmpty ? Array(NSScreen.main.map { [$0] } ?? []) : builtIn
  }

  private func geometry(for screen: NSScreen, config: GlowConfig) -> EdgeGeometry {
    EdgeGeometry(
      size: screen.frame.size,
      topCornerRadius: config.topCornerRadius,
      bottomCornerRadius: config.bottomCornerRadius,
      notch: screen.notch,
      notchCornerRadius: config.notchCornerRadius
    )
  }
}
