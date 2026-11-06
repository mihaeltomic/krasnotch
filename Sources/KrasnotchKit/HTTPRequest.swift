import Foundation

public struct HTTPRequest: Equatable, Sendable {
  public var method: String
  public var path: String
  public var query: [String: String]
  public var body: Data

  public enum ParseResult: Equatable, Sendable {
    case incomplete
    case invalid
    case complete(HTTPRequest)
  }

  private static let headerTerminator = Data("\r\n\r\n".utf8)
  /// Request line plus headers; hook requests use a few hundred bytes.
  public static let maxHeaderSize = 8 * 1024
  /// Claude Code hook payloads can include tool output, but nothing near this size is needed.
  public static let maxBodySize = 1024 * 1024

  /// Minimal HTTP/1.1 parser: request line, Content-Length, body. Enough for curl and scripts.
  /// Rejects oversized headers, oversized or malformed bodies, and conflicting Content-Length values.
  public static func parse(_ data: Data) -> ParseResult {
    guard let terminator = data.range(of: headerTerminator) else {
      return data.count > maxHeaderSize ? .invalid : .incomplete
    }
    guard terminator.lowerBound - data.startIndex <= maxHeaderSize,
          let head = String(data: data[data.startIndex..<terminator.lowerBound], encoding: .utf8) else {
      return .invalid
    }

    let lines = head.components(separatedBy: "\r\n")
    let requestLine = lines[0].split(separator: " ")
    guard requestLine.count >= 2 else { return .invalid }

    let lengthValues = lines.dropFirst().compactMap { line -> String? in
      let parts = line.split(separator: ":", maxSplits: 1)
      guard parts.count == 2, parts[0].lowercased() == "content-length" else { return nil }
      return parts[1].trimmingCharacters(in: .whitespaces)
    }
    guard Set(lengthValues).count <= 1 else { return .invalid }
    var contentLength = 0
    if let value = lengthValues.first {
      guard !value.isEmpty, value.count <= 8, value.allSatisfy({ $0.isASCII && $0.isNumber }),
            let parsed = Int(value), parsed <= maxBodySize else { return .invalid }
      contentLength = parsed
    }

    let bodyStart = terminator.upperBound
    guard data.endIndex - bodyStart >= contentLength else { return .incomplete }

    let components = URLComponents(string: String(requestLine[1]))
    let query = (components?.queryItems ?? []).reduce(into: [String: String]()) { $0[$1.name] = $1.value ?? "" }

    return .complete(HTTPRequest(
      method: String(requestLine[0]),
      path: components?.path ?? String(requestLine[1]),
      query: query,
      body: data[bodyStart..<(bodyStart + contentLength)]
    ))
  }
}
