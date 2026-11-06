import SwiftUI

enum TVRoute: Hashable {
  case detail(LiveVideoItem)
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
          onOpen: { homePath.append(TVRoute.detail($0)) },
          onPlay: { playing = $0 }
        )
        .navigationDestination(for: TVRoute.self, destination: destination)
      }
      .tabItem { Label("Home", systemImage: "house") }
      .tag(TVTab.home)

      NavigationStack(path: $searchPath) {
        TVComingSoon()
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
  }

  @ViewBuilder
  private func destination(_ route: TVRoute) -> some View {
    switch route {
    case let .detail(video):
      TVComingSoon(title: video.title)
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
