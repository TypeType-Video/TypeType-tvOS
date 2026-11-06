import SwiftUI

// Android TV's PlaylistScreen: the playlist's picture behind the page, its title, owner and size, Save, then the
// videos three a row.
struct TVPlaylistView: View {
  @StateObject private var model: LivePublicPlaylistViewModel
  @FocusState private var saveFocused: Bool
  let onOpen: (LiveVideoItem) -> Void

  init(playlist: LivePlaylistResult, dependencies: AppDependencies, onOpen: @escaping (LiveVideoItem) -> Void) {
    _model = StateObject(wrappedValue: LivePublicPlaylistViewModel(playlist: playlist, service: dependencies.playlistsService))
    self.onOpen = onOpen
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      TVBackdrop(artwork: model.playlist.thumbnail ?? model.videos.first?.thumbnail, key: model.playlist.url)
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 40) {
          header
          switch model.state {
          case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
          case let .failed(message):
            TVScreenFailure(message: message) { Task { await model.reload() } }
          case .loaded:
            TVVideoGrid(videos: model.videos, isLoadingMore: model.isLoadingMore, columnCount: 3, cardWidth: 536, onOpen: onOpen) {
              Task { await model.loadMore() }
            }
          }
        }
        .padding(.top, 40)
        .padding(.bottom, 96)
      }
      .scrollClipDisabled()
    }
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task {
      saveFocused = true
      await model.prepare()
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 40) {
      VStack(alignment: .leading, spacing: 12) {
        Text(verbatim: model.playlist.title).font(TVType.display).foregroundStyle(TVPalette.textHigh).lineLimit(2)
        Text(verbatim: meta).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
      }
      .accessibilityElement(children: .combine)
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: 12) {
        let saved = model.savedID != nil
        Button { Task { await model.toggleSaved() } } label: {
          Label(saved ? "Saved" : "Save", systemImage: saved ? "bookmark.fill" : "bookmark")
        }
        .buttonStyle(saved ? .tvPill : .tvPillEmphasized)
        .focused($saveFocused)
        if let error = model.errorMessage {
          Text(verbatim: error).font(TVType.meta).foregroundStyle(TVPalette.accent).lineLimit(2).frame(width: 480, alignment: .trailing)
        }
      }
      .fixedSize()
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
  }

  private var meta: String {
    let count = model.playlist.streamCount > 0 ? String(localized: "\(model.playlist.streamCount) videos") : ""
    return [model.playlist.uploaderName, count].filter { !$0.isEmpty }.joined(separator: " · ")
  }
}
