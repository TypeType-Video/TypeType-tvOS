import SwiftUI

// Android TV's UpNextCard: shown over the last seconds of the video, OK plays the next one now and Back cancels.
struct TVUpNextCard: View {
  let next: LiveVideoItem
  let fill: Double
  let secondsLeft: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        TVRemoteImage(url: next.thumbnail)
        Text("UP NEXT").font(TVType.label).foregroundStyle(TVPalette.accent)
          .padding(.horizontal, 18).padding(.vertical, 8)
          .background(TVPalette.ink.opacity(0.92), in: Capsule())
          .padding(24)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        if next.duration > 0 {
          Text(verbatim: LiveVideoMetadataFormatter.duration(next.duration)).font(TVType.label)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
      }
      .aspectRatio(16 / 9, contentMode: .fit)
      VStack(alignment: .leading, spacing: 8) {
        Text(verbatim: next.title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
        Text(verbatim: next.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
        countdown.padding(.top, 20)
        HStack(spacing: 36) {
          hint("OK", "Play now")
          hint("Back", "Cancel")
        }
        .padding(.top, 16)
      }
      .padding(.horizontal, 32).padding(.vertical, 28)
    }
    .frame(width: 760)
    .background(.black.opacity(0.72))
    .clipShape(RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .padding(.trailing, TVDimens.safeStart).padding(.bottom, 72)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Up next: \(next.title), \(next.uploaderName). Plays in \(secondsLeft) seconds. Press OK to play now, Back to cancel."))
  }

  private var countdown: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        TVPalette.glass
        TVPalette.accent.opacity(0.92).frame(width: proxy.size.width * fill)
          .animation(.linear(duration: 0.3), value: fill)
        Label("Playing in \(secondsLeft) s", systemImage: "play.fill")
          .font(TVType.title).foregroundStyle(TVPalette.textHigh)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(height: 92)
    .clipShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius))
  }

  private func hint(_ key: LocalizedStringKey, _ label: LocalizedStringKey) -> some View {
    HStack(spacing: 14) {
      Text(key).font(TVType.label).foregroundStyle(TVPalette.ink)
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(TVPalette.textHigh, in: Capsule())
      Text(label).font(TVType.meta).foregroundStyle(TVPalette.textMid)
    }
  }
}
