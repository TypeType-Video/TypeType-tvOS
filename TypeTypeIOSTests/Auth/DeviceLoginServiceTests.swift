import Foundation
import XCTest
@testable import TypeTypeIOS

final class DeviceLoginServiceTests: XCTestCase {
  override func setUp() {
    super.setUp()
    URLProtocolStub.reset()
  }

  override func tearDown() {
    URLProtocolStub.reset()
    super.tearDown()
  }

  func testStartSendsTheDeviceName() async throws {
    URLProtocolStub.register { request in
      XCTAssertEqual(request.url?.path, "/api/auth/device/start")
      let body = try XCTUnwrap(URLProtocolStub.bodyData(from: request))
      let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]
      XCTAssertEqual(payload?["deviceName"], "Apple TV")
      return try Self.response(
        request,
        status: 200,
        body: #"{"deviceCode":"dc","userCode":"ABCD-EFGH","expiresIn":600,"interval":5}"#
      )
    }
    let started = try await makeService().start(deviceName: "Apple TV")
    XCTAssertEqual(started, DeviceLoginStart(deviceCode: "dc", userCode: "ABCD-EFGH", expiresIn: 600, interval: 5))
  }

  func testPollMapsTheServerAnswers() async throws {
    var answers: [(Int, String)] = [
      (400, #"{"error":"authorization scanned","code":"authorization_scanned"}"#),
      (400, #"{"error":"slow down","code":"slow_down"}"#),
      (200, #"{"accessToken":"device-token"}"#),
    ]
    URLProtocolStub.register { request in
      XCTAssertEqual(request.url?.path, "/api/auth/device/token")
      let (status, body) = answers.removeFirst()
      return try Self.response(request, status: status, body: body)
    }
    let service = makeService()
    let first = try await service.poll(deviceCode: "dc")
    let second = try await service.poll(deviceCode: "dc")
    let third = try await service.poll(deviceCode: "dc")
    XCTAssertEqual(first, .pending(scanned: true))
    XCTAssertEqual(second, .slowDown)
    XCTAssertEqual(third, .approved(accessToken: "device-token"))
  }

  func testServerErrorTextMapsToPollStates() {
    XCTAssertEqual(DeviceLoginPoll(serverError: "authorization pending"), .pending(scanned: false))
    XCTAssertEqual(DeviceLoginPoll(serverError: "access denied"), .denied)
    XCTAssertEqual(DeviceLoginPoll(serverError: "expired token"), .expired)
    XCTAssertEqual(DeviceLoginPoll(serverError: nil), .expired)
  }

  func testLinkPointsAtTheWebsiteRootWithTheCode() throws {
    let base = try XCTUnwrap(URL(string: "https://watch.example.test:8443/tt/api"))
    let link = try XCTUnwrap(DeviceLoginLink.url(apiBase: base, userCode: "ABCD-EFGH"))
    XCTAssertEqual(link.absoluteString, "https://watch.example.test:8443/tt/link?code=ABCD-EFGH")
    XCTAssertEqual(DeviceLoginLink.label(for: link), "watch.example.test:8443/tt/link")
  }

  private func makeService() -> LiveDeviceLoginService {
    LiveDeviceLoginService(
      apiClient: URLSessionAPIClient(
        serverURLProvider: { URL(string: "https://example.test/api") },
        accessTokenProvider: { nil },
        session: Self.makeSession()
      )
    )
  }

  private static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
  }

  private static func response(_ request: URLRequest, status: Int, body: String) throws -> (HTTPURLResponse, Data) {
    let url = try XCTUnwrap(request.url)
    let response = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
    )
    return (response, Data(body.utf8))
  }
}
