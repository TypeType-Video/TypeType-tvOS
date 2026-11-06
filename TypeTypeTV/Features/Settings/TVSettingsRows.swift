import SwiftUI

struct TVSettingsRows: View {
  let group: TVSettingsGroup
  @ObservedObject var model: LiveTVSettingsModel
  @ObservedObject var coordinator: RootCoordinator
  @Binding var picker: TVPickerRequest?
  var rowFocus: FocusState<String?>.Binding
  @AppStorage(TVDeviceSetting.introKey) var intro = "full"
  @AppStorage(TVDeviceSetting.backdropKey) var backdrop = true

  private static let qualities = ["auto", "2160p", "1440p", "1080p", "720p", "480p", "360p"]
  private static let speeds: [Double] = [0.75, 1, 1.25, 1.5, 2]

  var body: some View {
    switch group {
    case .playback: playback
    case .content: content
    case .blocked: blocked
    case .performance: performance
    case .account: account
    case .instance: instance
    case .about:
      TVSettingRow(systemImage: "number", title: "Version", trailing: .value(Bundle.main.version))
    }
  }

  @ViewBuilder
  private var playback: some View {
    if let settings = model.settings {
      choice("4k.tv", "Default quality", "The quality a video starts in. Auto picks the best your TV can show.",
             Self.qualities.map { TVChoice(id: $0, label: Self.qualityLabel($0)) }, settings.defaultQuality) { value in
        { $0.defaultQuality = value }
      }
      choice("speedometer", "Playback speed", "The speed a video starts at.",
             Self.speeds.map { TVChoice(id: String($0), label: "\($0.formatted())×") }, String(settings.defaultPlaybackSpeed ?? 1)) { value in
        { $0.defaultPlaybackSpeed = Double(value) }
      }
      toggle("forward.end.alt", "Autoplay next video", "Start the next video in the queue after a short countdown.", settings.autoplay) {
        $0.autoplay.toggle()
      }
      toggle("captions.bubble", "Show captions by default", "Turn captions on whenever a video has them.", settings.subtitlesEnabled) {
        $0.subtitlesEnabled.toggle()
      }
      choice("forward", "Sponsor segments", "What to do with sponsored parts of a video.",
             [TVChoice(id: "auto_skip", label: String(localized: "Skip automatically")),
              TVChoice(id: "mark_only", label: String(localized: "Mark only")),
              TVChoice(id: "disabled", label: String(localized: "Off"))], settings.sponsorBlockMode) { value in
        { $0.sponsorBlockMode = value }
      }
      toggle("clock.arrow.circlepath", "Save watch history", "Keep a record of what you watch to resume where you left off.",
             !settings.disableWatchHistory) { $0.disableWatchHistory.toggle() }
    } else {
      ProgressView()
    }
  }

  @ViewBuilder
  private var content: some View {
    if let settings = model.settings {
      choice("house", "Start on", "The screen the app opens on.",
             [TVChoice(id: "home", label: String(localized: "Home")), TVChoice(id: "history", label: String(localized: "History")),
              TVChoice(id: "favorites", label: String(localized: "Favorites")),
              TVChoice(id: "watch-later", label: String(localized: "Watch later"))], settings.defaultLandingPage) { value in
        { $0.defaultLandingPage = value }
      }
      choice("magnifyingglass", "Search service", "Where a new search looks first.",
             [0, 5, 6].map { TVChoice(id: String($0), label: VideoService.service(for: $0).name) }, String(settings.defaultService)) { value in
        { $0.defaultService = Int(value) ?? 0 }
      }
      toggle("play.circle", "Continue watching", "The videos you started, at the top of Home.", !settings.hideContinueWatching) {
        $0.hideContinueWatching.toggle()
      }
      toggle("sparkles.tv", "Recommendations", "Suggested videos on Home.", !settings.hideHomeRecommendations) {
        $0.hideHomeRecommendations.toggle()
      }
      toggle("rectangle.stack", "More videos", "Related videos on a video page and in the player.", !settings.hideRelatedVideos) {
        $0.hideRelatedVideos.toggle()
      }
      toggle("text.bubble", "Comments", "Comments under a video.", !settings.hideComments) { $0.hideComments.toggle() }
      toggle("rectangle.portrait", "Shorts", "Short vertical videos in lists and search.", !settings.hideShorts) {
        $0.hideShorts.toggle()
      }
    } else {
      ProgressView()
    }
  }
}
