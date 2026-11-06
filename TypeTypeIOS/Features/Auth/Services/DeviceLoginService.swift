import Foundation

protocol LiveDeviceLoginServiceProtocol {
  func start(deviceName: String) async throws -> DeviceLoginStart
  func poll(deviceCode: String) async throws -> DeviceLoginPoll
}

final class LiveDeviceLoginService: LiveDeviceLoginServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func start(deviceName: String) async throws -> DeviceLoginStart {
    try await apiClient.request(
      APIEndpoint(
        path: "/auth/device/start",
        method: .post,
        body: try APIEndpoint.jsonBody(DeviceLoginStartPayload(deviceName: deviceName)),
        retriesTransientFailures: false
      ),
      as: DeviceLoginStart.self
    )
  }

  func poll(deviceCode: String) async throws -> DeviceLoginPoll {
    let endpoint = APIEndpoint(
      path: "/auth/device/token",
      method: .post,
      body: try APIEndpoint.jsonBody(DeviceLoginTokenPayload(deviceCode: deviceCode)),
      retriesTransientFailures: false
    )
    do {
      let response = try await apiClient.request(endpoint, as: AuthAccessTokenResponse.self)
      return .approved(accessToken: response.accessToken)
    } catch NetworkError.statusCode(400, let message) {
      return DeviceLoginPoll(serverError: message)
    }
  }
}
