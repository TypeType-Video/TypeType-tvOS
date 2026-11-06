import Combine
import Foundation

// The account settings the TV shows, saved one change at a time: the change shows at once and comes back if the
// server refuses it.
@MainActor
final class LiveTVSettingsModel: ObservableObject {
  @Published private(set) var settings: LiveSettings?
  @Published private(set) var blockedChannels: [LiveContentControlItem] = []
  @Published private(set) var failure: String?
  @Published private(set) var unreadNotifications: Int?

  private let settingsService: LiveSettingsServiceProtocol
  private let contentControls: LiveContentControlsServiceProtocol
  private let notifications: LiveNotificationsServiceProtocol?

  init(
    settingsService: LiveSettingsServiceProtocol,
    contentControls: LiveContentControlsServiceProtocol,
    notifications: LiveNotificationsServiceProtocol? = nil
  ) {
    self.settingsService = settingsService
    self.contentControls = contentControls
    self.notifications = notifications
  }

  func load() async {
    failure = nil
    async let current = settingsService.settings()
    async let blocked = contentControls.items(kind: .blockedChannels)
    do {
      settings = try await current
    } catch {
      failure = Self.message(error)
    }
    blockedChannels = (try? await blocked) ?? []
    if let notifications {
      do {
        unreadNotifications = try await notifications.unreadCount()
      } catch {
        unreadNotifications = nil
      }
    }
  }

  // Android TV's "Mark all as read": the new-video notifications of the account are cleared.
  func markNotificationsRead() async {
    guard let notifications else { return }
    do {
      _ = try await notifications.markAllRead()
      unreadNotifications = 0
      NotificationCenter.default.post(name: .liveSettingsDidChange, object: nil)
    } catch {
      failure = Self.message(error)
    }
  }

  func change(_ edit: (inout LiveSettings) -> Void) async {
    guard let before = settings else { return }
    var next = before
    edit(&next)
    guard next != before else { return }
    settings = next
    failure = nil
    do {
      settings = try await settingsService.update(next)
      NotificationCenter.default.post(name: .liveSettingsDidChange, object: nil)
    } catch {
      settings = before
      failure = Self.message(error)
    }
  }

  func unblock(_ channel: LiveContentControlItem) async {
    let before = blockedChannels
    blockedChannels.removeAll { $0.url == channel.url }
    do {
      try await contentControls.remove(kind: .blockedChannels, url: channel.url)
    } catch {
      blockedChannels = before
      failure = Self.message(error)
    }
  }

  private static func message(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(localized: "The change could not be saved. Check the connection and try again.")
  }
}

extension Notification.Name {
  // Screens built from the account settings, such as the TV home rows, load again when one changes.
  static let liveSettingsDidChange = Notification.Name("LiveSettingsDidChange")
}
