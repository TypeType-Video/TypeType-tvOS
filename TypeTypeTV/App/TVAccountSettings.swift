import Foundation

@MainActor
final class TVAccountSettings: ObservableObject {
  @Published private(set) var settings: LiveSettings?
  private let service: LiveSettingsServiceProtocol
  private var observation: NSObjectProtocol?

  init(service: LiveSettingsServiceProtocol) {
    self.service = service
    observation = NotificationCenter.default.addObserver(forName: .liveSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in await self?.load() }
    }
  }

  deinit {
    if let observation { NotificationCenter.default.removeObserver(observation) }
  }

  func load() async {
    do {
      let loaded = try await service.settings()
      settings = loaded
      UserDefaults.standard.set(loaded.defaultLandingPage, forKey: Self.landingKey)
    } catch {
      AppLogger.app.notice("account settings unavailable: \(String(describing: error), privacy: .public)")
    }
  }

  var landingPage: String? {
    settings?.defaultLandingPage ?? UserDefaults.standard.string(forKey: Self.landingKey)
  }

  private static let landingKey = "tv.startup.landing"

  var hidesRelated: Bool { settings?.hideRelatedVideos ?? false }
}
