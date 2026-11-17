import SwiftUI

struct TVTwitchChannelScreen: View {
  let login: String
  let onRoute: (TVRoute) -> Void
  @StateObject private var model: LiveTwitchChannelViewModel
  @StateObject private var videos: LiveTwitchPagedList<LiveTwitchVideo>
  @StateObject private var clips: LiveTwitchPagedList<LiveTwitchClip>

  init(login: String, service: LiveTwitchServiceProtocol, onRoute: @escaping (TVRoute) -> Void) {
    self.login = login
    self.onRoute = onRoute
    _model = StateObject(wrappedValue: LiveTwitchChannelViewModel(login: login, service: service))
    _videos = StateObject(wrappedValue: LiveTwitchPagedList { try await service.channelVideos(login: login, after: $0) })
    _clips = StateObject(wrappedValue: LiveTwitchPagedList { try await service.channelClips(login: login, after: $0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 56) {
        switch model.state {
        case .loading:
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        case let .failed(message):
          VStack(spacing: 24) {
            Text(verbatim: message).font(TVType.body).foregroundStyle(TVPalette.textMid)
            Button("Try again") { Task { await model.load() } }.buttonStyle(.tvPill)
          }
          .frame(maxWidth: .infinity, minHeight: 400)
        case .notFound:
          Text("This channel could not be found.").font(TVType.body).foregroundStyle(TVPalette.textMid)
            .frame(maxWidth: .infinity, minHeight: 400)
        case let .loaded(channel):
          header(channel).padding(.horizontal, TVDimens.safeStart)
          if let live = channel.live {
            liveSection(live).padding(.horizontal, TVDimens.safeStart)
          }
          row(title: "Past broadcasts", list: videos, empty: "No past broadcasts.") { video in
            TVTwitchMediaTile(title: video.title, previewURL: video.previewURL, duration: video.lengthSeconds,
                              detail: LiveTwitchFormat.videoDetail(views: video.views, created: video.createdAt))
          }
          row(title: "Clips", list: clips, empty: "No clips.") { clip in
            TVTwitchMediaTile(title: clip.title, previewURL: clip.thumbnailURL, duration: Int(clip.durationSeconds.rounded()),
                              detail: LiveTwitchFormat.videoDetail(views: clip.views, created: clip.createdAt))
          }
        }
      }
      .padding(.vertical, 40)
    }
    .tvReportsScroll()
    .tvContentEdges()
    .task {
      await model.load()
      async let past: Void = videos.prepare()
      async let short: Void = clips.prepare()
      _ = await (past, short)
    }
  }

  private func header(_ channel: LiveTwitchChannel) -> some View {
    HStack(spacing: 36) {
      TVRemoteImage(url: LiveImageURLResolver.resolve(channel.user.avatarURL))
        .frame(width: 160, height: 160)
        .clipShape(Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 10) {
        Text(verbatim: channel.user.name).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        Text("\(LiveTwitchFormat.count(channel.followers)) followers").font(TVType.meta).foregroundStyle(TVPalette.textMid)
        if channel.live == nil {
          Text("Offline").font(TVType.label).foregroundStyle(TVPalette.textMid)
        }
        if !channel.description.isEmpty {
          Text(verbatim: channel.description).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(2)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func liveSection(_ live: LiveTwitchStream) -> some View {
    VStack(alignment: .leading, spacing: 28) {
      TVTwitchMediaTile(title: live.title, previewURL: live.previewURL, duration: 0,
                        detail: [live.game?.name, String(localized: "\(LiveTwitchFormat.count(live.viewers)) watching")]
                          .compactMap { $0 }.joined(separator: " · "), width: 640)
      if !live.tags.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 20) {
            ForEach(live.tags, id: \.self) { tag in
              Button(tag) { onRoute(.twitch(.tag(tag))) }
                .buttonStyle(.tvPill)
                .accessibilityLabel(Text("See the lives tagged \(tag)"))
            }
          }
          .padding(.vertical, 16)
        }
        .scrollClipDisabled()
      }
    }
  }

  private func row<Item: Identifiable & Decodable, Tile: View>(
    title: LocalizedStringKey,
    list: LiveTwitchPagedList<Item>,
    empty: LocalizedStringKey,
    @ViewBuilder tile: @escaping (Item) -> Tile
  ) -> some View where Item.ID: Hashable {
    VStack(alignment: .leading, spacing: 24) {
      TVTwitchSectionTitle(title: title).padding(.leading, TVDimens.safeStart)
      TVTwitchPaged(list: list, empty: empty) {
        ScrollView(.horizontal) {
          LazyHStack(alignment: .top, spacing: 40) {
            ForEach(list.items) { item in
              tile(item)
                .onAppear { if item.id == list.items.last?.id { Task { await list.loadMore() } } }
            }
          }
          .padding(.horizontal, TVDimens.safeStart)
          .padding(.vertical, 24)
        }
        .scrollClipDisabled()
      }
    }
  }
}
