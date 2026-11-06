import Foundation
import TypeTypePlayerKit

// A muted, low-quality playback behind a browse screen, like Android TV's MutedPreview. It always starts at the
// beginning and records nothing: no history, no progress, no now playing, no audio session.
@MainActor
final class LivePreviewPlayer: ObservableObject {
  @Published private(set) var playback: LivePreviewPlayback?
  @Published private(set) var showsFrames = false

  private let service: LivePlaybackServiceProtocol?
  private var task: Task<Void, Never>?
  private var generation = 0

  private static let preferences = LivePlaybackPreferences(quality: "480p", audioOnly: false)
  // A small buffer, as on Android: a preview rarely plays long and should not pull a full window of segments.
  private static let configuration = TypeTypePlayerConfiguration(forwardBuffer: 6)

  init(service: LivePlaybackServiceProtocol?) {
    self.service = service
  }

  func show(_ video: LiveVideoItem?) {
    generation += 1
    let current = generation
    stop()
    guard let service, let video, !video.isLive, !video.isShortFormContent else { return }
    task = Task { [weak self] in await self?.start(video, service: service, generation: current) }
  }

  func stop() {
    task?.cancel()
    task = nil
    playback?.stop()
    playback = nil
    showsFrames = false
  }

  private func start(_ video: LiveVideoItem, service: LivePlaybackServiceProtocol, generation current: Int) async {
    do {
      let stream = try await service.playbackStream(for: video.url)
      guard current == generation, !stream.isLive else { return }
      let preparation = try service.prepare(stream: stream, sourceURL: video.url, preferences: Self.preferences)
      guard let (source, session) = try await source(for: preparation, service: service, generation: current) else { return }
      let player = TypeTypePlayer(source: source, configuration: Self.configuration)
      player.isMuted = true
      let playback = LivePreviewPlayback(player: player, session: session)
      player.onStart = { [weak self, weak playback] in
        guard let self, let playback, self.playback === playback else { return }
        showsFrames = true
      }
      player.onStateChange = { [weak self, weak playback] state in
        guard let self, let playback, self.playback === playback else { return }
        switch state {
        case .ended, .failed: showsFrames = false
        default: break
        }
      }
      player.onTime = { [weak playback] time in playback?.report(time) }
      self.playback = playback
      player.start(at: 0, autoplay: true)
    } catch is CancellationError {
      return
    } catch {
      AppLogger.playback.notice("preview unavailable: \(String(describing: error), privacy: .public)")
    }
  }

  private func source(
    for preparation: LivePlaybackPreparation,
    service: LivePlaybackServiceProtocol,
    generation current: Int
  ) async throws -> (MediaSegmentSource, LiveSABRPlaybackSession?)? {
    guard preparation.isSABR else {
      return LiveProviderSegmentSource(preparation: preparation, service: service).map { ($0, nil) }
    }
    let session = LiveSABRPlaybackSession(
      service: service,
      preparation: preparation,
      maintenanceFailureHandler: { [weak self] _ in
        Task { @MainActor [weak self] in self?.stop() }
      }
    )
    let snapshot = try await session.start()
    guard current == generation, snapshot.isIndexedVOD else {
      await session.stopMaintenance()
      return nil
    }
    return (LiveSABRSegmentSource(session: session, service: service, audioOnly: false), session)
  }
}

@MainActor
final class LivePreviewPlayback {
  let player: TypeTypePlayer
  let layerOwner: LiveNativeLayerOwner
  private let session: LiveSABRPlaybackSession?

  init(player: TypeTypePlayer, session: LiveSABRPlaybackSession?) {
    self.player = player
    self.session = session
    layerOwner = LiveNativeLayerOwner(layer: player.videoLayer)
  }

  func report(_ time: TimeInterval) {
    Task { [session] in await session?.updatePlayerTime(time) }
  }

  func stop() {
    player.stop()
    Task { [session] in await session?.stopMaintenance() }
  }
}
