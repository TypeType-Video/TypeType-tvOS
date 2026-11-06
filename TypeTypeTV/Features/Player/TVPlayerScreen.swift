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
            TVShelfRow(shelf: LiveHomeShelf(id: "more", title: String(localized: "MORE VIDEOS"), videos: related)) { playback.open($0) }
              .padding(.bottom, 40)
          }
        }
        .transition(.opacity)
      }
      if let panel = session.panel { TVPlayerPanel(controller: controller, session: session, panel: panel) }
      if case let .failed(message) = controller.state { failure(message) }
    }
    .animation(.easeOut(duration: 0.2), value: session.controlsVisible)
    .onExitCommand { if !session.back() { onClose() } }
    .onChange(of: session.controlsVisible) { _, visible in
      focus = visible ? (session.controlsFromBelow ? .play : .seek) : .catcher
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
      .disabled(session.controlsVisible || session.panel != nil)
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
