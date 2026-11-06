import SwiftUI

extension TVPlayerContent {
  var upNextVideo: LiveVideoItem? {
    guard controller.autoplayEnabled, !session.upNextDismissed, !session.controlsVisible, session.panel == nil,
      !session.scrub.isActive, !session.isLive, let next = playback.upcomingVideo,
      LiveUpNextTimeline.inWindow(position: controller.position, duration: controller.duration, window: upNextWindow)
    else { return nil }
    return next
  }

  var upNextFill: Double {
    LiveUpNextTimeline.fill(position: controller.position, duration: controller.duration, window: upNextWindow)
  }

  var upNextSecondsLeft: Int {
    LiveUpNextTimeline.secondsLeft(position: controller.position, duration: controller.duration)
  }

  private var upNextWindow: TimeInterval {
    LiveUpNextTimeline.window(duration: controller.duration, countdownSeconds: playback.autoplayCountdownSeconds)
  }
}
