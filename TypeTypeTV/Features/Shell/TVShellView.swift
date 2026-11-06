import SwiftUI

enum TVRoute: Hashable {
  case detail(LiveVideoItem)
  case channel(String)
  case playlist(LivePlaylistResult)
}

enum TVTab: Hashable {
  case home
  case search
  case library
  case settings
}

struct TVShellView: View {
  @ObservedObject var coordinator: RootCoordinator
  @State private var tab = TVTab.home
  @State private var homePath = NavigationPath()
  @State private var searchPath = NavigationPath()
  @State private var libraryPath = NavigationPath()
  @State private var playing: LiveVideoItem?

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack(path: $homePath) {
        TVHomeView(
          dependencies: coordinator.dependencies,
          onOpen: { open($0) },
          onPlay: { playing = $0 }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Home", systemImage: "house") }
      .tag(TVTab.home)

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
        TVComingSoon()
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
      TVPlayerScreen(video: video, playback: coordinator.dependencies.playbackCoordinator) { playing = nil }
    }
  }

  private func open(_ video: LiveVideoItem) {
    switch tab {
    case .home: homePath.append(TVRoute.detail(video))
    case .search: searchPath.append(TVRoute.detail(video))
    case .library: libraryPath.append(TVRoute.detail(video))
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
        onPlay: { video, _ in playing = video },
        onOpen: { open($0) }
      )
    case let .channel(url):
      TVChannelView(url: url, dependencies: coordinator.dependencies, onOpen: { open($0) })
    case let .playlist(playlist):
      TVPlaylistView(playlist: playlist, dependencies: coordinator.dependencies, onOpen: { open($0) })
    }
  }
}

struct TVComingSoon: View {
  var title: String?

  var body: some View {
    VStack(spacing: 24) {
      TVBrandLogo(markSize: 72)
      if let title {
        Text(verbatim: title).font(TVType.title).foregroundStyle(TVPalette.textMid)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TVPalette.ink.ignoresSafeArea())
  }
}
