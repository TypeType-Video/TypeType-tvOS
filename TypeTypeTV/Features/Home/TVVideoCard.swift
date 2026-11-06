import SwiftUI

struct TVVideoCard: View {
  let video: LiveVideoItem
  var progress: Double?
  var width: CGFloat = 392
  let onOpen: () -> Void
  var onFocus: (Bool) -> Void = { _ in }
  var externalFocus: FocusState<Bool>.Binding?
  @FocusState private var focused: Bool
  @State private var menuOpenedAt: Date?
  @Environment(\.livePrewarm) private var prewarm
  @State private var prewarmTask: Task<Void, Never>?

  private var isFocused: Bool { externalFocus?.wrappedValue ?? focused }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Button {
        if !TVVideoMenuTarget.swallowsRelease(menuOpenedAt) { onOpen() }
      } label: {
        ZStack(alignment: .bottomLeading) {
          TVRemoteImage(url: video.thumbnail)
          if video.isShortFormContent {
            Text("SHORT").font(TVType.label).foregroundStyle(TVPalette.textHigh)
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(TVPalette.accent, in: RoundedRectangle(cornerRadius: 8))
              .padding(14)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
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
      .focused(externalFocus ?? $focused)
      .tvVideoMenu(video, openedAt: $menuOpenedAt) {
        if let externalFocus { externalFocus.wrappedValue = true } else { focused = true }
      }
      .onChange(of: focused) { _, value in onFocus(value) }
      .onChange(of: isFocused) { _, value in schedulePrewarm(value) }
      .onDisappear { prewarmTask?.cancel() }
      .accessibilityLabel(Text(verbatim: "\(video.title), \(video.uploaderName)"))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: video.title)
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(1)
        Text(verbatim: meta)
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
          .lineLimit(1)
      }
      .frame(width: width, alignment: .leading)
      .accessibilityHidden(true)
    }
  }

  // Android TV's card line: the channel, then the views, or the viewers of a live.
  private var meta: String {
    guard video.viewCount > 0 else { return video.uploaderName }
    let count = video.isLive
      ? String(localized: "\(video.viewCount.formatted(.number.notation(.compactName))) watching")
      : LiveVideoMetadataFormatter.views(video.viewCount)
    return [video.uploaderName, count].filter { !$0.isEmpty }.joined(separator: " · ")
  }
}

extension TVVideoCard {
  // The focus rests on a card for a moment before the reader presses it: the instance prepares the stream
  // meanwhile, as the web client does when a card is hovered. YouTube opens a whole session, so it waits a
  // little longer than the providers, whose stream is a plain request.
  private func schedulePrewarm(_ focused: Bool) {
    prewarmTask?.cancel()
    prewarmTask = nil
    guard focused, !video.isLive, !video.url.isEmpty, let prewarm else { return }
    let isYouTube = video.url.contains("youtube.com") || video.url.contains("youtu.be")
    let delay: Duration = .milliseconds(isYouTube ? 600 : 250)
    let video = video
    // The prewarm closure belongs to the main actor.
    prewarmTask = Task { @MainActor in
      try? await Task.sleep(for: delay)
      if !Task.isCancelled { prewarm(video) }
    }
  }
}

struct TVShelfRow: View {
  let shelf: LiveHomeShelf
  let onOpen: (LiveVideoItem) -> Void
  var onFocusVideo: (LiveVideoItem) -> Void = { _ in }
  var firstCardFocus: FocusState<Bool>.Binding?

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(verbatim: shelf.title.uppercased())
        .font(TVType.label)
        .tracking(3.6)
        .foregroundStyle(TVPalette.textMid)
        .padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40) {
          ForEach(shelf.videos) { video in
            TVVideoCard(
              video: video,
              progress: shelf.progress[video.canonicalID],
              onOpen: { onOpen(video) },
              onFocus: { if $0 { onFocusVideo(video) } },
              externalFocus: video.id == shelf.videos.first?.id ? firstCardFocus : nil
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
