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
    var shorts: () async throws -> [LiveVideoItem] = { [] }
    // The videos of the unread notifications only: the row disappears once they are read.
    var notifications: () async throws -> [LiveVideoItem] = { [] }
    var settings: () async throws -> LiveSettings = { LiveSettings() }
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
    library: LiveLibraryServiceProtocol,
    notifications: LiveNotificationsServiceProtocol? = nil,
    settings: LiveSettingsServiceProtocol? = nil
  ) {
    self.init(
      sources: Sources(
        recommendations: { try await homeFeed.recommendations(serviceID: 0, intent: "auto", limit: 30, cursor: nil).items },
        history: { try await history.history(query: nil, from: nil, to: nil, limit: 80, offset: 0) },
        subscriptionFeed: { try await subscriptions.feed(nextPage: nil, filter: .all).videos },
        trending: { try await search.trending(serviceID: $0) },
        watchLater: { try await library.watchLater().map(\.libraryVideo.video) },
        favorites: { try await library.favorites().map(\.libraryVideo.video) },
        shorts: { try await homeFeed.shorts(limit: 20).items },
        notifications: {
          guard let page = try await notifications?.notifications(page: 1, limit: 20), page.unreadCount > 0 else { return [] }
          return page.items.filter { !$0.read }.map(\.video)
        },
        settings: { try await settings?.settings() ?? LiveSettings() }
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
    async let shorts = Self.attempt(sources.shorts)
    async let unread = Self.attempt(sources.notifications)
    async let settings = Self.attempt(sources.settings)

    let recommendedResult = await recommended
    let watchedResult = await watched
    let feedResult = await feed
    let trendingResult = await trending
    let core: [Error?] = [recommendedResult.error, watchedResult.error, feedResult.error, trendingResult.error]
    if core.allSatisfy({ $0 != nil }), let first = core.compactMap({ $0 }).first {
      throw first
    }

    // Like Android TV's ContentVisibility: the rows the account turned off are left out.
    let visibility = await settings.value ?? LiveSettings()
    let recommendedVideos = visibility.hideHomeRecommendations ? [] : recommendedResult.value ?? []
    let trendingVideos = trendingResult.value ?? []
    let source = recommendedVideos.isEmpty ? trendingVideos : recommendedVideos
    let described = source.filter { !($0.shortDescription ?? "").isEmpty }
    let featured = Array((described.isEmpty ? source : described).prefix(Self.featuredCount))
    let featuredIDs = Set(featured.map(\.canonicalID))
    let inProgress = visibility.hideContinueWatching ? [] : LiveHomeViewModel.inProgress(watchedResult.value ?? [])

    let shelves = [
      Self.shelf("notifications", String(localized: "New from your subscriptions"), await unread.value ?? []),
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
      Self.shorts(visibility.hideShorts ? [] : await shorts.value ?? []),
      Self.shelf("trending-bilibili", String(localized: "Trending on BiliBili"), await bilibili.value ?? []),
      Self.shelf("trending-niconico", String(localized: "Trending on NicoNico"), await niconico.value ?? []),
      Self.shelf("favorites", String(localized: "Favorites"), await favorites.value ?? []),
    ].filter { !$0.videos.isEmpty }

    let heroes = featured.isEmpty ? Array(shelves.first?.videos.prefix(1) ?? []) : featured
    return LiveShelfHome(featured: heroes, shelves: shelves)
  }

  // The one row that keeps short videos: the others leave them out.
  private static func shorts(_ videos: [LiveVideoItem]) -> LiveHomeShelf {
    LiveHomeShelf(id: "shorts", title: String(localized: "Shorts"), videos: Array(LiveHomeViewModel.uniqueVisibleVideos(videos).prefix(shelfLimit)))
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
