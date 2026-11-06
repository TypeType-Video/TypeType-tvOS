import XCTest
@testable import TypeTypeIOS

final class LiveShelfHomeLoaderTests: XCTestCase {
  func testFeaturesRecommendationsAndBuildsTheRows() async throws {
    let recommended = (1...6).map { Self.video("r\($0)", described: $0 != 2) }
    let loader = LiveShelfHomeLoader(sources: .init(
      recommendations: { recommended },
      history: { [LiveHistoryItem(id: "h", url: "https://example.test/h", title: "Half", duration: 600, progress: 300, watchedAt: 5)] },
      subscriptionFeed: { [Self.video("s1"), Self.video("short", short: true)] },
      trending: { $0 == 0 ? [Self.video("t1")] : $0 == 5 ? [Self.video("b1")] : [] },
      watchLater: { [] },
      favorites: { [Self.video("f1")] }
    ))
    let home = try await loader.load()
    XCTAssertEqual(home.featured.map(\.id), ["r1", "r3", "r4", "r5"])
    XCTAssertEqual(home.shelves.map(\.id), ["continue", "recommended", "subscriptions", "trending", "trending-bilibili", "favorites"])
    XCTAssertEqual(home.shelves[1].videos.map(\.id), ["r2", "r6"])
    XCTAssertEqual(home.shelves[2].videos.map(\.id), ["s1"])
    XCTAssertEqual(home.shelves[0].progress["https://example.test/h"], 0.5)
  }

  func testFallsBackToTrendingWithoutRecommendations() async throws {
    let loader = LiveShelfHomeLoader(sources: .init(
      recommendations: { [] },
      history: { throw NetworkError.transport },
      subscriptionFeed: { throw NetworkError.transport },
      trending: { $0 == 0 ? [Self.video("t1"), Self.video("t2")] : [] },
      watchLater: { throw NetworkError.transport },
      favorites: { throw NetworkError.transport }
    ))
    let home = try await loader.load()
    XCTAssertEqual(home.featured.map(\.id), ["t1", "t2"])
    XCTAssertEqual(home.shelves.map(\.id), ["trending"])
  }

  func testFailsOnlyWhenEveryMainSourceFails() async {
    let loader = LiveShelfHomeLoader(sources: .init(
      recommendations: { throw NetworkError.statusCode(502, nil) },
      history: { throw NetworkError.transport },
      subscriptionFeed: { throw NetworkError.transport },
      trending: { _ in throw NetworkError.transport },
      watchLater: { [Self.video("w1")] },
      favorites: { [] }
    ))
    do {
      _ = try await loader.load()
      XCTFail("expected a failure")
    } catch {
      XCTAssertNotNil(error as? NetworkError)
    }
  }

  @MainActor
  func testViewModelShowsFailureThenRetries() async {
    var attempts = 0
    let model = LiveShelfHomeViewModel {
      attempts += 1
      if attempts == 1 { throw NetworkError.transport }
      return LiveShelfHome(featured: [Self.video("a")], shelves: [])
    }
    await model.loadIfNeeded()
    guard case .failed = model.state else { return XCTFail("expected a failure") }
    await model.reload()
    XCTAssertEqual(model.state, .loaded(LiveShelfHome(featured: [Self.video("a")], shelves: [])))
  }

  private static func video(_ id: String, described: Bool = true, short: Bool = false) -> LiveVideoItem {
    let base = LiveVideoItemFixture.make(id: id, url: "https://example.test/\(id)", isShort: short)
    guard !described else { return base }
    return LiveVideoItem(
      id: base.id, title: base.title, url: base.url, thumbnailURL: base.thumbnailURL,
      uploaderName: base.uploaderName, uploaderURL: base.uploaderURL, uploaderAvatarURL: base.uploaderAvatarURL,
      duration: base.duration, viewCount: base.viewCount, uploadDate: base.uploadDate, uploaded: base.uploaded,
      streamType: base.streamType, isShortFormContent: base.isShortFormContent, uploaderVerified: base.uploaderVerified,
      shortDescription: nil, publishedAt: base.publishedAt, isLive: base.isLive, isPostLive: base.isPostLive,
      isLiveContent: base.isLiveContent, requiresMembership: base.requiresMembership
    )
  }
}
