import SwiftUI

struct TVVideoGrid: View {
  let videos: [LiveVideoItem]
  let isLoadingMore: Bool
  let onOpen: (LiveVideoItem) -> Void
  let onNearEnd: () -> Void

  private let columns = Array(repeating: GridItem(.fixed(392), spacing: 40, alignment: .top), count: 4)

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
      ForEach(Array(videos.enumerated()), id: \.element.canonicalID) { index, video in
        TVVideoCard(video: video, onOpen: { onOpen(video) })
          .onAppear { if index >= videos.count - 4 { onNearEnd() } }
      }
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
    if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
  }
}

struct TVChannelView: View {
  @StateObject private var model: LiveChannelViewModel
  let onOpen: (LiveVideoItem) -> Void

  init(url: String, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(
      wrappedValue: LiveChannelViewModel(
        channelURL: url,
        channelService: dependencies.channelService,
        subscriptionsService: dependencies.subscriptionsService
      )
    )
    self.onOpen = onOpen
  }

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 48) {
        if let channel = model.channel {
          HStack(spacing: 32) {
            TVRemoteImage(url: channel.avatar).frame(width: 140, height: 140).clipShape(Circle())
            VStack(alignment: .leading, spacing: 8) {
              Text(verbatim: channel.name).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
              if channel.subscriberCount > 0 {
                Text(verbatim: LiveVideoMetadataFormatter.subscribers(channel.subscriberCount))
                  .font(TVType.meta)
                  .foregroundStyle(TVPalette.textMid)
              }
            }
          }
          .padding(.leading, TVDimens.safeStart)
          .accessibilityElement(children: .combine)
        }
        switch model.state {
        case .idle, .loading:
          ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
        case let .failed(message):
          TVScreenFailure(message: message) { Task { await model.reloadChannel() } }
        case .empty, .loaded:
          TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, onOpen: onOpen) {
            Task { await model.loadMore() }
          }
        }
      }
      .padding(.vertical, 60)
    }
    .scrollClipDisabled()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.loadIfNeeded() }
  }
}

struct TVPlaylistView: View {
  @StateObject private var model: LivePublicPlaylistViewModel
  let onOpen: (LiveVideoItem) -> Void

  init(playlist: LivePlaylistResult, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(wrappedValue: LivePublicPlaylistViewModel(playlist: playlist, service: dependencies.playlistsService))
    self.onOpen = onOpen
  }

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 48) {
        VStack(alignment: .leading, spacing: 8) {
          Text(verbatim: model.playlist.title).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
          Text(verbatim: model.playlist.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
        .padding(.leading, TVDimens.safeStart)
        .accessibilityElement(children: .combine)
        switch model.state {
        case .idle, .loading:
          ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
        case let .failed(message):
          TVScreenFailure(message: message) { Task { await model.reload() } }
        case .loaded:
          TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, onOpen: onOpen) {
            Task { await model.loadMore() }
          }
        }
      }
      .padding(.vertical, 60)
    }
    .scrollClipDisabled()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.prepare() }
  }
}
