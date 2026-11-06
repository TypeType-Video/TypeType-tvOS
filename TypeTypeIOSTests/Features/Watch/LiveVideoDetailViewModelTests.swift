import XCTest
@testable import TypeTypeIOS

@MainActor
final class LiveVideoDetailViewModelTests: XCTestCase {
  func testLoadsDescriptionRelatedVideosAndResumePoint() async {
    let video = LiveVideoItemFixture.make(id: "main", url: "https://example.test/main")
    let related = [
      LiveVideoItemFixture.make(id: "a", url: "https://example.test/a"),
      LiveVideoItemFixture.make(id: "main", url: "https://example.test/main"),
      LiveVideoItemFixture.make(id: "short", url: "https://example.test/short", isShort: true),
      LiveVideoItemFixture.make(id: "a", url: "https://example.test/a"),
    ]
    let model = LiveVideoDetailViewModel(
      video: video,
      stream: { _ in Self.stream(description: "Full description", subscribers: 1_200, related: related) },
      progress: { _ in 120_000 }
    )
    await model.load()
    XCTAssertEqual(model.description, "Full description")
    XCTAssertEqual(model.subscriberCount, 1_200)
    XCTAssertEqual(model.related?.map(\.id), ["a"])
    XCTAssertEqual(model.resumeSeconds, 120)
    XCTAssertEqual(model.resumeFraction ?? 0, 120.0 / 596.0, accuracy: 0.0001)
  }

  func testNearlyFinishedVideoStartsOver() async {
    let video = LiveVideoItemFixture.make()
    let model = LiveVideoDetailViewModel(
      video: video,
      stream: { _ in Self.stream(description: "", subscribers: -1, related: []) },
      progress: { _ in 580_000 }
    )
    await model.load()
    XCTAssertNil(model.resumeFraction)
    XCTAssertNil(model.subscriberCount)
    XCTAssertEqual(model.description, "A deterministic fixture.")
  }

  func testStreamFailureKeepsTheCardDetails() async {
    let model = LiveVideoDetailViewModel(
      video: LiveVideoItemFixture.make(),
      stream: { _ in throw NetworkError.statusCode(502, "Bad gateway") },
      progress: { _ in nil }
    )
    await model.load()
    XCTAssertEqual(model.related, [])
    XCTAssertNotNil(model.failure)
    XCTAssertNil(model.resumeSeconds)
  }

  func testRefreshPicksUpTheNewResumePoint() async {
    var position: Int64? = nil
    let model = LiveVideoDetailViewModel(
      video: LiveVideoItemFixture.make(),
      stream: { _ in Self.stream(description: "", subscribers: -1, related: []) },
      progress: { _ in position }
    )
    await model.load()
    XCTAssertNil(model.resumeFraction)
    position = 200_000
    await model.refreshProgress()
    XCTAssertEqual(model.resumeSeconds, 200)
    XCTAssertNotNil(model.resumeFraction)
  }

  private static func stream(description: String, subscribers: Int64, related: [LiveVideoItem]) -> LivePlaybackStream {
    LivePlaybackStream(
      id: "fixture", title: "Fixture", uploaderName: "Channel", uploaderURL: "", uploaderAvatarURL: "",
      thumbnailURL: "", description: description, duration: 596, viewCount: 0, likeCount: 0, dislikeCount: 0,
      uploadDate: "", uploaded: -1, uploaderSubscriberCount: subscribers, uploaderVerified: false, publishedAt: nil,
      startPosition: 0, hlsURL: "", videoStreams: [], audioStreams: [], videoOnlyStreams: [],
      subtitles: [], chapters: [], sponsorBlockSegments: [], relatedStreams: related, category: nil, isLive: false,
      isPostLive: false, isLiveContent: false
    )
  }
}
