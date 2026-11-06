import SwiftUI

struct TVCaptionOverlay: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var subtitles: LiveNativeSubtitleTrack
  let raised: Bool

  var body: some View {
    if let playback = controller.nativePlayback, controller.subtitlesEnabled, !subtitles.cues.isEmpty {
      TimelineView(.animation(minimumInterval: 0.2, paused: controller.state != .playing)) { _ in
        if let cue = LiveWebVTT.cue(at: playback.player.currentTime, in: subtitles.cues) {
          TVCaptionText(text: cue.text, styles: controller.settings.captionStyles)
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

// A line of captions in the account's caption style, the same one the Android TV app reads.
struct TVCaptionText: View {
  let text: String
  let styles: LiveCaptionStyles

  var body: some View {
    Text(text)
      .font(.system(size: 44 * CGFloat(styles.sizePercent) / 100, weight: .medium))
      .multilineTextAlignment(.center)
      .foregroundStyle(Color(hex: styles.foregroundColor) ?? .white)
      .padding(.horizontal, 20)
      .padding(.vertical, 8)
      .background((Color(hex: styles.textBackground) ?? .black).opacity(Double(styles.backgroundOpacityPercent) / 100),
                  in: RoundedRectangle(cornerRadius: 10))
      .frame(maxWidth: 1500)
  }
}
