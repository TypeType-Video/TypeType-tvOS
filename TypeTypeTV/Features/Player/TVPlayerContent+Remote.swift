import SwiftUI

extension TVPlayerContent {
  // Takes the remote while the controls are hidden: Select pauses, Left and Right scrub, Up and Down bring the controls.
  var catcher: some View {
    Button(action: select) { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
      .buttonStyle(TVBareButtonStyle())
      .focused($focus, equals: .catcher)
      .disabled(session.controlsVisible || session.panel != nil || countdownActive)
      .onMoveCommand { direction in
        switch direction {
        case .left: if !session.undoSkip() { session.scrub(direction: -1) }
        case .right: session.scrub(direction: 1)
        case .down: session.showControls(fromBelow: true)
        default: session.showControls()
        }
      }
      .onPlayPauseCommand(perform: session.togglePlay)
      .accessibilityLabel(Text(verbatim: controller.video.title))
  }

  var restingFocus: TVPlayerFocus? {
    if countdownActive { return nil }
    guard session.controlsVisible else { return .catcher }
    return session.controlsFromBelow ? .play : .seek
  }

  var countdownActive: Bool { playback.autoplayCountdownRemaining != nil }

  var isOpening: Bool {
    controller.position == 0 && (controller.state == .loading || controller.state == .idle)
  }

  var related: [LiveVideoItem] {
    controller.stream?.relatedStreams.filter { !$0.isShortFormContent && !$0.isLive } ?? []
  }

  var nextVideo: LiveVideoItem? { related.first }

  private func select() {
    if upNextVideo != nil { playback.playUpcomingNow() } else { session.togglePlay() }
  }
}
