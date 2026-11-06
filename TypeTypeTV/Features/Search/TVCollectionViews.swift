import SwiftUI

struct TVVideoGrid: View {
  let videos: [LiveVideoItem]
  let isLoadingMore: Bool
  var columnCount = 4
  var cardWidth: CGFloat = 392
  let onOpen: (LiveVideoItem) -> Void
  let onNearEnd: () -> Void

  var body: some View {
    let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: 40, alignment: .top), count: columnCount)
    LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
      ForEach(Array(videos.enumerated()), id: \.element.canonicalID) { index, video in
        TVVideoCard(video: video, width: cardWidth, onOpen: { onOpen(video) })
          .onAppear { if index >= videos.count - columnCount * 2 { onNearEnd() } }
      }
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
    if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
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
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.prepare() }
  }
}
