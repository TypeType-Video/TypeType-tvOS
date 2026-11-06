import Foundation

// A provider's media links expire. Before a failure is shown or a lower quality is tried, a stream loaded
// ten minutes ago or more is fetched again, once, and playback resumes at the same position: the web
// client's claimStreamRefresh.
struct LiveStreamRefreshClaim {
  static let minimumAge: TimeInterval = 10 * 60

  private(set) var refreshedFor: Date?

  mutating func claim(loadedAt: Date, now: Date) -> Bool {
    guard refreshedFor != loadedAt,
      now.timeIntervalSince(loadedAt) >= Self.minimumAge
    else { return false }
    refreshedFor = loadedAt
    return true
  }

  // Only the providers whose links expire; YouTube plays through its own session.
  static func refreshesExpiredLinks(videoURL: String) -> Bool {
    guard let host = URL(string: videoURL)?.host?.lowercased() else { return false }
    return host == "nicovideo.jp" || host.hasSuffix(".nicovideo.jp")
      || host == "bilibili.com" || host.hasSuffix(".bilibili.com")
  }
}
