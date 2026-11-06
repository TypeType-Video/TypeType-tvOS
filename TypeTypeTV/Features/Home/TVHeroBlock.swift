import SwiftUI

struct TVHeroBlock: View {
  let video: LiveVideoItem
  let index: Int
  let count: Int
  let onPlay: () -> Void
  let onOpen: () -> Void
  var onFocus: () -> Void = {}
  @FocusState private var focusedButton: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 28) {
        Text("FEATURED")
          .font(TVType.label)
          .tracking(3.6)
          .foregroundStyle(TVPalette.accent)
        HStack(spacing: 10) {
          ForEach(0..<count, id: \.self) { dot in
            Capsule()
              .fill(dot == index ? TVPalette.accent : TVPalette.outline)
              .frame(width: dot == index ? 40 : 12, height: 8)
          }
        }
        .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 20) {
        Text(verbatim: video.title)
          .font(TVType.display)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(2)
        Text(verbatim: meta)
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
          .lineLimit(1)
        if let description = video.shortDescription, !description.isEmpty {
          Text(verbatim: description)
            .font(TVType.body)
            .foregroundStyle(TVPalette.textMid)
            .lineLimit(3)
        }
      }
      .frame(width: 860, height: 424, alignment: .bottomLeading)
      .id(video.canonicalID)
      .transition(.opacity.combined(with: .move(edge: .bottom)))
      HStack(spacing: 24) {
        Button(action: onPlay) { Label("Play", systemImage: "play.fill") }
          .buttonStyle(.tvPillEmphasized)
          .focused($focusedButton, equals: 0)
        Button(action: onOpen) { Label("More info", systemImage: "info.circle") }
          .buttonStyle(.tvPill)
          .focused($focusedButton, equals: 1)
      }
      .padding(.top, 16)
    }
    .padding(.leading, TVDimens.safeStart)
    .animation(.easeOut(duration: 0.42), value: video.canonicalID)
    .onChange(of: focusedButton) { _, value in if value != nil { onFocus() } }
  }

  private var meta: String {
    var parts = [video.uploaderName]
    if video.duration > 0 { parts.append(LiveVideoMetadataFormatter.duration(video.duration)) }
    return parts.filter { !$0.isEmpty }.joined(separator: " · ")
  }
}
