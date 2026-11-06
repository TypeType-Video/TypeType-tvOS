import SwiftUI

struct TVLibraryGrid: View {
  let videos: [LiveVideoItem]
  var progress: [String: Double] = [:]
  let isLoading: Bool
  let failure: String?
  var isLoadingMore = false
  let onOpen: (LiveVideoItem) -> Void
  var onNearEnd: () -> Void = {}
  let onRetry: () -> Void

  private let columns = Array(repeating: GridItem(.fixed(360), spacing: 36, alignment: .top), count: 3)

  var body: some View {
    if isLoading {
      ProgressView().frame(maxWidth: .infinity).padding(.top, 120)
    } else if let failure, videos.isEmpty {
      TVScreenFailure(message: failure, onRetry: onRetry)
    } else if videos.isEmpty {
      VStack(spacing: 16) {
        Text("Nothing here yet").font(TVType.title).foregroundStyle(TVPalette.textHigh)
        Text("Videos you save or watch show up here.").font(TVType.body).foregroundStyle(TVPalette.textMid)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 160)
    } else {
      LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
        ForEach(Array(videos.enumerated()), id: \.element.canonicalID) { index, video in
          TVVideoCard(video: video, progress: progress[video.canonicalID], width: 360, onOpen: { onOpen(video) })
            .onAppear { if index >= videos.count - 4 { onNearEnd() } }
        }
      }
      .focusSection()
      if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
    }
  }
}

struct TVLibraryPlaylist: View {
  @StateObject private var model: LivePlaylistDetailViewModel
  let refresh: Int
  let onOpen: (LiveVideoItem) -> Void

  init(playlist: LivePlaylist, service: LivePlaylistsServiceProtocol, refresh: Int, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(wrappedValue: LivePlaylistDetailViewModel(id: playlist.id, seed: playlist, service: service))
    self.refresh = refresh
    self.onOpen = onOpen
  }

  var body: some View {
    TVLibraryGrid(
      videos: model.videos.map(\.video),
      isLoading: model.state == .loading && model.videos.isEmpty,
      failure: model.errorMessage,
      onOpen: onOpen,
      onRetry: { Task { await model.reload() } }
    )
    .task { await model.prepare() }
    .onChange(of: refresh) { _, _ in Task { await model.reload() } }
  }
}
