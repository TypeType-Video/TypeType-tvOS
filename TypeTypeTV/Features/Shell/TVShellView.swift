import SwiftUI

struct TVShellView: View {
  @ObservedObject var coordinator: RootCoordinator
  @State private var tab = TVTab.home
  @State var paths = TVTabPaths()
  @State private var subscriptionsReset = 0
  @State var playing: LiveVideoItem?
  @State var playbackEnded = 0
  @State private var menuRequest: TVVideoMenuRequest?
  @State private var contentScrolled = false
  @State private var librarySection = TVLibrarySection.history
  @State private var landed = false
  @AppStorage(TVDeviceSetting.backReturnsKey) private var backReturns = false
  @State var contentFocus: [TVTab: Int] = [:]
  @StateObject private var account: TVAccountSettings

  init(coordinator: RootCoordinator) {
    self.coordinator = coordinator
    _account = StateObject(wrappedValue: TVAccountSettings(service: coordinator.dependencies.settingsService))
  }

  var body: some View {
    Group {
      if landed { tabs } else { TVPalette.ink.ignoresSafeArea() }
    }
    .task {
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
      NavigationStack(path: $paths.home) {
        TVHomeView(
          dependencies: coordinator.dependencies,
          refresh: playbackEnded,
          previewsAllowed: tab == .home && paths.home.isEmpty && playing == nil,
          onOpen: { open($0) },
          onPlay: { playing = $0 }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .environment(\.tvContentFocusRequest, contentFocus[.home] ?? 0)
      .tabItem { Label("Home", systemImage: "house") }
      .tag(TVTab.home)

      NavigationStack(path: $paths.subscriptions) {
        TVSubscriptionsView(dependencies: coordinator.dependencies, reset: subscriptionsReset, onOpen: { open($0) },
                            onOpenChannel: { openChannel($0) })
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .environment(\.tvContentFocusRequest, contentFocus[.subscriptions] ?? 0)
      .tabItem { Label("Subscriptions", systemImage: "play.square.stack") }
      .tag(TVTab.subscriptions)

      twitchTab

      NavigationStack(path: $paths.search) {
        TVSearchView(
          dependencies: coordinator.dependencies,
          onOpen: { open($0) },
          onOpenChannel: { openChannel($0.url) },
          onOpenPlaylist: { push(.playlist($0)) }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .environment(\.tvContentFocusRequest, contentFocus[.search] ?? 0)
      .tabItem { Label("Search", systemImage: "magnifyingglass") }
      .tag(TVTab.search)

      NavigationStack(path: $paths.library) {
        TVLibraryView(dependencies: coordinator.dependencies, refresh: playbackEnded, section: $librarySection, onOpen: { open($0) })
          .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .environment(\.tvContentFocusRequest, contentFocus[.library] ?? 0)
      .tabItem { Label("Library", systemImage: "square.stack") }
      .tag(TVTab.library)

      TVSettingsView(coordinator: coordinator)
        .environment(\.tvContentFocusRequest, contentFocus[.settings] ?? 0)
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(TVTab.settings)
    }
    .environmentObject(account)
    .environment(\.tvVideoMenu) { menuRequest = $0 }
    .environment(\.tvVideoMenuShown, menuRequest != nil)
    .disabled(menuRequest != nil)
    .environment(\.tvContentScrolled) { scrolled in if contentScrolled != scrolled { contentScrolled = scrolled } }
    .onChange(of: tab) { _, _ in contentScrolled = false }
    .modifier(TVShellJournal(tab: tab, depths: paths.depths, playing: playing?.canonicalID, menu: menuRequest?.video.canonicalID))
    .background(TVTabReselect(menuReturns: backReturns, onReselect: returnToRoot) {
      TVJournal.note("tabs", "menu on bar returns focus to \(tab) content")
      contentFocus[tab, default: 0] += 1
    })
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
      TVPlayerScreen(video: video, playback: coordinator.dependencies.playbackCoordinator, dependencies: coordinator.dependencies,
                     onOpenChannel: { url in Task { openChannel(url) } },
                     onOpenPlaylist: { playlist in Task { push(.playlist(playlist)) } }) {
        playing = nil
        playbackEnded += 1
      }
    }
  }

  private func land() {
    guard !landed else { return }
    defer { landed = true }
    let page = account.landingPage
    AppLogger.app.notice("landing \(page ?? "unknown", privacy: .public)")
    switch page {
    case "subscriptions": return tab = .subscriptions
    case "history": librarySection = .history
    case "favorites": librarySection = .favorites
    case "watch-later": librarySection = .watchLater
    case "playlists": break
    default: return
    }
    tab = .library
  }

  func open(_ video: LiveVideoItem) { push(.detail(video)) }

  func openChannel(_ url: String) {
    if case let .channel(login)? = URL(string: url).flatMap(LiveTwitchLink.target(for:)) {
      return push(.twitch(.channel(login)))
    }
    push(.channel(url))
  }

  func push(_ route: TVRoute) { paths.push(route, on: tab) }

  private func returnToRoot() {
    TVJournal.note("tabs", "reselect \(tab), stack empty \(paths.isEmpty(tab))")
    if paths.isEmpty(tab) {
      if tab == .subscriptions { subscriptionsReset += 1 }
    } else {
      paths.popToRoot(tab)
    }
  }
}
