import Foundation

extension LivePlaybackCoordinator {
  // Like Android: outside a queue, autoplay plays the first related video after the countdown.
  var upcomingRelated: LiveVideoItem? {
    controller?.stream?.relatedStreams.first {
      isPlayable($0) && $0.url != currentVideo?.url && hiddenVideos?.hides($0) != true
    }
  }

  // The video autoplay would open when this one ends, known before the end so a player can announce it.
  var upcomingVideo: LiveVideoItem? {
    guard queue.isActive else { return upcomingRelated }
    guard queue.repeatMode != .one, let index = queue.nextIndex, queue.videos.indices.contains(index) else { return nil }
    return queue.videos[index]
  }

  var autoplayCountdownSeconds: Int {
    appPreferences.preferences.playerAutoplayCountdownSeconds
  }
}
