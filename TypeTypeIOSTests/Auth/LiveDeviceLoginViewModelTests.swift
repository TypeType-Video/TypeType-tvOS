import Foundation
import XCTest
@testable import TypeTypeIOS

@MainActor
final class LiveDeviceLoginViewModelTests: XCTestCase {
  func testShowsTheCodeThenSignsInWhenApproved() async throws {
    let service = ScriptedDeviceLoginService(
      starts: [.success(Self.start(code: "AAAA"))],
      polls: [.success(.pending(scanned: false)), .success(.pending(scanned: true)), .success(.approved(accessToken: "t"))]
    )
    let clock = FakeClock()
    let model = try makeModel(service, clock)
    var seen: [LiveDeviceLoginViewModel.State] = []
    let observation = model.$state.sink { if seen.last != $0 { seen.append($0) } }
    await model.run()
    observation.cancel()
    let link = try XCTUnwrap(URL(string: "https://example.test/link?code=AAAA"))
    XCTAssertEqual(seen, [
      .starting,
      .showing(userCode: "AAAA", link: link, scanned: false),
      .showing(userCode: "AAAA", link: link, scanned: true),
      .approved(accessToken: "t"),
    ])
    XCTAssertEqual(clock.waits, [5, 5, 5])
  }

  func testRefusedCodeIsReplacedByANewOne() async throws {
    let service = ScriptedDeviceLoginService(
      starts: [.success(Self.start(code: "AAAA")), .success(Self.start(code: "BBBB"))],
      polls: [.success(.denied), .success(.approved(accessToken: "t"))]
    )
    let clock = FakeClock()
    let model = try makeModel(service, clock)
    var seen: [LiveDeviceLoginViewModel.State] = []
    let observation = model.$state.sink { seen.append($0) }
    await model.run()
    observation.cancel()
    XCTAssertTrue(seen.contains(.refused))
    XCTAssertEqual(service.startCount, 2)
    XCTAssertEqual(model.state, .approved(accessToken: "t"))
    XCTAssertEqual(clock.waits, [5, 3, 5])
  }

  func testSlowDownWidensTheInterval() async throws {
    let service = ScriptedDeviceLoginService(
      starts: [.success(Self.start(code: "AAAA"))],
      polls: [.success(.slowDown), .success(.approved(accessToken: "t"))]
    )
    let clock = FakeClock()
    try await makeModel(service, clock).run()
    XCTAssertEqual(clock.waits, [5, 10])
  }

  func testExpiringCodeIsRenewedBeforeItLapses() async throws {
    let service = ScriptedDeviceLoginService(
      starts: [.success(Self.start(code: "AAAA", expiresIn: 30)), .success(Self.start(code: "BBBB"))],
      polls: [.success(.pending(scanned: false)), .success(.pending(scanned: false)), .success(.pending(scanned: false)),
              .success(.approved(accessToken: "t"))]
    )
    let clock = FakeClock()
    try await makeModel(service, clock).run()
    XCTAssertEqual(service.startCount, 2)
  }

  func testServerWithoutDeviceLoginIsUnavailable() async throws {
    let service = ScriptedDeviceLoginService(starts: [.failure(NetworkError.statusCode(404, nil))], polls: [])
    let model = try makeModel(service, FakeClock())
    await model.run()
    XCTAssertEqual(model.state, .unavailable)
  }

  func testFailedStartsBackOffBeforeRetrying() async throws {
    let service = ScriptedDeviceLoginService(
      starts: [.failure(NetworkError.transport), .failure(NetworkError.transport), .success(Self.start(code: "AAAA"))],
      polls: [.success(.approved(accessToken: "t"))]
    )
    let clock = FakeClock()
    try await makeModel(service, clock).run()
    XCTAssertEqual(clock.waits, [4, 8, 5])
    XCTAssertEqual(LiveDeviceLoginViewModel.retryDelay(failures: 9), 30)
  }

  private func makeModel(_ service: ScriptedDeviceLoginService, _ clock: FakeClock) throws -> LiveDeviceLoginViewModel {
    LiveDeviceLoginViewModel(
      service: service,
      apiBase: try XCTUnwrap(URL(string: "https://example.test/api")),
      deviceName: "Apple TV",
      now: { clock.now },
      wait: { clock.advance($0) }
    )
  }

  private static func start(code: String, expiresIn: Int = 600) -> DeviceLoginStart {
    DeviceLoginStart(deviceCode: "device-\(code)", userCode: code, expiresIn: expiresIn, interval: 5)
  }
}

private final class FakeClock {
  private(set) var now = Date(timeIntervalSince1970: 0)
  private(set) var waits: [TimeInterval] = []

  func advance(_ seconds: TimeInterval) {
    waits.append(seconds)
    now = now.addingTimeInterval(seconds)
  }
}

private final class ScriptedDeviceLoginService: LiveDeviceLoginServiceProtocol {
  private var starts: [Result<DeviceLoginStart, Error>]
  private var polls: [Result<DeviceLoginPoll, Error>]
  private(set) var startCount = 0

  init(starts: [Result<DeviceLoginStart, Error>], polls: [Result<DeviceLoginPoll, Error>]) {
    self.starts = starts
    self.polls = polls
  }

  func start(deviceName: String) async throws -> DeviceLoginStart {
    startCount += 1
    guard !starts.isEmpty else { throw CancellationError() }
    return try starts.removeFirst().get()
  }

  func poll(deviceCode: String) async throws -> DeviceLoginPoll {
    guard !polls.isEmpty else { throw CancellationError() }
    return try polls.removeFirst().get()
  }
}
