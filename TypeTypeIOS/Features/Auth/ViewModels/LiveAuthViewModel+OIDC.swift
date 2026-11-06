import Foundation

extension LiveAuthViewModel {
  func redirectToOIDCIfNeeded(using coordinator: RootCoordinator) async {
    guard oidcStatus?.autoRedirect == true, !didAutoRedirect else {
      return
    }
    didAutoRedirect = true
    await continueWithOIDC(using: coordinator)
  }

  func continueWithOIDC(using coordinator: RootCoordinator) async {
    guard oidcEnabled else { return }
    await perform {
      try await coordinator.continueWithOIDC()
    }
  }
}
