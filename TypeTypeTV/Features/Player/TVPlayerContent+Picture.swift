import SwiftUI

extension TVPlayerContent {
  // The picture and what is drawn over it. With the live chat open it keeps the left of the screen and the
  // chat its own column, as YouTube's and Android TV's players do, so no message covers the stream.
  var picture: some View {
    ZStack {
      TVPlayerVideoSurface(controller: controller)
      if controller.supportsBulletComments, controller.bulletCommentsEnabled {
        LiveDanmakuOverlay(controller: controller).allowsHitTesting(false).ignoresSafeArea()
      }
      // The top right corner of Android TV's player: statistics, then the marked part being watched.
      VStack(alignment: .trailing, spacing: 20) {
        if session.statsShown { TVPlaybackStats(controller: controller) }
        if controller.sponsorBlockShowCurrentSegment, session.panel == nil { TVSponsorLabel(controller: controller) }
      }
      .padding(.trailing, TVDimens.safeStart).padding(.top, 80)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .allowsHitTesting(false)
      if controller.audioOnly { TVAudioOnlyPoster(video: controller.video).transition(.opacity) }
      TVCaptionOverlay(controller: controller, subtitles: controller.nativeSubtitles, raised: session.controlsVisible)
    }
    .padding(.trailing, chatInset)
  }

  var chatAvailable: Bool {
    hasChatService && session.isLive && LiveChatSupport.supports(videoURL: controller.video.url)
  }

  var chatVisible: Bool {
    chatAvailable && session.chatShown && chat.buffer.status != .ended
  }

  var chatInset: CGFloat { chatVisible ? TVLiveChatPanel.width : 0 }
}
