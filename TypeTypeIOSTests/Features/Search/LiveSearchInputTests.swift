import XCTest
@testable import TypeTypeIOS

final class LiveSearchInputTests: XCTestCase {
  func testKeysFillWholeRows() {
    XCTAssertEqual(LiveSearchInput.keys.count % LiveSearchInput.keysPerRow, 0)
  }

  func testSpacesAreNeverLeadingOrDoubled() {
    XCTAssertEqual(LiveSearchInput.append("", " "), "")
    XCTAssertEqual(LiveSearchInput.append("wing ", " "), "wing ")
    XCTAssertEqual(LiveSearchInput.append("wing", " "), "wing ")
  }

  func testLengthStopsAtForty() {
    let full = String(repeating: "a", count: 40)
    XCTAssertEqual(LiveSearchInput.append(full, "b"), full)
  }

  func testDeleteAndNormalize() {
    XCTAssertEqual(LiveSearchInput.delete("wing"), "win")
    XCTAssertEqual(LiveSearchInput.delete(""), "")
    XCTAssertEqual(LiveSearchInput.normalized("  Wing It!  Été 2 "), "wing it été 2 ")
  }
}
