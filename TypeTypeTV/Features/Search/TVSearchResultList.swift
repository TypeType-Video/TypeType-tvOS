import SwiftUI

struct TVSearchResultList: View {
  @ObservedObject var model: LiveSearchViewModel
  var entry: FocusState<String?>.Binding
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (LiveChannelResult) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  static let columns = Array(repeating: GridItem(.fixed(TVSearchTile.width), spacing: 40, alignment: .top), count: 4)

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      Text("\(model.results.count) results").textCase(.uppercase)
        .font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid)
      LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 56) {
        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
          tile(result)
            .onAppear {
              if index >= model.results.count - 8, model.canLoadMore { Task { await model.loadMore() } }
            }
        }
        if model.isLoadingMore {
          ForEach(0..<4, id: \.self) { _ in TVResultSkeleton() }
        }
      }
      .focusSection()
    }
    .padding(.bottom, 80)
  }

  @ViewBuilder
  private func tile(_ result: LiveSearchResult) -> some View {
    switch result {
    case let .video(video):
      TVSearchTile(id: result.id, entry: entry, video: video, image: video.thumbnail, artwork: .wide, title: video.title,
                   line: video.uploaderName, detail: meta(video),
                   badge: video.duration > 0 ? LiveVideoMetadataFormatter.duration(video.duration) : nil) {
        onOpen(video)
      }
    case let .channel(channel):
      TVSearchTile(id: result.id, entry: entry, image: channel.thumbnail, artwork: .round, title: channel.name,
                   line: channel.subscriberCount > 0 ? LiveVideoMetadataFormatter.subscribers(channel.subscriberCount) : "",
                   detail: "", badge: nil) {
        onOpenChannel(channel)
      }
    case let .playlist(playlist):
      TVSearchTile(id: result.id, entry: entry, image: playlist.thumbnail, artwork: .wide, title: playlist.title,
                   line: playlist.uploaderName, detail: "",
                   badge: playlist.streamCount > 0 ? String(localized: "\(playlist.streamCount) videos") : nil) {
        onOpenPlaylist(playlist)
      }
    }
  }

  private func meta(_ video: LiveVideoItem) -> String {
    [video.viewCount > 0 ? LiveVideoMetadataFormatter.views(video.viewCount) : "", LiveVideoMetadataFormatter.publication(video)]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}
