import XCTest
@testable import TypeTypeIOS

final class LiveSeekMathTests: XCTestCase {
  func testStepsGrowFromFiveSecondsUpToAShareOfTheVideo() {
    XCTAssertEqual(LiveSeekMath.scrubStep(press: 0, durationMilliseconds: 600_000), 5_000)
    XCTAssertEqual(LiveSeekMath.scrubStep(press: 10, durationMilliseconds: 600_000), 8_144)
    XCTAssertEqual(LiveSeekMath.scrubStep(press: 100, durationMilliseconds: 600_000), 15_000)
    XCTAssertEqual(LiveSeekMath.scrubStep(press: 300, durationMilliseconds: 36_000_000), 900_000)
    XCTAssertEqual(LiveSeekMath.scrubStep(press: 50, durationMilliseconds: 60_000), 10_000)
  }

  func testScrubAccumulatesOneTargetAndCommitsOnce() {
    var scrub = LiveScrubState()
    for _ in 0..<18 { scrub.move(current: 20_000, direction: 1, duration: 238_000) }
    let target = scrub.commit()
    XCTAssertNotNil(target)
    XCTAssertGreaterThan(target ?? 0, 20_000 + 18 * 5_000)
    XCTAssertFalse(scrub.isActive)
    XCTAssertEqual(scrub.presses, 0)
  }

  func testScrubStaysInsideTheVideo() {
    var scrub = LiveScrubState()
    scrub.move(current: 2_000, direction: -1, duration: 100_000)
    XCTAssertEqual(scrub.target, 0)
    for _ in 0..<40 { scrub.move(current: 0, direction: 1, duration: 100_000) }
    XCTAssertEqual(scrub.target, 100_000)
    XCTAssertEqual(LiveSeekMath.fraction(position: 50, duration: 0), 0)
  }
}
