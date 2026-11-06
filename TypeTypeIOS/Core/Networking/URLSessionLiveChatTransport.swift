import Foundation

// Carries the live chat stream over URLSession. It has a session of its own: the API and media sessions end a
// transfer after 120 to 180 seconds, and a live can run for hours.
struct URLSessionLiveChatTransport: LiveChatTransport, @unchecked Sendable {
  let client: URLSessionAPIClient
  var session: URLSession = Self.makeSession()

  // The server sends a keep-alive every 15 seconds; a minute without a byte means the connection is dead.
  static let idleTimeout: TimeInterval = 60

  func open(videoURL: String) async throws -> AsyncThrowingStream<UInt8, Error> {
    try DebugNetworkOutage.check()
    // The stream is public on an open instance; a signed-in session sends its token like every other request.
    let signedIn = client.accessTokenProvider() != nil
    var request = try client.makeURLRequest(
      APIEndpoint(
        path: "/live-chat",
        method: .get,
        queryItems: [URLQueryItem(name: "url", value: videoURL)],
        requiresAuth: signedIn,
        timeoutInterval: Self.idleTimeout
      )
    )
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    let (bytes, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      throw LiveChatRefused(
        status: http.statusCode,
        retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
      )
    }
    return AsyncThrowingStream { continuation in
      let pump = Task {
        do {
          for try await byte in bytes { continuation.yield(byte) }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in pump.cancel() }
    }
  }

  static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = idleTimeout
    configuration.timeoutIntervalForResource = 24 * 60 * 60
    configuration.waitsForConnectivity = false
    return URLSession(configuration: configuration)
  }
}
