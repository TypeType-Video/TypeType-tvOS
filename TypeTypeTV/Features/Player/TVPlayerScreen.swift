import SwiftUI

struct TVPlayerScreen: View {
  let video: LiveVideoItem
  @ObservedObject var playback: LivePlaybackCoordinator
  let dependencies: AppDependencies
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let controller = playback.controller {
        TVPlayerContent(controller: controller, playback: playback, dependencies: dependencies, onClose: close)
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
  @StateObject var session: TVPlayerSession
  @StateObject var actions: LiveVideoQuickActionsViewModel
  @StateObject var engagement: LiveVideoEngagementViewModel
  @StateObject var comments: LiveCommentsViewModel
  @StateObject var threads: LiveCommentThreads
  @FocusState var focus: TVPlayerFocus?
  @FocusState var relatedFocus: Bool
  @State var panelOrigin: TVPlayerFocus?

  init(
    controller: LivePlayerController, playback: LivePlaybackCoordinator, dependencies: AppDependencies,
    onClose: @escaping () -> Void
  ) {
    self.controller = controller
    self.playback = playback
    self.onClose = onClose
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
      TVPlayerVideoSurface(controller: controller)
      if controller.supportsBulletComments, controller.bulletCommentsEnabled {
        LiveDanmakuOverlay(controller: controller).allowsHitTesting(false).ignoresSafeArea()
      }
      if controller.audioOnly { TVAudioOnlyPoster(video: controller.video).transition(.opacity) }
      TVCaptionOverlay(controller: controller, subtitles: controller.nativeSubtitles, raised: session.controlsVisible)
      if isOpening { TVOpeningPoster(video: controller.video) }
      catcher
      if session.controlsVisible, session.panel == nil {
        VStack(spacing: 0) {
          TVPlayerControls(controller: controller, session: session, focus: $focus, onNext: nextVideo.map { next in { playback.open(next) } })
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
      if let panel = session.panel {
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
    .onExitCommand {
      if upNextVideo != nil { return session.upNextDismissed = true }
      let hadPanel = session.panel != nil
      guard session.back() else { return onClose() }
      if !hadPanel { focus = restingFocus }
    }
    .onChange(of: session.controlsVisible) { _, _ in focus = restingFocus }
    // Moving between controls counts as a press: the 4.5 s before they hide starts over.
    .onChange(of: focus) { _, _ in session.touch() }
    // Android opens the next video as soon as this one ends; Back on the Up next card stops that.
    .onChange(of: countdownActive) { _, active in
      guard active else { return }
      if session.upNextDismissed || hidesRelated { playback.cancelAutoplayCountdown() } else { playback.playUpcomingNow() }
    }
    .onChange(of: session.relatedOpen) { _, open in
      if open { Task { relatedFocus = true } }
    }
    // A closed panel gives the focus back to the control that opened it, as on Android TV.
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
