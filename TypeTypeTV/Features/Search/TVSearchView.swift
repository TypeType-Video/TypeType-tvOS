import SwiftUI

struct TVSearchView: View {
  @StateObject private var model: LiveSearchViewModel
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (LiveChannelResult) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  init(
    dependencies: AppDependencies,
    onOpen: @escaping (LiveVideoItem) -> Void,
    onOpenChannel: @escaping (LiveChannelResult) -> Void,
    onOpenPlaylist: @escaping (LivePlaylistResult) -> Void
  ) {
    _model = StateObject(
      wrappedValue: LiveSearchViewModel(
        searchService: dependencies.searchService,
        historyService: dependencies.searchHistoryService,
        serviceSelection: dependencies.serviceSelection,
        imagePipeline: dependencies.imagePipeline
      )
    )
    self.onOpen = onOpen
    self.onOpenChannel = onOpenChannel
    self.onOpenPlaylist = onOpenPlaylist
  }

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 48) {
        if model.services.count > 1 { servicePicker }
        content
      }
      .padding(.bottom, 112)
    }
    .scrollClipDisabled()
    .background(TVPalette.ink.ignoresSafeArea())
    .searchable(text: $model.query, prompt: Text("Type anything"))
    .searchSuggestions {
      ForEach(model.suggestions, id: \.self) { suggestion in
        Text(verbatim: suggestion).searchCompletion(suggestion)
      }
    }
    .onChange(of: model.query) { _, _ in model.queryDidChange() }
    .onSubmit(of: .search) { Task { await model.submit() } }
    .task(id: model.query) {
      // The TV keyboard has no search key: results follow the typing, and only a pause starts a search.
      let term = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !term.isEmpty, term != model.submittedQuery,
        (try? await Task.sleep(for: .milliseconds(600))) != nil
      else { return }
      await model.submit(recordsHistory: false)
    }
    .task { await model.prepare() }
  }

  private var servicePicker: some View {
    HStack(spacing: 20) {
      ForEach(model.services, id: \.id) { service in
        Button(service.name) {
          Task { await model.selectService(service.id) }
        }
        .buttonStyle(service.id == model.selectedServiceID ? .tvPillEmphasized : .tvPill)
        .accessibilityAddTraits(service.id == model.selectedServiceID ? .isSelected : [])
      }
    }
    .padding(.leading, TVDimens.safeStart)
    .focusSection()
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .idle:
      TVSearchMessage(title: "What do you want to watch?", detail: "Search videos, channels and playlists.")
    case .loading:
      ProgressView().frame(maxWidth: .infinity).padding(.top, 120)
    case .empty:
      TVSearchMessage(title: "Nothing found", detail: "Try a shorter word, or search by genre or channel.")
    case let .failed(message):
      TVScreenFailure(message: message) { Task { await model.submit() } }
    case .loaded:
      TVSearchResults(model: model, onOpen: onOpen, onOpenChannel: onOpenChannel, onOpenPlaylist: onOpenPlaylist)
    }
  }
}

private struct TVSearchMessage: View {
  let title: LocalizedStringKey
  let detail: LocalizedStringKey

  var body: some View {
    VStack(spacing: 16) {
      Text(title).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
      Text(detail).font(TVType.body).foregroundStyle(TVPalette.textMid)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 160)
  }
}
