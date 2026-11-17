import SwiftUI

extension TVPlayerContent {
  func prepareActions() async {
    async let state: Void = actions.prepare()
    async let subscription: Void = engagement.prepare()
    _ = await (state, subscription)
  }

  func openTwitchChannel() {
    session.closePanel()
    onOpenChannel(controller.video.uploaderURL)
  }
}
