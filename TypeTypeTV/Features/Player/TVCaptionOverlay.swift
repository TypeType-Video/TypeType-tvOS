import SwiftUI

struct TVCaptionOverlay: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var subtitles: LiveNativeSubtitleTrack
  let raised: Bool

  var body: some View {
    if let playback = controller.nativePlayback, controller.subtitlesEnabled, !subtitles.cues.isEmpty {
      TimelineView(.animation(minimumInterval: 0.2, paused: controller.state != .playing)) { _ in
        if let cue = LiveWebVTT.cue(at: playback.player.currentTime, in: subtitles.cues) {
          Text(cue.text)
            .font(.system(size: 44, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 1500)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      // Above the controls while they show, so a line is never hidden behind the seek bar.
      .padding(.bottom, raised ? 340 : 90)
      .animation(.easeOut(duration: 0.2), value: raised)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }
}

extension LivePlayerController {
  var captionTrack: LivePlaybackSubtitle? {
    Self.nativeSubtitle(
      for: selectedSubtitleLanguage, available: availableSubtitles,
      prepared: nativePlayback?.preparation.subtitles ?? []
    )
  }
}
