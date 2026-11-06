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
        TVSignedInPlaceholder(coordinator: coordinator)
      }
    }
    .task { await coordinator.bootstrap() }
  }
}

private struct TVSignedInPlaceholder: View {
  @ObservedObject var coordinator: RootCoordinator

  var body: some View {
    ZStack {
      TVPalette.ink.ignoresSafeArea()
      VStack(spacing: 40) {
        TVBrandLogo(markSize: 96)
        Text(verbatim: coordinator.currentUser?.publicUsername ?? "")
          .font(TVType.headline)
          .foregroundStyle(TVPalette.textHigh)
        Button("Sign out") {
          Task { await coordinator.signOut() }
        }
        .buttonStyle(.tvPill)
      }
    }
  }
}
