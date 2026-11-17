import SwiftUI

struct TVTwitchView: View {
  let service: LiveTwitchServiceProtocol
  let onRoute: (TVRoute) -> Void
  @StateObject private var games: LiveTwitchPagedList<LiveTwitchGame>
  @StateObject private var streams: LiveTwitchPagedList<LiveTwitchStream>
  @State private var query = ""

  init(service: LiveTwitchServiceProtocol, onRoute: @escaping (TVRoute) -> Void) {
    self.service = service
    self.onRoute = onRoute
    _games = StateObject(wrappedValue: LiveTwitchPagedList { try await service.games(after: $0) })
    _streams = StateObject(wrappedValue: LiveTwitchPagedList { try await service.streams(after: $0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 56) {
        TextField(String(localized: "Search Twitch"), text: $query)
          .onSubmit(search)
          .accessibilityLabel(Text("Search Twitch"))
          .frame(maxWidth: 1000)
          .padding(.horizontal, TVDimens.safeStart)
        if !games.items.isEmpty {
          VStack(alignment: .leading, spacing: 24) {
            TVTwitchSectionTitle(title: "Categories")
              .padding(.leading, TVDimens.safeStart)
            ScrollView(.horizontal) {
              LazyHStack(alignment: .top, spacing: 40) {
                ForEach(games.items.prefix(20)) { game in
                  TVTwitchGameCard(game: game) { onRoute(.twitch(.game(slug: game.slug, name: game.name))) }
                }
              }
              .padding(.horizontal, TVDimens.safeStart)
              .padding(.vertical, 24)
            }
            .scrollClipDisabled()
          }
        }
        VStack(alignment: .leading, spacing: 24) {
          TVTwitchSectionTitle(title: "Popular lives")
          TVTwitchStreamGrid(list: streams, empty: "No live right now.") { onRoute(.twitch(.channel($0.user.login))) }
        }
        .padding(.horizontal, TVDimens.safeStart)
      }
      .padding(.vertical, 40)
    }
    .tvReportsScroll()
    .tvContentEdges()
    .task {
      async let categories: Void = games.prepare()
      async let lives: Void = streams.prepare()
      _ = await (categories, lives)
    }
  }

  private func search() {
    let text = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
    guard !text.isEmpty else { return }
    TVJournal.note("twitch", "search")
    onRoute(.twitchSearch(text))
  }
}

struct TVTwitchStreamGrid: View {
  @ObservedObject var list: LiveTwitchPagedList<LiveTwitchStream>
  let empty: LocalizedStringKey
  let onOpen: (LiveTwitchStream) -> Void

  var body: some View {
    TVTwitchPaged(list: list, empty: empty) {
      LazyVGrid(columns: Array(repeating: GridItem(.fixed(520), spacing: 48, alignment: .top), count: 3), alignment: .leading, spacing: 56) {
        ForEach(list.items) { stream in
          TVTwitchStreamCard(stream: stream) { onOpen(stream) }
            .onAppear { if stream.id == list.items.last?.id { Task { await list.loadMore() } } }
        }
      }
    }
  }
}

struct TVTwitchPaged<Item: Identifiable & Decodable, Content: View>: View where Item.ID: Hashable {
  @ObservedObject var list: LiveTwitchPagedList<Item>
  let empty: LocalizedStringKey
  @ViewBuilder let content: () -> Content

  var body: some View {
    switch list.state {
    case .idle, .loading:
      ProgressView().frame(maxWidth: .infinity, minHeight: 200)
    case let .failed(message):
      VStack(spacing: 24) {
        Text(verbatim: message).font(TVType.body).foregroundStyle(TVPalette.textMid)
        Button("Try again") { Task { await list.reload() } }
          .buttonStyle(.tvPill)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
    case .loaded:
      if list.items.isEmpty {
        Text(empty).font(TVType.body).foregroundStyle(TVPalette.textMid)
          .frame(maxWidth: .infinity, minHeight: 160)
      } else {
        content()
      }
    }
  }
}
