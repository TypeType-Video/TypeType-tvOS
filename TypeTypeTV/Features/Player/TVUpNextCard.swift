import SwiftUI

struct TVUpNextCard: View {
  @ObservedObject var playback: LivePlaybackCoordinator
  @FocusState private var playNowFocused: Bool

  var body: some View {
    if let remaining = playback.autoplayCountdownRemaining {
      VStack(alignment: .leading, spacing: 20) {
        Text("UP NEXT")
          .font(TVType.label)
          .tracking(3.6)
          .foregroundStyle(TVPalette.accent)
        if let next = nextVideo {
          HStack(spacing: 24) {
            TVRemoteImage(url: next.thumbnail)
              .frame(width: 240, height: 135)
              .clipShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius))
            VStack(alignment: .leading, spacing: 6) {
              Text(verbatim: next.title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
              Text(verbatim: next.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
            }
          }
        }
        Text("Playing in \(remaining) s")
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
        HStack(spacing: 20) {
          Button("Play now") { playback.skipAutoplayCountdown() }
            .buttonStyle(.tvPillEmphasized)
            .focused($playNowFocused)
          Button("Cancel") { playback.cancelAutoplayCountdown() }
            .buttonStyle(.tvPill)
        }
      }
      .padding(40)
      .frame(width: 820, alignment: .leading)
      .background(TVPalette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      .padding(80)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      .onAppear { playNowFocused = true }
    }
  }

  private var nextVideo: LiveVideoItem? {
    switch playback.pendingAutoplay {
    case let .related(video): return video
    case let .queue(index): return playback.queue.videos.indices.contains(index) ? playback.queue.videos[index] : nil
    case nil: return nil
    }
  }
}
