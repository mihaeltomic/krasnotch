import AppKit
import KrasnotchKit
import SwiftUI

/// Owns the settings window so it can be placed on the screen under the mouse, in the current Space.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let model: AppModel
  private var window: NSWindow?

  init(model: AppModel) {
    self.model = model
  }

  func show(pane: SettingsPane? = nil, state: GlowState? = nil) {
    if let pane { model.settingsPane = pane }
    if let state { model.editingState = state }

    let window = window ?? makeWindow()
    self.window = window
    if !window.isVisible {
      let mouse = NSEvent.mouseLocation
      if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
        let area = screen.visibleFrame
        let size = NSSize(width: min(window.frame.width, area.width), height: min(window.frame.height, area.height))
        window.setFrame(NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height), display: false)
      }
    }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    model.settingsVisible = true
  }

  func windowWillClose(_ notification: Notification) {
    model.settingsVisible = false
  }

  private func makeWindow() -> NSWindow {
    let hosting = NSHostingController(rootView: SettingsView().environment(model))
    hosting.sceneBridgingOptions = [.toolbars, .title]
    let window = NSWindow(contentViewController: hosting)
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    window.toolbarStyle = .unified
    window.title = "Krasnotch"
    window.isReleasedWhenClosed = false
    window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
    window.setContentSize(NSSize(width: 800, height: 760))
    window.delegate = self
    return window
  }
}
