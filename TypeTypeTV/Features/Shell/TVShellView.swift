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
  @State private var menuVideo: LiveVideoItem?

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack(path: $homePath) {
        TVHomeView(
          dependencies: coordinator.dependencies,
          refresh: playbackEnded,
          previewsAllowed: tab == .home && homePath.isEmpty && playing == nil,
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
    .environment(\.tvVideoMenu) { menuVideo = $0 }
    .environment(\.tvVideoMenuShown, menuVideo != nil)
    .disabled(menuVideo != nil)
    .overlay { TVTopBarMarks(user: coordinator.currentUser) }
    .overlay {
      if let video = menuVideo {
        TVVideoMenuPanel(
          video: video, dependencies: coordinator.dependencies,
          onPlay: { menuVideo = nil; playing = video },
          onOpenChannel: { menuVideo = nil; openChannel(video.uploaderURL) },
          onClose: { menuVideo = nil }
        )
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: 0.26), value: menuVideo?.canonicalID)
    .background(TVPalette.ink.ignoresSafeArea())
    .fullScreenCover(item: $playing) { video in
      TVPlayerScreen(video: video, playback: coordinator.dependencies.playbackCoordinator, dependencies: coordinator.dependencies) {
        playing = nil
        playbackEnded += 1
      }
    }
  }

  private func open(_ video: LiveVideoItem) { push(.detail(video)) }

  private func openChannel(_ url: String) { push(.channel(url)) }

  private func push(_ route: TVRoute) {
    switch tab {
    case .home: homePath.append(route)
    case .subscriptions: subscriptionsPath.append(route)
    case .search: searchPath.append(route)
    case .library: libraryPath.append(route)
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
      TVChannelScreen(url: url, dependencies: coordinator.dependencies, onOpen: { open($0) },
                      onOpenPlaylist: { push(.playlist($0)) })
    case let .playlist(playlist):
      TVPlaylistView(playlist: playlist, dependencies: coordinator.dependencies, onOpen: { open($0) })
    }
  }
}

extension View {
  // tvOS insets tab content by its own 80 pt on each side; the screens already keep Android TV's 112 pt from the
  // edge, so the system margin is dropped instead of adding up to 192 pt. Set on each screen: on the TabView
  // content it has no effect.
  func tvContentEdges() -> some View {
    ignoresSafeArea(.container, edges: .horizontal)
  }
}
