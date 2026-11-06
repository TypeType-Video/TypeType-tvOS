import Foundation

enum DeviceLoginLink {
  static func url(apiBase: URL, userCode: String) -> URL? {
    guard var components = URLComponents(url: apiBase, resolvingAgainstBaseURL: false) else {
      return nil
    }
    var segments = components.path.split(separator: "/").map(String.init)
    if segments.last == "api" { segments.removeLast() }
    components.path = "/" + (segments + ["link"]).joined(separator: "/")
    components.queryItems = [URLQueryItem(name: "code", value: userCode)]
    components.fragment = nil
    return components.url
  }

  static func label(for url: URL) -> String {
    let host = url.host ?? ""
    let port = url.port.map { ":\($0)" } ?? ""
    return host + port + url.path
  }
}
