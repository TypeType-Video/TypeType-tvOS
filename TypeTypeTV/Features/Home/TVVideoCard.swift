import SwiftUI

struct TVVideoCard: View {
  let video: LiveVideoItem
  var progress: Double?
  var width: CGFloat = 392
  let onOpen: () -> Void
  var onFocus: (Bool) -> Void = { _ in }
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Button(action: onOpen) {
        ZStack(alignment: .bottomLeading) {
          TVRemoteImage(url: video.thumbnail)
          if video.duration > 0 {
            Text(verbatim: LiveVideoMetadataFormatter.duration(video.duration))
              .font(TVType.label)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
              .padding(14)
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
          if let progress, progress > 0 {
            GeometryReader { proxy in
              Rectangle().fill(TVPalette.accent).frame(width: proxy.size.width * min(progress, 1), height: 6)
            }
            .frame(height: 6)
          }
        }
        .frame(width: width, height: width * 9 / 16)
      }
      .buttonStyle(.card)
      .focused($focused)
      .onChange(of: focused) { _, value in onFocus(value) }
      .accessibilityLabel(Text(verbatim: "\(video.title), \(video.uploaderName)"))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: video.title)
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(2)
        Text(verbatim: video.uploaderName)
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
          .lineLimit(1)
      }
      .frame(width: width, alignment: .leading)
      .accessibilityHidden(true)
    }
  }
}

struct TVShelfRow: View {
  let shelf: LiveHomeShelf
  let onOpen: (LiveVideoItem) -> Void
  var onFocusVideo: (LiveVideoItem) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(verbatim: shelf.title)
        .font(TVType.title)
        .foregroundStyle(TVPalette.textHigh)
        .padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40) {
          ForEach(shelf.videos) { video in
            TVVideoCard(
              video: video,
              progress: shelf.progress[video.canonicalID],
              onOpen: { onOpen(video) },
              onFocus: { if $0 { onFocusVideo(video) } }
            )
          }
        }
        .padding(.horizontal, TVDimens.safeStart)
        .padding(.vertical, 24)
      }
      .scrollClipDisabled()
    }
    .focusSection()
  }
}
