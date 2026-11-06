import SwiftUI

enum TVLibrarySection: Hashable {
  case history
  case favorites
  case watchLater
  case playlist(LivePlaylist)
}

struct TVLibraryView: View {
  @StateObject private var collections: LivePlaylistsViewModel
  @StateObject private var history: LiveHistoryViewModel
  @State private var section = TVLibrarySection.history
  @FocusState private var railFocus: TVLibrarySection?
  let dependencies: AppDependencies
  let refresh: Int
  let onOpen: (LiveVideoItem) -> Void

  init(dependencies: AppDependencies, refresh: Int, onOpen: @escaping (LiveVideoItem) -> Void) {
    _collections = StateObject(
      wrappedValue: LivePlaylistsViewModel(
        playlistsService: dependencies.playlistsService,
        libraryService: dependencies.libraryService
      )
    )
    _history = StateObject(
      wrappedValue: LiveHistoryViewModel(service: dependencies.historyService, watchProgress: dependencies.watchProgress)
    )
    self.dependencies = dependencies
    self.refresh = refresh
    self.onOpen = onOpen
  }

  var body: some View {
    HStack(alignment: .top, spacing: 72) {
      rail
      ScrollView(.vertical) {
        content
          .padding(.vertical, 24)
      }
      .scrollClipDisabled()
      // The whole column takes the focus: from a section low in the rail, Right still reaches a short grid.
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .focusSection()
    }
    .padding(.leading, TVDimens.safeStart)
    .padding(.top, 40)
    .focusSection()
    .defaultFocus($railFocus, section, priority: .userInitiated)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task {
      async let lists: Void = collections.prepare()
      async let watched: Void = history.prepare()
      _ = await (lists, watched)
    }
    .onChange(of: refresh) { _, _ in
      Task {
        async let lists: Void = collections.reload()
        async let watched: Void = history.reload()
        _ = await (lists, watched)
      }
    }
  }

  private var rail: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Library")
        .font(TVType.headline)
        .foregroundStyle(TVPalette.textHigh)
        .padding(.bottom, 16)
      railButton("History", systemImage: "clock.arrow.circlepath", section: .history)
      railButton("Favorites", systemImage: "heart", section: .favorites)
      railButton("Watch later", systemImage: "bookmark", section: .watchLater)
      ForEach(collections.playlists) { playlist in
        railButton(LocalizedStringKey(playlist.name), systemImage: "music.note.list", section: .playlist(playlist), verbatim: playlist.name)
      }
    }
    .frame(width: 440, alignment: .leading)
    .focusSection()
  }

  private func railButton(
    _ title: LocalizedStringKey,
    systemImage: String,
    section target: TVLibrarySection,
    verbatim: String? = nil
  ) -> some View {
    Button {
      section = target
    } label: {
      Label {
        if let verbatim { Text(verbatim: verbatim) } else { Text(title) }
      } icon: {
        Image(systemName: systemImage)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(section == target ? .tvPillEmphasized : .tvPill)
    .focused($railFocus, equals: target)
    .accessibilityAddTraits(section == target ? .isSelected : [])
  }

  @ViewBuilder
  private var content: some View {
    switch section {
    case .history:
      TVLibraryGrid(
        videos: history.items.map(\.video),
        progress: Dictionary(history.items.map { ($0.video.canonicalID, $0.progressFraction) }, uniquingKeysWith: { a, _ in a }),
        isLoading: history.state == .loading && history.items.isEmpty,
        failure: history.errorMessage,
        isLoadingMore: history.isLoadingMore,
        onOpen: onOpen,
        onNearEnd: { Task { await history.loadMore() } },
        onRetry: { Task { await history.reload() } }
      )
    case .favorites:
      collectionGrid(collections.favorites.map(\.video))
    case .watchLater:
      collectionGrid(collections.watchLater.map(\.video))
    case let .playlist(playlist):
      TVLibraryPlaylist(playlist: playlist, service: dependencies.playlistsService, refresh: refresh, onOpen: onOpen)
        .id(playlist.id)
    }
  }

  private func collectionGrid(_ videos: [LiveVideoItem]) -> some View {
    TVLibraryGrid(
      videos: videos,
      isLoading: collections.state == .loading && videos.isEmpty,
      failure: collections.errorMessage,
      onOpen: onOpen,
      onRetry: { Task { await collections.reload() } }
    )
  }
}
