import SwiftUI

// Android TV's ResultList: one row a result beside the keyboard, the next page a few rows before the end.
struct TVSearchResultList: View {
  @ObservedObject var model: LiveSearchViewModel
  var entry: FocusState<String?>.Binding
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (LiveChannelResult) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  private static let prefetch = 3

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("\(model.results.count) results").textCase(.uppercase)
        .font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid)
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 20) {
          ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
            row(result)
              .focused(entry, equals: result.id)
              .onAppear {
                if index >= model.results.count - Self.prefetch, model.canLoadMore { Task { await model.loadMore() } }
              }
          }
          if model.isLoadingMore {
            ForEach(0..<2, id: \.self) { _ in TVResultSkeleton() }
          }
        }
        .padding(12)
        .padding(.bottom, 60)
      }
      .padding(-12)
    }
  }

  @ViewBuilder
  private func row(_ result: LiveSearchResult) -> some View {
    switch result {
    case let .video(video):
      TVResultRow(video: video, image: video.thumbnail, round: false, title: video.title, line: video.uploaderName,
                  detail: meta(video), badge: video.duration > 0 ? LiveVideoMetadataFormatter.duration(video.duration) : nil) {
        onOpen(video)
      }
    case let .channel(channel):
      TVResultRow(image: channel.thumbnail, round: true, title: channel.name,
                  line: channel.subscriberCount > 0 ? LiveVideoMetadataFormatter.subscribers(channel.subscriberCount) : "",
                  detail: "", badge: nil) {
        onOpenChannel(channel)
      }
    case let .playlist(playlist):
      TVResultRow(image: playlist.thumbnail, round: false, title: playlist.title, line: playlist.uploaderName,
                  detail: playlist.streamCount > 0 ? String(localized: "\(playlist.streamCount) videos") : "",
                  badge: nil) {
        onOpenPlaylist(playlist)
      }
    }
  }

  private func meta(_ video: LiveVideoItem) -> String {
    [video.viewCount > 0 ? LiveVideoMetadataFormatter.views(video.viewCount) : "", LiveVideoMetadataFormatter.publication(video)]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}

private struct TVResultRow: View {
  var video: LiveVideoItem?
  let image: URL?
  let round: Bool
  let title: String
  let line: String
  let detail: String
  let badge: String?
  let onOpen: () -> Void
  @State private var menuOpenedAt: Date?
  @FocusState private var focused: Bool

  var body: some View {
    let row = Button {
      if !TVVideoMenuTarget.swallowsRelease(menuOpenedAt) { onOpen() }
    } label: {
      HStack(spacing: 28) {
        ZStack(alignment: .bottomTrailing) {
          TVRemoteImage(url: image)
            .frame(width: round ? 171 : 304, height: 171)
            .clipShape(round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius)))
          if let badge {
            Text(verbatim: badge).font(TVType.label).foregroundStyle(TVPalette.textHigh)
              .padding(.horizontal, 10).padding(.vertical, 4)
              .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8)).padding(10)
          }
        }
        .frame(width: 304)
        VStack(alignment: .leading, spacing: 8) {
          Text(verbatim: title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
          if !line.isEmpty { Text(verbatim: line).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1) }
          if !detail.isEmpty { Text(verbatim: detail).font(TVType.meta).foregroundStyle(TVPalette.textLow).lineLimit(1) }
        }
        Spacer(minLength: 0)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(TVResultRowStyle())
    .focused($focused)
    .accessibilityLabel(Text(verbatim: line.isEmpty ? title : "\(title), \(line)"))
    if let video { row.tvVideoMenu(video, openedAt: $menuOpenedAt) { focused = true } } else { row }
  }
}

private struct TVResultRowStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVResultRowLabel(configuration: configuration)
  }
}

private struct TVResultRowLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .background(isFocused ? TVPalette.surfaceRaised : TVPalette.surface.opacity(0.7),
                  in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      .scaleEffect(isFocused ? 1.02 : 1)
      .animation(.easeOut(duration: 0.16), value: isFocused)
  }
}

struct TVResultSkeleton: View {
  var body: some View {
    HStack(spacing: 28) {
      RoundedRectangle(cornerRadius: TVDimens.cardRadius).fill(TVPalette.surfaceRaised).frame(width: 304, height: 171)
      VStack(alignment: .leading, spacing: 16) {
        Capsule().fill(TVPalette.surfaceRaised).frame(width: 360, height: 28)
        Capsule().fill(TVPalette.surfaceRaised).frame(width: 260, height: 22)
        Capsule().fill(TVPalette.surfaceRaised).frame(width: 300, height: 22)
      }
    }
    .padding(20)
    .accessibilityHidden(true)
  }
}
