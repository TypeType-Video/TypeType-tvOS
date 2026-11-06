import SwiftUI

// Android TV's SearchScreen: the drawn keyboard on the left and the results beside it, filled while typing.
// The system keyboard cannot sit beside a list on tvOS; it stays one key away for dictation.
struct TVSearchView: View {
  @StateObject private var model: LiveSearchViewModel
  @FocusState private var firstKey: Bool
  @FocusState private var entry: String?
  @State private var focusResults = false
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (LiveChannelResult) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  private static let debounce: Duration = .milliseconds(180)

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

  // The vertical scroll view lets Up from the top row reach the tab bar, as on the other tabs.
  var body: some View {
    ScrollView(.vertical) { screen }
      .scrollClipDisabled()
      .tvContentEdges()
      .background(TVPalette.ink.ignoresSafeArea())
      .defaultFocus($firstKey, true)
      // The model searches again by itself when the service or the kind changes; only the typing is followed here.
      .task(id: model.query) { await search() }
      .onChange(of: model.state) { _, state in
        guard focusResults, state == .loaded else { return }
        focusResults = false
        Task { entry = model.results.first?.id }
      }
      .task { await model.prepare() }
  }

  private var screen: some View {
    VStack(alignment: .leading, spacing: 8) {
      TVSearchScope(model: model)
      HStack(alignment: .top, spacing: 88) {
        VStack(spacing: 24) {
          TVQueryField(query: model.query, recent: model.history.map(\.term))
          TVSearchKeyboard(query: $model.query, firstKey: $firstKey)
        }
        .frame(width: 960)
        .focusSection()
        panel
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .focusSection()
      }
      // The outer scroll view proposes no height; the result list scrolls inside this fixed one.
      .frame(height: 790)
    }
    .padding(.horizontal, TVDimens.safeStart)
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func search() async {
    let term = model.query.trimmingCharacters(in: .whitespaces)
    guard !term.isEmpty else { return model.resetResults() }
    guard term != model.submittedQuery else { return }
    guard (try? await Task.sleep(for: Self.debounce)) != nil else { return }
    await model.submit(term, recordsHistory: false, keepsQuery: true)
  }

  @ViewBuilder
  private var panel: some View {
    switch model.state {
    case .idle:
      TVSearchMessage(title: "What do you want to watch?", detail: "Type with the keyboard or pick a recent search.") {
        if !model.history.isEmpty { recentSearches }
      }
    case .loading:
      VStack(spacing: 20) { ForEach(0..<4, id: \.self) { _ in TVResultSkeleton() } }.padding(.top, 56)
    case .empty:
      TVSearchMessage(title: "Nothing found", detail: "Try a shorter word, or search by genre or channel.") {}
    case let .failed(message):
      TVScreenFailure(message: message) { Task { await model.submit(model.query, recordsHistory: false, keepsQuery: true) } }
    case .loaded:
      TVSearchResultList(model: model, entry: $entry, onOpen: openResult, onOpenChannel: onOpenChannel,
                         onOpenPlaylist: onOpenPlaylist)
    }
  }

  // Searches run while typing and skip the history; opening a result is what makes the term a recent search.
  private func openResult(_ video: LiveVideoItem) {
    let term = model.submittedQuery
    Task { await model.record(term) }
    onOpen(video)
  }

  private var recentSearches: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("RECENT SEARCHES").font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid)
      TVFlowLayout(spacing: 20) {
        ForEach(model.history.prefix(8)) { item in
          Button {
            focusResults = true
            model.query = item.term
          } label: {
            Label(item.term, systemImage: "clock.arrow.circlepath")
          }
          .buttonStyle(.tvPill)
        }
      }
      .frame(width: 700, alignment: .leading)
    }
  }
}

private struct TVSearchMessage<Content: View>: View {
  let title: LocalizedStringKey
  let detail: LocalizedStringKey
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "magnifyingglass").font(.system(size: 40, weight: .semibold)).foregroundStyle(TVPalette.textHigh)
        .frame(width: 112, height: 112).background(TVPalette.glass, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      Text(title).font(TVType.headline).foregroundStyle(TVPalette.textHigh).padding(.top, 20)
      Text(detail).font(TVType.body).foregroundStyle(TVPalette.textMid)
      content().padding(.top, 28)
    }
    .frame(width: 700, alignment: .leading)
  }
}

// Lays the pills out in lines, wrapping when a line is full.
struct TVFlowLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    return place(subviews, width: width).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (index, point) in place(subviews, width: bounds.width).points.enumerated() {
      subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
    }
  }

  private func place(_ subviews: Subviews, width: CGFloat) -> (points: [CGPoint], size: CGSize) {
    var points: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var widest: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += lineHeight + spacing
        lineHeight = 0
      }
      points.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
      widest = max(widest, x - spacing)
    }
    return (points, CGSize(width: widest, height: y + lineHeight))
  }
}
