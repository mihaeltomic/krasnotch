import Foundation

public enum SessionUpdate: Equatable, Sendable {
  case set(session: String, state: GlowState)
  case end(session: String)
}

/// Tracks the state of every agent session and collapses them into the single state the glow shows.
public struct SessionTracker: Sendable {
  struct Entry: Equatable, Sendable {
    var state: GlowState
    var updatedAt: Date
  }

  /// Upper bound on tracked sessions; the least recently updated one makes room for a new one.
  public static let maxSessions = 64

  public var doneDuration: TimeInterval
  /// Sessions that stop reporting (e.g. interrupted with Esc, which fires no Stop hook) are dropped after this.
  public var staleDuration: TimeInterval
  private(set) var sessions: [String: Entry] = [:]

  public init(doneDuration: TimeInterval = 4, staleDuration: TimeInterval = 10 * 60) {
    self.doneDuration = doneDuration
    self.staleDuration = staleDuration
  }

  public var sessionCount: Int { sessions.count }

  public var activeSessions: [(id: String, state: GlowState)] {
    sessions.map { (id: $0.key, state: $0.value.state) }.sorted { $0.id < $1.id }
  }

  public mutating func apply(_ update: SessionUpdate, at now: Date) {
    switch update {
    case let .set(session, state):
      if sessions[session] == nil, sessions.count >= Self.maxSessions,
         let oldest = sessions.min(by: { $0.value.updatedAt < $1.value.updatedAt })?.key {
        sessions[oldest] = nil
      }
      sessions[session] = Entry(state: state, updatedAt: now)
    case let .end(session):
      sessions[session] = nil
    }
    prune(at: now)
  }

  public mutating func removeAll() {
    sessions.removeAll()
  }

  public mutating func prune(at now: Date) {
    sessions = sessions.filter { expiry(of: $0.value) > now }
  }

  /// Highest-priority state across live sessions; nil means idle.
  public func current(at now: Date) -> GlowState? {
    sessions.values
      .filter { expiry(of: $0) > now }
      .max { $0.state.priority < $1.state.priority }?
      .state
  }

  public func nextExpiry(after now: Date) -> Date? {
    sessions.values.map(expiry(of:)).filter { $0 > now }.min()
  }

  private func expiry(of entry: Entry) -> Date {
    entry.updatedAt.addingTimeInterval(entry.state == .done ? doneDuration : staleDuration)
  }
}
