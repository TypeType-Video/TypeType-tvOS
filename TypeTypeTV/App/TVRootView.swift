import SwiftUI

struct TVRootView: View {
  @StateObject private var coordinator: RootCoordinator

  @MainActor
  init(dependencies: AppDependencies) {
    _coordinator = StateObject(wrappedValue: RootCoordinator(dependencies: dependencies))
  }

  var body: some View {
    Group {
      switch coordinator.state {
      case .booting:
        ZStack {
          TVPalette.ink.ignoresSafeArea()
          TVBrandLogo(markSize: 96)
        }
      case .serverSetup:
        TVServerSetupView(coordinator: coordinator)
      case .authentication:
        TVLoginView(coordinator: coordinator)
      case .authenticated:
        TVShellView(coordinator: coordinator)
      }
    }
    .task { await coordinator.bootstrap() }
  }
}
