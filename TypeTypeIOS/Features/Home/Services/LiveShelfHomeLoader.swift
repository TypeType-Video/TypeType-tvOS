import Foundation

// The home of the TV app: a few featured videos above rows from every source, like the Android TV app.
final class LiveShelfHomeLoader {
  struct Sources {
    var recommendations: () async throws -> [LiveVideoItem]
    var history: () async throws -> [LiveHistoryItem]
    var subscriptionFeed: () async throws -> [LiveVideoItem]
    var trending: (Int) async throws -> [LiveVideoItem]
    var watchLater: () async throws -> [LiveVideoItem]
    var favorites: () async throws -> [LiveVideoItem]
  }

  private let sources: Sources

  init(sources: Sources) {
    self.sources = sources
  }

  convenience init(
    homeFeed: HomeFeedServiceProtocol,
    history: LiveHistoryServiceProtocol,
    subscriptions: LiveSubscriptionsServiceProtocol,
    search: LiveSearchServiceProtocol,
    library: LiveLibraryServiceProtocol
  ) {
    self.init(
      sources: Sources(
        recommendations: { try await homeFeed.recommendations(serviceID: 0, intent: "auto", limit: 30, cursor: nil).items },
        history: { try await history.history(query: nil, from: nil, to: nil, limit: 80, offset: 0) },
        subscriptionFeed: { try await subscriptions.feed(nextPage: nil, filter: .all).videos },
        trending: { try await search.trending(serviceID: $0) },
        watchLater: { try await library.watchLater().map(\.libraryVideo.video) },
        favorites: { try await library.favorites().map(\.libraryVideo.video) }
      )
    )
  }

  func load() async throws -> LiveShelfHome {
    let sources = sources
    async let recommended = Self.attempt(sources.recommendations)
    async let watched = Self.attempt(sources.history)
    async let feed = Self.attempt(sources.subscriptionFeed)
    async let trending = Self.attempt { try await sources.trending(0) }
    async let later = Self.attempt(sources.watchLater)
    async let favorites = Self.attempt(sources.favorites)
    async let bilibili = Self.attempt { try await sources.trending(5) }
    async let niconico = Self.attempt { try await sources.trending(6) }

    let recommendedResult = await recommended
    let watchedResult = await watched
    let feedResult = await feed
    let trendingResult = await trending
    let core: [Error?] = [recommendedResult.error, watchedResult.error, feedResult.error, trendingResult.error]
    if core.allSatisfy({ $0 != nil }), let first = core.compactMap({ $0 }).first {
      throw first
    }

    let recommendedVideos = recommendedResult.value ?? []
    let trendingVideos = trendingResult.value ?? []
    let source = recommendedVideos.isEmpty ? trendingVideos : recommendedVideos
    let described = source.filter { !($0.shortDescription ?? "").isEmpty }
    let featured = Array((described.isEmpty ? source : described).prefix(Self.featuredCount))
    let featuredIDs = Set(featured.map(\.canonicalID))
    let inProgress = LiveHomeViewModel.inProgress(watchedResult.value ?? [])

    let shelves = [
      LiveHomeShelf(
        id: "continue",
        title: String(localized: "Continue watching"),
        videos: inProgress.map(\.video),
        progress: Dictionary(inProgress.map { ($0.video.canonicalID, $0.progressFraction) }, uniquingKeysWith: { a, _ in a })
      ),
      Self.shelf("recommended", String(localized: "Recommended for you"), recommendedVideos.filter { !featuredIDs.contains($0.canonicalID) }),
      Self.shelf("subscriptions", String(localized: "From your subscriptions"), feedResult.value ?? []),
      Self.shelf("trending", String(localized: "Trending now"), trendingVideos),
      Self.shelf("watch-later", String(localized: "Watch later"), await later.value ?? []),
      Self.shelf("trending-bilibili", String(localized: "Trending on BiliBili"), await bilibili.value ?? []),
      Self.shelf("trending-niconico", String(localized: "Trending on NicoNico"), await niconico.value ?? []),
      Self.shelf("favorites", String(localized: "Favorites"), await favorites.value ?? []),
    ].filter { !$0.videos.isEmpty }

    let heroes = featured.isEmpty ? Array(shelves.first?.videos.prefix(1) ?? []) : featured
    return LiveShelfHome(featured: heroes, shelves: shelves)
  }

  private static func shelf(_ id: String, _ title: String, _ videos: [LiveVideoItem]) -> LiveHomeShelf {
    let visible = LiveHomeViewModel.uniqueVisibleVideos(videos.filter { !$0.isShortFormContent })
    return LiveHomeShelf(id: id, title: title, videos: Array(visible.prefix(shelfLimit)))
  }

  private static func attempt<T>(_ work: () async throws -> T) async -> Outcome<T> {
    do {
      return Outcome(value: try await work(), error: nil)
    } catch {
      return Outcome(value: nil, error: error)
    }
  }

  private struct Outcome<T> {
    let value: T?
    let error: Error?
  }

  private static let featuredCount = 4
  private static let shelfLimit = 20
}
