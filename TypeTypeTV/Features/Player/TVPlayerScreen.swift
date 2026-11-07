import SwiftUI

struct TVPlayerScreen: View {
  let video: LiveVideoItem
  @ObservedObject var playback: LivePlaybackCoordinator
  let dependencies: AppDependencies
  var onOpenChannel: (String) -> Void = { _ in }
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let controller = playback.controller {
        TVPlayerContent(controller: controller, playback: playback, dependencies: dependencies, onClose: close) { url in
          close()
          onOpenChannel(url)
        }
          .id(ObjectIdentifier(controller))
      }
    }
    .onAppear { playback.open(video) }
  }

  private func close() {
    playback.controller?.flushHistory()
    playback.close()
    onClose()
  }
}

struct TVPlayerContent: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var playback: LivePlaybackCoordinator
  let onClose: () -> Void
  let onOpenChannel: (String) -> Void
  let channelService: LiveChannelServiceProtocol
  @StateObject var session: TVPlayerSession
  @StateObject var actions: LiveVideoQuickActionsViewModel
  @StateObject var engagement: LiveVideoEngagementViewModel
  @StateObject var comments: LiveCommentsViewModel
  @StateObject var threads: LiveCommentThreads
  @StateObject var chat: TVLiveChatModel
  let hasChatService: Bool
  @FocusState var focus: TVPlayerFocus?
  @FocusState var relatedFocus: Bool
  @State var panelOrigin: TVPlayerFocus?
  @State var chatMayConnect = false

  init(
    controller: LivePlayerController, playback: LivePlaybackCoordinator, dependencies: AppDependencies,
    onClose: @escaping () -> Void, onOpenChannel: @escaping (String) -> Void
  ) {
    self.controller = controller
    self.playback = playback
    self.onClose = onClose
    hasChatService = dependencies.liveChatService != nil
    _chat = StateObject(wrappedValue: TVLiveChatModel(videoURL: controller.video.url, service: dependencies.liveChatService))
    self.onOpenChannel = onOpenChannel
    channelService = dependencies.channelService
    _session = StateObject(wrappedValue: TVPlayerSession(controller: controller))
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: controller.video, dependencies: dependencies))
    _engagement = StateObject(wrappedValue: LiveVideoEngagementViewModel(
      video: controller.video, allowsSubscription: true, service: dependencies.subscriptionsService
    ))
    _comments = StateObject(wrappedValue: LiveCommentsViewModel(
      videoURL: controller.video.url, commentsService: dependencies.commentsService,
      settingsService: dependencies.settingsService
    ))
    _threads = StateObject(wrappedValue: LiveCommentThreads(videoURL: controller.video.url, service: dependencies.commentsService))
  }

  var body: some View {
    ZStack {
      picture
      if chatVisible {
        TVLiveChatPanel(model: chat, underControls: session.controlsVisible && session.panel == nil, connects: chatMayConnect)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      if isOpening { TVOpeningPoster(video: controller.video).padding(.trailing, chatInset) }
      catcher
      if session.controlsVisible, session.panel == nil {
        VStack(spacing: 0) {
          TVPlayerControls(controller: controller, session: session, focus: $focus, onNext: nextVideo.map { next in { playback.open(next) } }, chatAvailable: chatAvailable)
            .onMoveCommand { if $0 == .down, !session.relatedOpen, !related.isEmpty { session.relatedOpen = true } }
          if session.relatedOpen {
            TVShelfRow(
              shelf: LiveHomeShelf(id: "more", title: String(localized: "MORE VIDEOS"), videos: related),
              onOpen: { playback.open($0) },
              firstCardFocus: $relatedFocus
            )
            .padding(.bottom, 40)
          }
        }
        .transition(.opacity)
      }
      if !session.controlsVisible, session.panel == nil, !countdownActive { TVSponsorNotice(controller: controller) }
      if let next = upNextVideo { TVUpNextCard(next: next, fill: upNextFill, secondsLeft: upNextSecondsLeft) }
      if session.panel == .channel {
        TVPlayerChannelPanel(video: controller.video, service: channelService, engagement: engagement) {
          onOpenChannel(controller.video.uploaderURL)
        }
      } else if let panel = session.panel {
        TVPlayerPanel(
          controller: controller, session: session, actions: actions, engagement: engagement,
          comments: comments, threads: threads, panel: panel, queue: related, onOpen: { playback.open($0) }
        )
      }
      if case let .failed(message) = controller.state {
        TVPlayerFailure(message: message, onRetry: controller.retry, onClose: onClose)
      }
    }
    .animation(.easeOut(duration: 0.2), value: session.controlsVisible)
    .animation(.easeOut(duration: 0.2), value: chatVisible)
    .background(TVHeldArrows(enabled: session.panel == nil && !session.isLive && (focus == .catcher || focus == .seek)) {
      session.scrub(direction: $0)
    })
    .task(id: controller.state == .playing) {
      guard controller.state == .playing, !chatMayConnect else { return }
      guard (try? await Task.sleep(for: .seconds(5))) != nil else { return }
      chatMayConnect = true
    }
    .onExitCommand {
      if upNextVideo != nil { return session.upNextDismissed = true }
      let hadPanel = session.panel != nil
      guard session.back() else { return onClose() }
      if !hadPanel { focus = restingFocus }
    }
    .onChange(of: session.controlsVisible) { _, _ in focus = restingFocus }
    .onChange(of: focus) { _, _ in session.touch() }
    .onChange(of: countdownActive) { _, active in
      guard active else { return }
      if session.upNextDismissed || hidesRelated { playback.cancelAutoplayCountdown() } else { playback.playUpcomingNow() }
    }
    .onChange(of: session.relatedOpen) { _, open in
      if open { Task { relatedFocus = true } }
    }
    .onChange(of: session.panel) { old, new in
      if old == nil, new != nil { panelOrigin = focus }
      if old != nil, new == nil { Task { focus = panelOrigin ?? .seek } }
    }
    .onAppear {
      focus = .seek
      session.touch()
    }
    .task {
      async let state: Void = actions.prepare()
      async let subscription: Void = engagement.prepare()
      _ = await (state, subscription)
    }
  }
}
