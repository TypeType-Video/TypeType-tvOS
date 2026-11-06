import Foundation

struct DeviceLoginStart: Decodable, Equatable {
  let deviceCode: String
  let userCode: String
  let expiresIn: Int
  let interval: Int
}

enum DeviceLoginPoll: Equatable {
  case approved(accessToken: String)
  case pending(scanned: Bool)
  case slowDown
  case expired
  case denied

  // The server's error text is its error code with spaces in place of underscores.
  init(serverError message: String?) {
    let code = (message ?? "").lowercased().replacingOccurrences(of: " ", with: "_")
    switch code {
    case "authorization_pending": self = .pending(scanned: false)
    case "authorization_scanned": self = .pending(scanned: true)
    case "slow_down": self = .slowDown
    case "access_denied": self = .denied
    default: self = .expired
    }
  }
}

struct DeviceLoginStartPayload: Encodable {
  let deviceName: String
}

struct DeviceLoginTokenPayload: Encodable {
  let deviceCode: String
}
