import SwiftUI

@main
struct TypeTypeTVApp: App {
  @MainActor private let dependencies = AppDependencies.live(
    platform: LivePlatformServices(),
    crashReports: LiveCrashReportArchive()
  )

  var body: some Scene {
    WindowGroup {
      TVRootView(dependencies: dependencies)
        .preferredColorScheme(.dark)
    }
  }
}
