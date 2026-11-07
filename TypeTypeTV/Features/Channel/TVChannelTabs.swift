import SwiftUI

enum TVChannelFocus: Hashable {
  case tab(LiveChannelTab)
  case search
  case more
}

struct TVChannelTabs: View {
  @ObservedObject var model: LiveChannelViewModel
  let tabs: [LiveChannelTab]
  let isYouTube: Bool
  var focus: FocusState<TVChannelFocus?>.Binding
  let onSearch: () -> Void

  var body: some View {
    HStack(spacing: 20) {
      if tabs.count > 1 {
        ForEach(tabs) { tab in
          let open = model.selectedTab == tab
          Button { Task { await model.selectTab(tab) } } label: {
            Label(Self.title(tab), systemImage: Self.icon(tab))
          }
          .buttonStyle(.tvPill)
          .focused(focus, equals: .tab(tab))
          .overlay(alignment: .bottom) {
            Capsule().fill(open ? TVPalette.accent : .clear).frame(width: 48, height: 6).offset(y: 18)
          }
          .accessibilityAddTraits(open ? .isSelected : [])
        }
      }
      if model.selectedTab == .videos, model.submittedQuery.isEmpty, isYouTube {
        Button { Task { await model.selectSort(Self.next(model.sort)) } } label: {
          Label(Self.title(model.sort), systemImage: Self.icon(model.sort))
        }
        .buttonStyle(.tvPill)
        .accessibilityLabel(Text("Sort: \(Self.title(model.sort))"))
        .padding(.leading, 28)
      }
      if isYouTube, model.selectedTab == .videos {
        let query = model.submittedQuery
        Button(action: onSearch) {
          Label(query.isEmpty ? String(localized: "Search") : "“\(query)”", systemImage: "magnifyingglass").lineLimit(1)
        }
        .buttonStyle(query.isEmpty ? .tvPill : .tvPillEmphasized)
        .focused(focus, equals: .search)
        .accessibilityLabel(query.isEmpty ? Text("Search") : Text("Searching for \(query). OK changes the search."))
        .padding(.leading, 28)
        if !query.isEmpty {
          TVCircleButton(systemImage: "xmark", label: "Clear the search") { Task { await model.search("") } }
        }
      }
    }
    .padding(.horizontal, TVDimens.safeStart)
    .padding(.vertical, 24)
    .focusSection()
  }

  static func title(_ tab: LiveChannelTab) -> String {
    switch tab {
    case .videos: String(localized: "Videos")
    case .live: String(localized: "Live")
    case .playlists: String(localized: "Playlists")
    case .about: String(localized: "About")
    }
  }

  private static func icon(_ tab: LiveChannelTab) -> String {
    switch tab {
    case .videos: "play.rectangle.on.rectangle"
    case .live: "dot.radiowaves.left.and.right"
    case .playlists: "list.bullet.rectangle"
    case .about: "info.circle"
    }
  }

  private static func next(_ sort: LiveChannelSort) -> LiveChannelSort {
    let all = LiveChannelSort.allCases
    guard let index = all.firstIndex(of: sort) else { return .latest }
    return all[(index + 1) % all.count]
  }

  static func title(_ sort: LiveChannelSort) -> String {
    switch sort {
    case .latest: String(localized: "Newest")
    case .popular: String(localized: "Popular")
    case .oldest: String(localized: "Oldest")
    }
  }

  private static func icon(_ sort: LiveChannelSort) -> String {
    switch sort {
    case .latest: "sparkles"
    case .popular: "flame"
    case .oldest: "clock.arrow.circlepath"
    }
  }
}
