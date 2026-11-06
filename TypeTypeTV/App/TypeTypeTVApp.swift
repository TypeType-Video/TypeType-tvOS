import SwiftUI

@main
struct TypeTypeTVApp: App {
  @MainActor private let dependencies = AppDependencies.live(
    platform: LivePlatformServices(),
    crashReports: LiveCrashReportArchive()
  )

  init() {
    // AVPlayerViewController needs an AVPlayer: the TV plays through the local HLS bridge, never the in-house
    // sample buffer renderer, which only the iPhone draws controls for.
    UserDefaults.standard.register(defaults: [LivePlayerController.nativePlaybackKey: false])
  }

  var body: some Scene {
    WindowGroup {
      TVRootView(dependencies: dependencies)
        .preferredColorScheme(.dark)
    }
  }
}
