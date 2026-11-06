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

  var body: some Scene {
    WindowGroup {
      TVRootView(dependencies: dependencies)
        .preferredColorScheme(.dark)
      #if DEBUG
        .onAppear { frameMonitor.startIfRequested() }
      #endif
    }
  }
}
