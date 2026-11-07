import SwiftUI

private struct TVVideoMenuKey: EnvironmentKey {
  static let defaultValue: ((TVVideoMenuRequest) -> Void)? = nil
}

private struct TVMenuPlaylistKey: EnvironmentKey {
  static let defaultValue: TVMenuPlaylist? = nil
}

struct TVMenuPlaylist {
  let id: String
  let name: String
  let onRemoved: (LiveVideoItem) -> Void
}

struct TVVideoMenuRequest {
  let video: LiveVideoItem
  let playlist: TVMenuPlaylist?
}

private struct TVVideoMenuShownKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var tvVideoMenu: ((TVVideoMenuRequest) -> Void)? {
    get { self[TVVideoMenuKey.self] }
    set { self[TVVideoMenuKey.self] = newValue }
  }

  var tvMenuPlaylist: TVMenuPlaylist? {
    get { self[TVMenuPlaylistKey.self] }
    set { self[TVMenuPlaylistKey.self] = newValue }
  }

  var tvVideoMenuShown: Bool {
    get { self[TVVideoMenuShownKey.self] }
    set { self[TVVideoMenuShownKey.self] = newValue }
  }
}

struct TVVideoMenuTarget: ViewModifier {
  let video: LiveVideoItem
  @Binding var openedAt: Date?
  let refocus: () -> Void
  @Environment(\.tvVideoMenu) private var openMenu
  @Environment(\.tvVideoMenuShown) private var menuShown
  @Environment(\.tvMenuPlaylist) private var playlist

  func body(content: Content) -> some View {
    content
      .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in
        guard let openMenu else { return }
        openedAt = Date()
        openMenu(TVVideoMenuRequest(video: video, playlist: playlist))
      })
      .onChange(of: menuShown) { _, shown in
        guard !shown, openedAt != nil else { return }
        openedAt = nil
        Task { refocus() }
      }
  }

  static func swallowsRelease(_ openedAt: Date?) -> Bool {
    guard let openedAt else { return false }
    return Date().timeIntervalSince(openedAt) < 0.8
  }
}

extension View {
  func tvVideoMenu(_ video: LiveVideoItem, openedAt: Binding<Date?>, refocus: @escaping () -> Void) -> some View {
    modifier(TVVideoMenuTarget(video: video, openedAt: openedAt, refocus: refocus))
  }
}
