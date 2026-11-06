import Foundation

// The account settings the screens read (related videos, the first screen, the search service), loaded once and
// again whenever a change is saved.
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
      settings = try await service.settings()
    } catch {
      AppLogger.app.notice("account settings unavailable: \(String(describing: error), privacy: .public)")
    }
  }

  var hidesRelated: Bool { settings?.hideRelatedVideos ?? false }
}
