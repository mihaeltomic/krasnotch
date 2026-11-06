import AppKit
import Foundation
import KrasnotchKit

/// Where a session lives and how to get back to it: the host app plus the most precise return plan.
@MainActor
struct SessionOrigin {
  let pid: pid_t
  let bundleID: String?
  let name: String
  let plan: ReturnPlan

  /// Walks the agent's process ancestry to its regular (Dock) app, then picks the most precise way back.
  /// The `ps` call runs off the main actor so a burst of events can't stall the UI.
  static func resolve(context: HookContext) async -> SessionOrigin? {
    guard let agentPID = context.pid, agentPID > 1,
          let table = await Task.detached(operation: { processTable() }).value else { return nil }
    var current = agentPID
    var seen = Set<pid_t>()
    while current > 1, seen.insert(current).inserted {
      if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular,
         app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
        let tty = table.tty[agentPID].flatMap { $0 == "??" ? nil : "/dev/" + $0 }
        let plan = ReturnPlan.make(bundleID: app.bundleIdentifier, context: context, t3EnvironmentID: t3EnvironmentID(), tty: tty)
        return SessionOrigin(pid: current, bundleID: app.bundleIdentifier, name: app.localizedName ?? "Application", plan: plan)
      }
      guard let parent = table.parent[current] else { break }
      current = parent
    }
    return nil
  }

  func activate() {
    switch plan {
    case let .url(url):
      if NSWorkspace.shared.open(url) { return }
    case let .terminalTab(app, tty):
      var error: NSDictionary?
      let result = NSAppleScript(source: ReturnPlan.terminalScript(app: app, tty: tty))?.executeAndReturnError(&error)
      if error == nil, result?.booleanValue == true { return }
    case .activateApp:
      break
    }
    guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
          app.bundleIdentifier == bundleID else { return }
    app.activate(options: [.activateAllWindows])
  }

  /// T3 Code keeps one id per machine; thread links are t3code://threads/<environment>/<thread>.
  private static func t3EnvironmentID() -> String? {
    let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".t3/userdata/environment-id")
    return (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  nonisolated private static func processTable() -> (parent: [pid_t: pid_t], tty: [pid_t: String])? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "pid=,ppid=,tty="]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0, let text = String(data: output, encoding: .utf8) else { return nil }
    var parent: [pid_t: pid_t] = [:], tty: [pid_t: String] = [:]
    for line in text.split(separator: "\n") {
      let fields = line.split(whereSeparator: \.isWhitespace)
      guard fields.count == 3, let child = pid_t(fields[0]), let ppid = pid_t(fields[1]) else { continue }
      parent[child] = ppid
      tty[child] = String(fields[2])
    }
    return (parent, tty)
  }
}

/// Separate small input window: the full-screen visual overlay remains click-through.
@MainActor
final class NotchClickWindow: NSPanel {
  var onClick: (() -> Void)?

  init(screen: NSScreen, notch: NotchGeometry) {
    let frame = NSRect(x: screen.frame.minX + notch.minX, y: screen.frame.maxY - notch.height - 20,
                       width: notch.maxX - notch.minX, height: 20)
    super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    isReleasedWhenClosed = false
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
  }

  override func mouseDown(with event: NSEvent) { onClick?() }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
