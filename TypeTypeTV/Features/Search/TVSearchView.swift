import SwiftUI

struct TVSearchView: View {
  @StateObject private var model: LiveSearchViewModel
  @FocusState private var barFocused: Bool
  @FocusState private var entry: String?
  @Environment(\.tvContentFocusRequest) private var focusRequest
  @State private var focusResults = false
  @State private var startedOnService = false
  @EnvironmentObject private var account: TVAccountSettings
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
        imagePipeline: dependencies.imagePipeline,
        settingsService: dependencies.settingsService
      )
    )
    self.onOpen = onOpen
    self.onOpenChannel = onOpenChannel
    self.onOpenPlaylist = onOpenPlaylist
  }

  var body: some View {
    ScrollView(.vertical) { screen }
      .scrollClipDisabled()
      .tvContentEdges()
      .background(TVPalette.ink.ignoresSafeArea())
      .defaultFocus($barFocused, true, priority: .userInitiated)
      .onChange(of: focusRequest) { _, _ in barFocused = true }
      .task(id: model.query) { await search() }
      .onChange(of: model.state) { _, state in
        guard focusResults, state == .loaded else { return }
        focusResults = false
        Task { entry = model.results.first?.id }
      }
      .task {
        await model.prepare()
        await startOnDefaultService()
      }
  }

  private func startOnDefaultService() async {
    guard !startedOnService, let service = account.settings?.defaultService else { return }
    startedOnService = true
    if service != model.selectedServiceID, model.services.contains(where: { $0.id == service }) {
      await model.selectService(service)
    }
  }

  private var screen: some View {
    VStack(alignment: .leading, spacing: 24) {
      TVSearchScope(model: model)
      TVSearchField(query: $model.query, recent: model.history.map(\.term), focus: $barFocused)
      panel
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 580, alignment: .topLeading)
        .focusSection()
    }
    .focusSection()
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
      TVSearchMessage(title: "What do you want to watch?", detail: "Select the search bar to type or dictate, or pick a recent search.") {
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
