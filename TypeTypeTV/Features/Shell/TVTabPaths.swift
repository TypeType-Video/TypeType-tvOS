import SwiftUI

struct TVTabPaths {
  var home = NavigationPath()
  var subscriptions = NavigationPath()
  var twitch = NavigationPath()
  var search = NavigationPath()
  var library = NavigationPath()

  mutating func push(_ route: TVRoute, on tab: TVTab) {
    switch tab {
    case .home: home.append(route)
    case .subscriptions: subscriptions.append(route)
    case .twitch: twitch.append(route)
    case .search: search.append(route)
    case .library: library.append(route)
    case .settings: break
    }
  }

  var depths: [Int] { [home.count, subscriptions.count, twitch.count, search.count, library.count] }

  func isEmpty(_ tab: TVTab) -> Bool {
    switch tab {
    case .home: home.isEmpty
    case .subscriptions: subscriptions.isEmpty
    case .twitch: twitch.isEmpty
    case .search: search.isEmpty
    case .library: library.isEmpty
    case .settings: true
    }
  }

  mutating func popToRoot(_ tab: TVTab) {
    switch tab {
    case .home: home = NavigationPath()
    case .subscriptions: subscriptions = NavigationPath()
    case .twitch: twitch = NavigationPath()
    case .search: search = NavigationPath()
    case .library: library = NavigationPath()
    case .settings: break
    }
  }
}
