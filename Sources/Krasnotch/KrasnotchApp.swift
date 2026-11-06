import AppKit
import KrasnotchKit
import SwiftUI

@main
struct KrasnotchApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    // The menu and settings window are AppKit-owned; SwiftUI needs at least one scene.
    Settings { EmptyView() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()
  private lazy var settings = SettingsWindowController(model: model)
  private var statusMenu: StatusMenuController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    model.start()
    statusMenu = StatusMenuController(model: model, settings: settings)
  }

  /// Launching Krasnotch again (e.g. double-clicking it in Finder) opens Settings, like other menu bar apps.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    settings.show()
    return false
  }
}
