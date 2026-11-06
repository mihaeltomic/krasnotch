import Foundation

/// Adds/removes Krasnotch's entries in ~/.claude/settings.json without touching anyone else's hooks.
public struct ClaudeHookInstaller: Sendable {
  public static let marker = "#krasnotch-hook"
  /// Markers from earlier names (Glowbug, Halo). Recognized as ours so they get replaced, never duplicated.
  static let legacyMarkers = ["#glowbug-hook", "#halo-hook"]
  static let allMarkers = [marker] + legacyMarkers
  static func isOwn(_ command: String?) -> Bool { command.map { c in allMarkers.contains { c.contains($0) } } ?? false }

  /// Event name → matcher (nil for events that don't take one).
  static let events: [(name: String, matcher: String?)] = [
    ("UserPromptSubmit", nil),
    ("PreToolUse", "*"),
    ("PostToolUse", "*"),
    ("Notification", "permission_prompt"),
    ("Stop", nil),
    ("SessionEnd", nil),
  ]

  public let settingsURL: URL
  /// Socket path as the hook's shell sees it.
  public let socketPath: String

  public init(
    settingsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json"),
    socketPath: String = EventServer.shellSocketPath
  ) {
    self.settingsURL = settingsURL
    self.socketPath = socketPath
  }

  /// Posts the hook payload to Krasnotch's private Unix socket. `-q` ignores ~/.curlrc and `--noproxy` keeps
  /// a proxy from the agent's environment out of the path; failures never block the agent.
  var command: String {
    "curl -q -s -m 1 -o /dev/null --noproxy '*' --unix-socket \"\(socketPath)\" --data-binary @- "
      + "\"http://localhost/claude?pid=$PPID&t3=$T3CODE_THREAD_ID\" || true \(Self.marker)"
  }

  public func isInstalled() throws -> Bool {
    let hooks = try readSettings()["hooks"] as? [String: Any] ?? [:]
    return Self.events.allSatisfy { event in
      (hooks[event.name] as? [[String: Any]] ?? []).contains { Self.containsOwnHook($0) }
    }
  }

  /// True when every Krasnotch hook is the exact current command (socket transport, pid and T3 thread id).
  public func isCurrent() throws -> Bool {
    let hooks = try readSettings()["hooks"] as? [String: Any] ?? [:]
    return Self.events.allSatisfy { event in
      (hooks[event.name] as? [[String: Any]] ?? []).contains { group in
        (group["hooks"] as? [[String: Any]] ?? []).contains {
          guard let command = $0["command"] as? String else { return false }
          return command == self.command
        }
      }
    }
  }

  public func install() throws {
    var settings = try readSettings()
    var hooks = Self.removingOwnHooks(from: settings["hooks"] as? [String: Any] ?? [:])
    for event in Self.events {
      var group: [String: Any] = ["hooks": [["type": "command", "command": command]]]
      if let matcher = event.matcher { group["matcher"] = matcher }
      hooks[event.name] = (hooks[event.name] as? [[String: Any]] ?? []) + [group]
    }
    settings["hooks"] = hooks
    try write(settings)
  }

  public func uninstall() throws {
    var settings = try readSettings()
    let hooks = Self.removingOwnHooks(from: settings["hooks"] as? [String: Any] ?? [:])
    settings["hooks"] = hooks.isEmpty ? nil : hooks
    try write(settings)
  }

  // MARK: - Private

  private static func containsOwnHook(_ group: [String: Any]) -> Bool {
    (group["hooks"] as? [[String: Any]] ?? []).contains { isOwn($0["command"] as? String) }
  }

  private static func removingOwnHooks(from hooks: [String: Any]) -> [String: Any] {
    hooks.reduce(into: [String: Any]()) { result, entry in
      guard let groups = entry.value as? [[String: Any]] else {
        result[entry.key] = entry.value
        return
      }
      let cleaned = groups.compactMap { group -> [String: Any]? in
        guard let commands = group["hooks"] as? [[String: Any]] else { return group }
        let kept = commands.filter { !isOwn($0["command"] as? String) }
        guard !kept.isEmpty else { return nil }
        var copy = group
        copy["hooks"] = kept
        return copy
      }
      if !cleaned.isEmpty { result[entry.key] = cleaned }
    }
  }

  private func readSettings() throws -> [String: Any] {
    guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
    let data = try Data(contentsOf: settingsURL)
    guard !data.isEmpty else { return [:] }
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return object
  }

  private func write(_ settings: [String: Any]) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    // Keep one pristine copy of the file from before the first install (a backup made under the old name counts).
    let backupURL = settingsURL.appendingPathExtension("krasnotch-backup")
    let legacyBackups = ["glowbug-backup", "halo-backup"].map { settingsURL.appendingPathExtension($0) }
    if fileManager.fileExists(atPath: settingsURL.path), !fileManager.fileExists(atPath: backupURL.path),
       !legacyBackups.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
      try fileManager.copyItem(at: settingsURL, to: backupURL)
    }

    let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .withoutEscapingSlashes])
    try data.write(to: settingsURL, options: .atomic)
  }
}
