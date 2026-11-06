import SwiftUI

struct TVRootView: View {
  @StateObject private var coordinator: RootCoordinator
  @State private var splashPlaying = true

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
    // The app starts under the intro; it takes no remote press until the intro is gone.
    .disabled(splashPlaying)
    .overlay {
      if splashPlaying { TVStartupSplash { splashPlaying = false } }
    }
    .task { await coordinator.bootstrap() }
  }
}
