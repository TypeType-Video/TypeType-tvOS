import SwiftUI

struct TVSubscriptionsView: View {
  @StateObject private var model: LiveSubscriptionsViewModel
  @State private var selected: LiveSubscription?
  let dependencies: AppDependencies
  let onOpen: (LiveVideoItem) -> Void

  private static let columns = 3
  private static let cardWidth: CGFloat = 536

  init(dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(wrappedValue: LiveSubscriptionsViewModel(service: dependencies.subscriptionsService))
    self.dependencies = dependencies
    self.onOpen = onOpen
  }

  var body: some View {
    Group {
      if model.state == .loaded, model.channels.isEmpty {
        TVEmptyPane(systemImage: "person.3", title: "No subscriptions yet",
                    detail: "Subscribe to a channel from its page to find it here.")
      } else {
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 40) {
            TVChannelStrip(
              channels: model.channels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
              selected: $selected
            )
            if let selected {
              TVChannelFeed(url: selected.channelURL, dependencies: dependencies, onOpen: onOpen)
                .id(selected.channelURL)
            } else {
              allFeed
            }
          }
          .padding(.vertical, 40)
        }
        .scrollClipDisabled()
        .tvReportsScroll()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.prepare() }
  }

  @ViewBuilder
  private var allFeed: some View {
    if model.videos.isEmpty, model.state == .loading || model.state == .idle {
      ProgressView().frame(maxWidth: .infinity).padding(.top, 120)
    } else if case let .failed(message) = model.state, model.videos.isEmpty {
      TVScreenFailure(message: message) { Task { await model.reload() } }
    } else if model.videos.isEmpty {
      TVEmptyPane(systemImage: "play.rectangle.on.rectangle", title: "No videos yet",
                  detail: "New videos from the channels you subscribe to appear here.")
    } else {
      TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, columnCount: Self.columns,
                  cardWidth: Self.cardWidth, onOpen: onOpen) { Task { await model.loadMore() } }
    }
  }
}

private struct TVChannelFeed: View {
  @StateObject private var model: LiveChannelViewModel
  let onOpen: (LiveVideoItem) -> Void

  init(url: String, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(wrappedValue: LiveChannelViewModel(
      channelURL: url, channelService: dependencies.channelService, subscriptionsService: dependencies.subscriptionsService
    ))
    self.onOpen = onOpen
  }

  var body: some View {
    Group {
      switch model.state {
      case .idle, .loading:
        ProgressView().frame(maxWidth: .infinity).padding(.top, 120)
      case let .failed(message):
        TVScreenFailure(message: message) { Task { await model.reloadChannel() } }
      case .empty, .loaded:
        TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, columnCount: 3, cardWidth: 536,
                    onOpen: onOpen) { Task { await model.loadMore() } }
      }
    }
    .task { await model.loadIfNeeded() }
  }
}

struct TVEmptyPane: View {
  let systemImage: String
  let title: LocalizedStringKey
  let detail: LocalizedStringKey

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: systemImage).font(.system(size: 80)).foregroundStyle(TVPalette.textLow)
      Text(title).font(TVType.title).foregroundStyle(TVPalette.textHigh)
      Text(detail).font(TVType.body).foregroundStyle(TVPalette.textMid).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 200)
  }
}
