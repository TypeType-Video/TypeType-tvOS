import XCTest
@testable import TypeTypeIOS

final class LiveDeArrowBatchTests: XCTestCase {
  private func video(_ id: String, title: String) -> LiveVideoItem {
    LiveVideoItem(
      id: id, title: title, url: "https://www.youtube.com/watch?v=\(id)", thumbnailURL: "https://i.ytimg.com/vi/\(id)/hq.jpg",
      uploaderName: "", uploaderURL: "", uploaderAvatarURL: "", duration: 60, viewCount: 0, uploadDate: "", uploaded: 0,
      streamType: "VIDEO_STREAM", isShortFormContent: false, uploaderVerified: false, isLive: false, isPostLive: false,
      isLiveContent: false, requiresMembership: false
    )
  }

  func testBrandingReplacesOnlyWhatChanged() {
    let original = video("abc", title: "SHOCKING!!")
    XCTAssertEqual(original.branded(LiveVideoBranding(title: original.title, thumbnailURL: original.thumbnail)), original)
    let branded = original.branded(LiveVideoBranding(title: "A calm title", thumbnailURL: URL(string: "https://example.test/t.jpg")))
    XCTAssertEqual(branded.title, "A calm title")
    XCTAssertEqual(branded.thumbnailURL, "https://example.test/t.jpg")
    XCTAssertEqual(branded.url, original.url)
  }

  func testTheHomeLoaderBrandsEveryRowAndTheFeaturedVideos() async throws {
    let trending = [video("a", title: "one"), video("b", title: "two")]
    let loader = LiveShelfHomeLoader(sources: .init(
      recommendations: { [] }, history: { [] }, subscriptionFeed: { [] }, trending: { $0 == 0 ? trending : [] },
      watchLater: { [] }, favorites: { [] },
      brand: { videos in videos.map { $0.branded(LiveVideoBranding(title: $0.title.uppercased(), thumbnailURL: $0.thumbnail)) } }
    ))
    let home = try await loader.load()
    XCTAssertEqual(home.featured.map(\.title), ["ONE", "TWO"])
    XCTAssertEqual(home.shelves.first { $0.id == "trending" }?.videos.map(\.title), ["ONE", "TWO"])
  }
}
