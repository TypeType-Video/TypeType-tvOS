import SwiftUI

extension TVPlayerContent {
  var endScreenCards: [LiveEndScreenElement] {
    guard controller.settings.hideEndScreens != true, !controller.audioOnly, !session.controlsVisible,
      session.panel == nil, !session.scrub.isActive, let elements = controller.stream?.endScreenElements
    else { return [] }
    let time = controller.position
    return elements.filter { $0.isUsable && $0.kind != .website && $0.isVisible(at: time) }
  }

  var endScreenAspectRatio: CGFloat {
    guard let video = controller.preparation?.video, video.width > 0, video.height > 0 else { return 16 / 9 }
    return CGFloat(video.width) / CGFloat(video.height)
  }

  @ViewBuilder
  var endScreen: some View {
    let cards = endScreenCards
    if !cards.isEmpty {
      TVEndScreenLayer(
        elements: cards, videoAspectRatio: endScreenAspectRatio, focused: endScreenFocused, focus: $focus,
        onOpen: openEndScreen
      )
      .padding(.trailing, chatInset)
      .onDisappear { if endScreenFocused { leaveEndScreen() } }
    }
  }

  func focusEndScreen() -> Bool {
    guard let first = endScreenCards.first else { return false }
    TVJournal.note("player", "end screen focused, \(endScreenCards.count) cards")
    endScreenFocused = true
    focus = .endScreen(first.id)
    return true
  }

  func leaveEndScreen() {
    endScreenFocused = false
    focus = restingFocus
  }

  private func openEndScreen(_ element: LiveEndScreenElement) {
    TVJournal.note("player", "end screen open \(element.kind?.rawValue ?? "?")")
    endScreenFocused = false
    guard let url = URL(string: element.url), let destination = LiveMediaLinkResolver.destination(for: url) else {
      return focus = restingFocus
    }
    switch destination {
    case let .video(video):
      playback.open(video)
    case let .channel(channelURL):
      onOpenChannel(channelURL)
    case let .playlist(playlist):
      onOpenPlaylist(playlist)
    case .twitch:
      focus = restingFocus
    }
  }
}
