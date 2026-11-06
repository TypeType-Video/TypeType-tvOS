import Foundation

extension AppDependencies {
  func diagnosticScope() -> LiveDiagnosticScope? {
    guard let serverID = serverStore.selectedServerID(),
      let session = sessionStore.session(forServerID: serverID)
    else {
      return nil
    }
    return LiveDiagnosticScope(
      serverID: serverID,
      accountID: session.userID
    )
  }
}

@MainActor
extension AppDependencies {
  func invalidateIdentityScopedRuntimeState() {
    playbackCoordinator.endSession()
    notificationCenter.clear()
    deArrowStore.invalidatePreferences()
    downloadCenter.cancelTracking()
    hiddenVideos.clear()
  }
}
