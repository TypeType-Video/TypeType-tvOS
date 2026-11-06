import XCTest
@testable import TypeTypeIOS

@MainActor
final class LiveTVSettingsModelTests: XCTestCase {
  func testChangeSavesAndKeepsTheServerAnswer() async {
    let service = SettingsStub()
    let model = LiveTVSettingsModel(settingsService: service, contentControls: ControlsStub())
    await model.load()
    await model.change { $0.autoplay = false }
    XCTAssertEqual(service.saved.map(\.autoplay), [false])
    XCTAssertEqual(model.settings?.autoplay, false)
    XCTAssertEqual(model.blockedChannels.map(\.url), ["https://example.test/c"])
  }

  func testSavedChangeIsAnnounced() async {
    let model = LiveTVSettingsModel(settingsService: SettingsStub(), contentControls: ControlsStub())
    await model.load()
    let announced = expectation(forNotification: .liveSettingsDidChange, object: nil)
    await model.change { $0.hideShorts = true }
    await fulfillment(of: [announced], timeout: 1)
  }

  func testRefusedChangeComesBack() async {
    let service = SettingsStub()
    service.refuses = true
    let model = LiveTVSettingsModel(settingsService: service, contentControls: ControlsStub())
    await model.load()
    await model.change { $0.hideShorts = true }
    XCTAssertEqual(model.settings?.hideShorts, false)
    XCTAssertNotNil(model.failure)
  }

  func testUnblockRemovesTheChannel() async {
    let controls = ControlsStub()
    let model = LiveTVSettingsModel(settingsService: SettingsStub(), contentControls: controls)
    await model.load()
    await model.unblock(LiveContentControlItem(url: "https://example.test/c", name: "C", thumbnailURL: nil, timestamp: 0, global: nil))
    XCTAssertTrue(model.blockedChannels.isEmpty)
    XCTAssertEqual(controls.removed, ["https://example.test/c"])
  }
}

private final class SettingsStub: LiveSettingsServiceProtocol {
  var refuses = false
  private(set) var saved: [LiveSettings] = []

  func settings() async throws -> LiveSettings { LiveSettings() }

  func update(_ settings: LiveSettings) async throws -> LiveSettings {
    if refuses { throw NetworkError.statusCode(500, nil) }
    saved.append(settings)
    return settings
  }
}

private final class ControlsStub: LiveContentControlsServiceProtocol {
  private(set) var removed: [String] = []

  func items(kind: LiveContentControlKind) async throws -> [LiveContentControlItem] {
    [LiveContentControlItem(url: "https://example.test/c", name: "C", thumbnailURL: nil, timestamp: 0, global: nil)]
  }

  func add(kind: LiveContentControlKind, item: LiveContentControlItem) async throws -> LiveContentControlItem { item }

  func remove(kind: LiveContentControlKind, url: String) async throws { removed.append(url) }

  func keywords() async throws -> [LiveBlockedKeywordItem] { [] }

  func addKeyword(_ keyword: String) async throws -> LiveBlockedKeywordItem { throw CancellationError() }

  func removeKeyword(_ keyword: String) async throws {}
}
