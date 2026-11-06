import XCTest
@testable import TypeTypeIOS

final class LiveStreamRefreshClaimTests: XCTestCase {
  private let loaded = Date(timeIntervalSince1970: 1_000_000)

  func testAFreshStreamIsNotRefreshed() {
    var claim = LiveStreamRefreshClaim()
    XCTAssertFalse(claim.claim(loadedAt: loaded, now: loaded.addingTimeInterval(9 * 60 + 59)))
  }

  func testAStreamOfTenMinutesIsRefreshedOnce() {
    var claim = LiveStreamRefreshClaim()
    let later = loaded.addingTimeInterval(10 * 60)
    XCTAssertTrue(claim.claim(loadedAt: loaded, now: later))
    XCTAssertFalse(claim.claim(loadedAt: loaded, now: later.addingTimeInterval(30)))
  }

  func testTheRefreshedStreamMayBeRefreshedAgainWhenItAgesToo() {
    var claim = LiveStreamRefreshClaim()
    XCTAssertTrue(claim.claim(loadedAt: loaded, now: loaded.addingTimeInterval(700)))
    let reloaded = loaded.addingTimeInterval(700)
    XCTAssertFalse(claim.claim(loadedAt: reloaded, now: reloaded.addingTimeInterval(60)))
    XCTAssertTrue(claim.claim(loadedAt: reloaded, now: reloaded.addingTimeInterval(601)))
  }

  func testOnlyBilibiliAndNicoNicoLinksExpire() {
    XCTAssertTrue(LiveStreamRefreshClaim.refreshesExpiredLinks(videoURL: "https://www.nicovideo.jp/watch/sm9"))
    XCTAssertTrue(LiveStreamRefreshClaim.refreshesExpiredLinks(videoURL: "https://www.bilibili.com/video/BV1xx411c7mD?p=1"))
    XCTAssertFalse(LiveStreamRefreshClaim.refreshesExpiredLinks(videoURL: "https://www.youtube.com/watch?v=abc"))
    XCTAssertFalse(LiveStreamRefreshClaim.refreshesExpiredLinks(videoURL: "https://evilbilibili.com/x"))
  }
}
