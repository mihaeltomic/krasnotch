import Foundation

/// What a hook request tells us about where its agent session lives.
public struct HookContext: Equatable, Sendable {
  public var pid: Int32?
  /// T3 Code thread id (`T3CODE_THREAD_ID` in the agent's environment), when the agent runs inside T3 Code.
  public var t3ThreadID: String?
  /// The agent's working directory, from the hook payload.
  public var cwd: String?
  /// The session's JSONL transcript, from the hook payload. Holds the thread's title.
  public var transcriptPath: String?

  public init(pid: Int32? = nil, t3ThreadID: String? = nil, cwd: String? = nil, transcriptPath: String? = nil) {
    self.pid = pid
    self.t3ThreadID = t3ThreadID
    self.cwd = cwd
    self.transcriptPath = transcriptPath
  }

  public static func parse(_ request: HTTPRequest) -> HookContext {
    let nonEmpty = { (s: String?) in s.flatMap { $0.isEmpty ? nil : $0 } }
    let payload = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any]
    return HookContext(
      pid: request.query["pid"].flatMap(Int32.init),
      t3ThreadID: nonEmpty(request.query["t3"]),
      cwd: nonEmpty(payload?["cwd"] as? String),
      transcriptPath: nonEmpty(payload?["transcript_path"] as? String)
    )
  }
}

/// How clicking the notch takes you back to a session, most precise first.
public enum ReturnPlan: Equatable, Sendable {
  /// Open the exact T3 Code thread.
  case url(URL)
  /// Select the Terminal.app or iTerm2 tab whose tty runs the agent.
  case terminalTab(app: TerminalApp, tty: String)
  /// Bring the host app forward.
  case activateApp

  public enum TerminalApp: String, Sendable {
    case terminal = "com.apple.Terminal"
    case iTerm = "com.googlecode.iterm2"
  }

  static let editorSchemes: [String: String] = [
    "com.microsoft.VSCode": "vscode",
    "com.microsoft.VSCodeInsiders": "vscode-insiders",
    "com.todesktop.230313mzl4w4u92": "cursor",
  ]

  public static func make(bundleID: String?, context: HookContext, t3EnvironmentID: String?, tty: String?) -> ReturnPlan {
    if let thread = context.t3ThreadID, let env = t3EnvironmentID, isSafeID(thread), isSafeID(env),
       let url = URL(string: "t3code://threads/\(env)/\(thread)") {
      return .url(url)
    }
    if let bundleID, let app = TerminalApp(rawValue: bundleID), let tty, isSafeTTY(tty) {
      return .terminalTab(app: app, tty: tty)
    }
    if let bundleID, let scheme = editorSchemes[bundleID], let cwd = context.cwd, cwd.hasPrefix("/") {
      var components = URLComponents()
      components.scheme = scheme
      components.host = "file"
      components.path = cwd
      if let url = components.url { return .url(url) }
    }
    return .activateApp
  }

  /// AppleScript for selecting the tab running `tty` (values are validated before they reach the script).
  public static func terminalScript(app: TerminalApp, tty: String) -> String {
    switch app {
    case .terminal:
      return """
      tell application id "com.apple.Terminal"
        repeat with w in windows
          repeat with t in tabs of w
            if tty of t is "\(tty)" then
              set selected of t to true
              set index of w to 1
              activate
              return true
            end if
          end repeat
        end repeat
      end tell
      return false
      """
    case .iTerm:
      return """
      tell application id "com.googlecode.iterm2"
        repeat with w in windows
          repeat with t in tabs of w
            repeat with s in sessions of t
              if tty of s is "\(tty)" then
                select w
                select t
                select s
                activate
                return true
              end if
            end repeat
          end repeat
        end repeat
      end tell
      return false
      """
    }
  }

  static func isSafeID(_ value: String) -> Bool {
    !value.isEmpty && value.count <= 64 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
  }

  static func isSafeTTY(_ value: String) -> Bool {
    value.hasPrefix("/dev/tty") && value.dropFirst(5).allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
  }
}
