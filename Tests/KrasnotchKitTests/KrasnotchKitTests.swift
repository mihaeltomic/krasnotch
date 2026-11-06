import Foundation
import Synchronization
import Testing
@testable import KrasnotchKit

@Suite struct ClaudeHookMapperTests {
  private func update(_ json: String) -> SessionUpdate? {
    ClaudeHookMapper.update(fromHookJSON: Data(json.utf8))
  }

  @Test func mapsLifecycleEvents() {
    #expect(update(#"{"hook_event_name":"UserPromptSubmit","session_id":"a"}"#) == .set(session: "claude:a", state: .working))
    #expect(update(#"{"hook_event_name":"PostToolUse","session_id":"a","tool_name":"Bash"}"#) == .set(session: "claude:a", state: .working))
    #expect(update(#"{"hook_event_name":"Stop","session_id":"a"}"#) == .set(session: "claude:a", state: .done))
    #expect(update(#"{"hook_event_name":"SessionEnd","session_id":"a"}"#) == .end(session: "claude:a"))
  }

  @Test func questionsAndPermissionsNeedInput() {
    #expect(update(#"{"hook_event_name":"PreToolUse","session_id":"a","tool_name":"Edit"}"#) == .set(session: "claude:a", state: .working))
    #expect(update(#"{"hook_event_name":"PreToolUse","session_id":"a","tool_name":"AskUserQuestion"}"#) == .set(session: "claude:a", state: .needsInput))
    #expect(update(#"{"hook_event_name":"Notification","session_id":"a","notification_type":"permission_prompt"}"#) == .set(session: "claude:a", state: .needsInput))
    #expect(update(#"{"hook_event_name":"Notification","session_id":"a","notification_type":"idle_prompt"}"#) == nil)
  }

  @Test func ignoresGarbage() {
    #expect(update("not json") == nil)
    #expect(update(#"{"hook_event_name":"SubagentStop"}"#) == nil)
  }
}

@Suite struct SessionTrackerTests {
  let t0 = Date(timeIntervalSince1970: 1_000)

  @Test func needsInputBeatsWorkingAcrossSessions() {
    var tracker = SessionTracker()
    tracker.apply(.set(session: "a", state: .working), at: t0)
    tracker.apply(.set(session: "b", state: .needsInput), at: t0)
    #expect(tracker.current(at: t0) == .needsInput)
    tracker.apply(.set(session: "b", state: .working), at: t0)
    #expect(tracker.current(at: t0) == .working)
  }

  @Test func doneExpiresThenIdle() {
    var tracker = SessionTracker(doneDuration: 4)
    tracker.apply(.set(session: "a", state: .done), at: t0)
    #expect(tracker.current(at: t0.addingTimeInterval(3)) == .done)
    #expect(tracker.nextExpiry(after: t0) == t0.addingTimeInterval(4))
    #expect(tracker.current(at: t0.addingTimeInterval(5)) == nil)
  }

  @Test func staleWorkingSessionsDrop() {
    var tracker = SessionTracker(staleDuration: 60)
    tracker.apply(.set(session: "a", state: .working), at: t0)
    tracker.prune(at: t0.addingTimeInterval(61))
    #expect(tracker.sessionCount == 0)
  }
}

@Suite struct HTTPAndRouterTests {
  @Test func parsesCurlPost() throws {
    let body = #"{"hook_event_name":"Stop","session_id":"x"}"#
    let raw = "POST /claude HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
    guard case let .complete(request) = HTTPRequest.parse(Data(raw.utf8)) else {
      Issue.record("expected complete request")
      return
    }
    #expect(request.path == "/claude")
    #expect(RequestRouter.update(for: request) == .set(session: "claude:x", state: .done))
  }

  @Test func waitsForFullBody() {
    let raw = "POST /claude HTTP/1.1\r\nContent-Length: 10\r\n\r\n{\"a\""
    #expect(HTTPRequest.parse(Data(raw.utf8)) == .incomplete)
    #expect(HTTPRequest.parse(Data("GET /state".utf8)) == .incomplete)
  }

  @Test func genericStateEndpoint() throws {
    guard case let .complete(request) = HTTPRequest.parse(Data("GET /state?session=codex&value=needsInput HTTP/1.1\r\n\r\n".utf8)) else {
      Issue.record("expected complete request")
      return
    }
    #expect(RequestRouter.update(for: request) == .set(session: "codex", state: .needsInput))
    #expect(RequestRouter.genericUpdate(query: ["session": "codex", "value": "idle"]) == .end(session: "codex"))
    #expect(RequestRouter.genericUpdate(query: ["value": "bogus"]) == nil)
  }
}

@Suite struct ClaudeHookInstallerTests {
  private func tempSettings(_ json: String?) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appending(path: "krasnotch-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appending(path: "settings.json")
    if let json { try Data(json.utf8).write(to: url) }
    return url
  }

  private func read(_ url: URL) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
  }

  @Test func installPreservesForeignHooksAndIsIdempotent() throws {
    let original = #"{"model":"opus","hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"other-tool stop"}]}]}}"#
    let url = try tempSettings(original)
    let installer = ClaudeHookInstaller(settingsURL: url)

    #expect(try installer.isInstalled() == false)
    try installer.install()
    try installer.install()
    #expect(try installer.isInstalled())

    let settings = try read(url)
    #expect(settings["model"] as? String == "opus")
    let hooks = try #require(settings["hooks"] as? [String: Any])
    let stop = try #require(hooks["Stop"] as? [[String: Any]])
    #expect(stop.count == 2)
    #expect(hooks.keys.sorted() == ["Notification", "PostToolUse", "PreToolUse", "SessionEnd", "Stop", "UserPromptSubmit"])

    let backup = try String(contentsOf: url.appendingPathExtension("krasnotch-backup"), encoding: .utf8)
    #expect(backup == original)
  }

  @Test func uninstallRestoresOnlyForeignHooks() throws {
    let url = try tempSettings(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"other-tool stop"}]}]}}"#)
    let installer = ClaudeHookInstaller(settingsURL: url)
    try installer.install()
    try installer.uninstall()

    let hooks = try #require(try read(url)["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == ["Stop"])
    #expect(try installer.isInstalled() == false)
  }

  @Test func createsMissingFile() throws {
    let url = try tempSettings(nil)
    try ClaudeHookInstaller(settingsURL: url).install()
    #expect(try ClaudeHookInstaller(settingsURL: url).isInstalled())
    #expect(try ClaudeHookInstaller(settingsURL: url).isCurrent())
  }
}

@Suite struct GeometryTests {
  @Test func pathHugsScreenAndNotch() {
    let notch = NotchGeometry(minX: 663.5, maxX: 848.5, height: 32)
    let geometry = EdgeGeometry(
      size: CGSize(width: 1512, height: 982), topCornerRadius: 10, bottomCornerRadius: 0, notch: notch, notchCornerRadius: 8
    )
    let path = geometry.path()
    #expect(path.boundingBoxOfPath == CGRect(x: 661.5, y: 948, width: 189, height: 34))
    let noNotch = EdgeGeometry(size: geometry.size, topCornerRadius: 10, bottomCornerRadius: 0, notch: nil, notchCornerRadius: 8)
    #expect(noNotch.path().isEmpty)
  }

  @Test func hexRoundTrip() {
    #expect(RGBA(hex: "#2EA8FF")?.hex == "#2EA8FF")
    #expect(RGBA(hex: "30d158")?.hex == "#30D158")
    #expect(RGBA(hex: "#12345") == nil)
  }
}

@Suite struct GlowConfigDecodingTests {
  @Test func olderConfigKeepsSavedValuesAndDefaultsNewOnes() throws {
    let json = ##"{"enabled":false,"notchCornerRadius":3,"working":{"motion":"comet","colors":["#FFFFFF"],"speed":2,"thickness":3,"intensity":0.5}}"##
    let config = try JSONDecoder().decode(GlowConfig.self, from: Data(json.utf8))
    #expect(config.enabled == false)
    #expect(config.notchCornerRadius == 3)
    #expect(config.working.motion == .comet)
    #expect(config.brightness == 1)
    #expect(config.done == GlowStyle.defaultStyle(for: .done))
    #expect(config.showDonePill == true)
    #expect(config.donePillDuration == 8)
  }
}

@Suite struct ReturnPlanTests {
  let env = "9d7ae3a4-b322-4646-9879-8e67c977f219"

  @Test func parsesHookContext() throws {
    let body = #"{"hook_event_name":"Stop","session_id":"s","cwd":"/Users/me/app","transcript_path":"/Users/me/.claude/projects/x/s.jsonl"}"#
    let raw = "POST /claude?pid=4242&t3=22c01477-a388 HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
    guard case let .complete(request) = HTTPRequest.parse(Data(raw.utf8)) else { Issue.record("parse"); return }
    #expect(HookContext.parse(request) == HookContext(
      pid: 4242, t3ThreadID: "22c01477-a388", cwd: "/Users/me/app", transcriptPath: "/Users/me/.claude/projects/x/s.jsonl"
    ))
  }

  @Test func emptyThreadParameterIsIgnored() throws {
    guard case let .complete(request) = HTTPRequest.parse(Data("POST /claude?pid=1&t3= HTTP/1.1\r\n\r\n".utf8)) else { Issue.record("parse"); return }
    #expect(HookContext.parse(request).t3ThreadID == nil)
  }

  @Test func t3ThreadWinsOverEverything() {
    let plan = ReturnPlan.make(bundleID: "com.t3tools.t3code", context: HookContext(t3ThreadID: "abc-123"), t3EnvironmentID: env, tty: "/dev/ttys003")
    #expect(plan == .url(URL(string: "t3code://threads/\(env)/abc-123")!))
  }

  @Test func terminalAndITermSelectTheTab() {
    #expect(ReturnPlan.make(bundleID: "com.apple.Terminal", context: HookContext(), t3EnvironmentID: env, tty: "/dev/ttys003") == .terminalTab(app: .terminal, tty: "/dev/ttys003"))
    #expect(ReturnPlan.make(bundleID: "com.googlecode.iterm2", context: HookContext(), t3EnvironmentID: nil, tty: "/dev/ttys010") == .terminalTab(app: .iTerm, tty: "/dev/ttys010"))
  }

  @Test func editorsOpenTheFolder() {
    let plan = ReturnPlan.make(bundleID: "com.microsoft.VSCode", context: HookContext(cwd: "/Users/me/my app"), t3EnvironmentID: nil, tty: nil)
    #expect(plan == .url(URL(string: "vscode://file/Users/me/my%20app")!))
  }

  @Test func unsafeValuesFallBackToActivating() {
    #expect(ReturnPlan.make(bundleID: "com.apple.Terminal", context: HookContext(), t3EnvironmentID: nil, tty: "/dev/tty\" & do shell script \"x") == .activateApp)
    #expect(ReturnPlan.make(bundleID: "com.t3tools.t3code", context: HookContext(t3ThreadID: "../../etc"), t3EnvironmentID: env, tty: nil) == .activateApp)
    #expect(ReturnPlan.make(bundleID: "com.example.Other", context: HookContext(), t3EnvironmentID: nil, tty: "/dev/ttys001") == .activateApp)
  }
}

@Suite struct ThreadTitleTests {
  private func title(_ lines: [String]) -> String? {
    ThreadTitle.parse(transcript: Data(lines.joined(separator: "\n").utf8))
  }

  @Test func customTitleBeatsGeneratedAndLatestWins() {
    #expect(title([
      #"{"type":"ai-title","aiTitle":"Generated","sessionId":"s"}"#,
      #"{"type":"custom-title","customTitle":"First name","sessionId":"s"}"#,
      #"{"type":"user","message":{"content":"hi"}}"#,
      #"{"type":"custom-title","customTitle":"  Renamed  ","sessionId":"s"}"#,
      #"{"type":"ai-title","aiTitle":"Later generated","sessionId":"s"}"#,
    ]) == "Renamed")
  }

  @Test func fallsBackToGeneratedTitle() {
    #expect(title([#"{"type":"ai-title","aiTitle":"One"}"#, #"{"type":"ai-title","aiTitle":"Two"}"#]) == "Two")
  }

  @Test func ignoresJunkAndMissingTitles() {
    #expect(title(["not json", #"{"type":"user","text":"\"type\":\"ai-title\""}"#, #"{"type":"custom-title","customTitle":""}"#]) == nil)
    #expect(title([]) == nil)
  }

  @Test func keepsTitlesShortAndSingleLine() {
    let long = String(repeating: "a", count: 200)
    #expect(title([#"{"type":"custom-title","customTitle":"Top line\nsecond"}"#]) == "Top line")
    #expect(title([#"{"type":"custom-title","customTitle":"\#(long)"}"#])?.count == ThreadTitle.maxLength)
  }
}

@Suite struct OrderedDitherTests {
  @Test func preservesAverageBrightnessAcrossTones() {
    for tone in [32, 96, 160, 224] as [UInt8] {
      let peak: UInt8 = 255
      let input = [peak] + [UInt8](repeating: tone, count: 64 * 64 - 1)
      let out = OrderedDither.apply(alpha: input, width: 64, height: 64, levels: 3)
      let meanIn = input.map(Double.init).reduce(0, +) / Double(input.count)
      let meanOut = out.map(Double.init).reduce(0, +) / Double(out.count)
      #expect(abs(meanIn - meanOut) < 255 * 0.03, "tone \(tone): \(meanIn) vs \(meanOut)")
    }
  }

  @Test func onlyEmitsTheQuantizedLevels() {
    let input = (0..<256).map { UInt8($0) }
    let out = OrderedDither.apply(alpha: input, width: 16, height: 16, levels: 3)
    #expect(Set(out).isSubset(of: [0, 128, 255]))
  }

  @Test func fullAndEmptyStayExact() {
    #expect(OrderedDither.apply(alpha: [UInt8](repeating: 200, count: 64), width: 8, height: 8, levels: 3) == [UInt8](repeating: 200, count: 64))
    #expect(OrderedDither.apply(alpha: [UInt8](repeating: 0, count: 64), width: 8, height: 8) == [UInt8](repeating: 0, count: 64))
  }

  @Test func midToneIsEvenlySpreadPerTile() {
    // Two levels at half intensity: exactly half of every 8×8 Bayer tile lights up.
    var input = [UInt8](repeating: 64, count: 16 * 16); input[0] = 128
    let out = OrderedDither.apply(alpha: input, width: 16, height: 16, levels: 2)
    for ty in 0..<2 { for tx in 0..<2 {
      var lit = 0
      for y in 0..<8 { for x in 0..<8 where out[(ty * 8 + y) * 16 + tx * 8 + x] > 0 { lit += 1 } }
      #expect((30...34).contains(lit), "tile \(tx),\(ty) lit \(lit)")
    } }
  }
}

@Suite struct RenameMigrationTests {
  @Test(arguments: ["#halo-hook", "#glowbug-hook"])
  func legacyHooksAreReplacedNotDuplicated(marker: String) throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "krasnotch-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appending(path: "settings.json")
    let legacy = "curl -s -m 1 -o /dev/null --data-binary @- \"http://127.0.0.1:47821/claude?pid=$PPID\" || true \(marker)"
    let other = "other-tool stop"
    let json: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": legacy], ["type": "command", "command": other]]]]]]
    try JSONSerialization.data(withJSONObject: json).write(to: url)
    let installer = ClaudeHookInstaller(settingsURL: url)
    #expect(try installer.isCurrent() == false)
    try installer.install()
    let data = try Data(contentsOf: url)
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains(marker))
    #expect(text.components(separatedBy: "#krasnotch-hook").count - 1 == 6)
    #expect(text.contains(other))
    #expect(try installer.isCurrent())
  }
}

@Suite struct MagicFlagTests {
  @Test func savedMagicAnimationBecomesFlowWithMagicOn() throws {
    let json = ##"{"motion":"magic","colors":["#FFD36E"],"speed":2,"thickness":4,"intensity":0.9}"##
    let style = try JSONDecoder().decode(GlowStyle.self, from: Data(json.utf8))
    #expect(style.motion == .flow)
    #expect(style.magic)
  }

  @Test func magicFlagRoundTripsAndDefaultsOff() throws {
    var style = GlowStyle.defaultStyle(for: .working)
    #expect(style.magic == false)
    style.magic = true
    let decoded = try JSONDecoder().decode(GlowStyle.self, from: JSONEncoder().encode(style))
    #expect(decoded == style)
    #expect(!GlowAnimation.allCases.map(\.rawValue).contains("magic"))
  }
}

@Suite struct HTTPHardeningTests {
  private func parse(_ raw: String) -> HTTPRequest.ParseResult { HTTPRequest.parse(Data(raw.utf8)) }

  @Test(arguments: ["-1", "+5", "1e3", "0x10", " ", "99999999999", "2000000"])
  func rejectsMalformedOrOversizedContentLength(_ value: String) {
    #expect(parse("POST /claude HTTP/1.1\r\nContent-Length: \(value)\r\n\r\n") == .invalid)
  }

  @Test func rejectsConflictingContentLengths() {
    #expect(parse("POST /claude HTTP/1.1\r\nContent-Length: 2\r\nContent-Length: 3\r\n\r\nabc") == .invalid)
    guard case .complete = parse("POST /claude HTTP/1.1\r\nContent-Length: 3\r\ncontent-length: 3\r\n\r\nabc") else {
      Issue.record("identical duplicates should parse"); return
    }
  }

  @Test func capsHeaderSize() {
    let big = "GET /state HTTP/1.1\r\nX: " + String(repeating: "a", count: HTTPRequest.maxHeaderSize)
    #expect(parse(big) == .invalid)
    #expect(parse(big + "\r\n\r\n") == .invalid)
  }

  @Test func idsMustBeASCII() {
    #expect(ReturnPlan.isSafeID("abc-123_X"))
    #expect(!ReturnPlan.isSafeID("abç"))
    #expect(!ReturnPlan.isSafeTTY("/dev/ttys٣"))
  }
}

@Suite struct SessionCapTests {
  @Test func oldestSessionMakesRoom() {
    var tracker = SessionTracker()
    let start = Date(timeIntervalSince1970: 1_000)
    for i in 0..<SessionTracker.maxSessions {
      tracker.apply(.set(session: "s\(i)", state: .working), at: start.addingTimeInterval(Double(i)))
    }
    tracker.apply(.set(session: "new", state: .working), at: start.addingTimeInterval(100))
    #expect(tracker.sessionCount == SessionTracker.maxSessions)
    #expect(!tracker.activeSessions.contains { $0.id == "s0" })
    #expect(tracker.activeSessions.contains { $0.id == "new" })
  }
}

@Suite struct EventServerTests {
  /// Short temp path: sun_path holds at most 103 bytes.
  private func tempSocketURL() -> URL {
    URL(fileURLWithPath: "/tmp/kt-\(UUID().uuidString.prefix(8))/events.sock")
  }

  private func send(_ raw: String, to path: String) -> String {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    defer { close(fd) }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path.utf8); $0[path.utf8.count] = 0 }
    let ok = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard ok == 0 else { return "connect failed" }
    _ = Array(raw.utf8).withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    var buffer = [UInt8](repeating: 0, count: 512)
    let count = read(fd, &buffer, buffer.count)
    return count > 0 ? String(decoding: buffer[0..<count], as: UTF8.self) : ""
  }

  @Test func deliversRequestsOverAPrivateSocket() async throws {
    let url = tempSocketURL()
    let received = Mutex<[HTTPRequest]>([])
    let server = EventServer(socketURL: url) { request in received.withLock { $0.append(request) } }
    try server.start()
    defer { server.stop(); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    var info = stat()
    #expect(lstat(url.deletingLastPathComponent().path, &info) == 0 && info.st_mode & 0o777 == 0o700)
    #expect(lstat(url.path, &info) == 0 && info.st_mode & 0o777 == 0o600)

    let reply = send("GET /state?session=t&value=working HTTP/1.1\r\n\r\n", to: url.path)
    #expect(reply.hasPrefix("HTTP/1.1 204"))
    #expect(send("POST / HTTP/1.1\r\nContent-Length: -1\r\n\r\n", to: url.path).hasPrefix("HTTP/1.1 400"))
    #expect(received.withLock { $0.map(\.path) } == ["/state"])
  }

  @Test func refusesADirectoryItDoesNotControl() throws {
    let base = URL(fileURLWithPath: "/tmp/kt-\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    let link = base.appending(path: "link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: base)
    #expect(throws: EventServer.StartError.self) {
      try EventServer(socketURL: link.appending(path: "events.sock")) { _ in }.start()
    }
  }
}

@Suite struct TransportMigrationTests {
  @Test func loopbackTCPHooksAreUpgradedToTheSocket() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "krasnotch-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appending(path: "settings.json")
    let tcp = "curl -s -m 1 -o /dev/null --data-binary @- \"http://127.0.0.1:47821/claude?pid=$PPID&t3=$T3CODE_THREAD_ID\" || true #krasnotch-hook"
    let json: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": tcp]]]]]]
    try JSONSerialization.data(withJSONObject: json).write(to: url)
    let installer = ClaudeHookInstaller(settingsURL: url)
    #expect(try installer.isInstalled() == false || installer.isCurrent() == false)
    try installer.install()
    let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
    #expect(!text.contains("127.0.0.1"))
    #expect(text.components(separatedBy: "--unix-socket").count - 1 == 6)
    #expect(try installer.isCurrent())
  }
}
