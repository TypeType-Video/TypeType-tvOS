import SwiftUI

// One navigation stack per tab; Settings has none.
struct TVTabPaths {
  var home = NavigationPath()
  var subscriptions = NavigationPath()
  var search = NavigationPath()
  var library = NavigationPath()

  mutating func push(_ route: TVRoute, on tab: TVTab) {
    switch tab {
    case .home: home.append(route)
    case .subscriptions: subscriptions.append(route)
    case .search: search.append(route)
    case .library: library.append(route)
    case .settings: break
    }
  }

  func isEmpty(_ tab: TVTab) -> Bool {
    switch tab {
    case .home: home.isEmpty
    case .subscriptions: subscriptions.isEmpty
    case .search: search.isEmpty
    case .library: library.isEmpty
    case .settings: true
    }
  }

  mutating func popToRoot(_ tab: TVTab) {
    switch tab {
    case .home: home = NavigationPath()
    case .subscriptions: subscriptions = NavigationPath()
    case .search: search = NavigationPath()
    case .library: library = NavigationPath()
    case .settings: break
    }
  }
}
