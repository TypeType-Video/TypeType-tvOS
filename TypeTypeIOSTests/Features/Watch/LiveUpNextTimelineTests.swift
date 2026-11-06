import XCTest
@testable import TypeTypeIOS

final class LiveUpNextTimelineTests: XCTestCase {
  func testWindowFollowsTheCountdownWithinBounds() {
    XCTAssertEqual(LiveUpNextTimeline.window(duration: 600, countdownSeconds: 10), 10)
    XCTAssertEqual(LiveUpNextTimeline.window(duration: 21, countdownSeconds: 10), 7)
    XCTAssertEqual(LiveUpNextTimeline.window(duration: 600, countdownSeconds: 1), 3)
    XCTAssertEqual(LiveUpNextTimeline.window(duration: 19, countdownSeconds: 10), 0)
  }

  func testInWindowFillAndSecondsLeft() {
    XCTAssertFalse(LiveUpNextTimeline.inWindow(position: 589, duration: 600, window: 10))
    XCTAssertTrue(LiveUpNextTimeline.inWindow(position: 590, duration: 600, window: 10))
    XCTAssertEqual(LiveUpNextTimeline.fill(position: 595, duration: 600, window: 10), 0.5, accuracy: 0.001)
    XCTAssertEqual(LiveUpNextTimeline.secondsLeft(position: 595.2, duration: 600), 5)
    XCTAssertEqual(LiveUpNextTimeline.secondsLeft(position: 700, duration: 600), 0)
  }
}
