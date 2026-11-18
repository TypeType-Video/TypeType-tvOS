import Foundation

@MainActor
final class TVTwitchChat: ObservableObject {
  let live: LiveTwitchChatViewModel?
  let replay: LiveTwitchVodChatViewModel?

  init(video: LiveVideoItem, dependencies: AppDependencies) {
    var live: LiveTwitchChatViewModel?
    var replay: LiveTwitchVodChatViewModel?
    if dependencies.twitchEnabled, let service = dependencies.twitchAccountService, let link = video.twitchLink {
      switch link {
      case let .channel(login):
        if let chat = dependencies.twitchChatService {
          live = LiveTwitchChatViewModel(login: login, chatService: chat, service: service, signedIn: true)
        }
      case let .video(id):
        let owner = URL(string: video.uploaderURL).flatMap(LiveTwitchLink.target(for:))
        let login: String? = if case let .channel(login) = owner { login } else { nil }
        replay = LiveTwitchVodChatViewModel(videoID: id, login: login, service: service)
      case .clip:
        break
      }
    }
    self.live = live
    self.replay = replay
  }

  var isAvailable: Bool { live != nil || replay != nil }

  func run() async {
    await live?.run()
  }
}
