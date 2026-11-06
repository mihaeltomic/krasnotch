import Foundation

/// Finds a session's human title in a Claude Code JSONL transcript.
///
/// Claude Code appends `{"type":"custom-title","customTitle":…}` when a thread is named (T3 Code writes its
/// thread title this way) and `{"type":"ai-title","aiTitle":…}` for generated titles. Both may repeat; the
/// latest wins, and a custom title always beats a generated one.
public enum ThreadTitle {
  static let maxLength = 80

  public static func parse(transcript: Data) -> String? {
    var custom: String?, generated: String?
    for line in transcript.split(separator: UInt8(ascii: "\n")) {
      // Cheap byte check first so a large transcript is never JSON-decoded line by line.
      let isCustom = line.firstRange(of: Data(#""type":"custom-title""#.utf8)) != nil
      guard isCustom || line.firstRange(of: Data(#""type":"ai-title""#.utf8)) != nil,
            let record = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
      if isCustom, let title = clean(record["customTitle"]) { custom = title }
      if !isCustom, let title = clean(record["aiTitle"]) { generated = title }
    }
    return custom ?? generated
  }

  /// Reads and parses a transcript file. Returns nil when it can't be read.
  public static func read(path: String) -> String? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    return parse(transcript: data)
  }

  private static func clean(_ value: Any?) -> String? {
    guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
    let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    return line.count > maxLength ? String(line.prefix(maxLength - 1)) + "…" : line
  }
}
