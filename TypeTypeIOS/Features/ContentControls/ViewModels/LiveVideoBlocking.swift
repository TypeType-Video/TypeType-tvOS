import Foundation

// Whether a video and its channel are blocked for the account, as the Android TV video menu shows it. A change
// shows at once, hides or shows the video in the lists on screen, and is undone if the server refuses it.
@MainActor
final class LiveVideoBlocking: ObservableObject {
  @Published private(set) var videoBlocked = false
  @Published private(set) var channelBlocked = false
  @Published private(set) var isLoaded = false
  @Published private(set) var failed = false

  private let video: LiveVideoItem
  private let service: LiveContentControlsServiceProtocol
  private let hidden: LiveHiddenVideos

  init(video: LiveVideoItem, service: LiveContentControlsServiceProtocol, hidden: LiveHiddenVideos) {
    self.video = video
    self.service = service
    self.hidden = hidden
  }

  func load() async {
    do {
      async let videos = service.items(kind: .blockedVideos)
      async let channels = service.items(kind: .blockedChannels)
      let (blockedVideos, blockedChannels) = try await (videos, channels)
      videoBlocked = blockedVideos.contains { $0.url == video.url }
      channelBlocked = !video.uploaderURL.isEmpty && blockedChannels.contains { $0.url == video.uploaderURL }
    } catch is CancellationError {
      return
    } catch {
      failed = true
    }
    isLoaded = true
  }

  func setVideoBlocked(_ blocked: Bool) async {
    let previous = videoBlocked
    videoBlocked = blocked
    let succeeded = await change(.blockedVideos, item: LiveContentControlItem(url: video.url), blocked: blocked)
    if !succeeded { videoBlocked = previous }
  }

  func setChannelBlocked(_ blocked: Bool) async {
    guard !video.uploaderURL.isEmpty else { return }
    let previous = channelBlocked
    channelBlocked = blocked
    let item = LiveContentControlItem(url: video.uploaderURL, name: video.uploaderName, thumbnailURL: video.uploaderAvatarURL)
    let succeeded = await change(.blockedChannels, item: item, blocked: blocked)
    if !succeeded { channelBlocked = previous }
  }

  private func change(_ kind: LiveContentControlKind, item: LiveContentControlItem, blocked: Bool) async -> Bool {
    failed = false
    if blocked { hidden.hide(kind, url: item.url) } else { hidden.show(kind, url: item.url) }
    do {
      if blocked {
        _ = try await service.add(kind: kind, item: item)
      } else {
        try await service.remove(kind: kind, url: item.url)
      }
      return true
    } catch {
      if blocked { hidden.show(kind, url: item.url) } else { hidden.hide(kind, url: item.url) }
      failed = true
      return false
    }
  }
}
