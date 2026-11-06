import SwiftUI

struct TVPlayerScreen: View {
  let video: LiveVideoItem
  @ObservedObject var playback: LivePlaybackCoordinator
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let controller = playback.controller {
        TVPlayerContent(controller: controller, playback: playback, onClose: close)
          .id(ObjectIdentifier(controller))
      }
      TVUpNextCard(playback: playback)
    }
    .onAppear { playback.open(video) }
  }

  private func close() {
    playback.controller?.flushHistory()
    playback.close()
    onClose()
  }
}

private struct TVPlayerContent: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var playback: LivePlaybackCoordinator
  let onClose: () -> Void
  @StateObject private var session: TVPlayerSession
  @FocusState private var focus: TVPlayerFocus?
  @FocusState private var relatedFocus: Bool
  @State private var panelOrigin: TVPlayerFocus?

  init(controller: LivePlayerController, playback: LivePlaybackCoordinator, onClose: @escaping () -> Void) {
    self.controller = controller
    self.playback = playback
    self.onClose = onClose
    _session = StateObject(wrappedValue: TVPlayerSession(controller: controller))
  }

  var body: some View {
    ZStack {
      TVPlayerVideoSurface(controller: controller)
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
      if let panel = session.panel { TVPlayerPanel(controller: controller, session: session, panel: panel) }
      if case let .failed(message) = controller.state { failure(message) }
    }
    .animation(.easeOut(duration: 0.2), value: session.controlsVisible)
    .onExitCommand {
      let hadPanel = session.panel != nil
      guard session.back() else { return onClose() }
      if !hadPanel { focus = restingFocus }
    }
    .onChange(of: session.controlsVisible) { _, _ in focus = restingFocus }
    // Moving between controls counts as a press: the 4.5 s before they hide starts over.
    .onChange(of: focus) { _, _ in session.touch() }
    // The Up next card takes the screen and the focus while it counts down, as on Android TV.
    .onChange(of: countdownActive) { _, active in
      guard active else { return }
      session.controlsVisible = false
      session.relatedOpen = false
      focus = nil
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
  }

  // Takes the remote while the controls are hidden: Select pauses, Left and Right scrub, Up and Down bring the controls.
  private var catcher: some View {
    Button(action: session.togglePlay) { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
      .buttonStyle(TVBareButtonStyle())
      .focused($focus, equals: .catcher)
      .disabled(session.controlsVisible || session.panel != nil || countdownActive)
      .onMoveCommand { direction in
        switch direction {
        case .left: session.scrub(direction: -1)
        case .right: session.scrub(direction: 1)
        case .down: session.showControls(fromBelow: true)
        default: session.showControls()
        }
      }
      .onPlayPauseCommand(perform: session.togglePlay)
      .accessibilityLabel(Text(verbatim: controller.video.title))
  }

  private var restingFocus: TVPlayerFocus? {
    if countdownActive { return nil }
    guard session.controlsVisible else { return .catcher }
    return session.controlsFromBelow ? .play : .seek
  }

  private var countdownActive: Bool { playback.autoplayCountdownRemaining != nil }

  private var isOpening: Bool {
    controller.position == 0 && (controller.state == .loading || controller.state == .idle)
  }

  private var related: [LiveVideoItem] {
    controller.stream?.relatedStreams.filter { !$0.isShortFormContent && !$0.isLive } ?? []
  }

  private var nextVideo: LiveVideoItem? { related.first }

  private func failure(_ message: String) -> some View {
    VStack(spacing: 32) {
      Text(verbatim: message).font(TVType.body).foregroundStyle(TVPalette.textHigh).multilineTextAlignment(.center)
        .frame(maxWidth: 1100)
      HStack(spacing: 24) {
        Button("Try again") { controller.retry() }.buttonStyle(.tvPillEmphasized)
        Button("Close", action: onClose).buttonStyle(.tvPill)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.85))
  }
}

private struct TVOpeningPoster: View {
  let video: LiveVideoItem

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      TVRemoteImage(url: video.thumbnail).opacity(0.5)
      LinearGradient(colors: [.clear, TVPalette.ink], startPoint: .center, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 20) {
        ProgressView()
        Text(verbatim: video.title).font(TVType.headline).foregroundStyle(TVPalette.textHigh).lineLimit(2)
      }
      .padding(TVDimens.safeStart)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}
