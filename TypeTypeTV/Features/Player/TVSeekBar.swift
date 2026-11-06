import SwiftUI

struct TVSeekBar: View {
  let position: TimeInterval
  let duration: TimeInterval
  let scrub: TimeInterval?
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    GeometryReader { proxy in
      let shown = scrub ?? position
      let fraction = duration > 0 ? min(max(shown / duration, 0), 1) : 0
      let track: CGFloat = isFocused || scrub != nil ? 16 : 8
      ZStack(alignment: .leading) {
        Capsule().fill(TVPalette.outline.opacity(0.75)).frame(height: track)
        Capsule().fill(TVPalette.accent).frame(width: proxy.size.width * fraction, height: track)
        if isFocused || scrub != nil {
          Circle()
            .fill(TVPalette.textHigh)
            .frame(width: 40, height: 40)
            .offset(x: proxy.size.width * fraction - 20)
        }
        if let scrub {
          Text(verbatim: TVTime.label(scrub))
            .font(TVType.meta)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
            .offset(x: min(max(proxy.size.width * fraction - 60, 0), proxy.size.width - 120), y: -70)
        }
      }
      .frame(height: proxy.size.height)
      .animation(.easeOut(duration: 0.16), value: isFocused)
    }
    .frame(height: 68)
    .contentShape(Rectangle())
    .accessibilityElement()
    .accessibilityLabel(Text("Seek bar"))
    .accessibilityValue(Text(verbatim: TVTime.label(scrub ?? position)))
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
