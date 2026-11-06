import XCTest
@testable import TypeTypeIOS

@MainActor
final class LiveVideoBlockingTests: XCTestCase {
  private let video = LiveVideoItem(
    id: "v", title: "Clip", url: "https://example.test/v", thumbnailURL: "", uploaderName: "Channel",
    uploaderURL: "https://example.test/c", uploaderAvatarURL: "", duration: 60, viewCount: 0, uploadDate: "",
    uploaded: 0, streamType: "VIDEO_STREAM", isShortFormContent: false, uploaderVerified: false, isLive: false,
    isPostLive: false, isLiveContent: false, requiresMembership: false
  )

  func testLoadsTheBlockedStateOfTheVideoAndItsChannel() async {
    let blocking = LiveVideoBlocking(video: video, service: BlockedStub(channels: ["https://example.test/c"]), hidden: LiveHiddenVideos())
    await blocking.load()
    XCTAssertTrue(blocking.isLoaded)
    XCTAssertFalse(blocking.videoBlocked)
    XCTAssertTrue(blocking.channelBlocked)
  }

  func testUnblockingShowsTheVideoAgain() async {
    let service = BlockedStub(channels: [])
    let hidden = LiveHiddenVideos()
    let blocking = LiveVideoBlocking(video: video, service: service, hidden: hidden)
    await blocking.setVideoBlocked(true)
    XCTAssertTrue(hidden.hides(video))
    await blocking.setVideoBlocked(false)
    XCTAssertFalse(hidden.hides(video))
    XCTAssertEqual(service.removed, ["https://example.test/v"])
  }

  func testRefusedBlockIsUndone() async {
    let service = BlockedStub(channels: [])
    service.refuses = true
    let hidden = LiveHiddenVideos()
    let blocking = LiveVideoBlocking(video: video, service: service, hidden: hidden)
    await blocking.setChannelBlocked(true)
    XCTAssertFalse(blocking.channelBlocked)
    XCTAssertFalse(hidden.hides(video))
    XCTAssertTrue(blocking.failed)
  }
}

private final class BlockedStub: LiveContentControlsServiceProtocol {
  let channels: [String]
  var refuses = false
  private(set) var removed: [String] = []

  init(channels: [String]) { self.channels = channels }

  func items(kind: LiveContentControlKind) async throws -> [LiveContentControlItem] {
    kind == .blockedChannels ? channels.map { LiveContentControlItem(url: $0) } : []
  }

  func add(kind: LiveContentControlKind, item: LiveContentControlItem) async throws -> LiveContentControlItem {
    if refuses { throw URLError(.badServerResponse) }
    return item
  }

  func remove(kind: LiveContentControlKind, url: String) async throws { removed.append(url) }

  func keywords() async throws -> [LiveBlockedKeywordItem] { [] }

  func addKeyword(_ keyword: String) async throws -> LiveBlockedKeywordItem { throw CancellationError() }

  func removeKeyword(_ keyword: String) async throws {}
}
