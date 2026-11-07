import SwiftUI

struct TVSubscriptionsView: View {
  @StateObject private var model: LiveSubscriptionsViewModel
  @State private var selected: LiveSubscription?
  let dependencies: AppDependencies
  let reset: Int
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (String) -> Void

  private static let columns = 3
  private static let cardWidth: CGFloat = 536

  init(dependencies: AppDependencies, reset: Int, onOpen: @escaping (LiveVideoItem) -> Void,
       onOpenChannel: @escaping (String) -> Void) {
    _model = StateObject(wrappedValue: LiveSubscriptionsViewModel(service: dependencies.subscriptionsService))
    self.dependencies = dependencies
    self.reset = reset
    self.onOpen = onOpen
    self.onOpenChannel = onOpenChannel
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
              TVChannelFeed(channel: selected, dependencies: dependencies, onOpen: onOpen) {
                onOpenChannel(selected.channelURL)
              }
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
    .onChange(of: reset) { _, _ in selected = nil }
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
  let name: String
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: () -> Void

  init(channel: LiveSubscription, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void,
       onOpenChannel: @escaping () -> Void) {
    _model = StateObject(wrappedValue: LiveChannelViewModel(
      channelURL: channel.channelURL, channelService: dependencies.channelService,
      subscriptionsService: dependencies.subscriptionsService
    ))
    name = channel.name
    self.onOpen = onOpen
    self.onOpenChannel = onOpenChannel
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      HStack(spacing: 32) {
        Text(verbatim: name).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(1)
        Button(action: onOpenChannel) { Label("Open channel", systemImage: "arrow.right") }
          .buttonStyle(.tvPill)
          .accessibilityHint(Text("Shows the channel page with its lives and playlists"))
      }
      .padding(.horizontal, TVDimens.safeStart)
      feed
    }
  }

  private var feed: some View {
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
