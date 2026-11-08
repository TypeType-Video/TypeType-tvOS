import SwiftUI

@main
struct TypeTypeTVApp: App {
  @MainActor private let dependencies = AppDependencies.live(
    platform: LivePlatformServices(),
    crashReports: LiveCrashReportArchive()
  )
  #if DEBUG
  @MainActor private let frameMonitor = TVFrameMonitor()
  #endif
  @Environment(\.scenePhase) private var scenePhase

  init() {
    Task { await TVJournal.shared.start() }
  }

  var body: some Scene {
    WindowGroup {
      TVRootView(dependencies: dependencies)
        .preferredColorScheme(.dark)
      #if DEBUG
        .onAppear { frameMonitor.startIfRequested() }
      #endif
    }
    .onChange(of: scenePhase) { _, phase in
      TVJournal.note("app", "scene \(phase)")
      Task { await TVJournal.shared.flush() }
    }
  }
}
