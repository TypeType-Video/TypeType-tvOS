import XCTest
@testable import TypeTypeIOS

final class LiveCaptionStyleChoicesTests: XCTestCase {
  func testDefaultsMatchTheAndroidApp() {
    let styles = LiveCaptionStyles()
    XCTAssertEqual(styles.sizePercent, 100)
    XCTAssertEqual(styles.backgroundOpacityPercent, 100)
    XCTAssertEqual(styles.foregroundColor, "#ffffff")
  }

  func testEachChoiceMovesOneStepAndWraps() {
    var styles = LiveCaptionStyles()
    styles = styles.nextSize()
    XCTAssertEqual(styles.fontSize, "125%")
    styles.fontSize = "200%"
    XCTAssertEqual(styles.nextSize().fontSize, "75%")
    XCTAssertEqual(styles.nextColor().textColor, "#ffeb3b")
    let background = styles.nextBackground()
    XCTAssertEqual(background.textBackground, "#000000")
    XCTAssertEqual(background.textBackgroundOpacity, "0%")
  }
}
