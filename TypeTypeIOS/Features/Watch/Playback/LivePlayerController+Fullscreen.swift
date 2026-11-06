import Foundation

extension LivePlayerController {
  func enterNativeFullscreen(_ reason: String = "unspecified") {
    AppLogger.playback
      .info("fullscreen: enter requested reason=\(reason, privacy: .public) flag=\(self.isPresentingFullscreen, privacy: .public)")
    guard !isPresentingFullscreen else { return }
    fullscreen.present()
  }

  func exitNativeFullscreen(_ reason: String = "unspecified", byUser: Bool = false) {
    AppLogger.playback
      .info("fullscreen: exit requested reason=\(reason, privacy: .public) flag=\(self.isPresentingFullscreen, privacy: .public)")
    fullscreen.dismiss(byUser: byUser)
  }
}
