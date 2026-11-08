import SwiftUI

struct TVRootView: View {
  @StateObject private var coordinator: RootCoordinator
  @State private var splashPlaying: Bool
  private let shortIntro: Bool

  @MainActor
  init(dependencies: AppDependencies) {
    _coordinator = StateObject(wrappedValue: RootCoordinator(dependencies: dependencies))
    let intro = UserDefaults.standard.string(forKey: TVDeviceSetting.introKey)
    _splashPlaying = State(initialValue: intro != "off")
    shortIntro = intro == "short"
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
      case .authenticated where coordinator.isUsingOfflineSession:
        TVReconnectView(coordinator: coordinator)
      case .authenticated:
        TVShellView(coordinator: coordinator)
      }
    }
    .disabled(splashPlaying)
    .overlay {
      if splashPlaying { TVStartupSplash(short: shortIntro) { splashPlaying = false } }
    }
    .background(TVControlTrace())
    .task { await coordinator.bootstrap() }
    .onChange(of: String(describing: coordinator.state)) { _, state in TVJournal.note("app", "root \(state)") }
  }
}
