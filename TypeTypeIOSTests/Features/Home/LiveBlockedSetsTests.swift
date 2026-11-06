import XCTest
@testable import TypeTypeIOS

final class LiveBlockedSetsTests: XCTestCase {
  private func video(_ id: String, channel: String = "") -> LiveVideoItem {
    LiveVideoItem(
      id: id, title: id, url: "https://www.youtube.com/watch?v=\(id)", thumbnailURL: "",
      uploaderName: "", uploaderURL: channel, uploaderAvatarURL: "", duration: 60, viewCount: 0, uploadDate: "",
      uploaded: 0, streamType: "VIDEO_STREAM", isShortFormContent: false, uploaderVerified: false, isLive: false,
      isPostLive: false, isLiveContent: false, requiresMembership: false
    )
  }

  func testLeavesOutBlockedVideosAndChannels() {
    let sets = LiveBlockedSets(
      videos: ["https://www.youtube.com/watch?v=b"],
      channels: ["https://www.youtube.com/@blocked"]
    )
    let list = [video("a"), video("b"), video("c", channel: "https://www.youtube.com/@blocked"), video("d", channel: "https://www.youtube.com/@fine")]
    XCTAssertEqual(sets.filter(list).map(\.id), ["a", "d"])
    XCTAssertEqual(LiveBlockedSets().filter(list).count, 4)
  }

  func testTheHomeLeavesBlockedVideosOutOfEveryRow() async throws {
    let trending = [video("a"), video("b"), video("c")]
    let loader = LiveShelfHomeLoader(sources: .init(
      recommendations: { [] }, history: { [] }, subscriptionFeed: { [] }, trending: { $0 == 0 ? trending : [] },
      watchLater: { [self.video("b"), self.video("d")] }, favorites: { [] },
      blocked: { LiveBlockedSets(videos: ["https://www.youtube.com/watch?v=b"]) }
    ))
    let home = try await loader.load()
    XCTAssertFalse(home.featured.contains { $0.id == "b" })
    XCTAssertEqual(home.shelves.first { $0.id == "trending" }?.videos.map(\.id), ["a", "c"])
    XCTAssertEqual(home.shelves.first { $0.id == "watch-later" }?.videos.map(\.id), ["d"])
  }
}
