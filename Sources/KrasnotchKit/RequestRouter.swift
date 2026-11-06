import Foundation

/// Turns incoming HTTP requests into session updates.
///
/// - `POST /claude` with a Claude Code hook payload on the body.
/// - `GET|POST /state?session=NAME&value=working|needsInput|done|idle` for any other tool or script.
public enum RequestRouter {
  public static func update(for request: HTTPRequest) -> SessionUpdate? {
    switch request.path {
    case "/claude": ClaudeHookMapper.update(fromHookJSON: request.body)
    case "/state": genericUpdate(query: request.query)
    default: nil
    }
  }

  static func genericUpdate(query: [String: String]) -> SessionUpdate? {
    let session = query["session"] ?? "default"
    guard let value = query["value"] else { return nil }
    if value == "idle" { return .end(session: session) }
    guard let state = GlowState(rawValue: value) else { return nil }
    return .set(session: session, state: state)
  }
}

public enum ClaudeHookMapper {
  /// Tools that block on the user even though they arrive as PreToolUse.
  static let questionTools: Set<String> = ["AskUserQuestion", "ExitPlanMode"]

  public static func update(fromHookJSON data: Data) -> SessionUpdate? {
    guard
      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let event = payload["hook_event_name"] as? String
    else { return nil }

    let session = "claude:" + (payload["session_id"] as? String ?? "unknown")

    switch event {
    case "UserPromptSubmit", "PostToolUse":
      return .set(session: session, state: .working)
    case "PreToolUse":
      let tool = payload["tool_name"] as? String ?? ""
      return .set(session: session, state: questionTools.contains(tool) ? .needsInput : .working)
    case "Notification":
      if payload["notification_type"] as? String == "idle_prompt" { return nil }
      return .set(session: session, state: .needsInput)
    case "Stop":
      return .set(session: session, state: .done)
    case "SessionEnd":
      return .end(session: session)
    default:
      return nil
    }
  }
}
