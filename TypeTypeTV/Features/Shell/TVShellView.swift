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
  @State private var menuRequest: TVVideoMenuRequest?
  @State private var contentScrolled = false
  @State private var librarySection = TVLibrarySection.history
  @State private var landed = false
  @StateObject private var account: TVAccountSettings

  init(coordinator: RootCoordinator) {
    self.coordinator = coordinator
    _account = StateObject(wrappedValue: TVAccountSettings(service: coordinator.dependencies.settingsService))
  }

  // The tabs appear once the first screen is known: a selection changed by code after the tab bar is drawn moves the
  // content but leaves the bar highlighting the old tab. This happens under the intro, like Android's blank start.
  var body: some View {
    Group {
      if landed { tabs } else { TVPalette.ink.ignoresSafeArea() }
    }
    .task {
      // Whichever comes first: the settings, or two seconds, after which a slow server leaves the app on Home.
      await withTaskGroup(of: Void.self) { group in
        group.addTask { await account.load() }
        group.addTask { _ = try? await Task.sleep(for: .seconds(2)) }
        await group.next()
        land()
        await group.waitForAll()
      }
    }
  }

  private var tabs: some View {
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
        TVLibraryView(dependencies: coordinator.dependencies, refresh: playbackEnded, section: $librarySection, onOpen: { open($0) })
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Library", systemImage: "square.stack") }
      .tag(TVTab.library)

      TVSettingsView(coordinator: coordinator)
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(TVTab.settings)
    }
    .environmentObject(account)
    .environment(\.tvVideoMenu) { menuRequest = $0 }
    .environment(\.tvVideoMenuShown, menuRequest != nil)
    .disabled(menuRequest != nil)
    .environment(\.tvContentScrolled) { scrolled in if contentScrolled != scrolled { contentScrolled = scrolled } }
    .onChange(of: tab) { _, _ in contentScrolled = false }
    .overlay { TVTopBarMarks(user: coordinator.currentUser, hidden: contentScrolled) }
    .overlay {
      if let request = menuRequest {
        TVVideoMenuPanel(
          request: request, dependencies: coordinator.dependencies,
          onPlay: { menuRequest = nil; playing = request.video },
          onOpenChannel: { menuRequest = nil; openChannel(request.video.uploaderURL) },
          onClose: { menuRequest = nil }
        )
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: 0.26), value: menuRequest?.video.canonicalID)
    .background(TVPalette.ink.ignoresSafeArea())
    .environment(\.livePrewarm) { video in
      coordinator.dependencies.playbackPrewarmer?.prewarm(video)
    }
    .fullScreenCover(item: $playing) { video in
      TVPlayerScreen(video: video, playback: coordinator.dependencies.playbackCoordinator, dependencies: coordinator.dependencies) {
        playing = nil
        playbackEnded += 1
      }
    }
  }

  // The account's "Start on" setting: Home, or one of the library sections, chosen once when the app opens.
  private func land() {
    guard !landed else { return }
    defer { landed = true }
    switch account.settings?.defaultLandingPage {
    case "history": librarySection = .history
    case "favorites": librarySection = .favorites
    case "watch-later": librarySection = .watchLater
    default: return
    }
    tab = .library
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
