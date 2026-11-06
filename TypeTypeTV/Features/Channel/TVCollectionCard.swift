import SwiftUI

// A playlist laid out like a video card, as on Android TV, so every tab of the channel reads alike.
struct TVCollectionCard: View {
  let title: String
  let line: String
  let image: URL?
  let count: Int64
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button(action: onOpen) {
        ZStack(alignment: .bottomTrailing) {
          TVRemoteImage(url: image)
          if count > 0 {
            Text("\(count) videos").font(TVType.label).foregroundStyle(TVPalette.textHigh)
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8)).padding(14)
          }
        }
        .frame(width: 536, height: 302)
      }
      .buttonStyle(.card)
      .accessibilityLabel(Text(verbatim: "\(title), \(line)"))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(1)
        Text(verbatim: line).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
      }
      .frame(width: 536, alignment: .leading)
      .accessibilityHidden(true)
    }
  }
}
