import Combine
import Foundation

@MainActor
final class LiveVideoDetailViewModel: ObservableObject {
  @Published private(set) var description: String
  @Published private(set) var subscriberCount: Int64?
  @Published private(set) var category: String?
  @Published private(set) var chapters: [LivePlaybackChapter] = []
  @Published private(set) var bestHeight: Int?
  @Published private(set) var related: [LiveVideoItem]?
  @Published private(set) var resumeSeconds: Int64?
  @Published private(set) var failure: String?
  @Published private(set) var isLoading = false

  let video: LiveVideoItem
  private let stream: (String) async throws -> LivePlaybackStream
  private let progress: (String) async throws -> Int64?

  init(
    video: LiveVideoItem,
    stream: @escaping (String) async throws -> LivePlaybackStream,
    progress: @escaping (String) async throws -> Int64?
  ) {
    self.video = video
    self.stream = stream
    self.progress = progress
    description = video.shortDescription ?? ""
  }

  convenience init(video: LiveVideoItem, dependencies: AppDependencies) {
    let playback = dependencies.playbackService
    let history = dependencies.historyService
    self.init(
      video: video,
      stream: { url in
        guard let playback else { throw NetworkError.missingServerURL }
        return try await playback.stream(for: url)
      },
      progress: { try await history.progress(videoURL: $0) }
    )
  }

  // A position this close to the end counts as watched: Play starts over instead of resuming the credits.
  var resumeFraction: Double? {
    guard let resumeSeconds, video.duration > 0, resumeSeconds > 0,
      resumeSeconds < video.duration - Self.watchedMargin
    else { return nil }
    return Double(resumeSeconds) / Double(video.duration)
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    failure = nil
    defer { isLoading = false }
    let url = video.url
    async let streamRequest = stream(url)
    async let progressRequest = progress(url)
    resumeSeconds = (try? await progressRequest).flatMap { $0 }.map { $0 / 1_000 }
    do {
      let details = try await streamRequest
      if !details.description.isEmpty { description = details.description }
      subscriberCount = details.uploaderSubscriberCount > 0 ? details.uploaderSubscriberCount : nil
      category = details.category.flatMap { $0.isEmpty ? nil : $0 }
      chapters = details.chapters
      bestHeight = details.allVideoSources.map(\.effectiveHeight).max()
      related = LiveHomeViewModel.uniqueVisibleVideos(
        details.relatedStreams.filter { !$0.isShortFormContent && $0.canonicalID != video.canonicalID }
      )
    } catch is CancellationError {
      return
    } catch {
      related = []
      failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
  }

  func refreshProgress() async {
    guard let position = try? await progress(video.url) else { return }
    resumeSeconds = position / 1_000
  }

  private static let watchedMargin: Int64 = 30
}
