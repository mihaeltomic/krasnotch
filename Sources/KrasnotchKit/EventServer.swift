import Darwin
import Foundation

/// Receives agent events over a Unix domain socket that only the current user can reach.
///
/// The socket lives in a 0700 directory and is itself 0600, and every connection's peer uid is checked.
/// Unlike a loopback TCP port, browsers can't reach it, other macOS users can't connect, and nobody else
/// can bind it while Krasnotch isn't running.
public final class EventServer: @unchecked Sendable {
  public enum StartError: Error, CustomStringConvertible {
    case unsafeDirectory(String)
    case pathTooLong
    case posix(String, Int32)

    public var description: String {
      switch self {
      case let .unsafeDirectory(path): "\(path) isn't a private directory owned by you"
      case .pathTooLong: "socket path is too long"
      case let .posix(call, code): "\(call) failed: \(String(cString: strerror(code)))"
      }
    }
  }

  /// `~/Library/Application Support/Krasnotch/events.sock`
  public static var defaultSocketURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Application Support/Krasnotch/events.sock")
  }

  /// The same path written for a shell, so hook commands work for whoever runs them.
  public static let shellSocketPath = "$HOME/Library/Application Support/Krasnotch/events.sock"

  static let maxConnections = 32
  static let idleTimeout: DispatchTimeInterval = .seconds(5)

  private let socketURL: URL
  private let queue = DispatchQueue(label: "krasnotch.event-server")
  private let handler: @Sendable (HTTPRequest) -> Void
  private var listenSource: DispatchSourceRead?
  private var connections: [Int32: Connection] = [:]

  public init(socketURL: URL = defaultSocketURL, handler: @escaping @Sendable (HTTPRequest) -> Void) {
    self.socketURL = socketURL
    self.handler = handler
  }

  public func start() throws {
    let directory = socketURL.deletingLastPathComponent().path
    try Self.preparePrivateDirectory(directory)
    let path = socketURL.path
    removeStaleSocket(at: path)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw StartError.posix("socket", errno) }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard path.utf8.count < capacity else { close(fd); throw StartError.pathTooLong }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in
      raw.copyBytes(from: path.utf8)
      raw[path.utf8.count] = 0
    }
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard bound == 0 else { let code = errno; close(fd); throw StartError.posix("bind", code) }
    chmod(path, 0o600)
    guard listen(fd, 16) == 0 else { let code = errno; close(fd); throw StartError.posix("listen", code) }
    _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)

    let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
    source.setEventHandler { [weak self] in self?.acceptPending(on: fd) }
    source.setCancelHandler { close(fd) }
    listenSource = source
    source.resume()
  }

  public func stop() {
    queue.sync {
      listenSource?.cancel()
      listenSource = nil
      connections.values.forEach { $0.close() }
      connections.removeAll()
    }
    removeStaleSocket(at: socketURL.path)
  }

  // MARK: - Private

  /// Creates the directory 0700 and refuses symlinks or directories owned by someone else.
  static func preparePrivateDirectory(_ path: String) throws {
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
    var info = stat()
    guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR, info.st_uid == getuid() else {
      throw StartError.unsafeDirectory(path)
    }
    if info.st_mode & 0o077 != 0 { chmod(path, 0o700) }
  }

  private func removeStaleSocket(at path: String) {
    var info = stat()
    if lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFSOCK { unlink(path) }
  }

  private func acceptPending(on listener: Int32) {
    while true {
      let fd = accept(listener, nil, nil)
      guard fd >= 0 else { return }
      var uid: uid_t = 0, gid: gid_t = 0
      guard getpeereid(fd, &uid, &gid) == 0, uid == getuid(), connections.count < Self.maxConnections else {
        close(fd)
        continue
      }
      var on: Int32 = 1
      setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
      _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
      let connection = Connection(fd: fd, queue: queue, handler: handler) { [weak self] in
        self?.connections[fd] = nil
      }
      connections[fd] = connection
      connection.start()
    }
  }
}

/// One request per connection: read until a full request parses, answer, close. Runs on the server queue.
private final class Connection: @unchecked Sendable {
  private let fd: Int32
  private let queue: DispatchQueue
  private let handler: @Sendable (HTTPRequest) -> Void
  private let onClose: () -> Void
  private var buffer = Data()
  private var source: DispatchSourceRead?
  private var timeout: DispatchWorkItem?
  private var closed = false

  init(fd: Int32, queue: DispatchQueue, handler: @escaping @Sendable (HTTPRequest) -> Void, onClose: @escaping () -> Void) {
    self.fd = fd
    self.queue = queue
    self.handler = handler
    self.onClose = onClose
  }

  func start() {
    let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
    source.setEventHandler { [weak self] in self?.readAvailable() }
    source.setCancelHandler { [fd] in Darwin.close(fd) }
    self.source = source
    let timeout = DispatchWorkItem { [weak self] in self?.close() }
    self.timeout = timeout
    queue.asyncAfter(deadline: .now() + EventServer.idleTimeout, execute: timeout)
    source.resume()
  }

  func close() {
    guard !closed else { return }
    closed = true
    timeout?.cancel()
    source?.cancel()
    onClose()
  }

  private func readAvailable() {
    var chunk = [UInt8](repeating: 0, count: 64 * 1024)
    let count = read(fd, &chunk, chunk.count)
    if count < 0, errno == EAGAIN || errno == EINTR { return }
    guard count > 0 else { return close() }
    buffer.append(contentsOf: chunk[0..<count])

    switch HTTPRequest.parse(buffer) {
    case let .complete(request):
      handler(request)
      respond("204 No Content")
    case .invalid:
      respond("400 Bad Request")
    case .incomplete:
      break
    }
  }

  private func respond(_ status: String) {
    let response = Array("HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
    _ = response.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    close()
  }
}
