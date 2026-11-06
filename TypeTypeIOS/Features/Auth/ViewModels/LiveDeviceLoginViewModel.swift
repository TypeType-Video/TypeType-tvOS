import Combine
import Foundation

@MainActor
final class LiveDeviceLoginViewModel: ObservableObject {
  enum State: Equatable {
    case starting
    case showing(userCode: String, link: URL, scanned: Bool)
    case refused
    case unavailable
    case approved(accessToken: String)
  }

  @Published private(set) var state = State.starting

  private let service: LiveDeviceLoginServiceProtocol
  private let apiBase: URL
  private let deviceName: String
  private let now: () -> Date
  private let wait: (TimeInterval) async throws -> Void

  init(
    service: LiveDeviceLoginServiceProtocol,
    apiBase: URL,
    deviceName: String,
    now: @escaping () -> Date = Date.init,
    wait: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
  ) {
    self.service = service
    self.apiBase = apiBase
    self.deviceName = deviceName
    self.now = now
    self.wait = wait
  }

  // Runs until approved, unavailable or cancelled; a code that expires or is refused is replaced by a new one.
  func run() async {
    var failures = 0
    while !Task.isCancelled {
      state = .starting
      let started: DeviceLoginStart
      do {
        started = try await service.start(deviceName: deviceName)
      } catch {
        if Self.isUnsupported(error) {
          state = .unavailable
          return
        }
        failures += 1
        guard (try? await wait(Self.retryDelay(failures: failures))) != nil else { return }
        continue
      }
      failures = 0
      guard await showUntilDone(started) else { return }
    }
  }

  private func showUntilDone(_ started: DeviceLoginStart) async -> Bool {
    guard let link = DeviceLoginLink.url(apiBase: apiBase, userCode: started.userCode) else {
      state = .unavailable
      return false
    }
    var interval = TimeInterval(max(started.interval, 1))
    let lifetime = max(TimeInterval(started.expiresIn) - Self.renewMargin, interval)
    let renewAt = now().addingTimeInterval(lifetime)
    state = .showing(userCode: started.userCode, link: link, scanned: false)
    while now() < renewAt {
      guard (try? await wait(interval)) != nil else { return false }
      let result: DeviceLoginPoll
      do {
        result = try await service.poll(deviceCode: started.deviceCode)
      } catch {
        if Self.isUnsupported(error) {
          state = .unavailable
          return false
        }
        continue
      }
      switch result {
      case let .approved(accessToken):
        state = .approved(accessToken: accessToken)
        return false
      case let .pending(scanned):
        state = .showing(userCode: started.userCode, link: link, scanned: scanned)
      case .slowDown:
        interval += Self.slowDownStep
      case .expired:
        return true
      case .denied:
        state = .refused
        guard (try? await wait(Self.refusedPause)) != nil else { return false }
        return true
      }
    }
    return true
  }

  // A server without device login answers 404, or 403 when an administrator turned it off.
  private static func isUnsupported(_ error: Error) -> Bool {
    guard case let NetworkError.statusCode(code, _) = error else { return false }
    return code == 404 || code == 403
  }

  static func retryDelay(failures: Int) -> TimeInterval {
    min(4 * pow(2, Double(min(failures - 1, 3))), 30)
  }

  private static let renewMargin: TimeInterval = 15
  private static let slowDownStep: TimeInterval = 5
  private static let refusedPause: TimeInterval = 3
}
