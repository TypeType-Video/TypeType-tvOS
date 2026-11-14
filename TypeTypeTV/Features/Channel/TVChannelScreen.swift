import SwiftUI

struct TVChannelScreen: View {
  @StateObject private var model: LiveChannelViewModel
  @State private var searching = false
  @State private var menuOpen = false
  @State private var bannerScroll = TVBannerScroll()
  @FocusState private var focus: TVChannelFocus?
  @Environment(\.tvContentFocusRequest) private var focusRequest
  let contentControls: LiveContentControlsServiceProtocol
  let onOpen: (LiveVideoItem) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  init(
    url: String, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void,
    onOpenPlaylist: @escaping (LivePlaylistResult) -> Void
  ) {
    _model = StateObject(wrappedValue: LiveChannelViewModel(
      channelURL: url, channelService: dependencies.channelService, subscriptionsService: dependencies.subscriptionsService
    ))
    contentControls = dependencies.contentControlsService
    self.onOpen = onOpen
    self.onOpenPlaylist = onOpenPlaylist
  }

  var body: some View {
    ZStack {
      TVChannelBanner(url: model.channel?.banner, scroll: bannerScroll)
        .frame(maxHeight: .infinity, alignment: .top)
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 0) {
          Color.clear.frame(height: TVChannelBanner.height)
          if let page = model.channel {
            TVChannelHeader(model: model, page: page, focus: $focus) { menuOpen = true }
              .padding(.top, -260)
            if !model.podcasts.isEmpty { podcasts.padding(.top, 48) }
            TVChannelTabs(model: model, tabs: tabs, isYouTube: isYouTube, focus: $focus) { searching = true }
              .padding(.top, 32)
          }
          content.padding(.top, 16)
        }
        .padding(.bottom, 96)
      }
      .scrollClipDisabled()
      .tvReportsScroll()
      .tvFadesBanner(bannerScroll)
      .disabled(searching || menuOpen)
      if searching, let page = model.channel {
        TVChannelSearchPanel(channelName: page.name, initial: model.submittedQuery,
                             onSearch: { term in Task { await model.search(term) } }) { close(.search) }
      }
      if menuOpen, let page = model.channel {
        TVChannelMoreMenu(
          channel: LiveContentControlItem(url: model.channelURL, name: page.name, thumbnailURL: page.avatarURL),
          service: contentControls
        ) { close(.more) }
      }
    }
    .ignoresSafeArea(edges: .top)
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task {
      let opening = model.channel == nil
      await model.loadIfNeeded()
      if opening, tabs.count > 1 { focus = .tab(model.selectedTab) }
    }
    .onChange(of: focusRequest) { _, _ in focus = tabs.count > 1 ? .tab(model.selectedTab) : .more }
  }

  private func close(_ origin: TVChannelFocus) {
    searching = false
    menuOpen = false
    Task { focus = model.submittedQuery.isEmpty || origin == .more ? origin : .search }
  }

  private var isYouTube: Bool { LiveChannelRequestURLBuilder.isYouTube(model.channelURL) }

  private var tabs: [LiveChannelTab] {
    guard isYouTube else { return [.videos] }
    return [.videos, .live, .posts, .playlists] + (model.channel?.hasCourses == true ? [.courses] : [])
  }

  @ViewBuilder
  private var content: some View {
    if model.selectedTab == .posts {
      TVChannelPosts(channelURL: model.channelURL, service: model.channelService) { link in
        guard case let .video(video)? = URL(string: link).flatMap({ LiveMediaLinkResolver.destination(for: $0) }) else { return }
        onOpen(video)
      }
    } else {
      channelContent
    }
  }

  @ViewBuilder
  private var channelContent: some View {
    switch model.state {
    case .idle, .loading:
      ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
    case let .failed(message):
      TVScreenFailure(message: message) { Task { await model.reloadChannel() } }
    case .empty where !model.selectedTab.listsPlaylists:
      empty
    case .empty, .loaded:
      if model.selectedTab.listsPlaylists {
        if model.playlists.isEmpty { empty } else { playlistGrid }
      } else {
        TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, columnCount: 3, cardWidth: 536, onOpen: onOpen) {
          Task { await model.loadMore() }
        }
      }
    }
  }

  private var empty: some View {
    Group {
      if model.submittedQuery.isEmpty {
        Text("Nothing to show here yet.")
      } else {
        Text("No video of this channel matches “\(model.submittedQuery)”.")
      }
    }
    .font(TVType.body).foregroundStyle(TVPalette.textMid)
    .padding(.horizontal, TVDimens.safeStart).padding(.vertical, 80)
  }

  private var playlistGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(536), spacing: 40, alignment: .top), count: 3), alignment: .leading, spacing: 56) {
      ForEach(Array(model.playlists.enumerated()), id: \.element.canonicalID) { index, playlist in
        TVCollectionCard(title: playlist.title, line: playlist.uploaderName, image: playlist.thumbnail, count: playlist.streamCount) {
          onOpenPlaylist(playlist)
        }
        .onAppear { if index >= model.playlists.count - 6 { Task { await model.loadMore() } } }
      }
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
  }

  private var podcasts: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("PODCASTS").font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid).padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40) {
          ForEach(model.podcasts) { podcast in
            TVCollectionCard(title: podcast.title, line: podcast.uploaderName,
                             image: URL(string: podcast.thumbnailURL), count: podcast.streamCount) {
              onOpenPlaylist(LivePlaylistResult(
                id: podcast.id, title: podcast.title, url: podcast.url, thumbnailURL: podcast.thumbnailURL,
                uploaderName: podcast.uploaderName, streamCount: podcast.streamCount, playlistType: podcast.playlistType
              ))
            }
          }
        }
        .padding(.horizontal, TVDimens.safeStart)
        .padding(.vertical, 20)
      }
      .scrollClipDisabled()
    }
    .focusSection()
  }
}
