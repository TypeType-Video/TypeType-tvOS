import SwiftUI

struct TVSeekBar: View {
  let position: TimeInterval
  let duration: TimeInterval
  let scrub: TimeInterval?
  var chapters: [LivePlaybackChapter] = []
  var sponsors: [LiveSponsorBlockWindow] = []
  var storyboard: LivePlaybackPreviewFrames?
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    GeometryReader { proxy in
      let shown = scrub ?? position
      let fraction = duration > 0 ? min(max(shown / duration, 0), 1) : 0
      let track: CGFloat = isFocused || scrub != nil ? 16 : 8
      ZStack(alignment: .leading) {
        Capsule().fill(TVPalette.outline.opacity(0.75)).frame(height: track)
        Capsule().fill(TVPalette.accent).frame(width: proxy.size.width * fraction, height: track)
        markers(width: proxy.size.width, track: track)
        if isFocused || scrub != nil {
          Circle()
            .fill(TVPalette.textHigh)
            .frame(width: 40, height: 40)
            .offset(x: proxy.size.width * fraction - 20)
        }
      }
      .frame(height: proxy.size.height)
      .overlay(alignment: .bottomLeading) {
        if let scrub {
          let half = TVSeekPreview.width / 2
          TVSeekPreview(
            position: scrub,
            chapter: chapters.last { TimeInterval($0.startTimeSeconds) <= scrub }?.title,
            storyboard: storyboard
          )
          .offset(x: min(max(proxy.size.width * fraction - half, 0), proxy.size.width - TVSeekPreview.width), y: -64)
        }
      }
      .animation(.easeOut(duration: 0.16), value: isFocused)
    }
    .frame(height: 68)
    .contentShape(Rectangle())
    .accessibilityElement()
    .accessibilityLabel(Text("Seek bar"))
    .accessibilityValue(Text(verbatim: TVTime.label(scrub ?? position)))
  }
}

extension TVSeekBar {
  // Sponsor parts are soft bands over the track and chapter starts are thin cuts, as on Android TV.
  func markers(width: CGFloat, track: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      if duration > 0 {
        ForEach(sponsors) { window in
          Rectangle().fill(TVPalette.accentSoft.opacity(0.65))
            .frame(width: max(width * (window.end - window.start) / duration, 2), height: track)
            .offset(x: width * window.start / duration)
        }
        ForEach(chapters.dropFirst()) { chapter in
          let start = TimeInterval(chapter.startTimeSeconds) / duration
          if start > 0, start < 1 {
            Rectangle().fill(TVPalette.ink.opacity(0.9)).frame(width: 4, height: track).offset(x: width * start - 2)
          }
        }
      }
    }
    .frame(width: width, height: track, alignment: .leading)
    .clipShape(Capsule())
    .allowsHitTesting(false)
  }
}

enum TVTime {
  static func label(_ seconds: TimeInterval) -> String {
    let total = max(Int(seconds.rounded(.down)), 0)
    let hours = total / 3_600
    let minutes = (total % 3_600) / 60
    let rest = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
  }
}
