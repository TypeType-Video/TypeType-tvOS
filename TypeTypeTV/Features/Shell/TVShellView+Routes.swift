import SwiftUI

extension TVShellView {
  var twitchService: LiveTwitchServiceProtocol? {
    coordinator.dependencies.twitchEnabled ? coordinator.dependencies.twitchService : nil
  }

  @ViewBuilder
  var twitchTab: some View {
    if let twitch = twitchService {
      NavigationStack(path: $paths.twitch) {
        TVTwitchView(service: twitch, account: coordinator.dependencies.twitchAccountService, onPlay: { playing = $0 }) { push($0) }
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .environment(\.tvContentFocusRequest, contentFocus[.twitch] ?? 0)
      .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }
      .tag(TVTab.twitch)
    }
  }

  @ViewBuilder
  func twitchDestination(_ route: LiveTwitchRoute) -> some View {
    if let twitch = twitchService {
      switch route {
      case let .channel(login):
        TVTwitchChannelScreen(login: login, service: twitch, account: coordinator.dependencies.twitchAccountService, onPlay: { playing = $0 }) { push($0) }
      case let .game(slug, name):
        TVTwitchStreamsScreen(title: Text(verbatim: name), load: { try await twitch.gameStreams(slug: slug, after: $0).streams }, onPlay: { playing = $0 }) { push($0) }
      case let .tag(tag):
        TVTwitchStreamsScreen(title: Text("\(tag) lives"), load: { try await twitch.tagStreams(tag: tag, after: $0) }, onPlay: { playing = $0 }) { push($0) }
      case .linkAccount:
        if let account = coordinator.dependencies.twitchAccountService { TVTwitchLinkScreen(service: account) }
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
        TVTwitchSearchScreen(query: query, service: twitch, onPlay: { playing = $0 }) { push($0) }
      }
    }
  }
}

extension View {
  func tvContentEdges() -> some View {
    ignoresSafeArea(.container, edges: .horizontal)
  }
}
