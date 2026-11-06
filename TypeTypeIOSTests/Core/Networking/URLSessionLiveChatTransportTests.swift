import XCTest
@testable import TypeTypeIOS

final class URLSessionLiveChatTransportTests: XCTestCase {
  override func setUp() {
    super.setUp()
    URLProtocolStub.reset()
  }

  override func tearDown() {
    URLProtocolStub.reset()
    super.tearDown()
  }

  private func transport(token: String? = "access-token") -> URLSessionLiveChatTransport {
    let client = URLSessionAPIClient(
      serverURLProvider: { URL(string: "https://example.test/api") },
      accessTokenProvider: { token }
    )
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSessionLiveChatTransport(client: client, session: URLSession(configuration: configuration))
  }

  private func stub(status: Int, headers: [String: String] = [:], body: String = "", check: ((URLRequest) -> Void)? = nil) {
    URLProtocolStub.register { request in
      check?(request)
      let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
      return (response, Data(body.utf8))
    }
  }

  func testAsksTheServerForTheStreamOfTheVideo() async throws {
    stub(status: 200, headers: ["Content-Type": "text/event-stream"]) { request in
      XCTAssertEqual(request.url?.path, "/api/live-chat")
      XCTAssertEqual(
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "url" }?.value,
        "https://www.youtube.com/watch?v=live"
      )
      XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream, application/json")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }
    _ = try await transport().open(videoURL: "https://www.youtube.com/watch?v=live")
  }

  func testAnOpenInstanceNeedsNoToken() async throws {
    stub(status: 200) { request in
      XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }
    _ = try await transport(token: nil).open(videoURL: "https://www.youtube.com/watch?v=live")
  }

  func testARefusalCarriesItsStatusAndRetryAfter() async {
    stub(status: 429, headers: ["Retry-After": "5"], body: "{\"error\":\"Live chat capacity is temporarily full\"}")
    do {
      _ = try await transport().open(videoURL: "https://www.youtube.com/watch?v=live")
      XCTFail("a 429 must be refused")
    } catch {
      XCTAssertEqual(error as? LiveChatRefused, LiveChatRefused(status: 429, retryAfter: 5))
    }
  }

  func testServiceReadsMessagesFromARealResponse() async {
    stub(
      status: 200,
      headers: ["Content-Type": "text/event-stream"],
      body: ": connected\n\nevent: message\ndata: {\"id\":\"chat-1\",\"text\":\"Hello\",\"receivedAtMs\":1}\n\nevent: ended\ndata: {}\n\n"
    )
    let service = LiveChatService(transport: transport(), pause: { _ in })
    var events: [LiveChatEvent] = []
    for await event in service.events(videoURL: "https://www.youtube.com/watch?v=live") { events.append(event) }
    XCTAssertEqual(events, [
      .connected,
      .message(LiveChatMessage(id: "chat-1", author: "", text: "Hello", moderator: false)),
      .ended,
    ])
  }

  func testTheStreamSessionOutlivesTheApiSessions() {
    let configuration = URLSessionLiveChatTransport.makeSession().configuration
    XCTAssertGreaterThan(configuration.timeoutIntervalForResource, 3_600)
    XCTAssertGreaterThan(configuration.timeoutIntervalForRequest, 15)
    XCTAssertNil(configuration.urlCache)
  }
}
