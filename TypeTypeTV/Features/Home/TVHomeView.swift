import SwiftUI

struct TVHomeView: View {
  @StateObject private var model: LiveShelfHomeViewModel
  @StateObject private var preview: LivePreviewPlayer
  let refresh: Int
  let previewsAllowed: Bool
  private let deArrow: LiveDeArrowStore
  private let hidden: LiveHiddenVideos
  let onOpen: (LiveVideoItem) -> Void
  let onPlay: (LiveVideoItem) -> Void

  init(
    dependencies: AppDependencies,
    refresh: Int,
    previewsAllowed: Bool,
    onOpen: @escaping (LiveVideoItem) -> Void,
    onPlay: @escaping (LiveVideoItem) -> Void
  ) {
    self.refresh = refresh
    self.previewsAllowed = previewsAllowed
    _preview = StateObject(wrappedValue: LivePreviewPlayer(service: dependencies.playbackService))
    _model = StateObject(
      wrappedValue: LiveShelfHomeViewModel(
        loader: LiveShelfHomeLoader(
          homeFeed: dependencies.homeFeedService,
          history: dependencies.historyService,
          subscriptions: dependencies.subscriptionsService,
          search: dependencies.searchService,
          library: dependencies.libraryService,
          notifications: dependencies.notificationsService,
          settings: dependencies.settingsService,
          deArrow: dependencies.deArrowStore,
          contentControls: dependencies.contentControlsService
        )
      )
    )
    deArrow = dependencies.deArrowStore
    hidden = dependencies.hiddenVideos
    self.onOpen = onOpen
    self.onPlay = onPlay
  }

  var body: some View {
    Group {
      switch model.state {
      case .loading:
        TVHomeSkeleton()
      case let .failed(message):
        TVScreenFailure(message: message) { Task { await model.reload() } }
      case let .loaded(home):
        TVHomeLoaded(home: home, hidden: hidden, preview: preview, previewsAllowed: previewsAllowed, onOpen: onOpen, onPlay: onPlay)
      }
    }
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.loadIfNeeded() }
    .onChange(of: refresh) { _, _ in Task { await model.reload() } }
    .onReceive(NotificationCenter.default.publisher(for: .liveSettingsDidChange)) { _ in
      deArrow.invalidatePreferences()
      Task { await model.reload() }
    }
  }
}

private struct TVHomeLoaded: View {
  let home: LiveShelfHome
  @ObservedObject var hidden: LiveHiddenVideos
  @ObservedObject var preview: LivePreviewPlayer
  let previewsAllowed: Bool
  @AppStorage(TVDeviceSetting.videoPreviewsKey) private var previewsOn = true
  let onOpen: (LiveVideoItem) -> Void
  let onPlay: (LiveVideoItem) -> Void
  @State private var heroIndex = 0
  @State private var focusedCard: LiveVideoItem?
  @State private var backdrop: LiveVideoItem?

  private static let rotation: Duration = .seconds(9)

  private var visibleShelves: [LiveHomeShelf] {
    home.shelves.compactMap { shelf in
      let videos = hidden.visible(shelf.videos)
      return videos.isEmpty ? nil : LiveHomeShelf(id: shelf.id, title: shelf.title, videos: videos, progress: shelf.progress)
    }
  }
  private static let backdropSettle: Duration = .milliseconds(260)
  private static let previewDelay: Duration = .seconds(2)

  var body: some View {
    let hero = home.featured[min(heroIndex, home.featured.count - 1)]
    ZStack(alignment: .topLeading) {
      TVBackdrop(video: backdrop ?? hero, preview: preview.playback, previewShowing: preview.showsFrames)
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
          ForEach(visibleShelves) { shelf in
            TVShelfRow(shelf: shelf, onOpen: onOpen, onFocusVideo: { focusedCard = $0 })
          }
        }
        .padding(.bottom, 112)
      }
      .scrollClipDisabled()
      .tvReportsScroll()
    }
    .task(id: focusedCard == nil && !preview.showsFrames) {
      guard focusedCard == nil, !preview.showsFrames, home.featured.count > 1 else { return }
      while (try? await Task.sleep(for: Self.rotation)) != nil {
        heroIndex = (heroIndex + 1) % home.featured.count
      }
    }
    .task(id: focusedCard?.canonicalID ?? hero.canonicalID) {
      if focusedCard != nil, (try? await Task.sleep(for: Self.backdropSettle)) == nil { return }
      backdrop = focusedCard ?? hero
    }
    .environment(\.tvHomePreviews, previewsAllowed && previewsOn)
    .task(id: PreviewKey(video: (backdrop ?? hero).canonicalID, allowed: previewsAllowed && previewsOn)) {
      preview.stop()
      guard previewsAllowed, previewsOn, (try? await Task.sleep(for: Self.previewDelay)) != nil else { return }
      preview.show(backdrop ?? hero)
    }
    .onDisappear { preview.stop() }
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

private struct PreviewKey: Hashable {
  let video: String
  let allowed: Bool
}
