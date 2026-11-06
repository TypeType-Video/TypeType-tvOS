import SwiftUI

struct TVHomeView: View {
  @StateObject private var model: LiveShelfHomeViewModel
  let refresh: Int
  let onOpen: (LiveVideoItem) -> Void
  let onPlay: (LiveVideoItem) -> Void

  init(
    dependencies: AppDependencies,
    refresh: Int,
    onOpen: @escaping (LiveVideoItem) -> Void,
    onPlay: @escaping (LiveVideoItem) -> Void
  ) {
    self.refresh = refresh
    _model = StateObject(
      wrappedValue: LiveShelfHomeViewModel(
        loader: LiveShelfHomeLoader(
          homeFeed: dependencies.homeFeedService,
          history: dependencies.historyService,
          subscriptions: dependencies.subscriptionsService,
          search: dependencies.searchService,
          library: dependencies.libraryService
        )
      )
    )
    self.onOpen = onOpen
    self.onPlay = onPlay
  }

  var body: some View {
    Group {
      switch model.state {
      case .loading:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case let .failed(message):
        TVScreenFailure(message: message) { Task { await model.reload() } }
      case let .loaded(home):
        TVHomeLoaded(home: home, onOpen: onOpen, onPlay: onPlay)
      }
    }
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.loadIfNeeded() }
    .onChange(of: refresh) { _, _ in Task { await model.reload() } }
  }
}

private struct TVHomeLoaded: View {
  let home: LiveShelfHome
  let onOpen: (LiveVideoItem) -> Void
  let onPlay: (LiveVideoItem) -> Void
  @State private var heroIndex = 0
  @State private var focusedCard: LiveVideoItem?
  @State private var backdrop: LiveVideoItem?

  private static let rotation: Duration = .seconds(9)
  private static let backdropSettle: Duration = .milliseconds(260)

  var body: some View {
    let hero = home.featured[min(heroIndex, home.featured.count - 1)]
    ZStack(alignment: .topLeading) {
      TVBackdrop(video: backdrop ?? hero)
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 52) {
          TVHeroBlock(
            video: hero,
            index: heroIndex,
            count: home.featured.count,
            onPlay: { onPlay(hero) },
            onOpen: { onOpen(hero) },
            onFocus: { focusedCard = nil }
          )
          .padding(.top, 60)
          ForEach(home.shelves) { shelf in
            TVShelfRow(shelf: shelf, onOpen: onOpen, onFocusVideo: { focusedCard = $0 })
          }
        }
        .padding(.bottom, 112)
      }
      .scrollClipDisabled()
    }
    .task(id: focusedCard == nil) {
      guard focusedCard == nil, home.featured.count > 1 else { return }
      while (try? await Task.sleep(for: Self.rotation)) != nil {
        heroIndex = (heroIndex + 1) % home.featured.count
      }
    }
    .task(id: focusedCard?.canonicalID ?? hero.canonicalID) {
      // Only a card waits, so scrolling fast along a row does not load every backdrop on the way.
      if focusedCard != nil, (try? await Task.sleep(for: Self.backdropSettle)) == nil { return }
      backdrop = focusedCard ?? hero
    }
  }
}

struct TVBackdrop: View {
  let video: LiveVideoItem
  @AppStorage(TVDeviceSetting.backdropKey) private var shown = true

  var body: some View {
    ZStack {
      if shown {
        TVRemoteImage(url: video.thumbnail)
          .id(video.canonicalID)
          .transition(.opacity)
      }
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0.96), location: 0),
          .init(color: TVPalette.ink.opacity(0.78), location: 0.42),
          .init(color: TVPalette.ink.opacity(0.18), location: 0.78),
          .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0.55), location: 0),
          .init(color: .clear, location: 0.22),
          .init(color: TVPalette.ink.opacity(0.55), location: 0.58),
          .init(color: TVPalette.ink, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .animation(.easeOut(duration: 0.45), value: video.canonicalID)
    .ignoresSafeArea()
  }
}

struct TVScreenFailure: View {
  let message: String
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Text(verbatim: message)
        .font(TVType.body)
        .foregroundStyle(TVPalette.textMid)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 1000)
      Button("Try again", action: onRetry)
        .buttonStyle(.tvPillEmphasized)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
