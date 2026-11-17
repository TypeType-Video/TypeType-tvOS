import SwiftUI

extension TVShellView {
  var twitchService: LiveTwitchServiceProtocol? {
    coordinator.dependencies.twitchEnabled ? coordinator.dependencies.twitchService : nil
  }

  @ViewBuilder
  func twitchDestination(_ route: LiveTwitchRoute) -> some View {
    if let twitch = twitchService {
      switch route {
      case let .channel(login):
        TVTwitchChannelScreen(login: login, service: twitch) { push($0) }
      case let .game(slug, name):
        TVTwitchStreamsScreen(title: Text(verbatim: name), load: { try await twitch.gameStreams(slug: slug, after: $0).streams }) { push($0) }
      case let .tag(tag):
        TVTwitchStreamsScreen(title: Text("\(tag) lives"), load: { try await twitch.tagStreams(tag: tag, after: $0) }) { push($0) }
      }
    }
  }

  @ViewBuilder
  func destination(_ route: TVRoute) -> some View {
    switch route {
    case let .detail(video):
      TVVideoDetailView(
        video: video,
        dependencies: coordinator.dependencies,
        refresh: playbackEnded,
        onPlay: { video, _ in playing = video },
        onOpen: { open($0) },
        onOpenChannel: { openChannel($0) }
      )
    case let .channel(url):
      TVChannelScreen(url: url, dependencies: coordinator.dependencies, onOpen: { open($0) },
                      onOpenPlaylist: { push(.playlist($0)) })
    case let .playlist(playlist):
      TVPlaylistView(playlist: playlist, dependencies: coordinator.dependencies, onOpen: { open($0) })
    case let .twitch(route):
      twitchDestination(route)
    case let .twitchSearch(query):
      if let twitch = twitchService {
        TVTwitchSearchScreen(query: query, service: twitch) { push($0) }
      }
    }
  }
}

extension View {
  func tvContentEdges() -> some View {
    ignoresSafeArea(.container, edges: .horizontal)
  }
}
