import SwiftUI

struct TVTwitchStreamsScreen: View {
  let title: Text
  let onPlay: (LiveVideoItem) -> Void
  let onRoute: (TVRoute) -> Void
  @StateObject private var list: LiveTwitchPagedList<LiveTwitchStream>

  init(
    title: Text, load: @escaping (String?) async throws -> LiveTwitchPage<LiveTwitchStream>,
    onPlay: @escaping (LiveVideoItem) -> Void, onRoute: @escaping (TVRoute) -> Void
  ) {
    self.title = title
    self.onPlay = onPlay
    self.onRoute = onRoute
    _list = StateObject(wrappedValue: LiveTwitchPagedList(load: load))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        title.font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        TVTwitchStreamGrid(list: list, empty: "No live right now.") { onPlay(LiveTwitchPlayback.item(live: $0)) }
      }
      .padding(.horizontal, TVDimens.safeStart)
      .padding(.vertical, 40)
    }
    .tvReportsScroll()
    .tvContentEdges()
    .task { await list.prepare() }
  }
}

struct TVTwitchSearchScreen: View {
  let query: String
  let onPlay: (LiveVideoItem) -> Void
  let onRoute: (TVRoute) -> Void
  @StateObject private var channels: LiveTwitchPagedList<LiveTwitchChannel>
  @StateObject private var games: LiveTwitchPagedList<LiveTwitchGame>
  @StateObject private var streams: LiveTwitchPagedList<LiveTwitchStream>

  init(query: String, service: LiveTwitchServiceProtocol, onPlay: @escaping (LiveVideoItem) -> Void, onRoute: @escaping (TVRoute) -> Void) {
    self.query = query
    self.onPlay = onPlay
    self.onRoute = onRoute
    _channels = StateObject(wrappedValue: LiveTwitchPagedList { try await service.searchChannels(query, after: $0) })
    _games = StateObject(wrappedValue: LiveTwitchPagedList { try await service.searchGames(query, after: $0) })
    _streams = StateObject(wrappedValue: LiveTwitchPagedList { try await service.searchStreams(query, after: $0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 56) {
        Text("Twitch results for “\(query)”").font(TVType.headline).foregroundStyle(TVPalette.textHigh)
          .padding(.horizontal, TVDimens.safeStart)
        shelf("Channels", list: channels) { channel in
          VStack(spacing: 16) {
            Button { onRoute(.twitch(.channel(channel.user.login))) } label: {
              TVRemoteImage(url: LiveImageURLResolver.resolve(channel.user.avatarURL))
                .frame(width: 180, height: 180)
                .clipShape(Circle())
            }
            .buttonStyle(.card)
            .clipShape(Circle())
            .accessibilityLabel(Text(verbatim: channel.user.name))
            .accessibilityValue(Text("\(LiveTwitchFormat.count(channel.followers)) followers"))
            Text(verbatim: channel.user.name).font(TVType.meta).foregroundStyle(TVPalette.textHigh).lineLimit(1)
              .frame(width: 200)
              .accessibilityHidden(true)
          }
        }
        shelf("Categories", list: games) { game in
          TVTwitchGameCard(game: game) { onRoute(.twitch(.game(slug: game.slug, name: game.name))) }
        }
        shelf("Lives", list: streams) { stream in
          TVTwitchStreamCard(stream: stream, width: 440) { onPlay(LiveTwitchPlayback.item(live: stream)) }
        }
      }
      .padding(.vertical, 40)
    }
    .tvReportsScroll()
    .tvContentEdges()
    .task {
      async let first: Void = channels.prepare()
      async let second: Void = games.prepare()
      async let third: Void = streams.prepare()
      _ = await (first, second, third)
    }
  }

  private func shelf<Item: Identifiable & Decodable, Tile: View>(
    _ title: LocalizedStringKey,
    list: LiveTwitchPagedList<Item>,
    @ViewBuilder tile: @escaping (Item) -> Tile
  ) -> some View where Item.ID: Hashable {
    VStack(alignment: .leading, spacing: 24) {
      TVTwitchSectionTitle(title: title).padding(.leading, TVDimens.safeStart)
      TVTwitchPaged(list: list, empty: "No results.") {
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
