import XCTest
@testable import TypeTypeIOS

final class LiveImageURLResolverTests: XCTestCase {
  private let instance = URL(string: "https://watch.example/api")

  override func setUp() {
    super.setUp()
    LiveImageURLResolver.baseURLProvider = { [instance] in instance }
  }

  override func tearDown() {
    LiveImageURLResolver.baseURLProvider = { nil }
    super.tearDown()
  }

  private func proxied(_ address: String) -> String {
    "https://watch.example/api/proxy?url=" + address
      .addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()"))!
  }

  private func resolved(_ reference: String, size: LiveImageSize = .card) -> String? {
    LiveImageURLResolver.resolve(reference, size: size)?.absoluteString
  }

  func testBilibiliCoversAndAvatarsAreAskedForAtTheirShownSize() {
    XCTAssertEqual(
      resolved("https://i1.hdslb.com/bfs/archive/abc.jpg"),
      proxied("https://i1.hdslb.com/bfs/archive/abc.jpg@672w_378h_1c.webp")
    )
    XCTAssertEqual(
      resolved("https://i1.hdslb.com/bfs/archive/abc.jpg", size: .poster),
      proxied("https://i1.hdslb.com/bfs/archive/abc.jpg@1280w_720h_1c.webp")
    )
    // An avatar has one size, wherever it is shown.
    XCTAssertEqual(
      resolved("https://i1.hdslb.com/bfs/face/def.jpg", size: .poster),
      proxied("https://i1.hdslb.com/bfs/face/def.jpg@240w_240h_1c.webp")
    )
  }

  // The server sends http avatars; ATS only allows local networking, so they never loaded on Apple TV.
  func testHTTPAndSchemeRelativeAddressesBecomeHTTPS() {
    XCTAssertEqual(
      resolved("http://i2.hdslb.com/bfs/face/def.jpg"),
      proxied("https://i2.hdslb.com/bfs/face/def.jpg@240w_240h_1c.webp")
    )
    XCTAssertEqual(
      resolved("//i0.hdslb.com/bfs/archive/abc.jpg"),
      proxied("https://i0.hdslb.com/bfs/archive/abc.jpg@672w_378h_1c.webp")
    )
  }

  func testBiliimgUsesTheHdslbImageHost() {
    XCTAssertEqual(
      resolved("https://archive.biliimg.com/bfs/archive/abc.jpg"),
      proxied("https://i0.hdslb.com/bfs/archive/abc.jpg@672w_378h_1c.webp")
    )
  }

  func testAnAddressThatNamesASizeOrIsNeitherCoverNorAvatarKeepsItsPath() {
    XCTAssertEqual(
      resolved("https://i0.hdslb.com/bfs/archive/abc.jpg@320w_180h.webp"),
      proxied("https://i0.hdslb.com/bfs/archive/abc.jpg@320w_180h.webp")
    )
    XCTAssertEqual(
      resolved("https://i0.hdslb.com/bfs/emote/smile.png"),
      proxied("https://i0.hdslb.com/bfs/emote/smile.png")
    )
  }

  func testTheQueryOfABilibiliImageSurvives() {
    XCTAssertEqual(
      resolved("https://i0.hdslb.com/bfs/archive/abc.jpg?v=3"),
      proxied("https://i0.hdslb.com/bfs/archive/abc.jpg@672w_378h_1c.webp?v=3")
    )
  }

  func testResolvingAResolvedAddressChangesNothing() throws {
    let once = try XCTUnwrap(LiveImageURLResolver.resolve("http://i0.hdslb.com/bfs/archive/abc.jpg"))
    XCTAssertEqual(LiveImageURLResolver.resolve(once), once)
  }

  func testWithoutAnInstanceTheImageHostIsAskedDirectly() {
    LiveImageURLResolver.baseURLProvider = { nil }
    XCTAssertEqual(
      resolved("http://i0.hdslb.com/bfs/archive/abc.jpg"),
      "https://i0.hdslb.com/bfs/archive/abc.jpg@672w_378h_1c.webp"
    )
  }

  func testOtherImagesAreNotChanged() {
    XCTAssertEqual(
      resolved("https://i.ytimg.com/vi/abc/hqdefault.jpg"),
      "https://i.ytimg.com/vi/abc/hqdefault.jpg"
    )
    XCTAssertEqual(
      resolved("https://nicovideo.cdn.nimg.jp/thumbnails/1/1.2.L"),
      "https://nicovideo.cdn.nimg.jp/thumbnails/1/1.2.L"
    )
  }

  func testInstanceRelativeAddressesStillResolveAgainstTheInstance() {
    XCTAssertEqual(resolved("/media/m1_abc"), "https://watch.example/api/media/m1_abc")
  }
}
