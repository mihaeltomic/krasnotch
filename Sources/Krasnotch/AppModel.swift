import AppKit
import KrasnotchKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
  private static let configKey = "config.v1"

  var config: GlowConfig {
    didSet {
      guard config != oldValue else { return }
      persist()
      tracker.doneDuration = config.doneDuration
      if !config.enabled || (!config.showDonePill && !config.showNeedsInputPill) { pill.dismiss() }
      refresh()
    }
  }

  // Settings window state. While it's open on the Glow pane, the notch previews the style being edited.
  var settingsVisible = false { didSet { refresh() } }
  var settingsPane: SettingsPane = .glow {
    didSet {
      UserDefaults.standard.set(settingsPane.rawValue, forKey: "settingsPane")
      refresh()
    }
  }
  var editingState: GlowState = .working { didSet { refresh() } }
  var livePreview = true { didSet { refresh() } }

  var preview: GlowState? {
    settingsVisible && livePreview && settingsPane == .glow ? editingState : nil
  }

  private(set) var liveState: GlowState?
  private(set) var sessionCount = 0
  private(set) var sessions: [SessionTarget] = []
  private(set) var hooksInstalled = false
  private(set) var serverError: String?
  var hookError: String?

  var launchAtLogin = SMAppService.mainApp.status == .enabled {
    didSet {
      guard launchAtLogin != oldValue else { return }
      do {
        if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      } catch {
        hookError = "Open at login failed: \(error.localizedDescription)"
      }
    }
  }

  var displayedState: GlowState? { preview ?? liveState }

  private var tracker = SessionTracker()
  private let overlay = OverlayController()
  private let pill = ThreadPillController()
  private let installer = ClaudeHookInstaller()
  private var server: EventServer?
  private var origins: [String: SessionOrigin] = [:]
  /// Sessions whose origin was looked up already (found or not), so repeated events never re-run `ps`.
  private var originLookups: Set<String> = []
  private var expiryTask: Task<Void, Never>?

  init() {
    Self.migrateDefaultsFromEarlierNames()
    settingsPane = UserDefaults.standard.string(forKey: "settingsPane").flatMap(SettingsPane.init) ?? .glow
    let stored = UserDefaults.standard.string(forKey: Self.configKey).map { Data($0.utf8) }
    config = stored.flatMap { try? JSONDecoder().decode(GlowConfig.self, from: $0) } ?? GlowConfig()
    tracker.doneDuration = config.doneDuration
  }

  func start() {
    refreshHookStatus()
    if hooksInstalled {
      do {
        if try !installer.isCurrent() { try installer.install() }
      } catch { hookError = "Couldn't update Claude Code hooks: \(error.localizedDescription)" }
    }
    let server = EventServer { [weak self] request in
      guard let update = RequestRouter.update(for: request) else { return }
      let context = HookContext.parse(request)
      Task { @MainActor in self?.handle(update, context: context) }
    }
    do {
      try server.start()
      self.server = server
    } catch {
      serverError = "Event listener failed: \(error)"
    }
  }

  func handle(_ update: SessionUpdate, context: HookContext = HookContext()) {
    if case let .set(session, _) = update, context.pid != nil, originLookups.insert(session).inserted {
      Task { [weak self] in
        guard let origin = await SessionOrigin.resolve(context: context), let self,
              self.originLookups.contains(session) else { return }
        self.origins[session] = origin
        self.refresh()
      }
    }
    if case let .end(session) = update {
      origins[session] = nil
      originLookups.remove(session)
    }
    let previous = state(of: update.session)
    tracker.apply(update, at: .now)
    refresh()
    switch update {
    case let .set(session, state) where state != previous && config.showsPill(for: state):
      announce(session: session, state: state, context: context)
    case let .set(session, state) where state != previous:
      pill.dismiss(session: session)
    case .set:
      break
    case let .end(session):
      pill.dismiss(session: session)
    }
  }

  private func state(of session: String) -> GlowState? {
    tracker.activeSessions.first { $0.id == session }?.state
  }

  /// Shows the pill named after the thread. The transcript is read off the main actor; it can be large.
  private func announce(session: String, state: GlowState, context: HookContext) {
    guard config.enabled else { return }
    let path = context.transcriptPath
    let folder = context.cwd.map { URL(fileURLWithPath: $0).lastPathComponent }
    Task { [weak self] in
      let title = await Task.detached { path.flatMap(ThreadTitle.read(path:)) }.value
      // Skip if the thread moved on (or the setting changed) while the title was being read.
      guard let self, self.config.enabled, self.config.showsPill(for: state),
            [nil, state].contains(self.state(of: session)) else { return }
      let target = self.sessions.first { $0.id == session }
      self.pill.show(
        session: session,
        state: state,
        style: self.config[state],
        title: title ?? folder ?? target?.displayName ?? session,
        origin: self.origins[session],
        duration: self.config.pillDuration,
        hideFromCapture: self.config.hideFromScreenCapture
      )
    }
  }

  /// Fires a short-lived fake session so you can see a state without an agent running.
  func test(_ state: GlowState) {
    handle(.set(session: "test", state: state))
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(5))
      self?.handle(.end(session: "test"))
    }
  }

  func clearSessions() {
    pill.dismiss()
    tracker.removeAll()
    origins.removeAll()
    originLookups.removeAll()
    refresh()
  }

  func setHooksInstalled(_ install: Bool) {
    do {
      if install { try installer.install() } else { try installer.uninstall() }
      hookError = nil
    } catch {
      hookError = "Couldn't update \(installer.settingsURL.path): \(error.localizedDescription)"
    }
    refreshHookStatus()
  }

  private func refreshHookStatus() {
    hooksInstalled = (try? installer.isInstalled()) ?? false
  }

  private func refresh() {
    let now = Date.now
    tracker.prune(at: now)
    liveState = tracker.current(at: now)
    sessionCount = tracker.sessionCount
    let active = tracker.activeSessions
    let activeIDs = Set(active.map(\.id))
    origins = origins.filter { activeIDs.contains($0.key) }
    originLookups.formIntersection(activeIDs)
    sessions = active.map { SessionTarget(id: $0.id, state: $0.state, origin: origins[$0.id]) }
    overlay.render(state: displayedState, config: config, sessions: sessions)
    scheduleExpiry(after: now)
  }

  private func scheduleExpiry(after now: Date) {
    expiryTask?.cancel()
    guard let next = tracker.nextExpiry(after: now) else { return }
    expiryTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(next.timeIntervalSince(now) + 0.05))
      guard !Task.isCancelled else { return }
      self?.refresh()
    }
  }

  /// The app was called Glowbug (dev.glowbug.app) and before that Halo (dev.halo.notchglow).
  /// On first launch under the new name, carry the most recent of those settings over once.
  private static func migrateDefaultsFromEarlierNames() {
    let defaults = UserDefaults.standard
    guard defaults.string(forKey: configKey) == nil else { return }
    for suite in ["dev.glowbug.app", "dev.halo.notchglow"] {
      guard let old = UserDefaults(suiteName: suite), old.string(forKey: configKey) != nil else { continue }
      for key in [configKey, "settingsPane"] {
        if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
      }
      return
    }
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(config) else { return }
    UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Self.configKey)
  }
}
