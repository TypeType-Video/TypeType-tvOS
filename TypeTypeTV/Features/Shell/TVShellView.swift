import SwiftUI

enum TVRoute: Hashable {
  case detail(LiveVideoItem)
  case channel(String)
  case playlist(LivePlaylistResult)
}

enum TVTab: Hashable {
  case home
  case subscriptions
  case search
  case library
  case settings
}

struct TVShellView: View {
  @ObservedObject var coordinator: RootCoordinator
  @State private var tab = TVTab.home
  @State private var homePath = NavigationPath()
  @State private var subscriptionsPath = NavigationPath()
  @State private var searchPath = NavigationPath()
  @State private var libraryPath = NavigationPath()
  @State private var playing: LiveVideoItem?
  @State private var playbackEnded = 0

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack(path: $homePath) {
        TVHomeView(
          dependencies: coordinator.dependencies,
          refresh: playbackEnded,
          onOpen: { open($0) },
          onPlay: { playing = $0 }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Home", systemImage: "house") }
      .tag(TVTab.home)

      NavigationStack(path: $subscriptionsPath) {
        TVSubscriptionsView(dependencies: coordinator.dependencies, onOpen: { open($0) })
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Subscriptions", systemImage: "play.square.stack") }
      .tag(TVTab.subscriptions)

      NavigationStack(path: $searchPath) {
        TVSearchView(
          dependencies: coordinator.dependencies,
          onOpen: { open($0) },
          onOpenChannel: { searchPath.append(TVRoute.channel($0.url)) },
          onOpenPlaylist: { searchPath.append(TVRoute.playlist($0)) }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Search", systemImage: "magnifyingglass") }
      .tag(TVTab.search)

      NavigationStack(path: $libraryPath) {
        TVLibraryView(dependencies: coordinator.dependencies, refresh: playbackEnded, onOpen: { open($0) })
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Library", systemImage: "square.stack") }
      .tag(TVTab.library)

      TVSettingsView(coordinator: coordinator)
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(TVTab.settings)
    }
    .background(TVPalette.ink.ignoresSafeArea())
    .fullScreenCover(item: $playing) { video in
      TVPlayerScreen(video: video, playback: coordinator.dependencies.playbackCoordinator, dependencies: coordinator.dependencies) {
        playing = nil
        playbackEnded += 1
      }
    }
  }

  private func open(_ video: LiveVideoItem) {
    switch tab {
    case .home: homePath.append(TVRoute.detail(video))
    case .subscriptions: subscriptionsPath.append(TVRoute.detail(video))
    case .search: searchPath.append(TVRoute.detail(video))
    case .library: libraryPath.append(TVRoute.detail(video))
    case .settings: break
    }
  }

  private func openChannel(_ url: String) {
    switch tab {
    case .home: homePath.append(TVRoute.channel(url))
    case .subscriptions: subscriptionsPath.append(TVRoute.channel(url))
    case .search: searchPath.append(TVRoute.channel(url))
    case .library: libraryPath.append(TVRoute.channel(url))
    case .settings: break
    }
  }

  @ViewBuilder
  private func destination(_ route: TVRoute) -> some View {
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
      TVChannelView(url: url, dependencies: coordinator.dependencies, onOpen: { open($0) })
    case let .playlist(playlist):
      TVPlaylistView(playlist: playlist, dependencies: coordinator.dependencies, onOpen: { open($0) })
    }
  }
}
