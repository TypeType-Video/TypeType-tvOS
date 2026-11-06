import SwiftUI

struct TVPlayerScreen: View {
  let video: LiveVideoItem
  @ObservedObject var playback: LivePlaybackCoordinator
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let controller = playback.controller {
        TVPlayerSurface(controller: controller, onClose: close)
      }
    }
    .onAppear { playback.open(video) }
    .onExitCommand(perform: close)
  }

  private func close() {
    playback.controller?.flushHistory()
    playback.close()
    onClose()
  }
}

private struct TVPlayerSurface: View {
  @ObservedObject var controller: LivePlayerController
  let onClose: () -> Void

  var body: some View {
    ZStack {
      TVSystemPlayer(controller: controller)
        .ignoresSafeArea()
      switch controller.state {
      case .idle, .loading:
        if controller.position == 0 {
          VStack(spacing: 32) {
            ProgressView()
            Text(verbatim: controller.video.title)
              .font(TVType.title)
              .foregroundStyle(TVPalette.textMid)
              .lineLimit(2)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(0.6))
          .allowsHitTesting(false)
        }
      case let .failed(message):
        VStack(spacing: 32) {
          Text(verbatim: message)
            .font(TVType.body)
            .foregroundStyle(TVPalette.textHigh)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 1100)
          HStack(spacing: 24) {
            Button("Try again") { controller.retry() }
              .buttonStyle(.tvPillEmphasized)
            Button("Close", action: onClose)
              .buttonStyle(.tvPill)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
      case .ready, .playing, .paused:
        EmptyView()
      }
    }
  }
}
