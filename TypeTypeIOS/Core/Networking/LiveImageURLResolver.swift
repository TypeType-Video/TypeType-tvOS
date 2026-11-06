import Foundation

// Where a picture is shown decides how large Bilibili's image service has to render it.
enum LiveImageSize {
  // Lists, shelves, related videos and avatars.
  case card
  // The picture the player shows before the first frame.
  case poster
}

enum LiveImageURLResolver {
  static var baseURLProvider: () -> URL? = { nil }

  static func resolve(_ reference: String?, size: LiveImageSize = .card) -> URL? {
    guard var reference = reference?.trimmingCharacters(
      in: .whitespacesAndNewlines
    ), !reference.isEmpty
    else { return nil }
    // The server sometimes emits "httpss://".
    if reference.hasPrefix("httpss://") {
      reference = "https://" + reference.dropFirst("httpss://".count)
    } else if reference.hasPrefix("//") {
      reference = "https:" + reference
    }
    return resolve(URL(string: reference), size: size)
  }

  static func resolve(_ url: URL?, size: LiveImageSize = .card) -> URL? {
    guard let url else { return nil }
    if url.scheme == "http" || url.scheme == "https" {
      return remoteImage(url, size: size)
    }
    let reference = url.absoluteString
    if url.scheme == nil, reference.hasPrefix("//") {
      return resolve(URL(string: "https:" + reference), size: size)
    }
    guard let base = baseURLProvider() else { return url }
    let baseString = base.absoluteString.hasSuffix("/")
      ? String(base.absoluteString.dropLast())
      : base.absoluteString
    if reference.hasPrefix("/") {
      return URL(string: baseString + reference) ?? url
    }
    guard let root = URL(string: baseString + "/") else { return url }
    return URL(string: reference, relativeTo: root)?.absoluteURL ?? url
  }

  // Bilibili covers and avatars are several hundred kilobytes at full size; its image service scales them on
  // request. Like the web client, the picture is asked for at the size it is shown, and it goes through the
  // instance's /proxy, so the app never contacts the image host itself and ATS never sees an http address.
  private static func remoteImage(_ url: URL, size: LiveImageSize) -> URL {
    let target = proxiedTarget(of: url) ?? url
    guard let sized = BilibiliImage(target)?.url(for: size) else { return url }
    return throughInstance(sized)
  }

  private static func proxiedTarget(of url: URL) -> URL? {
    guard url.path.hasSuffix("/proxy"),
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let value = components.queryItems?.first(where: { $0.name == "url" })?.value
    else { return nil }
    return URL(string: value)
  }

  private static func throughInstance(_ url: URL) -> URL {
    guard let base = baseURLProvider() else { return url }
    let baseString = base.absoluteString.hasSuffix("/")
      ? String(base.absoluteString.dropLast())
      : base.absoluteString
    guard var components = URLComponents(string: baseString + "/proxy"),
      let value = url.absoluteString.addingPercentEncoding(withAllowedCharacters: componentAllowed)
    else { return url }
    components.percentEncodedQuery = "url=" + value
    return components.url ?? url
  }

  // The characters encodeURIComponent leaves alone, as the web client builds this address.
  private static let componentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
  )
}

private struct BilibiliImage {
  let host: String
  let path: String
  let query: String?

  init?(_ url: URL) {
    guard let host = url.host?.lowercased(),
      host.hasSuffix("hdslb.com") || host.hasSuffix("biliimg.com"),
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }
    // biliimg.com serves the same files as the hdslb image hosts.
    self.host = host.hasSuffix("biliimg.com") ? "i0.hdslb.com" : host
    self.path = components.percentEncodedPath
    self.query = components.percentEncodedQuery
  }

  func url(for size: LiveImageSize) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = host
    components.percentEncodedPath = path + suffix(for: size)
    components.percentEncodedQuery = query
    return components.url
  }

  // An address that already names a size, or any path other than a cover or an avatar, stays as it is.
  private func suffix(for size: LiveImageSize) -> String {
    guard !path.contains("@") else { return "" }
    if path.hasPrefix("/bfs/archive/") {
      return size == .poster ? "@1280w_720h_1c.webp" : "@672w_378h_1c.webp"
    }
    if path.hasPrefix("/bfs/face/") { return "@240w_240h_1c.webp" }
    return ""
  }
}
