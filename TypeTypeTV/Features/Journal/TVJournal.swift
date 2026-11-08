import Foundation
import OSLog

actor TVJournal {
  static let shared = TVJournal()
  nonisolated static let fileURL = URL.cachesDirectory.appending(path: "journal.log")
  nonisolated static let previousURL = URL.cachesDirectory.appending(path: "journal.1.log")
  nonisolated private static let console = Logger(subsystem: "dev.typetype.tv.journal", category: "journal")
  private static let limit = 4_000_000

  private var pending: [(Date, String)] = []
  private var harvestedUntil = Date.distantPast
  private var harvestFailed = false
  private var pump: Task<Void, Never>?

  nonisolated static func note(_ category: String, _ message: String, at date: Date = Date()) {
    console.notice("\(category, privacy: .public) \(message, privacy: .public)")
    Task { await shared.queue(date, "\(category) \(message)") }
  }

  func start() {
    guard pump == nil else { return }
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    let system = ProcessInfo.processInfo.operatingSystemVersionString
    queue(Date(), "session start TypeType \(version) (\(build)), tvOS \(system), \(Self.model())")
    pump = Task { [weak self] in
      repeat { await self?.flush() } while (try? await Task.sleep(for: .seconds(2))) != nil
    }
  }

  func flush() {
    let lines = (pending + harvest()).sorted { $0.0 < $1.0 }
    pending.removeAll()
    guard !lines.isEmpty else { return }
    let text = lines.map { "\(Self.stamp($0.0)) \($0.1)\n" }.joined()
    write(Data(text.utf8))
  }

  func tail(_ count: Int) -> [String] {
    flush()
    let current = (try? String(contentsOf: Self.fileURL, encoding: .utf8)) ?? ""
    var lines = current.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    if lines.count < count, let older = try? String(contentsOf: Self.previousURL, encoding: .utf8) {
      lines = older.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) + lines
    }
    return Array(lines.suffix(count))
  }

  func size() -> Int {
    let current = (try? FileManager.default.attributesOfItem(atPath: Self.fileURL.path)[.size] as? Int) ?? 0
    let older = (try? FileManager.default.attributesOfItem(atPath: Self.previousURL.path)[.size] as? Int) ?? 0
    return current + older
  }

  private func queue(_ date: Date, _ line: String) {
    pending.append((date, line))
  }

  private func harvest() -> [(Date, String)] {
    do {
      let store = try OSLogStore(scope: .currentProcessIdentifier)
      let since = harvestedUntil
      let start = since == .distantPast ? store.position(timeIntervalSinceLatestBoot: 0) : store.position(date: since)
      let predicate = NSPredicate(format: "subsystem BEGINSWITH %@ AND subsystem != %@", "dev.typetype", "dev.typetype.tv.journal")
      var lines: [(Date, String)] = []
      for case let entry as OSLogEntryLog in try store.getEntries(at: start, matching: predicate) where entry.date > since {
        lines.append((entry.date, "\(entry.category) \(Self.level(entry.level)) \(entry.composedMessage)"))
        harvestedUntil = max(harvestedUntil, entry.date)
      }
      return lines
    } catch {
      guard !harvestFailed else { return [] }
      harvestFailed = true
      return [(Date(), "journal system log unavailable: \(error.localizedDescription)")]
    }
  }

  private func write(_ data: Data) {
    let manager = FileManager.default
    if let size = try? manager.attributesOfItem(atPath: Self.fileURL.path)[.size] as? Int, size > Self.limit {
      try? manager.removeItem(at: Self.previousURL)
      try? manager.moveItem(at: Self.fileURL, to: Self.previousURL)
    }
    if !manager.fileExists(atPath: Self.fileURL.path) {
      manager.createFile(atPath: Self.fileURL.path, contents: nil)
    }
    do {
      let handle = try FileHandle(forWritingTo: Self.fileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
    } catch {
      Self.console.error("journal write failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private static func level(_ level: OSLogEntryLog.Level) -> String {
    switch level {
    case .debug: "debug"
    case .info: "info"
    case .notice: "notice"
    case .error: "error"
    case .fault: "fault"
    default: "log"
    }
  }

  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()

  private static func stamp(_ date: Date) -> String { formatter.string(from: date) }

  private static func model() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
  }
}
