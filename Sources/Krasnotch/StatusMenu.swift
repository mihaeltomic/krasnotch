import AppKit
import KrasnotchKit
import Observation
import SwiftUI

/// Menu bar item with a native NSMenu: icons on every row, section headers, live SwiftUI rows at the top.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  private let model: AppModel
  private let settings: SettingsWindowController
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()

  init(model: AppModel, settings: SettingsWindowController) {
    self.model = model
    self.settings = settings
    super.init()
    menu.delegate = self
    menu.autoenablesItems = false
    item.menu = menu
    updateIcon()
    observeIcon()
    if let button = item.button {
      button.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
  }

  // MARK: - Glancing eyes on hover

  private var glanceTimer: Timer?
  private var hovering = false
  private var glanceStart = Date.now
  /// Current eye offset in points; eased toward the glance loop while hovering, back to 0 after.
  private var eyeOffset: CGFloat = 0

  // NSTrackingArea sends `mouseEntered:`; a plain @objc method on an NSObject would be `mouseEnteredWith:`.
  @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
    hovering = true
    glanceStart = .now
    startGlanceTimer()
  }

  @objc(mouseExited:) func mouseExited(with event: NSEvent) {
    hovering = false
  }

  private func startGlanceTimer() {
    guard glanceTimer == nil else { return }
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.glanceTick() }
    }
    RunLoop.main.add(timer, forMode: .common) // keeps ticking while the menu is open
    glanceTimer = timer
  }

  private func glanceTick() {
    let target: CGFloat
    if hovering {
      // Look left, then right, then left again: a slow sine across the glance range, 1.4 s per cycle.
      let t = Date.now.timeIntervalSince(glanceStart)
      let range = KrasnotchIcon.glanceRange
      let mid = (range.lowerBound + range.upperBound) / 2, amplitude = (range.upperBound - range.lowerBound) / 2
      target = mid - amplitude * CGFloat(sin(t * 2 * .pi / 1.4))
    } else {
      target = 0
    }
    // Ease toward the target so entering and leaving never jump.
    eyeOffset += (target - eyeOffset) * 0.22
    if !hovering, abs(eyeOffset) < 0.05 {
      eyeOffset = 0
      glanceTimer?.invalidate()
      glanceTimer = nil
    }
    updateIcon()
  }

  private var menuOpen = false

  func menuWillOpen(_ menu: NSMenu) {
    menuOpen = true
    observeWhileOpen()
  }

  func menuDidClose(_ menu: NSMenu) {
    menuOpen = false
  }

  /// Rows are AppKit items built once, so rebuild them if sessions or settings change while the menu is open.
  private func observeWhileOpen() {
    withObservationTracking {
      _ = model.sessions.map { "\($0.id)\($0.state)" }
      _ = model.config
      _ = model.hooksInstalled
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.menuOpen else { return }
        self.menuNeedsUpdate(self.menu)
        self.observeWhileOpen()
      }
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    menu.addItem(hosted(MenuStatusRow(), height: 50))
    menu.addItem(hosted(MenuBrightnessRow(), height: 32))
    menu.addItem(.separator())

    let enabled = model.config.enabled
    menu.addItem(ActionItem(enabled ? "Pause Glow" : "Resume Glow", symbol: enabled ? "pause.circle" : "play.circle") { [model] in
      model.config.enabled.toggle()
    })

    menu.addItem(.sectionHeader(title: "Configure"))
    for state in GlowState.allCases {
      menu.addItem(stateItem(state))
    }
    let test = ActionItem("Test Glow", symbol: "wand.and.sparkles") {}
    test.submenu = NSMenu()
    for state in GlowState.allCases {
      test.submenu?.addItem(ActionItem(state.title, symbol: state.symbol) { [model] in model.test(state) })
    }
    menu.addItem(test)

    if !model.sessions.isEmpty {
      menu.addItem(.sectionHeader(title: "Sessions"))
      for session in model.sessions {
        let name = session.displayName
        let row = ActionItem("\(name) · \(session.state.title)", symbol: session.state.symbol) {
          session.origin?.activate()
        }
        row.isEnabled = session.origin != nil
        menu.addItem(row)
      }
      menu.addItem(ActionItem("Clear Sessions", symbol: "xmark.circle") { [model] in model.clearSessions() })
    }

    menu.addItem(.sectionHeader(title: "App"))
    let claude = ActionItem(model.hooksInstalled ? "Disconnect Claude Code" : "Connect Claude Code", symbol: model.hooksInstalled ? "checkmark.circle.fill" : "link.circle") { [model] in
      model.setHooksInstalled(!model.hooksInstalled)
    }
    menu.addItem(claude)
    menu.addItem(ActionItem("Settings…", symbol: "gearshape.fill", key: ",") { [settings] in settings.show() })
    menu.addItem(ActionItem("Quit Krasnotch", symbol: "xmark.circle.fill", key: "q") { NSApp.terminate(nil) })
  }

  private func stateItem(_ state: GlowState) -> NSMenuItem {
    let style = model.config[state]
    let item = ActionItem(state.title, symbol: state.symbol) {}
    item.badge = NSMenuItemBadge(string: style.motion.title)
    let submenu = NSMenu()
    for motion in GlowAnimation.allCases {
      let option = ActionItem(motion.title, symbol: motion.symbol) { [model] in model.config[state].motion = motion }
      option.state = motion == style.motion ? .on : .off
      submenu.addItem(option)
    }
    submenu.addItem(.separator())
    let magic = ActionItem("Magic?", symbol: "wand.and.stars") { [model] in model.config[state].magic.toggle() }
    magic.state = style.magic ? .on : .off
    submenu.addItem(magic)
    submenu.addItem(ActionItem("Preview on Notch", symbol: "eye") { [model] in model.test(state) })
    submenu.addItem(ActionItem("Customize…", symbol: "slider.horizontal.3") { [settings] in
      settings.show(pane: .glow, state: state)
    })
    item.submenu = submenu
    return item
  }

  private func hosted(_ view: some View, height: CGFloat) -> NSMenuItem {
    let item = NSMenuItem()
    let host = NSHostingView(rootView: view.environment(model))
    host.frame = NSRect(x: 0, y: 0, width: 280, height: height)
    item.view = host
    return item
  }

  private func updateIcon() {
    item.button?.image = KrasnotchIcon.menuBar(state: model.liveState, enabled: model.config.enabled, eyeOffset: eyeOffset)
  }

  private func observeIcon() {
    withObservationTracking { _ = (model.liveState, model.config.enabled) } onChange: { [weak self] in
      Task { @MainActor in
        self?.updateIcon()
        self?.observeIcon()
      }
    }
  }
}

/// NSMenuItem that runs a closure and carries an SF Symbol.
private final class ActionItem: NSMenuItem {
  private let handler: () -> Void

  init(_ title: String, symbol: String, key: String = "", handler: @escaping () -> Void) {
    self.handler = handler
    super.init(title: title, action: #selector(fire), keyEquivalent: key)
    target = self
    image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
  }

  @available(*, unavailable)
  required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  @objc private func fire() { handler() }
}

extension GlowState {
  var symbol: String {
    switch self {
    case .working: "sparkles"
    case .needsInput: "hand.raised.fill"
    case .done: "checkmark.seal.fill"
    }
  }
}

extension GlowAnimation {
  var symbol: String {
    switch self {
    case .flow: "water.waves"
    case .pulse: "waveform.path.ecg"
    case .comet: "sparkle"
    case .scanner: "arrow.left.and.right"
    case .blink: "light.beacon.max"
    case .solid: "circle.fill"
    }
  }
}
