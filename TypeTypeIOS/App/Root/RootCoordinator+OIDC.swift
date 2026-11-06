import Foundation

extension RootCoordinator {
  func continueWithOIDC() async throws {
    let coordinator = OIDCAuthenticationCoordinator(
      oidcService: dependencies.oidcService,
      authService: dependencies.authService
    )
    completeAuthentication(try await coordinator.signIn())
  }
}
