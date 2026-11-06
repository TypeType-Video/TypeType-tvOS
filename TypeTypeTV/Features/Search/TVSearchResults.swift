import SwiftUI

struct TVSearchResults: View {
  @ObservedObject var model: LiveSearchViewModel
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (LiveChannelResult) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 56) {
      Text("\(model.results.count) results")
        .textCase(.uppercase)
        .font(TVType.label)
        .tracking(3.6)
        .foregroundStyle(TVPalette.textMid)
        .padding(.leading, TVDimens.safeStart)
      if !channels.isEmpty {
        row(title: "Channels") {
          ForEach(channels, id: \.canonicalID) { channel in
            TVChannelCard(channel: channel) { onOpenChannel(channel) }
          }
        }
      }
      if !playlists.isEmpty {
        row(title: "Playlists") {
          ForEach(playlists, id: \.canonicalID) { playlist in
            TVPlaylistCard(playlist: playlist) { onOpenPlaylist(playlist) }
          }
        }
      }
      if !videos.isEmpty {
        TVVideoGrid(videos: videos, isLoadingMore: model.isLoadingMore, onOpen: onOpen) {
          Task { await model.loadMore() }
        }
      }
    }
  }

  private var videos: [LiveVideoItem] {
    model.results.compactMap { if case let .video(video) = $0 { video } else { nil } }
  }

  private var channels: [LiveChannelResult] {
    model.results.compactMap { if case let .channel(channel) = $0 { channel } else { nil } }
  }

  private var playlists: [LivePlaylistResult] {
    model.results.compactMap { if case let .playlist(playlist) = $0 { playlist } else { nil } }
  }

  private func row<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(title)
        .textCase(.uppercase)
        .font(TVType.label)
        .tracking(3.6)
        .foregroundStyle(TVPalette.textMid)
        .padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40, content: content)
          .padding(.horizontal, TVDimens.safeStart)
          .padding(.vertical, 24)
      }
      .scrollClipDisabled()
    }
    .focusSection()
  }
}

struct TVChannelCard: View {
  let channel: LiveChannelResult
  let onOpen: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Button(action: onOpen) {
        TVRemoteImage(url: channel.thumbnail)
          .frame(width: 200, height: 200)
          .clipShape(Circle())
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(Text(verbatim: channel.name))
      Text(verbatim: channel.name)
        .font(TVType.meta)
        .foregroundStyle(TVPalette.textHigh)
        .lineLimit(1)
        .frame(width: 240)
        .accessibilityHidden(true)
    }
  }
}

struct TVPlaylistCard: View {
  let playlist: LivePlaylistResult
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Button(action: onOpen) {
        ZStack(alignment: .bottomTrailing) {
          TVRemoteImage(url: playlist.thumbnail)
          if playlist.streamCount > 0 {
            Label(String(playlist.streamCount), systemImage: "list.bullet")
              .font(TVType.label)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
              .padding(14)
          }
        }
        .frame(width: 392, height: 220)
      }
      .buttonStyle(.card)
      .accessibilityLabel(Text(verbatim: playlist.title))
      Text(verbatim: playlist.title)
        .font(TVType.title)
        .foregroundStyle(TVPalette.textHigh)
        .lineLimit(2)
        .frame(width: 392, alignment: .leading)
        .accessibilityHidden(true)
    }
  }
}
